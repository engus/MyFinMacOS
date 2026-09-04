# Agent Methodology Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a minimal, validated Agent Project Methodology 2.1 bootstrap for this otherwise empty repository.

**Architecture:** Repository-local JSON documents describe methodology wiring, module ownership, and module dependencies. A standard-library Python validator parses those documents, enforces their cross-document and filesystem contracts, and runs configured generated-artifact checks without invoking a shell. Tests use temporary repositories to exercise the validator through its public CLI.

**Tech Stack:** Python 3 (`argparse`, `json`, `pathlib`, `subprocess`, `unittest`) plus `jsonschema`; JSON Schema documents retained as portable contracts.

**Spec:** `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/docs/superpowers/specs/2026-09-01-agent-methodology-bootstrap-design.md`

## Global Constraints

- Do not invent a product module, generated artifact, or runtime evidence.
- `AGENTS.md` contains a pointer, not a copied execution core.
- `agent/execution-core.md` begins with `[EXECUTION-CORE v2.1]`.
- The validator must not execute shell command strings; generated checks use JSON argument arrays.
- Path lifecycle is strict: `planned` must not exist; `implemented` and `deprecated` must exist.

---

### Task 1: Bootstrap documents and schemas

**Files:**
- Create: `AGENTS.md`
- Create: `agent/execution-core.md`
- Create: `agent/methodology.json`
- Create: `agent/module-index.json`
- Create: `agent/dependency-graph.json`
- Create: `agent/modules/.gitkeep`
- Create: `agent/schemas/methodology.schema.json`
- Create: `agent/schemas/module-index.schema.json`
- Create: `agent/schemas/module-manifest.schema.json`
- Create: `agent/schemas/dependency-graph.schema.json`
- Create: `docs/agent-methodology.md`

**Interfaces:**
- Consumes: no product metadata; this repository has no product modules.
- Produces: empty valid index `{ "schema_version": 1, "modules": {} }` and empty graph `{ "schema_version": 1, "edges": [] }`.

- [ ] **Step 1: Create the minimal bootstrap JSON documents**

Create `agent/methodology.json` with:

```json
{
  "methodology": "agent-project-methodology",
  "version": "2.1",
  "module_index": "agent/module-index.json",
  "dependency_graph": "agent/dependency-graph.json",
  "module_manifests": "agent/modules",
  "schemas": "agent/schemas"
}
```

Create the empty module index and dependency graph specified above.

- [ ] **Step 2: Add deterministic boot instructions and compact core**

Make `AGENTS.md` point to `agent/execution-core.md` using the exact v2.1 sentinel; include routing, source-of-truth, cross-module, and validation rules only. Make the first non-empty execution-core line exactly:

```text
[EXECUTION-CORE v2.1]
```

- [ ] **Step 3: Add JSON Schema contracts**

Define schemas with Draft 2020-12 declarations. The module-manifest schema accepts `paths[]` entries with `lifecycle` in `planned|implemented|deprecated`, `provenance` in `authored|generated`, requires `generator` and array-valued `check` for generated entries, and requires `legacy_consumers` for deprecated entries.

- [ ] **Step 4: Document first-module onboarding**

Write a concise guide showing how to add a real index entry and matching manifest atomically, define lifecycle/provenance, and invoke `python3 scripts/validate_agent_contracts.py`.

- [ ] **Step 5: Commit**

Skip this step if the repository has no Git metadata. Otherwise:

```bash
git add AGENTS.md agent docs/agent-methodology.md
git commit -m "chore: bootstrap agent methodology metadata"
```

### Task 2: Define failing validator behavior tests

**Files:**
- Create: `tests/test_validate_agent_contracts.py`
- Test: `tests/test_validate_agent_contracts.py`

**Interfaces:**
- Consumes: `scripts/validate_agent_contracts.py` CLI called as `python3 scripts/validate_agent_contracts.py --root <temporary-repository>`.
- Produces: CLI exit status `0` for valid repositories and non-zero status containing a human-readable violation for invalid repositories.

