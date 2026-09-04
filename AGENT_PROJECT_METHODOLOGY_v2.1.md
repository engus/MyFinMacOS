# Agent Project Methodology

Version: 2.1

## Purpose

This methodology defines a lightweight repository contract and execution policy for working with coding agents across engineering projects.

The goal is not to encode the whole repository into metadata or to optimize for the fewest possible tool calls. The goal is to:

- reduce unnecessary context loading and agent round trips;
- make ownership and dependencies explicit;
- keep navigation deterministic;
- distinguish intent from implementation;
- prevent metadata drift;
- separate current semantics from historical runtime evidence;
- shorten the inspect → edit → validate → fix feedback loop;
- reduce repeated lookup, environment-discovery, polling, and symptom-patching loops;
- make the same repository understandable to different agents and chat sessions.

The methodology has two categories, separated by semantics and verification rather than by where the text is stored:

```text
repository contracts  → describe repository state; machine-checkable where practical; may gate the repository
execution heuristics  → guide agent behavior; empirically evaluated; do not become repository gates merely because they are stored locally
```

The repository contract tells the agent where to look and what must remain true.

The execution policy tells the agent how to obtain and validate that information with fewer non-informative steps. An execution heuristic may reference repository-specific infrastructure such as the module index or domain validators; this does not make the heuristic a repository invariant.

Production code/configuration and runtime evidence remain the source of truth.

---

## Design principles

### 1. Keep the map much smaller than the territory

Global navigation metadata must stay compact.

Do not put every file, artifact, status, evidence record, note, or generated path into one global map.

Use two levels:

1. a thin global module index;
2. detailed per-module manifests loaded only when that module is relevant.

The global index should route the agent. It should not mirror the filesystem.

---

### 2. Boot context must be small

The normal boot sequence is:

1. read `AGENTS.md`;
2. if the exact execution-core sentinel required by `AGENTS.md` is not already present in current instructions, read `agent/execution-core.md` directly; do not search for it;
3. read `agent/module-index.json`;
4. identify the owning module;
5. read only that module's manifest;
6. inspect the relevant production files;
7. read architecture/docs only when broader context is required.

If a host injected an older execution core, the sentinel version does not match and the repository-local core is read. This is intentional: on version mismatch, the repository methodology version wins.

Do not require the agent to read all manifests or the full architecture for local work.

---

### 3. Metadata is navigation, not implementation evidence

`AGENTS.md`, module indexes, manifests, architecture documents, and README files describe intent, ownership, routing, and contracts.

They do not prove that a feature exists or works.

For implementation claims, inspect:

- source code;
- configuration;
- schemas;
- generated artifacts where relevant;
- tests;
- runtime evidence.

Production code/configuration has priority over README and metadata.

Runtime evidence has priority for claims about what actually ran.

---

### 4. Historical runtime evidence is immutable

Once an accepted runtime measurement or verification bundle is committed, it should not be rewritten merely because the repository evolves.

When current semantics change:

- preserve the historical evidence byte-for-byte;
- preserve snapshots of the exact contracts/configuration used for that run;
- validate historical integrity separately;
- compare current behavior against normalized semantic projections where compatibility matters;
- keep new runtime proof in a new evidence bundle.

Do not rewrite history to make old evidence look current.

---

### 5. Verifiable contracts and execution effectiveness are different categories

Repository contracts that are mechanically verifiable must have validators.

Examples:

- module listed in the index has a manifest;
- every manifest belongs to a known module;
- implemented paths exist;
- planned paths do not exist;
- generated artifacts match their generators;
- dependency graph references only known modules;
- immutable evidence hashes still match.

Methodology and execution-policy effectiveness are not repository invariants.

Claims such as "this methodology reduces repair iterations", "bounded inspection saves tokens", or "batched reconnaissance reduces tool cost" should be evaluated through lightweight empirical observations, not turned into hard repository gates.

Otherwise the methodology would violate its own rule by treating an empirical hypothesis as a static contract.

---

### 6. Do not model everything

Only add metadata if it:

- helps the agent decide where to look;
- expresses ownership or contract meaning that the filesystem does not;
- can be validated;
- reduces future repair or navigation cost.

Avoid metadata that merely duplicates cheaply discoverable filesystem information.

---

### 7. Evolve the methodology only after observed friction

Do not expand the methodology speculatively.

Add or change rules in response to observed:

- navigation failures;
- ambiguous ownership;
- metadata drift;
- validation gaps;
- migration friction;
- repeated repair loops;
- evidence integrity problems.

A concrete failure mode is stronger justification than a theoretical improvement.

---

### 8. Start efficient; expand on demonstrated insufficiency

Use one expansion rule consistently across navigation, inspection, reconnaissance, and verification:

> Start with the smallest justified scope. Expand only when the current step reveals a concrete unanswered question, dependency, contract uncertainty, or verification gap.

This rule prevents both failure modes:

- reading too little and silently missing required context;
- reading broadly in advance merely because more context might become useful.

Correctness overrides efficiency when a concrete gap demonstrates that more context or verification is required. Efficiency should not be used to justify incomplete understanding, and "sufficient context" should not be used to justify speculative repository-wide reading.

---

### 9. Context budgets are optimization signals, not correctness constraints

Size targets and warnings exist to expose drift and recurring context cost. They are not caps.

No instruction, contract, evidence, safety clause, or context required for correctness may be removed solely to satisfy a size target.

When a size warning is accepted, the reason should be recorded in the normal change rationale (for example a changelog entry, review description, or migration report). Do not create a separate waiver-metadata system merely to justify size.

Prefer observing growth over optimizing toward an arbitrary constant. Absolute byte targets are coarse review signals; deltas against an available accepted baseline are usually more informative.

---

# Execution policy

Execution heuristics are intentionally separated from repository invariants.

They guide how the agent works. Their effectiveness is empirical, and `validate_agent_contracts.py` must not pretend to prove that a natural-language heuristic improves quality or cost.

The full rationale, exceptions, evidence status, and underspecification risks live in this methodology. The compact executable wording lives in `agent/execution-core.md`.

## Delivery model

Each repository using methodology 2.1 carries a compact canonical executable payload at the deterministic path:

```text
agent/execution-core.md
```

The payload begins with an exact versioned sentinel:

```text
[EXECUTION-CORE v2.1]
```

`AGENTS.md` contains only a pointer, not a copy of the payload:

