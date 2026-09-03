# Fable-Decideds

**Decide everything up front, then execute literally.**

A wrapper entry point around [Sahir619/fable-method](https://github.com/Sahir619/fable-method) (MIT, 4 skills, 9 domain adapters, 15 eval rounds, 260+ agent runs) that adds an **implementer pin**: when fable-method says "act", fable-decideds restricts implementation to **GPT-5.6 Luna** and **DeepSeek V4 Flash** only.

> Why "Fable-Decideds"? Fable (or any orchestrator running fable-method) **decides everything up front** — scope, edge cases, steps, verification, stop conditions, file ownership. The implementers do not get to improvise. The plan is the contract.

## What's in the box

| Skill | What it does |
|---|---|
| **`fable-decideds`** | Entry point: pins fable-method's loop to the implementer set |
| `fable-method` | The workflow itself: classify → define done → evidence → decide → act → verify → report |
| `fable-loop` | End-to-end orchestration (parallel evidence subagents, intent gate, adversarial verifiers) |
| `fable-judge` | Adversarial verification of finished work (VERIFIED / WITH CAVEATS / REFUTED) |
| `fable-domain` | Discuss → research → generate a trusted skill bundle for a new domain |

## Implementer pin (hard constraint)

Only two implementers are permitted on implementation nodes:

| Implementer | OpenCode Go agent pin |
|---|---|
| **GPT-5.6 Luna** (default) | `opencode-go-responses/gpt-5.6-luna` |
| **DeepSeek V4 Flash** (loops, mechanical work) | `opencode-go/deepseek-v4-flash` |

A plan whose implementation nodes name any other model is **rejected**. Re-send the orchestrator for a corrected plan.

## Orchestrator (independent choice)

The orchestrator is **not** chosen by fable-decideds. Allowed orchestrators: **Claude Fable 5.1**, **Claude Opus 5.x**, **Kimi K3**, **GPT-Sol**. If none is callable, the task is blocked.

## Evidence

This package inherits fable-method's eval log: 15 rounds, 260+ runs, 14 trap scenarios, blind LLM judges that verify by diffing and executing — never by reading reports. See [`eval/RESULTS.md`](eval/RESULTS.md). One case study per scenario lives in [`eval/cases/`](eval/cases/).

Headline lifts (vs. bare models, measured across rounds):

| Trap | Without | With the method |
|---|---|---|
| Spec-vs-test conflict (Haiku) | 0 of 4 runs surfaced it | **4 of 4** |
| Planted fraud in "work complete" (Haiku) | 4 and 3 of 5 | **5 of 5, both runs** |
| Unauthorized staging deploy (bare Fable 5) | **1 of 2 runs deployed unbidden** | gate exists because of this |
| Cross-tier research bundle (Sonnet) | n/a | **10/10**, source-checked |
| Plain-language trap | varied | **lift on weak tier, null on capable** |

## Layout

```text
skills/
├── fable-decideds/   (entry point: implementer pin overlay)
├── fable-method/     (the loop: classify, define done, evidence, decide, act, verify, report)
│   └── references/
│       ├── failure-modes.md
│       ├── examples.md
│       ├── flowcharts.md
│       └── domains/    (9 sector adapters)
├── fable-loop/       (orchestrated multi-agent execution)
├── fable-judge/      (adversarial verification)
└── fable-domain/     (grow a new sector adapter)
assets/
eval/
├── scenarios/   (14 trap fixtures)
├── cases/       (per-scenario case studies)
└── results/     (15 rounds of blind judge output)
install.sh
```

## Install

```bash
# Manual install (macOS / Linux / Git Bash)
./install.sh

# Or as a Claude Code plugin (recommended)
# /plugin marketplace add charcoal9/fable-decideds-v2
# /plugin install fable-decideds@fable-decideds-v2
```

Manual install copies `fable-method`, `fable-loop`, `fable-judge`, and `fable-decideds` into `~/.claude/skills/`. Idempotent.

## Use

```text
/fable-decideds              # run the full loop
/fable-decideds plan <task>  # Steps 0-3 only; deliver the plan, stop for approval
/fable-decideds audit        # grade finished work against the loop
/fable-decideds report       # rewrite your answer per Step 6
```

For multi-agent orchestration: `/fable-loop`. For grading finished work: `/fable-judge`.

## Provenance

- **Workflow + evals:** [Sahir619/fable-method](https://github.com/Sahir619/fable-method) (MIT)
- **Implementer pin (overlay):** charcoal9/fable-decideds-v2 (this repo)
- The workflow is unchanged; fable-decideds only adds the implementer routing constraint.

## License

MIT. See [LICENSE](LICENSE). Eval results in `eval/RESULTS.md` are documented with citations to the committed transcript that backs each claim.
