#!/usr/bin/env python3
"""Validate the repository-local Agent Project Methodology 2.1 contract."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Iterable

from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError


SENTINEL = "[EXECUTION-CORE v2.1]"
SCHEMA_FILES = {
    "methodology": "methodology.schema.json",
    "module_index": "module-index.schema.json",
    "dependency_graph": "dependency-graph.schema.json",
    "module_manifest": "module-manifest.schema.json",
}
SHELL_EXECUTABLES = {"bash", "cmd", "dash", "fish", "ksh", "pwsh", "sh", "powershell", "zsh"}


def load_json(path: Path, errors: list[str]) -> Any | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        errors.append(f"missing JSON document: {path}")
    except json.JSONDecodeError as error:
        errors.append(f"invalid JSON in {path}: {error.msg}")
    return None


def validate_schema(document: Any, schema_path: Path, label: str, errors: list[str]) -> None:
    schema = load_json(schema_path, errors)
    if schema is None:
        return
    try:
        validator = Draft202012Validator(schema)
    except SchemaError as error:
        errors.append(f"invalid schema {schema_path}: {error.message}")
        return
    for error in sorted(validator.iter_errors(document), key=lambda item: list(item.path)):
        location = "/".join(str(part) for part in error.path) or "<root>"
        errors.append(f"schema violation in {label} at {location}: {error.message}")


def repository_path(root: Path, value: str, label: str, errors: list[str]) -> Path | None:
    candidate = Path(value)
    if candidate.is_absolute() or ".." in candidate.parts:
        errors.append(f"unsafe repository path for {label}: {value}")
        return None
    return root / candidate


def first_nonempty_line(path: Path, errors: list[str]) -> str | None:
    try:
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                return line.strip()
    except FileNotFoundError:
        errors.append(f"missing execution core: {path}")
        return None
    errors.append(f"execution core is empty: {path}")
    return None


def validate_delivery(root: Path, errors: list[str]) -> None:
    agents = root / "AGENTS.md"
    try:
        instructions = agents.read_text(encoding="utf-8")
    except FileNotFoundError:
        errors.append("missing AGENTS.md")
        instructions = ""
    if SENTINEL not in instructions or "agent/execution-core.md" not in instructions:
        errors.append("AGENTS.md must reference the v2.1 sentinel and agent/execution-core.md")
    core = root / "agent" / "execution-core.md"
    if first_nonempty_line(core, errors) != SENTINEL:
        errors.append("execution core sentinel must be [EXECUTION-CORE v2.1]")


def validate_paths(root: Path, module_id: str, manifest: dict[str, Any], errors: list[str]) -> None:
    for entry in manifest.get("paths", []):
        path_value = entry["path"]
        lifecycle = entry["lifecycle"]
        artifact = repository_path(root, path_value, f"{module_id} path", errors)
        if artifact is None:
            continue
        exists = artifact.exists()
        if lifecycle == "planned" and exists:
            errors.append(f"planned path exists for module {module_id}: {path_value}")
        if lifecycle in {"implemented", "deprecated"} and not exists:
            errors.append(f"{lifecycle} path is missing for module {module_id}: {path_value}")
        if lifecycle == "implemented" and entry["provenance"] == "generated":
            validate_generated_path(root, module_id, entry, errors)


def validate_generated_path(root: Path, module_id: str, entry: dict[str, Any], errors: list[str]) -> None:
    generator = repository_path(root, entry["generator"], f"{module_id} generator", errors)
    if generator is None:
        return
    if not generator.exists():
        errors.append(f"generated path has missing generator for module {module_id}: {entry['generator']}")
        return
    command = entry["check"]
    executable = Path(command[0]).name.lower()
    if executable in SHELL_EXECUTABLES:
        errors.append(f"generated check uses forbidden executable for module {module_id}: {command[0]}")
        return
    if "--check" not in command:
        errors.append(f"generated check must include --check for module {module_id}")
        return
    try:
        result = subprocess.run(command, cwd=root, capture_output=True, text=True, shell=False, check=False)
    except OSError as error:
        errors.append(f"generated check could not run for module {module_id}: {error}")
        return
    if result.returncode != 0:
        details = result.stderr.strip() or result.stdout.strip() or f"exit code {result.returncode}"
        errors.append(f"generated check failed for module {module_id}: {details}")


def validate_modules(
    root: Path,
    methodology: dict[str, Any],
    index: dict[str, Any],
    graph: dict[str, Any],
    errors: list[str],
) -> None:
    modules = index.get("modules", {})
    manifests_directory = repository_path(root, methodology["module_manifests"], "module manifests", errors)
    if manifests_directory is None:
        return

    manifests: dict[str, dict[str, Any]] = {}
    if manifests_directory.exists():
        for manifest_path in sorted(manifests_directory.glob("*.json")):
            manifest = load_json(manifest_path, errors)
            if manifest is None:
                continue
            validate_schema(
                manifest,
                root / methodology["schemas"] / SCHEMA_FILES["module_manifest"],
                str(manifest_path.relative_to(root)),
                errors,
            )
            module_id = manifest.get("module_id") if isinstance(manifest, dict) else None
            if isinstance(module_id, str):
                expected_path = manifests_directory / f"{module_id}.json"
                if manifest_path != expected_path:
                    errors.append(
                        f"manifest for module {module_id} must use {expected_path.relative_to(root)}"
                    )
                if module_id in manifests:
                    errors.append(f"duplicate manifest identity for module: {module_id}")
                manifests[module_id] = manifest
            else:
                errors.append(f"manifest has no valid module_id: {manifest_path.relative_to(root)}")

    for module_id, definition in modules.items():
        manifest_path = repository_path(root, definition["manifest"], f"{module_id} manifest", errors)
        if manifest_path is not None and not manifest_path.exists():
            errors.append(f"missing manifest for indexed module {module_id}: {definition['manifest']}")
        manifest = manifests.get(module_id)
        if manifest is not None:
            validate_paths(root, module_id, manifest, errors)
        elif manifest_path is not None and manifest_path.exists():
            errors.append(f"manifest module_id does not match index key: {module_id}")

        if definition["status"] == "implemented":
            for path_value in [*definition["roots"], *definition["entrypoints"]]:
                target = repository_path(root, path_value, f"{module_id} structural path", errors)
                if target is not None and not target.exists():
                    errors.append(f"implemented module path is missing for {module_id}: {path_value}")
        for dependency in definition["dependencies"]:
            if dependency not in modules:
                errors.append(f"unknown dependency for module {module_id}: {dependency}")

    for module_id in manifests:
        if module_id not in modules:
            errors.append(f"orphan manifest for unknown module: {module_id}")

    incoming: dict[str, set[str]] = {}
    for edge in graph.get("edges", []):
        source, destination = edge
        if source not in modules or destination not in modules:
            errors.append(f"dependency graph edge references unknown module: {source} -> {destination}")
            continue
        incoming.setdefault(destination, set()).add(source)
    for module_id, manifest in manifests.items():
        for path in manifest.get("paths", []):
            if path["lifecycle"] != "deprecated":
                continue
            allowed = set(path["legacy_consumers"])
            for consumer in incoming.get(module_id, set()) - allowed:
                errors.append(
                    f"deprecated module {module_id} has non-legacy consumer {consumer} for {path['path']}"
                )


def validate(root: Path) -> list[str]:
    root = root.resolve()
    errors: list[str] = []
    validate_delivery(root, errors)

    methodology_path = root / "agent" / "methodology.json"
    methodology = load_json(methodology_path, errors)
    if not isinstance(methodology, dict):
        return errors
    validate_schema(methodology, root / "agent" / "schemas" / SCHEMA_FILES["methodology"], "methodology", errors)
    if errors:
        return errors

    index_path = repository_path(root, methodology["module_index"], "module index", errors)
    graph_path = repository_path(root, methodology["dependency_graph"], "dependency graph", errors)
    if index_path is None or graph_path is None:
        return errors
    index = load_json(index_path, errors)
    graph = load_json(graph_path, errors)
    if not isinstance(index, dict) or not isinstance(graph, dict):
        return errors
    schemas_path = repository_path(root, methodology["schemas"], "schemas", errors)
    if schemas_path is None:
        return errors
    validate_schema(index, schemas_path / SCHEMA_FILES["module_index"], "module index", errors)
    validate_schema(graph, schemas_path / SCHEMA_FILES["dependency_graph"], "dependency graph", errors)
    if errors:
        return errors
    validate_modules(root, methodology, index, graph, errors)
    return errors


def main(arguments: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="repository root (default: current directory)")
    options = parser.parse_args(arguments)
    errors = validate(options.root)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("agent contracts: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