```text
0. If `[EXECUTION-CORE v2.1]` is not already present in your current instructions, read `agent/execution-core.md`. Do not search for it.
```

Compatible hosts may inject the same repository-local core directly at session start. If the exact sentinel is already present, the agent does not read the file again. If the host injected an older version, the sentinel differs and the repository-local version is read. Repository version therefore wins automatically on mismatch.

This design deliberately avoids:

- discoverable skill-folder searches;
- host-specific delivery metadata in the repository contract;
- duplicated fallback copies inside `AGENTS.md`;
- a generator whose only purpose is to maintain such a duplicate.

The repository does not record whether a particular host injects the core. Delivery is host/session behavior and is not a portable repository property.

## Rule lifecycle and evidence status

Execution heuristics may have the methodology-level lifecycle:

```text
external → provisional → stable
                     ↘ narrowed
                     ↘ removed
```

- `external` — supported by external agent traces or evaluation but not yet evaluated on this methodology's repositories;
- `provisional` — adopted into the methodology but not yet established on representative local tasks;
- `stable` — supported by representative local observations or by a recurring locally observed failure mode without material correctness regression;
- `narrowed` — retained only for the cases where evidence supports it;
- `removed` — no longer justified or creates more cost/risk than it saves.

Lifecycle belongs to the central methodology specification, not to product-repository metadata.

Before expanding, hardening, or adding defensive clauses to a provisional rule, evaluate selected representative tasks when practical. If repeated observations show no useful effect, prefer narrowing or removing the rule rather than preserving it indefinitely.

The initial 2.1 execution rules imported from Benjamin-Plus-style external evidence are provisional unless this methodology already has a direct local failure mode for the same behavior. Effects must not be assumed additive with the repository navigation layer.

## Canonical expansion rule

All execution rules use the same expansion condition:

> Start with the smallest justified scope. Expand only when the current step reveals a concrete unanswered question, dependency, contract uncertainty, or verification gap.

Do not create separate weaker variants such as "read more if useful" or "do another reconnaissance pass if needed."

## EX-1 — Resolve scope and batch independent reconnaissance

Status: `provisional`

Resolve the smallest owning scope before deep inspection. After scope is known, gather independent low-volume facts together where practical.

Typical first-pass facts may include:

- relevant manifest;
- nearby directory layout;
- package/dependency declaration;
- targeted tests;
- canonical schema or generator;
- file size/line count when inspection size is unknown;
- one or two exact-construct examples when no formal contract exists.

Do not batch unknown or potentially huge output merely to reduce tool calls. Measure or constrain it first.

A follow-up reconnaissance round is allowed only under the canonical expansion rule above.

`risk_if_underspecified`: incompleteness through premature commitment.

`required_core_semantics`:

- resolve scope before broad exploration;
- batch independent bounded facts;
- allow follow-up when a concrete gap is revealed.

## EX-2 — Measure unknown size; bound large inspection, not understanding

Status: `provisional`

If input size is unknown and cheap to measure, include a size/line-count probe in reconnaissance.

Use the result to choose the cheapest safe read:

```text
known small relevant file  → usually read it whole
known large file           → inspect the target symbol/range first
unknown size               → measure, then choose
```

For large inspection, prefer symbol search, targeted ranges, bounded grep/find output, and limited directory listings. A range around roughly 50–100 relevant lines may be a useful starting example, not a hard limit.

Expand under the canonical expansion rule when surrounding context, dependencies, contracts, or edit safety require more.

Never truncate content that must be transformed, parsed as a complete structure, copied verbatim, validated as an authoritative whole, or otherwise understood as a whole for correctness.

`risk_if_underspecified`: correctness/data corruption.

`required_core_semantics`:

- measure unknown size when cheap;
- do not split small files merely to save tokens;
- bound large inspection first;
- never truncate required whole-input semantics;
- widen on demonstrated insufficiency.

## EX-3 — Prefer formal contracts; otherwise inspect two examples of the exact construct

Status: `provisional`

When reproducing an unfamiliar repository convention, use this order:

1. formal schema or specification;
2. canonical generator/template;
3. two existing examples of the exact construct you are about to create;
4. one exact-construct example only when no second example exists.

Do not read two arbitrary representative files. The value comes from sampling the exact construct, because one implementation may be an exception.

Do not sample examples when a formal contract already defines the construct completely.

`risk_if_underspecified`: style/contract drift; usually conservative rather than destructive.

`required_core_semantics`:

- prefer schema/template;
- otherwise inspect two examples of the exact construct.

## EX-4 — Probe and repair the required environment in one pass

Status: `provisional`

Before running a workflow with several runtime/tool dependencies, check the task-relevant environment together where practical.

Examples:

- runtime version;
- required binaries;
- package manager;
- critical imports;
- compiler/build tool;
- service/container availability when required.

Avoid discovering requirements one traceback at a time. Do not inspect or install every repository dependency by default.

A missing required tool or dependency is not successful verification. Repair it and rerun when the repair is local, reversible, and within the task environment. If repair would require unrelated, destructive, privileged, or contract-changing changes, report verification as blocked and state the exact blocker.

`risk_if_underspecified`: destructive or scope-expanding environment mutation; false-green verification.

`required_core_semantics`:

- probe task-required dependencies together;
- local/reversible/in-scope repair is expected;
- otherwise report an exact blocker, never green.

## EX-5 — Run required and affected checks, then stop

Status: `provisional`

If the task, audit, CI contract, or repository instructions name verification commands, run them as required.

A named task check is mandatory but not exclusive. Normal verification is:

```text
explicit task checks
+ affected domain validators/tests
+ agent-contract validator when agent metadata changed
+ cross-module checks when contracts changed
+ runtime verifier when the claim is runtime-dependent
```

Do not build an ad hoc verification harness when existing checks already measure the required property. Create or improve durable validators only when a real repository invariant is otherwise unprotected.

Once the requested change is complete, required and affected checks pass, and no required runtime claim remains unresolved, stop unless broader review was requested. Do not reread files for ceremonial confirmation. Additional verification requires a concrete uncovered risk under the canonical expansion rule.

`risk_if_underspecified`: false completion or verification theater.

`required_core_semantics`:

- task checks are mandatory;
- affected repository checks still apply;
- unresolved runtime claims prevent completion;
- once sufficient verification is green, stop.

## EX-6 — A repeated identical failure requires a different hypothesis/action

Status: `provisional`

If the same check fails a second time for materially the same reason under the same approach, stop patching the next symptom.