- [ ] **Step 1: Write failing CLI behavior tests**

Create temporary repository fixtures with a valid minimal methodology layout. Add tests that call the validator subprocess and assert:

```python
def test_valid_empty_repository_passes(self):
    result = self.run_validator(self.valid_repository())
    self.assertEqual(result.returncode, 0, result.stderr)

def test_missing_manifest_for_indexed_module_fails(self):
    root = self.valid_repository()
    self.write_index(root, {
        "schema_version": 1,
        "modules": {
            "api": {
                "status": "implemented",
                "roots": ["src/api"],
                "entrypoints": ["src/api/main.py"],
                "manifest": "agent/modules/api.json",
                "dependencies": []
            }
        }
    })
    result = self.run_validator(root)
    self.assertNotEqual(result.returncode, 0)
    self.assertIn("missing manifest", result.stderr)
```

Also cover a bad execution-core sentinel, an unknown dependency, and an existing `planned` path. Each test must assert a consumer-visible CLI result, not source text.

- [ ] **Step 2: Run tests and verify red**

Run:

```bash
python3 -m unittest tests/test_validate_agent_contracts.py -v
```

Expected: FAIL because `scripts/validate_agent_contracts.py` does not yet exist.

### Task 3: Implement the validator

**Files:**
- Create: `scripts/validate_agent_contracts.py`
- Test: `tests/test_validate_agent_contracts.py`

**Interfaces:**
- Consumes: `--root PATH`, defaults to current working directory.
- Produces: exit code `0` plus `agent contracts: OK` for success; exit code `1` and one `ERROR: ...` line per violation otherwise.

- [ ] **Step 1: Implement JSON loading and core-delivery checks**

Implement `validate(root: Path) -> list[str]` to load the three top-level JSON files, check that `AGENTS.md` references both `[EXECUTION-CORE v2.1]` and `agent/execution-core.md`, and check the first non-empty execution-core line.

- [ ] **Step 2: Implement index, manifest, dependency, and lifecycle checks**

For every indexed module, require exactly its declared manifest, matching `module_id`, implemented roots and entrypoints. Reject orphan manifests. Require each dependency and graph edge to name known modules. For manifest paths, test existence relative to `root` according to lifecycle. For deprecated paths, reject incoming edges from modules outside `legacy_consumers`.

- [ ] **Step 3: Implement safe generated checks**

For generated, implemented paths only, require `generator` to exist and run a non-empty argument-array `check` with `subprocess.run(..., shell=False, cwd=root, capture_output=True, text=True)`. Record a violation on a non-zero return code. Do not run generated checks for planned paths.

- [ ] **Step 4: Run focused tests and verify green**

Run:

```bash
python3 -m unittest tests/test_validate_agent_contracts.py -v
```

Expected: PASS for all tests.

- [ ] **Step 5: Run validator against the actual repository**

Run:

```bash
python3 scripts/validate_agent_contracts.py --root /Users/yevgeniygolota/Documents/Projects/MyFinLocal
```

Expected: `agent contracts: OK`.

- [ ] **Step 6: Commit**

Skip this step if the repository has no Git metadata. Otherwise:

```bash
git add scripts/validate_agent_contracts.py tests/test_validate_agent_contracts.py
git commit -m "feat: validate agent methodology contracts"
```

### Task 4: Final verification

**Files:**
- Verify: all files created in Tasks 1–3

- [ ] **Step 1: Run the full Python test suite**

Run:

```bash
python3 -m unittest discover -s tests -v
```

Expected: PASS with no failures or errors.

- [ ] **Step 2: Inspect bootstrap output**

Run:

```bash
python3 scripts/validate_agent_contracts.py
```

Expected: `agent contracts: OK`.

- [ ] **Step 3: Report the bootstrap and extension boundary**

State that the index is intentionally empty and that the next production module must be registered in index and manifest together.
