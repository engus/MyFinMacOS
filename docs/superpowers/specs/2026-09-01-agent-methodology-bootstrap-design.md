# Agent Methodology 2.1 Bootstrap

## Purpose

Bootstrap the repository-local navigation and validation layer from Agent Project Methodology 2.1 without inventing product modules or adding product-specific metadata.

## Scope

The bootstrap adds:

- `AGENTS.md` containing only deterministic boot navigation;
- `agent/execution-core.md`, with the `[EXECUTION-CORE v2.1]` sentinel and compact execution rules;
- methodology metadata, a module index, and a dependency graph;
- JSON Schemas for those documents and future module manifests;
- a Python validator and tests for its core behavior;
- concise bootstrap documentation explaining how a real module is added later.

The repository currently has no product code. The module index and dependency graph will therefore start empty. No placeholder product module or fabricated evidence bundle will be created.

## Layout

```text
AGENTS.md
agent/
  execution-core.md
  methodology.json
  module-index.json
  dependency-graph.json
  modules/
  schemas/
scripts/
  validate_agent_contracts.py
tests/
  test_validate_agent_contracts.py
docs/
  agent-methodology.md
```

`AGENTS.md` points to the execution core, then to the module index. It does not duplicate the execution rules. The execution core uses the v2.1 sentinel and contains only actionable execution guidance, not this full methodology rationale.

## Validation

`scripts/validate_agent_contracts.py` will:

1. parse and schema-validate agent JSON documents;
2. verify methodology 2.1 execution-core sentinel wiring from `AGENTS.md`;
3. verify index-to-manifest and manifest-to-index integrity;
4. verify module dependencies reference known module IDs;
5. enforce declared path lifecycle (`implemented`/`deprecated` exists; `planned` does not exist);
6. validate generated implemented paths only when present in metadata, using an explicitly configured read-only check.

The validator will not infer code dependencies, execute arbitrary shell strings, or claim to prove natural-language policy effectiveness. Generated checks will be parsed as command arrays and executed without a shell.

## Testing

Tests will build temporary miniature repositories and cover successful validation plus invalid sentinel wiring, orphan/missing manifests, unknown dependencies, and invalid lifecycle paths. They will be written before the validator implementation.

## Extension path

When product code is introduced, add one index entry and its manifest in the same change, then run the validator. Add generated-artifact checks, deprecation allowlists, and runtime evidence only when the real project contains those concerns.