Name one alternative root-cause hypothesis and try a materially different action before making another similar patch.

The alternative may involve reassessing ownership, contract boundary, environment assumptions, validation interpretation, or the layer at which the fix is applied. Those are diagnostic prompts, not a required reasoning checklist.

`risk_if_underspecified`: repeated symptom patching or unnecessary hypothesis churn.

`required_core_semantics`:

- second materially identical failure under the same approach triggers a change;
- name one alternative hypothesis;
- take a materially different action before another similar patch.

## EX-7 — Poll only when polling can produce new information

Status: `provisional`

Polling is an agent step.

When the execution host returns while a command is still running, do not rapid-poll. About 30 seconds is a useful default minimum before the next status check; use longer intervals for builds, test suites, training, benchmarks, or other workloads where useful output is unlikely sooner.

Do not send empty input merely to ask whether the same process is still running.

This rule costs nothing when the execution environment blocks until completion; no artificial sleep is required in that case.

`risk_if_underspecified`: unnecessary latency if interpreted too rigidly; otherwise primarily efficiency risk.

`required_core_semantics`:

- no rapid polling;
- ~30 seconds is a default when polling is actually necessary;
- use longer intervals when appropriate;
- blocking execution needs no artificial wait.

## Core safety review

Before a methodology release writes or shortens `agent/execution-core.md`, review each rule's `risk_if_underspecified` and `required_core_semantics`.

This is a design-review classification, not a machine-verifiable proof of prompt safety.

A clause whose removal would convert a rule from conservative inefficiency into silent correctness loss, destructive mutation, false completion, or data corruption is part of the executable rule itself and must remain in the core even when size targets are exceeded.

Do not claim that `validate_agent_contracts.py` semantically understands the English prompt.

---

# Recommended repository layout

```text
project/
├── AGENTS.md
├── agent/
│   ├── methodology.json
│   ├── execution-core.md
│   ├── module-index.json
│   ├── dependency-graph.json
│   ├── modules/
│   │   ├── client.json
│   │   ├── deployment.json
│   │   ├── monitoring.json
│   │   └── ...
│   └── schemas/
│       ├── methodology.schema.json
│       ├── module-index.schema.json
│       ├── module-manifest.schema.json
│       └── dependency-graph.schema.json
├── docs/
│   ├── architecture.md
│   ├── evidence/
│   └── generated/
├── scripts/
│   ├── validate_agent_contracts.py
│   └── ...
├── schemas/
├── tests/
└── production source...
```

Use `agent/`, not a hidden `.agent/` directory.

Reason:

- easier for human auditors to see;
- less likely to be skipped by tooling;
- less sensitive to glob/file-search behavior;
- avoids a class of hidden-directory discovery problems.

Agent metadata schemas live inside `agent/` so the navigation layer remains self-contained and portable between projects.

Production artifact schemas stay in the project's normal `schemas/` directory because they belong to the product/domain, not to the agent navigation layer.

---

# `AGENTS.md`

`AGENTS.md` is boot instructions, not project documentation and not a second copy of the execution core.

It should remain short.

Recommended content:

```text
# Agent navigation

0. If `[EXECUTION-CORE v2.1]` is not already present in your current instructions, read `agent/execution-core.md`. Do not search for it.
1. Read `agent/module-index.json`.
2. Identify the module that owns the requested feature using roots and entrypoints.
3. Read only `agent/modules/<module-id>.json`.
4. Inspect the relevant production code/config.
5. Read `docs/architecture.md` only when architectural context is required under the canonical expansion rule.
6. Treat README and agent metadata as navigation, not implementation evidence.
7. For runtime claims, inspect committed evidence or run the relevant verifier.
8. Before changing cross-module contracts, inspect `agent/dependency-graph.json`.
9. Run explicit task checks and the affected domain validators/tests after changes.
10. Run `scripts/validate_agent_contracts.py` when agent metadata or `agent/execution-core.md` changes.
11. Do not read every module manifest unless the task is repository-wide.
12. If ownership is ambiguous, do not guess: mark resolution as ambiguous, inspect roots and the dependency graph, then open only candidate manifests.
```

The exact sentinel is part of the delivery protocol. An older injected sentinel does not satisfy a newer repository requirement; this intentionally causes the repository-local core to be read.

Do not embed a copied fallback execution policy in `AGENTS.md`. The pointer avoids semantic drift, duplicate maintenance, and silent double-loading.

Avoid instructions such as:

```text
Read the whole module map.
Read ARCHITECTURE.md.
Read all module manifests.
```

unless the task is explicitly repository-wide or the canonical expansion rule demonstrates that broader context is required.

---

# `agent/methodology.json`

Each repository records which version of the methodology it follows.

Example:

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

Methodology upgrades are deliberate migrations.

Do not silently mutate old repositories when the central methodology evolves.

---

# `agent/module-index.json`

The global index answers only:

- what modules exist;
- module-level lifecycle/status;
- where their implementation roots are;
- what their primary entrypoints are;
- where their detailed manifest lives;
- which modules they depend on.

Example:

```json
{
  "schema_version": 1,
  "modules": {
    "client": {
      "status": "implemented",
      "roots": ["client/"],
      "entrypoints": ["client/inference_client.py"],
      "manifest": "agent/modules/client.json",
      "dependencies": ["shared-contracts"]
    },
    "triton-serving": {
      "status": "implemented",
      "roots": ["deployment/triton/", "models/"],
      "entrypoints": ["deployment/triton/verify_serving.py"],
      "manifest": "agent/modules/triton-serving.json",
      "dependencies": ["model-repository", "shared-contracts"]
    }
  }
}
```

## Module-level statuses

Recommended module statuses:

- `planned`
- `implemented`
- `deprecated`

The index is the canonical structural contract for module roots and entrypoints.

A structure validator should derive required implemented roots from the index instead of maintaining an independent hard-coded list.

---

# `agent/modules/<module-id>.json`

Per-module manifests contain the detail needed only when entering that module.

A logical module always has one mechanical manifest location:

```text
agent/modules/<module-id>.json
```

This avoids special cases when implementation spans several production directories.

---

## Path model: two independent axes

Do not use `generated` as a lifecycle status.

A path has two orthogonal properties:

```text
lifecycle:  planned | implemented | deprecated
provenance: authored | generated
```

This avoids category errors such as trying to decide whether an artifact is "planned" or "generated" when both can be true.

Example:

