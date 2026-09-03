#!/usr/bin/env bash
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  echo "Claude Code CLI is not available on PATH." >&2
  exit 127
fi

if [[ $# -gt 0 ]]; then
  packet="$*"
else
  packet="$(cat)"
fi

if [[ -z "${packet//[[:space:]]/}" ]]; then
  echo "Provide a non-empty orchestration packet on stdin or as arguments." >&2
  exit 64
fi

system_prompt='You are the orchestration controller for Codex. You are one of: Claude Fable 5.1, Claude Opus 5.x, Kimi K3, or GPT-Sol. You plan and adjudicate only; you NEVER write code, you NEVER execute tools, you NEVER assign yourself implementation. Your only job is to produce a complete, code-aware, edge-case-explicit, step-by-step plan that another agent will execute literally. Use only the supplied packet.

The plan you return MUST conform to the schema in references/plan-schema.md in full. Specifically it MUST contain, in this order, with these exact keys:

1. objective — verbatim or faithful paraphrase of the user request
2. scope_in, scope_out — explicit lists
3. assumptions — bulleted, each must be verifiable before dispatch
4. risks — ordered by likelihood × impact
5. acceptance_criteria — observable, testable, exhaustive
6. invariants — what must remain true throughout
7. edge_cases — at minimum for every node: empty input, boundary values, concurrent access, failure path, error message shape. Every edge_case has {case, when, behavior, handled_by_node}
8. task_graph.nodes[] — each node has: id, role, model_or_agent_type, owns_files (exclusive), owns_responsibility, depends_on, can_run_parallel_with, steps[] (exhaustive: each step has action, inputs, outputs, exit_criteria), verification[] (exact commands + expects), stop_condition (one sentence)
9. task_graph.edges[] — {from, to, contract}
10. final_verification[] — exact commands + expects
11. completion_signal — one short line

Hard rules:
- Every implementation node uses GPT-5.6 Luna or DeepSeek V4 Flash only, pinned to a callable agent_type (opencode-go-responses/gpt-5.6-luna or opencode-go/deepseek-v4-flash). No other model.
- owns_files is exclusive across nodes. Two nodes MUST NEVER own overlapping files. If they would, insert a serializing node.
- A step is one verb + one concrete artifact. "Implement X" is not a step — it is a node title. Steps must be small enough that a subagent can follow them without judgment calls.
- verification per node is exact commands with expected results — subagents run them.
- stop_condition per node is one sentence. If a node cannot write a stop_condition in one sentence, split the node.
- edge_cases is mandatory. A node with zero edge cases is itself a flag — re-examine.
- Do not invent models. If no allowed implementation route is callable, report the blocker; never silently substitute.
- Do not expose chain-of-thought; provide decisions and brief rationale only.
- Do not include code blocks in your output. Plans are decision artifacts, not implementation artifacts.
- Code-aware specifics: name concrete types, function signatures, file paths, command names, and expected outputs. Subagents follow the plan literally — if you say "the helper", say which file; if you say "the command", give the exact invocation.

Apply this classifier only when the user did not explicitly choose an allowed implementation route. Loop construction, repeated iteration, and high-throughput mechanical work use a callable OpenCode Go agent pinned to opencode-go/deepseek-v4-flash. All other implementation prefers a callable OpenCode Go agent pinned to opencode-go-responses/gpt-5.6-luna, then opencode-go/deepseek-v4-flash. Planning, research, and review use normal task fit but remain orchestration support, not implementation. Fable 5.1 adjudication stays outside the worker graph. Prefer a callable agent_type that pins both model and provider over a raw cross-provider model string, and classify by that pin rather than the agent display name. A model merely discovered in local config is not callable. If neither allowed implementation route is callable, report the blocker; never invent or silently substitute a model or agent. After any applicable approval gate, start the answer with one short line per ready assignment in the form: Agent — Model: bounded responsibility.

INLINE SCHEMA REFERENCE (do not rely on file reads; this is the contract you must satisfy):

plan:
  objective: <one sentence verbatim from user>
  scope_in: [<bullet>]
  scope_out: [<bullet>]
  assumptions: [<bullet>]
  risks: [<bullet, ordered by likelihood × impact>]
  acceptance_criteria: [<observable, testable>]
  invariants: [<bullet>]
  edge_cases:
    - case: <name>
      when: <trigger condition>
      behavior: <system behavior>
      handled_by_node: <node-id>
  task_graph:
    nodes:
      - id: <kebab-case>
        role: <planner|implementer|verifier|integrator|adjudicator>
        model_or_agent_type: <pinned callable agent_type>
        owns_files: [<relative path>]   # exclusive — no overlap
        owns_responsibility: <one-line>
        depends_on: [<node-id>]
        can_run_parallel_with: [<node-id>]
        steps:
          - step: 1
            action: <verb + concrete artifact>
            inputs: <what this step needs>
            outputs: <what this step produces>
            exit_criteria: <checkable condition>
        verification:
          - command: <exact command>
            expects: <expected result>
        stop_condition: <one sentence>
    edges:
      - from: <node-id>
        to: <node-id>
        contract: <artifact>
  final_verification:
    - command: <exact command>
      expects: <expected result>
  completion_signal: <one short line>'

fable_effort="${FABLE_EFFORT:-low}"

# Orchestrator selection.
#
# Allowed orchestrators: Claude Fable 5.1, Claude Opus 5.x, Kimi K3, GPT-Sol.
# The orchestrator name comes from (in priority order):
#   1. --orchestrator CLI flag
#   2. FABLE_ORCHESTRATOR env var
#   3. Auto-detect: try each in priority order until one is callable
#
# Auto-detect priority (matches SKILL.md):
#   Claude Fable 5.1 → Claude Opus 5.x → Kimi K3 → GPT-Sol
#
# Each orchestrator has its own CLI:
#   fable / opus → `claude` CLI (Claude Code). Pass --model <model-slug>.
#   kimi-k3      → `kimi` CLI.    Pass the system prompt natively.
#   gpt-sol      → `gpt-sol` CLI (or `sol` alias). Pass the system prompt natively.
orchestrator="${FABLE_ORCHESTRATOR:-auto}"
positional_packet=""
while (($#)); do
  case "$1" in
    --orchestrator)
      (($# >= 2)) || { echo '--orchestrator requires a value.' >&2; exit 64; }
      orchestrator="$2"
      shift 2
      ;;
    --orchestrator=*)
      orchestrator="${1#*=}"
      shift
      ;;
    *)
      positional_packet+="${1} "
      shift
      ;;
  esac
done
if [[ -n "$positional_packet" ]]; then
  packet="$positional_packet"
fi

run_claude_orchestrator() {
  local model="$1"
  local -a model_args=()
  if [[ -n "$model" ]]; then model_args=(--model "$model"); fi
  set +e
  local out
  out="$(claude \
    --print \
    "${model_args[@]+"${model_args[@]}"}" \
    --effort "$fable_effort" \
    --permission-mode dontAsk \
    --tools "" \
    --no-session-persistence \
    --output-format text \
    --system-prompt "$system_prompt" \
    "$packet" 2>&1)"
  local rc=$?
  set -e
  printf '%s\n' "$out"
  return $rc
}

run_kimi_orchestrator() {
  if ! command -v kimi >/dev/null 2>&1; then
    echo "kimi CLI not available on PATH" >&2
    return 127
  fi
  set +e
  local out
  out="$(kimi --print --no-session-persistence --system-prompt "$system_prompt" "$packet" 2>&1)"
  local rc=$?
  set -e
  printf '%s\n' "$out"
  return $rc
}

run_gpt_sol_orchestrator() {
  local cli=""
  if command -v gpt-sol >/dev/null 2>&1; then cli="gpt-sol"
  elif command -v sol >/dev/null 2>&1; then cli="sol"
  else
    echo "gpt-sol CLI not available on PATH" >&2
    return 127
  fi
  set +e
  local out
  out="$($cli --print --no-session-persistence --system-prompt "$system_prompt" "$packet" 2>&1)"
  local rc=$?
  set -e
  printf '%s\n' "$out"
  return $rc
}

# Returns 0 with stdout=response when selected, or non-zero if the orchestrator
# could not be reached. Caller chooses the next orchestrator on non-zero.
try_orchestrator() {
  local name="$1"
  case "$name" in
    fable|fable-5.1|claude-fable-5.1)
      if ! command -v claude >/dev/null 2>&1; then return 127; fi
      # Build model candidates the same way the original helper did.
      local candidates=()
      if [[ -n "${FABLE_MODEL:-}" ]]; then
        candidates=("$FABLE_MODEL")
      elif [[ -n "${FABLE_MODEL_CANDIDATES:-}" ]]; then
        read -r -a candidates <<<"$FABLE_MODEL_CANDIDATES"
      else
        if command -v jq >/dev/null 2>&1; then
          for model_file in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" \
            "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json.bak" \
            "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/stats-cache.json"; do
            [[ -f "$model_file" ]] || continue
            while IFS= read -r m; do
              [[ -n "$m" ]] && candidates+=("$m")
            done < <(jq -r '.. | objects | .model? // empty, (.modelUsage? // {} | keys[])' "$model_file" 2>/dev/null)
          done
        fi
        ((${#candidates[@]})) || candidates=("")
      fi
      local response="" sel=""
      for m in "${candidates[@]}"; do
        if out="$(run_claude_orchestrator "$m")"; then
          response="$out"; sel="${m:-default}"
          printf 'Fable 5.1 speaks (%s):\n\n%s\n' "$sel" "$response"
          return 0
        fi
      done
      return 69
      ;;
    opus|opus-5|claude-opus-5)
      if ! command -v claude >/dev/null 2>&1; then return 127; fi
      # Same Claude CLI; force Opus 5.x via --model override or env.
      local opus_model="${OPUS_MODEL:-}"
      if [[ -z "$opus_model" && -n "${FABLE_MODEL_CANDIDATES:-}" ]]; then
        # pick the first candidate containing "opus"
        read -r -a tmparr <<<"$FABLE_MODEL_CANDIDATES"
        for cand in "${tmparr[@]}"; do
          if [[ "$cand" == *opus* ]]; then opus_model="$cand"; break; fi
        done
      fi
      local out sel="${opus_model:-opus-5-x}"
      out="$(run_claude_orchestrator "$opus_model")" || return 69
      printf 'Opus 5.x speaks (%s):\n\n%s\n' "$sel" "$out"
      return 0
      ;;
    kimi|kimi-k3)
      local out
      out="$(run_kimi_orchestrator)" || return 69
      printf 'Kimi K3 speaks:\n\n%s\n' "$out"
      return 0
      ;;
    gpt-sol|sol)
      local out
      out="$(run_gpt_sol_orchestrator)" || return 69
      printf 'GPT-Sol speaks:\n\n%s\n' "$out"
      return 0
      ;;
    *)
      echo "Unknown orchestrator: $name. Allowed: fable, opus, kimi-k3, gpt-sol." >&2
      return 64
      ;;
  esac
}

if [[ "$orchestrator" == "auto" ]]; then
  for cand in fable opus kimi-k3 gpt-sol; do
    if try_orchestrator "$cand"; then exit 0; fi
  done
  echo "No usable orchestrator was found. Tried: fable, opus, kimi-k3, gpt-sol." >&2
  exit 69
else
  try_orchestrator "$orchestrator" || {
    echo "Orchestrator '$orchestrator' failed or is not callable." >&2
    exit 69
  }
fi
