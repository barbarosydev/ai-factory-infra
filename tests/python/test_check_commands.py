"""Tests for scripts/lib/check_commands.py."""

import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts" / "lib"))
import check_commands  # noqa: E402


class CheckCommandsTests(unittest.TestCase):
    def _make_repo(self, tmp: str, taskfile: str, agents: str, runbook: str) -> pathlib.Path:
        root = pathlib.Path(tmp)
        (root / "docs").mkdir(parents=True, exist_ok=True)
        (root / "Taskfile.yml").write_text(taskfile, encoding="utf-8")
        (root / "AGENTS.md").write_text(agents, encoding="utf-8")
        (root / "docs" / "runbook.md").write_text(runbook, encoding="utf-8")
        return root

    def test_matching_tasks_pass(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = self._make_repo(
                tmp,
                'version: "3"\ntasks:\n  default:\n    cmds: []\n  up:\n    cmds: []\n  smoke:cluster:\n    cmds: []\n',
                "Run `task up` and `task smoke:cluster` or `task --list`.\n",
                "Use `task up` and `task smoke:cluster`.\n",
            )
            self.assertEqual(check_commands.check_repo(root), [])

    def test_missing_and_unknown_tasks_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = self._make_repo(
                tmp,
                'version: "3"\ntasks:\n  up:\n    cmds: []\n  down:\n    cmds: []\n',
                "Run `task up` and `task ghost`.\n",
                "Run `task up` and `task down`.\n",
            )
            errs = check_commands.check_repo(root)
            self.assertEqual(len(errs), 2)
            self.assertIn("missing tasks", errs[0])
            self.assertIn("down", errs[0])
            self.assertIn("unknown tasks", errs[1])
            self.assertIn("ghost", errs[1])


if __name__ == "__main__":
    unittest.main()