```json
{
  "schema_version": 1,
  "module_id": "client",
  "purpose": "Reusable inference client and request logging",
  "paths": [
    {
      "path": "client/inference_client.py",
      "lifecycle": "implemented",
      "provenance": "authored"
    },
    {
      "path": "client/visualizer.py",
      "lifecycle": "planned",
      "provenance": "authored"
    },
    {
      "path": "shared/client-model-contracts.json",
      "lifecycle": "implemented",
      "provenance": "generated",
      "generator": "scripts/generate_client_contract.py",
      "check": "python scripts/generate_client_contract.py --check"
    }
  ],
  "contracts": [
    "shared/client-model-contracts.json"
  ],
  "validators": [
    "scripts/validate_client_evidence.py"
  ],
  "tests": [
    "tests/unit/client/"
  ],
  "runtime_evidence": [
    "docs/evidence/step-5/"
  ]
}
```

---

# Path lifecycle semantics

The lifecycle state must be strict and machine-checkable.

## `planned`

Meaning:

> The implementation path is declared but does not yet exist.

Validator rule:

```text
path MUST NOT exist
```

If the path exists, the metadata is stale and validation fails.

This intentionally prevents "planned" from becoming a vague declaration that survives after implementation.

---

## `implemented`

Meaning:

> The implementation path exists and is part of the current repository contract.

Validator rule:

```text
path MUST exist
```

---

## `deprecated`

Meaning:

> The path still exists for compatibility/migration reasons but should not gain new cross-module consumers.

Validator rule:

```text
path MUST exist
```

The manifest must also define:

```json
"legacy_consumers": ["module-a", "module-b"]
```

`legacy_consumers` contains module IDs, not file paths.

The dependency graph is the canonical mechanism for checking cross-module use.

A deprecated path/module may have incoming dependency edges only from modules listed in `legacy_consumers`.

Any incoming edge from another module is a validation failure.

Do not attempt to detect "new references" through repository-wide grep.

Internal use by the owning module is outside this cross-module rule.

---

# Path provenance semantics

## `authored`

The file/path is maintained directly.

No generator metadata is required.

---

## `generated`

The path is produced from another canonical source.

Schema requirements:

```text
generator is required
check is required
```

Example:

```json
{
  "path": "shared/client-model-contracts.json",
  "lifecycle": "implemented",
  "provenance": "generated",
  "generator": "scripts/generate_client_contract.py",
  "check": "python scripts/generate_client_contract.py --check"
}
```

---

# Lifecycle × provenance matrix

This matrix describes repository reality checks performed by `validate_agent_contracts.py`.

| Lifecycle | Provenance | Repository invariant |
|---|---|---|
| `planned` | `authored` | path MUST NOT exist |
| `planned` | `generated` | artifact path MUST NOT exist |
| `implemented` | `authored` | path MUST exist |
| `implemented` | `generated` | path MUST exist; generator must exist; `check` must pass |
| `deprecated` | `authored` | path MUST exist; dependency allowlist enforced |
| `deprecated` | `generated` | path MUST exist; generator/check contract remains valid; dependency allowlist enforced |

## Important rule for `planned + generated`

For:

```text
lifecycle: planned
provenance: generated
```

the fields `generator` and `check` are still required by the schema because they describe intended generation semantics.

However, the repository validator:

- checks only that the artifact path does not exist;
- does not require the generator path to exist;
- does not execute `check`.

Reason:

If the generator were already required to exist and its check had to pass, the artifact would already be reproducible and the meaning of `planned` would become ambiguous.

The generation fields are therefore declarative until lifecycle changes to `implemented`.

---

# Schema responsibility vs validator responsibility

Keep these responsibilities separate.

## JSON Schema validates document shape

Schemas answer:

- is the JSON structurally valid;
- are required fields present;
- are enum values valid;
- does `provenance: generated` require `generator` and `check`;
- does `lifecycle: deprecated` require `legacy_consumers`;
- are dependency/module identifiers valid strings;
- are unsupported combinations rejected.

Schema validates metadata as a document.

It does not inspect the filesystem or execute commands.

---

## `validate_agent_contracts.py` validates repository reality

The validator answers:

- does a planned path exist when it should not;
- does an implemented path exist;
- does a generated artifact match its check;
- does a generator exist when required;
- do all module manifests exist;
- do all manifests map back to known modules;
- do dependency edges reference known modules;
- do deprecated consumers comply with their allowlists;
- does `agent/execution-core.md` exist and begin with the sentinel required by methodology version;
- does `AGENTS.md` contain the deterministic pointer to the same sentinel/path and avoid an embedded fallback copy;
- are instruction/navigation sizes and available size deltas reported for review;
- are generated navigation documents current.

Schema and runtime validation must not duplicate responsibility unnecessarily.

---

# `agent/dependency-graph.json`

Keep the dependency graph compact.

Its role is to answer:

- which modules depend on which;
- which direction contracts flow;
- whether a change is cross-module;
- whether deprecated consumers are allowed.

Example:

```json
{
  "schema_version": 1,
  "edges": [
    ["client", "shared-contracts"],
    ["triton-serving", "model-repository"],
    ["benchmarking", "triton-serving"]
  ]
}
```

Rules:

- graph nodes are module IDs;
- every referenced module must exist in the module index;
- unknown module IDs fail validation;
- prohibited dependencies fail validation;
- cycles may fail validation when the project requires an acyclic graph.

Do not model file-level references in the dependency graph unless a concrete project requirement proves it necessary.

---

# Agent metadata schemas

All agent metadata JSON must be schema-validated.

Recommended schemas:

```text
agent/schemas/
├── methodology.schema.json
├── module-index.schema.json
├── module-manifest.schema.json
└── dependency-graph.schema.json
```

These schemas belong inside `agent/` because they are part of the portable navigation layer.

Production/domain schemas remain in the project's normal `schemas/`.

---

# Validator topology

A project should have one validator dedicated to the agent metadata contract:

```text
scripts/validate_agent_contracts.py
```

This does NOT mean the project should have only one validator.

The project may have any number of targeted domain validators:

```text
scripts/validate_models.py
scripts/validate_benchmark.py
scripts/validate_monitoring.py
scripts/validate_serving.py
...
```

Recommended usage:

### Local production change

Run:

```text
affected domain validator/tests
```

### Agent metadata change

Run:

```text
scripts/validate_agent_contracts.py
```

plus any affected domain validator.

### Final repository gate

Run the complete validation suite.

