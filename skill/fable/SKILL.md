---
name: fable
description: Use the locally authenticated Claude Fable 5.1, Claude Opus 5.x, Kimi K3, or GPT-Sol as the planning orchestrator for a task. The orchestrator writes a complete, code-aware, edge-case-explicit step-by-step plan; implementation is then executed by GPT-5.6 Luna or DeepSeek V4 Flash subagents. Use when the user invokes $fable or asks to orchestrate Codex agents.
---

# Fable orchestrator (detailed-plan mode)

The **orchestrator** — Claude Fable 5.1 (primary), Claude Opus 5.x (fallback), Kimi K3, or GPT-Sol — supplies the **entire plan** for the task: objective, scope, assumptions, risks, edge cases, an exhaustive step list per node, per-node verification, stop conditions, parallel-safety map, and final verification. The plan is the artifact. Codex remains the runtime that spawns workers, owns files, runs tools, executes the plan verbatim, verifies the result, and reports to the user. Subagents do **not** improvise — they read the plan and execute it step by step.

## Roles

- **Orchestrator** — one of `Claude Fable 5.1` (primary), `Claude Opus 5.x` (fallback), `Kimi K3`, or `GPT-Sol`. Plans only. Owns `task_graph`, `edge_cases`, `verification`, `stop_condition`, `completion_signal`. Never writes code. The orchestrator's plan is the contract every implementation worker reads.
- **GPT-5.6 Luna** — callable OpenCode Go agent, pinned to `opencode-go-responses/gpt-5.6-luna`. Default implementation model.
- **DeepSeek V4 Flash** — callable OpenCode Go agent, pinned to `opencode-go/deepseek-v4-flash`. Used for loops, repeated iteration, and high-throughput mechanical work.
- **Codex (this runtime)** — picks the orchestrator, spawns workers from the plan, owns files, runs verification, reports.

## Orchestrator selection

The orchestrator must be one of: **Claude Fable 5.1**, **Claude Opus 5.x**, **Kimi K3**, **GPT-Sol**. No other model may orchestrate.

Selection rules (apply in order):

1. If the user explicitly names an orchestrator (`$fable orchestrate with kimi k3`, `$fable use opus`, `$fable use gpt-sol`, etc.), use that one.
2. Otherwise, in priority order: prefer **Claude Fable 5.1** if callable; else **Claude Opus 5.x** if callable; else **Kimi K3** if callable; else **GPT-Sol** if callable.
3. If none of the four is callable, report the blocker — never invent or silently substitute an orchestrator.

Each orchestrator must conform to the plan schema in [`references/plan-schema.md`](./references/plan-schema.md) identically. Kimi K3 and GPT-Sol are not Claude; pass the schema inline as a system prompt, the same way Fable gets it. Never use a non-Claude orchestrator with `--tools ""` or any Claude-only flag — use the orchestrator's native CLI invocation.

## Invocation

Treat everything after `$fable` as the objective. The orchestrator always owns planning. Implementation workers are restricted to GPT-5.6 Luna and DeepSeek V4 Flash:

- `$fable build the feature`
- `$fable debug this; orchestrator: kimi k3; implementer: gpt-5.6-luna`
- `$fable orchestrate with opus` — explicit orchestrator override
- `$fable use gpt-sol; implementer: deepseek-v4-flash` — explicit orchestrator + implementer

Model names are requests, not guesses. Before dispatch, inspect the current `spawn_agent` tool description and custom agent roles. Use only models or roles that are currently callable. If a requested model is unavailable, say so and use the closest available choice only when that substitution is low-risk; otherwise ask for a replacement.

For the simplest automatic path, the user can provide only an objective. Apply this ordered classifier when they did not explicitly choose a route:

- loop construction, repeated iteration, or high-throughput mechanical work: use a callable OpenCode Go agent pinned to `opencode-go/deepseek-v4-flash`;
- implementation: use a callable OpenCode Go agent pinned to `opencode-go-responses/gpt-5.6-luna`, then `opencode-go/deepseek-v4-flash`;
- orchestrator selection: apply the Orchestrator selection rules above (Fable → Opus → Kimi K3 → GPT-Sol).

Prefer an exposed `agent_type` that pins both model and provider. Never infer callability from a config file or send a raw model override across providers. An explicit implementation choice wins only when it is GPT-5.6 Luna or DeepSeek V4 Flash. Do not assign implementation to any other model. After any applicable approval gate, state only `<Agent> — <Model>: <bounded responsibility>`, then immediately start. Classify by the callable model pin, not the agent's display name. Do not show the full model catalog unless asked.

## What the orchestrator's plan MUST contain

The orchestrator does not return a sketch. Every plan returned by `scripts/ask_fable.sh` MUST conform to [`references/plan-schema.md`](./references/plan-schema.md) in full, regardless of which orchestrator produced it. A plan missing any of these sections is a **rejected plan** — Codex must send it back to the orchestrator for completion before dispatching any worker:

