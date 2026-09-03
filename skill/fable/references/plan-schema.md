# Plan schema (authoritative contract)

Every Fable/Opus orchestration plan MUST conform to this schema. Subagents will follow the plan literally — ambiguity in the plan becomes a bug in the implementation.

## Top-level structure

```yaml
plan:
  objective: <one sentence, verbatim from the user>
  scope_in: <bulleted list of changes owned by this plan>
  scope_out: <bulleted list of what is explicitly NOT changing>
  assumptions: <bulleted, each must be verified before node dispatch>
  risks: <bulleted, ordered by likelihood × impact>
  acceptance_criteria:
    - <observable, testable criterion>
    - <observable, testable criterion>
  invariants: <bulleted, the things that must remain true throughout>
  edge_cases:           # every edge case MUST appear here
    - case: <name>
      when: <condition that triggers it>
      behavior: <what the system does>
      handled_by_node: <node-id>
  task_graph:
    nodes:
      - id: <kebab-case>
        role: <planner | implementer | verifier | integrator | adjudicator>
        model_or_agent_type: <pinned callable agent_type, never a raw model>
        owns_files:         # exclusive ownership — no other node may touch these
          - <relative path>
        owns_responsibility: <one-line human description>
        depends_on: [<node-id>, ...]
        can_run_parallel_with: [<node-id>, ...]
        steps:               # exhaustive step list — subagent does NOT get to improvise
          - step: 1
            action: <verb + concrete artifact>
            inputs: <what this step needs>
            outputs: <what this step produces>
            exit_criteria: <checkable condition>
          - step: 2
            ...
        verification:        # how this node proves it worked — not the whole plan, just this node
          - command: <exact command or check>
            expects: <expected result>
        stop_condition: <single sentence: when does this node stop?>
    edges:
      - from: <node-id>
        to: <node-id>
        contract: <artifact that flows from `from` to `to`>
  final_verification:
    - command: <exact command>
      expects: <expected result>
    - command: <exact command>
      expects: <expected result>
  completion_signal: <single short line, e.g. "all checks pass and feature visible at /path">
```

## Hard rules

1. **`objective`** must be a verbatim quote of the user's words (or the closest faithful paraphrase if the user was vague). Never invent an objective.
2. **`edge_cases` is mandatory.** If a node has zero edge cases, that is itself a flag — re-examine the node. A non-trivial implementation always has at least: empty input, boundary values, concurrent access, failure path, error message shape.
3. **`steps` is mandatory per node.** Each node must list every step it will perform. "Implement X" is not a step — it is a node title. A step is one verb + one artifact.
4. **`verification` per node** is mandatory. Subagents must be able to run it themselves.
5. **`stop_condition` per node** is one sentence. If the node cannot write a stop_condition in one sentence, the node is too coarse — split it.
6. **`can_run_parallel_with`** must be set explicitly. Empty list = "no parallel candidates identified", which is itself a signal to the orchestrator.
7. **`owns_files`** is exclusive. Two nodes must NEVER own overlapping files. If they would, introduce a serializing node in between.
8. **No invented models.** If the plan calls for a model/agent not in the callable menu, the plan is wrong — return to Fable for a blocker report, do not silently substitute.
9. **`completion_signal`** is one line. When the orchestrator sees this exact line, it stops.

## Why this shape

The subagents reading this plan are not Fable — they have no judgment to fall back on. Every ambiguity is a bug. The schema forces Fable to make every decision explicit, every boundary clear, every exit condition testable. If a subagent ever has to ask "what do I do here?", the plan failed.