This preserves targeted feedback loops without turning the agent-contract validator into a monolith for every engineering concern.

---

# Required agent-contract invariants

## Index ↔ manifest integrity

For every module in the index:

- exactly one manifest must exist;
- manifest `module_id` must match the index key.

For every manifest:

- its module must exist in the index.

Validation is bidirectional.

This prevents:

- index entry without manifest;
- orphan manifest;
- accidental duplicate ownership identity.

A deprecated module still requires a manifest while it remains present in the index.

When fully removed, remove both index entry and manifest in the same change.

---

## Structural integrity

For every module with `status: implemented`:

- required roots exist;
- declared entrypoints exist.

For every module with `status: planned`:

- project-specific structural rules may permit absent roots.

File-level lifecycle remains governed by each manifest's `paths[]`.

---

## Dependency integrity

Every dependency:

- points to a known module;
- satisfies project dependency rules;
- respects deprecated consumer allowlists.

---

## Generated artifact integrity

For:

```text
lifecycle: implemented
provenance: generated
```

the validator must confirm:

- artifact exists;
- generator exists;
- configured read-only `check` succeeds.

`check` should not rewrite the repository.

Generation tooling should support deterministic `--check` or equivalent read-only mode wherever practical.

---

## Execution-core delivery integrity

For methodology 2.1 repositories, the validator must mechanically confirm:

- `agent/execution-core.md` exists;
- its first non-empty line is `[EXECUTION-CORE v2.1]`;
- `AGENTS.md` references that exact sentinel and deterministic path;
- `AGENTS.md` does not embed the executable rule body (for example `EX-1` through `EX-7` blocks) instead of using the pointer;
- no repository metadata attempts to record host-specific delivery mode.

These checks validate delivery wiring only. They do not validate the semantic quality or effectiveness of the natural-language execution rules.

The central methodology repository should additionally verify rule-ID coverage between the METHOD specification and the distributed execution-core template. Coverage can be checked mechanically; semantic equivalence of prose cannot.

---

# Instruction and navigation size budgets

Size budgets are optimization signals, not correctness constraints.

The original locally observed failure mode was a global map growing until it cost as much context as the modules it routed to. Navigation budgets therefore have stronger local evidence than the newer execution-core size targets.

Recommended defaults:

```text
agent/module-index.json
  target: <= 8 KB
  warning: > 12 KB
  maturity: stable

agent/modules/<module-id>.json
  target: <= 6 KB
  warning: > 10 KB
  maturity: stable

AGENTS.md
  target: <= 4 KB
  warning: > 6 KB
  maturity: provisional

agent/execution-core.md
  target: <= 4 KB
  warning: > 6 KB
  maturity: provisional / externally informed

mandatory session instruction surface
  measure: size(AGENTS.md) + size(agent/execution-core.md)
  target: <= 8 KB
  warning: > 12 KB
  maturity: provisional
```

With the sentinel/pointer design, the mandatory content surface is the same in either delivery path: injected core + `AGENTS.md`, or `AGENTS.md` followed by the deterministic core read. The non-injected path may cost one additional read step, but it does not require a duplicated fallback payload.

These are byte-size signals, not token caps.

Reasons:

- byte size is independent of model/tokenizer;
- easy to measure;
- stable enough for repository review;
- does not pretend that a particular token count is universally optimal.

## Growth-oriented review

When Git history is available, report current size together with a baseline from the merge-base or another clearly accepted revision. Do not create a new permanent metadata file solely to store accepted sizes.

Example:

```text
agent/execution-core.md
  current: 4.1 KB
  merge-base: 3.9 KB
  delta: +0.2 KB (+5.1%)
```

The delta is often more informative than an absolute threshold because it exposes gradual policy accretion.

If no reliable history baseline is available, report only current size and absolute warning state.

Validators should not fail the repository merely because a size target or warning threshold is exceeded. They should surface the warning prominently (for example through CI annotations or summary output where supported).

A warning means review why the artifact grew. It does not mean shorten it.

Review questions include:

- is discoverable information duplicated;
- did rationale leak into an executable payload;
- did a new rule address an observed failure;
- can an existing rule be narrowed or removed;
- is a correctness-critical safety clause being retained even though it increases size.

If growth is intentionally accepted, record the rationale in the normal change record. No correctness-critical text may be removed merely to clear the warning.

Do not hard-fail on size. A hard cap encourages minification and unsafe rule deletion instead of architectural improvement.

---

# Reading policy

## Local task

```text
AGENTS.md
→ execution core if exact sentinel is absent
→ module-index
→ one module manifest
→ smallest justified reconnaissance scope
→ expand only on a concrete question/dependency/contract/verification gap
→ relevant production files
→ explicit task checks + targeted domain validator/tests
```

---

## Cross-module task

```text
AGENTS.md
→ execution core if exact sentinel is absent
→ module-index
→ dependency graph
→ manifests of affected modules
→ targeted inspection of both sides of the contract
→ expand only on a concrete question/dependency/contract/verification gap
→ production contracts
→ explicit task checks + affected validators/tests
```

---

## Ambiguous ownership

If the module owner cannot be resolved directly:

1. mark `owner_resolution = ambiguous`;
2. inspect module roots and entrypoints;
3. inspect dependency graph;
4. open only candidate manifests;
5. do not guess ownership;
6. do not fall back immediately to repository-wide reading.

If the initially selected module later proves wrong, record:

```text
owner_resolution = misrouted
```

This turns navigation failure into an observable event instead of silent context expansion.

---

## Repository-wide audit

Only repository-wide work justifies reading:

- all module manifests;
- full architecture documentation;
- global evidence indexes;
- full validator topology.

Even then, inspect production implementation/evidence before accepting metadata claims. Repository-wide scope permits broad coverage, but it does not require indiscriminate full-file reads when smaller justified reads answer the question.

---

# Source-of-truth hierarchy

When sources disagree:

1. production code and configuration;
2. immutable runtime evidence for historical claims;
3. validators and schemas;
4. generated contracts;
5. per-module manifests;
6. architecture documentation;
7. README prose.

Agent metadata is routing and contract metadata, not a substitute for implementation evidence.

---

# Evidence methodology

## Historical bundle

Once a runtime step is accepted, its evidence becomes immutable.

Example:

```text
docs/evidence/step-4/
├── serving-runtime.json
├── repository-versions.txt
├── runtime-model-spec.yaml
├── runtime-model-manifest.json
└── runtime-integrity.json
```