1. **`objective`** — verbatim or faithful paraphrase of the user's request.
2. **`scope_in` / `scope_out`** — explicit lists. What is changing, what is not.
3. **`assumptions`** — bulleted, each must be verified before the first node dispatches. An unverified assumption is a blocker.
4. **`risks`** — ordered by likelihood × impact.
5. **`acceptance_criteria`** — observable, testable, exhaustive. Every criterion must map to a verification step.
6. **`invariants`** — the things that must remain true throughout (existing behavior preserved, public API shape, perf budget, etc.).
7. **`edge_cases`** — every edge case the implementation could face. At minimum, every node must enumerate: empty input, boundary values, concurrent access, failure path, error message shape. If a node has zero edge cases, that is a flag to split the node.
8. **`task_graph.nodes[]`** — for each node:
   - `id` (kebab-case), `role`, `model_or_agent_type` (pinned agent_type, never raw model)
   - `owns_files` (exclusive — two nodes MUST NEVER own overlapping files)
   - `owns_responsibility` (one-line human description)
   - `depends_on` (explicit list, can be empty)
   - `can_run_parallel_with` (explicit list; empty list = "none identified")
   - **`steps[]` — exhaustive step list.** Each step is one verb + one concrete artifact: `action`, `inputs`, `outputs`, `exit_criteria`. Subagents follow these steps literally; they do not get to improvise.
   - **`verification[]` — per-node.** Exact commands or checks the node must run to prove it worked, with expected results.
   - **`stop_condition`** — one sentence. If a node cannot write a stop condition in one sentence, the node is too coarse — split it.
9. **`task_graph.edges[]`** — `from`, `to`, `contract` (the artifact that flows between them).
10. **`final_verification[]`** — exact commands with expected results, run by Codex after the graph completes.
11. **`completion_signal`** — one short line. When the orchestrator sees this exact line, it stops.

A plan that is a paragraph instead of this structure is rejected. A plan missing `edge_cases` is rejected. A plan with no per-node `steps` is rejected. A plan with no per-node `verification` is rejected. A plan with no `stop_condition` per node is rejected.

## OpenCode Go compatibility

Codex Router owns OpenCode Go provider setup, model discovery, and credentials; Fable must not duplicate them. A user adds the OpenCode Go API key once through the router's local secure setup. Never request or paste an API key in chat or store it in a Fable packet. Fable consumes only callable `opencode-go/` and `opencode-go-responses/` agents supplied by Codex, so it needs no proxy, dashboard, or second static model list. Start a new Codex task after changing the provider or agent definitions.

## Workflow

1. Read the objective and relevant local instructions. Inspect enough of the workspace to give Fable facts rather than assumptions.
2. Build a compact orchestration packet containing the objective, acceptance criteria, workspace context, constraints, protected files, evidence already gathered, callable worker menu, concurrency limit, and user preferences. Never put credentials in a packet.
3. Send the packet to `scripts/ask_fable.sh`. Use Claude's `fable` alias; do not read, copy, print, or modify Claude credentials.
4. **Reject any plan that does not conform to `references/plan-schema.md`.** Specifically: missing `edge_cases`, missing per-node `steps`, missing per-node `verification`, missing per-node `stop_condition`, two nodes owning overlapping files, or any implementation node assigned to a model other than GPT-5.6 Luna or DeepSeek V4 Flash. Re-send to Fable with a precise deficiency list.
5. Validate the graph against the actual task and current tools. Codex has final responsibility for safety and scope. Do not execute invented models, unsafe actions, or work outside the user's request.
6. Spawn independent ready nodes in parallel, up to the live collaboration limit. Pass every code-writing worker its **entire node block from the plan** — `steps`, `verification`, `stop_condition`, and the global `invariants` and `edge_cases` it must respect. Tell every worker that other agents share the workspace, so it must preserve and accommodate their edits.
7. Collect results, inspect changed files, and run the plan's `final_verification` block. For complex work, send a concise results packet back through the helper for the next graph or final adjudication. Cap this at three Fable calls unless the user asks to continue.
8. Finish only when `completion_signal` is observed, all `acceptance_criteria` are met, and `final_verification` passes. Report selected models, material changes, and concrete proof.

Whenever the helper returns Fable's orchestration output, display it verbatim under this exact heading:

```text
Fable 5.1 speaks:
```

Do not relabel ordinary Codex or worker-agent output as Fable speech.

## Boundaries

- The orchestrator plans and adjudicates; it does not silently replace the Codex workers.
- Exchange decisions, evidence, task packets, diffs, test results, and blockers, not hidden reasoning.
- Orchestration does not expand authorization. Publishing, deployment, destructive operations, spending, and external messages retain their normal approval boundaries.
- If delegation adds no value, use one worker or execute directly after the orchestrator's plan.
- **The orchestrator does not write code.** Its output is a plan that conforms to `references/plan-schema.md`. If a "plan" from the orchestrator contains code blocks, treat that as a violation and re-send for a plan-only response.
- **Orchestrator routing rule.** Only **Claude Fable 5.1**, **Claude Opus 5.x**, **Kimi K3**, or **GPT-Sol** may orchestrate. If none is callable, the task is blocked — do not silently fall back to any other model.

## Calling the orchestrator

Pass the packet as standard input:

```bash
printf '%s' "$PACKET" | /Users/arnavdas/.codex/skills/fable/scripts/ask_fable.sh
```

Do not place secrets in the packet. The helper uses the existing local CLI authentication (Claude Code for Fable/Opus, the respective native CLI for Kimi K3 and GPT-Sol) and creates no persistent session.
