# Agent navigation

0. If `[EXECUTION-CORE v2.1]` is not already present in current instructions, read `agent/execution-core.md`. Do not search for it.
1. Read `agent/module-index.json`.
2. Identify the owning module from its roots and entrypoints.
3. Read only that module's manifest at `agent/modules/<module-id>.json`.
4. Inspect relevant production code or configuration before making implementation claims.
5. Expand context only when a concrete unanswered question, dependency, contract uncertainty, or verification gap requires it.
6. Treat agent metadata as navigation, not implementation evidence.
7. Before changing a cross-module contract, inspect `agent/dependency-graph.json`.
8. Run explicit task checks and affected validators after changes.
9. Run `python3 scripts/validate_agent_contracts.py` when agent metadata or the execution core changes.