`runtime-integrity.json` binds historical files by hash.

Historical validation must not depend on live mutable files.

---

## Current compatibility

When code evolves, compare normalized semantic projections.

Include only behavior that must remain compatible, for example:

- source/weights identity;
- preprocessing;
- input/output contracts;
- model versions;
- batching;
- precision semantics;
- tolerances;
- protocol behavior;
- lifecycle behavior.

Exclude non-semantic host/runtime provenance when it is intentionally variable, for example:

- GPU name;
- compute capability when engines are rebuilt per GPU;
- driver version;
- timestamps;
- rebuilt engine SHA;
- exact measured parity values;
- benchmark performance numbers.

Those belong to build/runtime evidence.

---

## New runtime proof

A later verification should write a new bundle.

Example:

```text
docs/evidence/portability/
```

Do not overwrite:

```text
docs/evidence/step-4/
```

---

# Feedback-loop design

The largest practical benefit of this methodology is deterministic feedback combined with disciplined execution.

Without validators:

```text
agent edits
→ user runs
→ failure
→ trace returned
→ agent rereads
→ second edit
→ another failure
→ repeat
```

With deterministic validation and the canonical expansion rule:

```text
resolve smallest justified scope
→ batch independent bounded facts
→ targeted edit
→ explicit task checks + affected validators/tests
→ concrete gap? expand specifically to resolve it
→ deterministic violation list
→ targeted fix
→ pass
```

If a materially identical failure repeats under the same hypothesis/approach:

```text
same failure a second time
→ stop symptom patching
→ name one alternative root-cause hypothesis
→ take a materially different action
→ rerun the relevant check
```

Prioritize:

1. correctness and required verification;
2. deterministic validators;
3. targeted tests;
4. correct scope and ownership;
5. compact navigation;
6. evidence-driven context expansion;
7. bounded/batched inspection where safe;
8. read-only check modes;
9. task-scoped environment probing;
10. avoiding repeated non-informative steps.

This list is not permission to gather broad context in advance. Start efficient; expand only after the current step reveals a concrete information or verification gap.

Do not optimize tool-call count, bytes, or tokens at the expense of correctness. The objective is to eliminate steps that do not add information or verification value.

---

# Methodology evaluation telemetry

Do not turn methodology effectiveness into a repository gate.

Instead, collect lightweight observations on selected non-trivial tasks.

Suggested fields:

```text
validation_runs_to_green
repair_rounds
agent_metadata_files_read
module_manifests_read
unexpected_cross_module_reads
owner_resolution
lookup_rounds
environment_repair_rounds
repeated_same_failure
poll_steps                # only when host telemetry exposes it
```

Recommended `owner_resolution` values:

```text
direct
ambiguous
misrouted
```

Definitions:

- `direct` — owner resolved from the index without detour;
- `ambiguous` — index did not resolve a single owner, fallback process was used;
- `misrouted` — initial owner selection later proved wrong.

Additional execution observations are optional:

- `lookup_rounds` — distinct reconnaissance rounds before implementation;
- `environment_repair_rounds` — iterations caused by missing/incorrect tooling or dependencies;
- `repeated_same_failure` — whether a materially identical failure repeated under the same hypothesis;
- `poll_steps` — non-blocking status checks, only when the host exposes this reliably.

These observations are methodology evaluation data, not pass/fail project requirements.

Do not add instrumentation whose collection cost outweighs the decision value.

Execution telemetry is not required on every task. It becomes important before a provisional rule is expanded, hardened, or promoted to stable. Use selected representative tasks and, when evaluating causal effect, prefer matched or otherwise meaningful comparisons rather than assuming that navigation and execution-policy savings are additive.

A provisional rule should not remain provisional forever by inertia. Periodic methodology review should either promote it, narrow it, retain it with explicit unresolved evidence, or remove it. Absence of a measured difference without an adequate counterfactual is not by itself evidence for removal.

---

# Migration policy

Methodology upgrades must be explicit, reviewable, and atomic.

A metadata-layout migration must not silently rewrite historical runtime evidence.

---

## General migration rules

1. identify old canonical metadata;
2. inspect current filesystem state;
3. derive new lifecycle/provenance semantics from actual state;
4. report mismatches before writes;
5. migrate metadata, execution-core delivery wiring, schemas, validators, and generated navigation docs together;
6. validate the new layout;
7. remove the old canonical source instead of maintaining two permanent sources of truth;
8. preserve immutable runtime evidence;
9. run migration again and verify it is a no-op.

Migration tooling should support:

```text
--dry-run
```

or equivalent.

---

## Migration from 2.0 to 2.1

Methodology 2.1 introduces a new canonical repository-local executable artifact and changes delivery semantics. Treat the migration as atomic.

A 2.0 → 2.1 dry-run should:

1. update `agent/methodology.json` from `2.0` to `2.1`;
2. add `agent/execution-core.md` from the 2.1 methodology template;
3. ensure the first non-empty line is `[EXECUTION-CORE v2.1]`;
4. replace any copied/fallback execution-policy block in `AGENTS.md` with the deterministic sentinel pointer;
5. update `AGENTS.md` navigation wording to use the canonical expansion rule;
6. update `validate_agent_contracts.py` to check core existence, sentinel/path wiring, and size reporting without pretending to validate prompt semantics;
7. add `AGENTS.md`, execution-core, and combined instruction-surface size reporting;
8. update bootstrap/template consumers and documentation that still reference a host-only `EXECUTION_POLICY.md` or `AGENTS.md` fallback copy;
9. preserve historical runtime evidence unchanged;
10. rerun the migration and verify no changes.

The migration report should additionally show:

```text
execution core added/replaced
sentinel version
AGENTS pointer state
legacy fallback block detected/removed
old EXECUTION_POLICY references
current instruction sizes
available merge-base size deltas
```

Do not add `execution_policy_delivery` or equivalent host-specific metadata. Whether a host injects the core is session behavior and is not a portable repository contract.

---

# Status migration must inspect filesystem reality

Do not migrate statuses by blind textual substitution.

Example:

Old:

```text
generated
```

must not automatically become:

```text
lifecycle: implemented
provenance: generated
```

without checking whether the artifact actually exists.

General derivation:

```text
old planned + path absent
→ lifecycle: planned

old implemented + path present
→ lifecycle: implemented
  provenance: authored unless old metadata proves generation

old generated + path present
→ lifecycle: implemented
  provenance: generated

old generated + path absent
→ requires migration review
```

