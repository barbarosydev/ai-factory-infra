"""Tests for scripts/lib/check_links.py using a throwaway git repository.

Run: python3 -m unittest discover -s tests/python -q
"""

import contextlib
import io
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts" / "lib"))

import check_links  # noqa: E402


class CheckLinksTests(unittest.TestCase):
    def setUp(self):
        # Drop git's hook environment so `git init` targets the temporary directory.
        for var in [v for v in os.environ if v.startswith("GIT_")]:
            self.addCleanup(os.environ.__setitem__, var, os.environ.pop(var))
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = pathlib.Path(self._tmp.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        (self.root / "docs").mkdir()
        (self.root / "docs" / "real.md").write_text("# Real\n", encoding="utf-8")
        (self.root / "scripts").mkdir()
        (self.root / "scripts" / "run.sh").write_text("#!/bin/sh\n", encoding="utf-8")
        (self.root / ".gitignore").write_text("local.json\n", encoding="utf-8")

    def check(self, text: str) -> list[tuple[int, str]]:
        page = self.root / "docs" / "page.md"
        page.write_text(text, encoding="utf-8")
        return check_links.check_file(self.root, page)

    def test_good_links(self):
        self.assertEqual(self.check("See [real](real.md) and [anchor](real.md#real) and `scripts/run.sh`.\n"), [])

    def test_broken_link(self):
        self.assertEqual(self.check("ok\n[gone](missing.md)\n"), [(2, "missing.md")])

    def test_broken_link_with_anchor(self):
        self.assertEqual(self.check("[gone](missing.md#top)\n"), [(1, "missing.md#top")])

    def test_skipped_links(self):
        text = "[a](https://example.invalid/x.md) [b](mailto:a@example.invalid) [c](#local-anchor)\n"
        self.assertEqual(self.check(text), [])

    def test_link_is_relative_to_the_file(self):
        self.assertEqual(self.check("[x](docs/real.md)\n"), [(1, "docs/real.md")])

    def test_broken_code_path(self):
        self.assertEqual(self.check("Run `scripts/missing.sh` now.\n"), [(1, "scripts/missing.sh")])

    def test_code_block_ignored(self):
        text = "```\n[gone](missing.md)\n`scripts/missing.sh`\n```\nafter\n"
        self.assertEqual(self.check(text), [])

    def test_glob_and_placeholder_ignored(self):
        text = "`terraform/modules/*/tests/x.tftest.hcl` `docs/<name>.md` `docs/{a,b}.md` `scripts/$X.sh`\n"
        self.assertEqual(self.check(text), [])

    def test_not_a_file_path(self):
        # Folders, commands and unknown prefixes are not checked.
        self.assertEqual(self.check("`docs/` `scripts/lib` `task kube -- get pods` `other/file.txt`\n"), [])

    def test_ignored_file_allowed(self):
        self.assertEqual(self.check("`docs/local.json` is local.\n"), [])

    def test_main_exit_codes(self):
        (self.root / "docs" / "page.md").write_text("[gone](missing.md)\n", encoding="utf-8")
        subprocess.run(["git", "-C", str(self.root), "add", "-A"], check=True)
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(check_links.main(["check_links.py", str(self.root)]), 1)
        (self.root / "docs" / "page.md").write_text("[real](real.md)\n", encoding="utf-8")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(check_links.main(["check_links.py", str(self.root)]), 0)

    def test_adr_index_sync(self):
        adr_dir = self.root / "docs" / "adr"
        adr_dir.mkdir(parents=True)
        (adr_dir / "0001-first.md").write_text("# 0001\n", encoding="utf-8")
        (adr_dir / "README.md").write_text("# ADRs\n", encoding="utf-8")
        self.assertEqual(
            check_links.check_adr_index(self.root),
            ["docs/adr/README.md: missing index link for 0001-first.md"],
        )
        (adr_dir / "README.md").write_text("# ADRs\n- [0001](0001-first.md)\n", encoding="utf-8")
        self.assertEqual(check_links.check_adr_index(self.root), [])


if __name__ == "__main__":
    unittest.main()
