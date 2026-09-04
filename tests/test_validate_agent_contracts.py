import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = PROJECT_ROOT / "scripts" / "validate_agent_contracts.py"


class ValidateAgentContractsTests(unittest.TestCase):
    def valid_repository(self) -> Path:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        (root / "agent" / "modules").mkdir(parents=True)
        (root / "agent" / "schemas").mkdir(parents=True)

        self.write_json(
            root / "agent" / "methodology.json",
            {
                "methodology": "agent-project-methodology",
                "version": "2.1",
                "module_index": "agent/module-index.json",
                "dependency_graph": "agent/dependency-graph.json",
                "module_manifests": "agent/modules",
                "schemas": "agent/schemas",
            },
        )
        self.write_json(root / "agent" / "module-index.json", {"schema_version": 1, "modules": {}})
        self.write_json(root / "agent" / "dependency-graph.json", {"schema_version": 1, "edges": []})
        (root / "AGENTS.md").write_text(
            "[EXECUTION-CORE v2.1] agent/execution-core.md\n", encoding="utf-8"
        )
        (root / "agent" / "execution-core.md").write_text(
            "[EXECUTION-CORE v2.1]\n", encoding="utf-8"
        )
        for name in (
            "methodology.schema.json",
            "module-index.schema.json",
            "dependency-graph.schema.json",
            "module-manifest.schema.json",
        ):
            self.write_json(root / "agent" / "schemas" / name, {"$schema": "https://json-schema.org/draft/2020-12/schema"})
        return root

    def run_validator(self, root: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(VALIDATOR), "--root", str(root)],
            capture_output=True,
            text=True,
            check=False,
        )

    def write_index(self, root: Path, index: dict) -> None:
        self.write_json(root / "agent" / "module-index.json", index)

    @staticmethod
    def write_json(path: Path, payload: dict) -> None:
        path.write_text(json.dumps(payload), encoding="utf-8")

    def test_valid_empty_repository_passes(self) -> None:
        result = self.run_validator(self.valid_repository())
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_manifest_for_indexed_module_fails(self) -> None:
        root = self.valid_repository()
        (root / "src" / "api").mkdir(parents=True)
        (root / "src" / "api" / "main.py").touch()
        self.write_index(
            root,
            {
                "schema_version": 1,
                "modules": {
                    "api": {
                        "status": "implemented",
                        "roots": ["src/api"],
                        "entrypoints": ["src/api/main.py"],
                        "manifest": "agent/modules/api.json",
                        "dependencies": [],
                    }
                },
            },
        )
        result = self.run_validator(root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing manifest", result.stderr)

    def test_bad_execution_core_sentinel_fails(self) -> None:
        root = self.valid_repository()
        (root / "agent" / "execution-core.md").write_text("[EXECUTION-CORE v2.0]\n", encoding="utf-8")
        result = self.run_validator(root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("execution core sentinel", result.stderr)

    def test_unknown_module_dependency_fails(self) -> None:
        root = self.valid_repository()
        self.write_index(
            root,
            {
                "schema_version": 1,
                "modules": {
                    "api": {
                        "status": "planned",
                        "roots": [],
                        "entrypoints": [],
                        "manifest": "agent/modules/api.json",
                        "dependencies": ["missing-module"],
                    }
                },
            },
        )
        self.write_json(
            root / "agent" / "modules" / "api.json",
            {"schema_version": 1, "module_id": "api", "purpose": "API", "paths": []},
        )
        result = self.run_validator(root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown dependency", result.stderr)

    def test_existing_planned_path_fails(self) -> None:
        root = self.valid_repository()
        self.write_index(
            root,
            {
                "schema_version": 1,
                "modules": {
                    "api": {
                        "status": "planned",
                        "roots": [],
                        "entrypoints": [],
                        "manifest": "agent/modules/api.json",
                        "dependencies": [],
                    }
                },
            },
        )
        (root / "src").mkdir()
        (root / "src" / "future.py").touch()
        self.write_json(
            root / "agent" / "modules" / "api.json",
            {
                "schema_version": 1,
                "module_id": "api",
                "purpose": "API",
                "paths": [
                    {
                        "path": "src/future.py",
                        "lifecycle": "planned",
                        "provenance": "authored",
                    }
                ],
            },
        )
        result = self.run_validator(root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("planned path exists", result.stderr)

    def test_duplicate_manifest_identity_fails(self) -> None:
        root = self.valid_repository()
        self.write_index(
            root,
            {
                "schema_version": 1,
                "modules": {
                    "api": {
                        "status": "planned",
                        "roots": [],
                        "entrypoints": [],
                        "manifest": "agent/modules/api.json",
                        "dependencies": [],
                    }
                },
            },
        )
        manifest = {"schema_version": 1, "module_id": "api", "purpose": "API", "paths": []}
        self.write_json(root / "agent" / "modules" / "api.json", manifest)
        self.write_json(root / "agent" / "modules" / "api-copy.json", manifest)
        result = self.run_validator(root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate manifest identity", result.stderr)

    def test_generated_check_rejects_shell_interpreter(self) -> None:
        root = self.valid_repository()
        self.write_index(
            root,
            {
                "schema_version": 1,
                "modules": {
                    "generated": {
                        "status": "implemented",
                        "roots": ["generated"],
                        "entrypoints": ["generated/artifact.json"],
                        "manifest": "agent/modules/generated.json",
                        "dependencies": [],
                    }
                },
            },
        )
        (root / "generated").mkdir()
        (root / "generated" / "artifact.json").touch()
        (root / "scripts").mkdir()
        (root / "scripts" / "generate.py").touch()
        self.write_json(
            root / "agent" / "modules" / "generated.json",
            {
                "schema_version": 1,
                "module_id": "generated",
                "purpose": "Generated artifact",
                "paths": [
                    {
                        "path": "generated/artifact.json",
                        "lifecycle": "implemented",
                        "provenance": "generated",
                        "generator": "scripts/generate.py",
                        "check": ["/bin/sh", "-c", "touch generated/unsafe", "--check"],
                    }
                ],
            },
        )
        result = self.run_validator(root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("forbidden executable", result.stderr)


if __name__ == "__main__":
    unittest.main()