Any inconsistency must appear in a migration report before commit.

---

## Migration report

A migration dry-run should report at least:

```text
modules migrated
paths migrated
status/provenance mappings
missing expected paths
unexpected existing planned paths
orphan manifests
unknown dependencies
generated artifacts without generators/checks
legacy metadata references
files to rewrite
files intentionally preserved
```

Do not write when unresolved semantic mismatches remain.

---

## Migration idempotency

The migration must be idempotent.

Running the migration against an already migrated repository must:

```text
produce no changes
```

This distinguishes a state transition from an uncontrolled one-time mutation script.

---

## Atomic layout migration

When paths such as:

```text
module-map.json
dependency-graph.json
```

move to:

```text
agent/module-index.json
agent/dependency-graph.json
```

all mutable consumers of the old layout should migrate in the same change:

- AGENTS.md;
- `agent/execution-core.md` when the methodology version changes its executable core;
- schemas;
- validators;
- README references;
- generated navigation documents;
- scripts that load old paths.

Do not keep a compatibility stub merely because some validator was not migrated.

That creates a second source of truth.

---

## Historical evidence during migration

Historical runtime evidence should remain where it is if it does not depend on agent navigation metadata.

Example:

```text
docs/evidence/step-N/
```

does not move simply because:

```text
module-map.json
```

became:

```text
agent/module-index.json
```

If historical validators depend on old runtime snapshots, keep supporting those snapshots as historical formats.

Current metadata validation may use the new layout.

---

# Deprecated metadata and removal

A deprecated module or path remains fully represented while it exists.

For a deprecated module:

- index entry remains;
- manifest remains;
- legacy consumers are explicit;
- new cross-module consumers outside the allowlist fail.

Final removal is atomic:

```text
remove production path
remove index entry
remove manifest
remove dependency edges
update affected validators/docs
```

Do not leave an orphan manifest or dead index entry.

---

# Anti-patterns

## Mandatory discovery of execution instructions

Bad:

```text
every session
→ search for skill/policy
→ guess a path
→ read it
→ begin repository work
```

Methodology 2.1 uses a deterministic path and exact sentinel. The agent either already has `[EXECUTION-CORE v2.1]` or reads `agent/execution-core.md` directly because `AGENTS.md` tells it to.

Do not turn execution-core discovery back into search.

---

## Duplicated execution-core fallback

Bad:

```text
agent/execution-core.md
+ copied execution rules inside AGENTS.md
```

This creates semantic drift and can silently double per-session payload when a host also injects the core.

Keep one repository-local executable payload and a sentinel pointer from `AGENTS.md`.

---

## Lookup ping-pong

Bad:

```text
list directory
→ response
read package file
→ response
find tests
→ response
find examples
→ response
```

when these are independent, bounded facts inside an already resolved scope.

Batch them where practical.

---

## Unbounded inspection by default

Bad:

```text
open an unknown or large file completely
```

when one symbol or section is likely to answer the question.

If size is unknown and cheap to measure, measure it in reconnaissance. Small relevant files may be cheaper and safer to read whole; large files should normally start with targeted inspection.

Do not apply bounded inspection to complete inputs that must be transformed, parsed, copied, validated, or understood as a whole.

---

## Dependency discovery by repeated crashes

Bad:

```text
run
→ missing dependency A
→ fix A
→ run
→ missing dependency B
→ fix B
```

when the required environment could have been checked in one scoped probe.

---

## Symptom-patching loop

Bad:

```text
same failure
→ local patch
→ same failure
→ similar local patch
→ same failure
```

A repeated materially identical failure should trigger root-cause and scope reassessment.

---

## Verification theater

Bad:

```text
required checks pass
→ invent unrelated generic harness
→ reread all changed files
→ rerun unrelated suites
→ repeat confirmation
```

Additional verification must correspond to a concrete uncovered risk.

---

## High-frequency polling

Bad:

```text
process still running?
process still running?
process still running?
```

without a realistic chance of useful new information.

Polling is an execution heuristic, not a repository invariant. Its executable wording may live in the repository-local core without becoming a repository gate.

---

## Giant global module map

Bad:

```text
module-map.json =
every path
+ every status
+ every artifact
+ every evidence record
+ every note
```

Why it fails:

- expensive boot context;
- duplicates filesystem discovery;
- high drift surface;
- every local change mutates a global file.

Use thin index + per-module manifests.

---

## Mandatory full architecture read

Bad:

```text
Every task starts by reading ARCHITECTURE.md.
```

Architecture is useful for architectural work, not every local fix.

---

## File lifecycle without strict semantics

Bad:

```text
planned = may or may not exist
```

This does not detect stale metadata.

Correct:

```text
planned = MUST NOT exist
implemented = MUST exist
deprecated = MUST exist until removal
```

---

## Generated as lifecycle

Bad:

```text
status: generated
```

Generated is provenance, not lifecycle.

Correct:

```text
lifecycle: implemented
provenance: generated
```

---

## Duplicated structure contracts

Bad:

```text
module-index says benchmarks/results/raw
validate_structure.py hard-codes benchmarks/raw
```

Derive structure from one canonical source.

---

## Mutable historical evidence

Bad:

```text
old runtime evidence references live current metadata/config
```

Snapshot historical contracts and bind them by hash.

---

## Host-specific values inside portable semantic contracts

Bad:

```text
portable pair contract contains GPU name, driver, exact parity measurement
```

If those are not semantic requirements, keep them in runtime provenance/evidence.

---

## Metadata without validation

Bad:

```text
manifest says implemented
path does not exist
nothing checks it
```

Unvalidated metadata eventually lies.

---

## Uncheckable deprecation rules

Bad:

```text
deprecated path must not gain new references
```

if "new references" are not mechanically observable.

Correct:

```text
legacy_consumers = [module IDs]
dependency graph enforces the allowlist
```

---

## Tokenizer-specific or correctness-overriding budgets

Bad:

```text
manifest must be under 1500 tokens
execution core must fit 4 KB even if safety semantics are removed
```

Token counts vary by model/tokenizer, and hard byte caps encourage optimization toward the metric rather than toward correctness.

Use byte-size targets, warnings, and growth deltas as review signals. Never remove correctness-critical semantics solely to satisfy a budget.

---

# Central methodology repository

Maintain the methodology separately from product repositories.

Suggested structure:

