---
name: fable-decideds
description: "Decide everything up front, then execute literally. Wrapper that pins fable-method's think/act/prove loop to callable implementer agents only."
---

# Fable-Decideds

> **This skill is an entry point and constraint overlay**, not a parallel workflow. It names the discipline (`fable-method`) and pins the implementer set; it does not redefine the loop.

The name says it: Fable (or any orchestrator running fable-method) **decides everything up front** — scope, edge cases, steps, verification, stop conditions, file ownership — and the implementers execute it literally. No improvisation.

## Workflow: fable-method

This skill delegates the loop to **`fable-method`** (Sahir619/fable-method, MIT). Read it in full before any work. In particular, follow Steps 0–3 (classify, define done, gather evidence, decide) before any edit, and Step 4's intent gate + recall gate before any behavior change. Step 5 (verify by observation) and Step 6 (outcome-first report) are non-negotiable.

Subcommands:

```
/fable-decideds plan <task>   Steps 0-3 only; deliver the plan, stop for approval
/fable-decideds audit         grade finished work against the loop
/fable-decideds report        rewrite the answer per Step 6
```

For multi-agent orchestration (parallel evidence + adversarial verification), use **`fable-loop`**. For grading finished work, use **`fable-judge`**. To grow a new domain adapter, use **`fable-domain`**.

## Implementer pin (hard constraint)

Only two implementers are permitted on **implementation nodes**:

| Implementer | OpenCode Go agent pin |
|-------------|-----------------------|
| **GPT-5.6 Luna** (default) | `opencode-go-responses/gpt-5.6-luna` |
| **DeepSeek V4 Flash** (loops, mechanical work) | `opencode-go/deepseek-v4-flash` |

No other model may appear in `model_or_agent_type` for an implementation node. **Orchestrator choice is independent** — fable-decideds does not pick an orchestrator; the runtime does, from among Claude Fable 5.1, Claude Opus 5.x, Kimi K3, or GPT-Sol.

## What this skill adds on top of fable-method

1. **Hard implementer pin.** A plan whose implementation nodes name any model other than GPT-5.6 Luna or DeepSeek V4 Flash is rejected; re-send the orchestrator for a corrected plan.
2. **File-ownership discipline, restated.** `owns_files` is exclusive across nodes; two nodes MUST NEVER own overlapping files. If the orchestrator's plan would overlap, insert a serializing node.
3. **Outcome-first report.** Per fable-method Step 6 — but the report MUST name which implementer ran each node and what each node's verification returned. No silent substitutions.

## When NOT to use this skill

- Trivial per the method's triviality gate: do it, verify with one obvious check, report in two sentences.
- Pure questions with no multi-step work: `fable-method` covers the shape.
- Inside an already-orchestrated workflow that owns its stages: that workflow owns the loop; apply `fable-method`'s rules within phases instead of nesting.

## Origin

This skill wraps the publicly available **`Sahir619/fable-method`** plugin (MIT, 4 skills, 9 domain adapters, 15 eval rounds, 260+ agent runs of evidence). Fable-decideds is an implementer-pinning overlay; the workflow itself is unchanged and lives in `skills/fable-method/`.
