# Fable-Decideds

A small, local-first orchestration skill for Codex. The orchestrator writes the
**entire plan**; the implementation workers execute it literally.

> **Why "Fable-Decideds"?** Fable (or any of the other three allowed
> orchestrators) **decides everything up front**: scope, edge cases, steps,
> verification, stop conditions, file ownership. The implementers do not get to
> improvise. The plan is the contract.

## Orchestrator (any of)

| Priority | Orchestrator | How to invoke |
|---------:|--------------|---------------|
| 1 | **Claude Fable 5.1** | local Claude Code (`claude` CLI) |
| 2 | **Claude Opus 5.x** | local Claude Code (`claude` CLI, `--model` override) |
| 3 | **Kimi K3** | `kimi` CLI |
| 4 | **GPT-Sol** | `gpt-sol` CLI (or `sol` alias) |

Only these four may orchestrate. If none is callable, the task is **blocked** —
never silently substituted.

## Implementer (any of)

| Implementer | OpenCode Go agent pin |
|-------------|-----------------------|
| **GPT-5.6 Luna** (default) | `opencode-go-responses/gpt-5.6-luna` |
| **DeepSeek V4 Flash** (loops, mechanical work) | `opencode-go/deepseek-v4-flash` |

Only these two may implement. No other model is permitted on an implementation
node.

## What the plan contains

Every plan returned by `scripts/ask_fable.sh` MUST conform to
[`skill/fable/references/plan-schema.md`](skill/fable/references/plan-schema.md)
in full. Mandatory sections:

- `objective` (verbatim from the user)
- `scope_in` / `scope_out`
- `assumptions`, `risks`, `acceptance_criteria`, `invariants`
- **`edge_cases`** — at minimum per node: empty input, boundary values,
  concurrent access, failure path, error message shape
- `task_graph.nodes[]` — each node with exclusive `owns_files`, exhaustive
  `steps[]`, per-node `verification[]`, one-sentence `stop_condition`
- `task_graph.edges[]`, `final_verification[]`, `completion_signal`

A plan missing any of these is rejected by Codex and sent back to the
orchestrator for completion.

## Layout

```text
skill/fable/
├── SKILL.md                       (orchestrator selection, invocation, workflow)
├── agents/openai.yaml
├── scripts/ask_fable.sh           (multi-orchestrator dispatcher)
└── references/plan-schema.md      (authoritative plan contract)
assets/fable-orchestrator.svg
install.sh
tests/test_skill.sh
```

## Install

```bash
./install.sh --dry-run    # preview
./install.sh --copy       # install to ~/.codex/skills/fable
./install.sh --copy --target "$PWD/.local/codex/skills"
```

Idempotent. Reads only this repository and the destination path. Never reads,
creates, or modifies credentials.

## Use

```bash
# Auto-detect orchestrator: Fable → Opus → Kimi K3 → GPT-Sol
printf '%s' "$PACKET" | scripts/ask_fable.sh

# Explicit orchestrator
scripts/ask_fable.sh --orchestrator fable    "build the feature"
scripts/ask_fable.sh --orchestrator opus     "debug this"
scripts/ask_fable.sh --orchestrator kimi-k3  "refactor module X"
scripts/ask_fable.sh --orchestrator gpt-sol  "ship the migration"

# Or via env
FABLE_ORCHESTRATOR=kimi-k3 printf '%s' "$PACKET" | scripts/ask_fable.sh
```

## Test

```bash
tests/test_skill.sh
```

Checks shell syntax, the copied source files, required routing strings, basic
YAML structure, optional `xmllint` XML validation, SVG safety constraints, a
temporary-home dry run, an idempotent copy, and common credential-shaped strings.

## License

MIT. See [LICENSE](LICENSE).