```text
agent-project-methodology/
├── METHOD.md
├── CHANGELOG.md
├── templates/
│   ├── AGENTS.md
│   └── agent/
│       ├── methodology.json
│       ├── execution-core.md
│       ├── module-index.json
│       ├── dependency-graph.json
│       ├── modules/
│       └── schemas/
├── scripts/
│   └── validate_methodology_distribution.py
├── bootstrap/
└── migration/
```

`METHOD.md` is the full specification: rationale, exceptions, evidence status, lifecycle, `risk_if_underspecified`, and `required_core_semantics`.

`templates/agent/execution-core.md` is the compact authored executable payload distributed into each methodology-2.1 product repository as `agent/execution-core.md`. It is not a prose summary of METHOD and should contain only instructions needed by the model at execution time.

The central methodology validator should mechanically verify:

- expected execution rule IDs are present in both METHOD and the core template;
- the template sentinel matches the methodology release;
- required template paths exist;
- size/growth signals are reported.

It must not claim semantic equivalence between explanatory METHOD prose and executable natural-language rules.

Product repositories receive the compact core because deterministic repo-local versioning, migration, and sentinel failover are more reliable than requiring every host to carry an exactly synchronized global policy. The old prohibition against copying a long global execution policy remains: only the compact canonical payload is distributed.

Neither the full METHOD nor central research/evaluation notes are mandatory boot context for ordinary repository work.

---

# Persistent-memory rule

Do not store the entire methodology or execution core in assistant memory.

Store only a compact routing rule such as:

> For engineering repositories using the agent-project methodology, read `AGENTS.md`; if its exact execution-core sentinel is absent from current instructions, read `agent/execution-core.md` directly; then use the compact module index to resolve the smallest owning scope and load only relevant manifests/production evidence. Treat metadata as navigation, production code/config as ground truth, runtime evidence as proof, and expand context only after a concrete question, dependency, contract uncertainty, or verification gap appears.

The full methodology belongs in versioned `METHOD.md`; the executable policy belongs in the repository-local `agent/execution-core.md`.

---

# New-project bootstrap checklist

When starting a new project:

1. define coarse modules before implementation;
2. create `agent/module-index.json`;
3. create one manifest per module in `agent/modules/`;
4. create `agent/dependency-graph.json`;
5. copy the methodology-versioned compact payload to `agent/execution-core.md`;
6. create short `AGENTS.md` with the exact sentinel pointer, not a fallback copy;
7. create `agent/methodology.json`;
8. add schemas for all agent metadata;
9. add bidirectional index/manifest validation;
10. validate execution-core existence/sentinel wiring without pretending to validate prompt semantics;
11. define strict path lifecycle semantics;
12. separate path lifecycle from provenance;
13. derive required module roots from the index;
14. add deterministic read-only checks for generated metadata/artifacts;
15. add targeted domain validators/tests;
16. define historical evidence policy before first runtime capture;
17. keep architecture/README outside normal boot context;
18. report instruction/navigation sizes and available growth deltas as warnings, never correctness caps;
19. sample methodology/execution telemetry on selected non-trivial tasks when evaluating provisional rules;
20. revise methodology only after observed friction or meaningful measured evidence.

---

# Decision rule for adding metadata

Before adding something to the agent layer, ask:

1. Does this help the agent decide where to look or what contract applies?
2. Is it ownership/semantic information that the filesystem alone cannot express?
3. Can it be validated?
4. Is it already cheaply discoverable?
5. Does it belong globally or only in one module manifest?
6. Will maintaining it reduce future navigation/repair cost more than it adds maintenance cost?

If 1 and 2 are both "no", do not add it.

If 3 is "no", be suspicious of adding it as contract metadata.

If 4 is "yes", prefer discovery unless ownership/semantic meaning is valuable.

If 5 is "module-local", keep it out of the global index.

---

# Decision rule for execution heuristics

Before adding or expanding an execution rule, ask:

1. Does it address a repeated observed failure or measurable source of waste?
2. Does it preserve correctness, required verification, and necessary safety semantics?
3. Is it behavior guidance rather than a repository-state invariant?
4. Can its effect be observed on representative tasks without disproportionate telemetry overhead?
5. Does the recurring work it saves plausibly exceed the recurring instruction/context cost it adds?
6. Could a narrower rule solve the same failure mode?
7. What happens if the executable wording is read without its METHOD rationale: fail-safe inefficiency, or correctness/destructive risk?

Prefer removing or narrowing a rule over accumulating defensive instruction layers.

New externally supported rules enter as `external`/`provisional`, not automatically as `stable`. Before expanding or hardening them, seek representative local observations.

Execution heuristics should remain compact enough for routine loading, but size warnings never outrank required semantics.

Do not convert execution heuristics into repository gates unless the claimed property is actually a machine-checkable repository invariant.

---

# Summary

The methodology has six operational layers:

```text
Execution discipline
→ Navigation
→ Ownership & contracts
→ Production ground truth
→ Runtime evidence
→ Deterministic feedback
```

And five governance rules:

```text
strict validation of machine-checkable repository contracts
empirical lifecycle for execution heuristics
deliberate/idempotent migrations
versioned repo-local execution core with deterministic sentinel delivery
context-size signals that never override correctness
```

The two instruction categories are separated by semantics, not physical location:

```text
repository contracts = describe repository state; validated/gated where practical
execution heuristics = guide agent behavior; empirically evaluated; not repository gates
```

The canonical context-expansion rule is:

> Start with the smallest justified scope. Expand only when the current step reveals a concrete unanswered question, dependency, contract uncertainty, or verification gap.

The navigation layer must stay thin.

Per-module manifests may be detailed, but remain bounded and loaded on demand.

The execution core must remain compact, concrete, and safe when read without its METHOD rationale. It may exceed size targets when required semantics justify the growth.

The repository-local execution core uses an exact versioned sentinel. Host injection is optional; if a host supplies an older version, the mismatch causes the repository-local version to be loaded intentionally.

A successful agent wrapper should make the repository:

- easier to enter;
- cheaper to inspect without starving context;
- harder to misunderstand;
- harder to silently drift;
- cheaper to repair iteratively;
- less likely to trap an agent in repeated diagnostic or polling loops;
- portable across coding agents and chat sessions;
- explicit about where efficiency stops and correctness wins.

The methodology itself should evolve only when real projects or measured agent traces expose concrete failure modes. Provisional rules should be promoted, narrowed, explicitly retained as unresolved, or removed rather than accumulating indefinitely.
