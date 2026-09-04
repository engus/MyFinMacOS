# Using the agent methodology bootstrap

This repository begins with no product modules. The empty module index is intentional.

## Validator dependency

The validator uses `jsonschema` to enforce the portable JSON Schema documents. Install the development dependency before running it:

```bash
python3 -m pip install -r requirements-dev.txt
```

## Add a first module

In the same change:

1. Add an entry to `agent/module-index.json` with the module's roots, entrypoints, manifest path, and module dependencies.
2. Create the matching `agent/modules/<module-id>.json` manifest with `module_id`, purpose, and significant paths.
3. Mark a path `implemented` only if it exists; mark it `planned` only if it does not exist. Use `provenance: generated` only when it has a generator and a read-only argument-array `check` that includes `--check`; shell interpreters are rejected.
4. Add cross-module edges to `agent/dependency-graph.json` when the module uses another module's contract.
5. Run:

```bash
python3 scripts/validate_agent_contracts.py
```

The index routes work; manifests provide module detail. Neither proves a feature works: inspect production code and run relevant tests for implementation claims.
