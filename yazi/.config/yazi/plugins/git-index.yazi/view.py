#!/usr/bin/env python3
"""Open a decoded Git index in nvim as read-only (does not modify the index file)."""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from preview import format_index  # noqa: E402


def view_one(path: Path) -> int:
	text = format_index(path)
	label = f"git-index:{path.parent.parent.name}/{path.name}"

	fd, tmp = tempfile.mkstemp(prefix="yazi-git-index-", suffix=".txt", text=True)
	try:
		with os.fdopen(fd, "w", encoding="utf-8") as f:
			f.write(text)
		cmd = [
			"nvim",
			"-R",
			"-M",
			"-c",
			"setlocal noswapfile nobuflisted bufhidden=wipe",
			"-c",
			f"file {label}",
			"-c",
			"setlocal filetype=git",
			tmp,
		]
		return subprocess.call(cmd)
	finally:
		try:
			os.unlink(tmp)
		except OSError:
			pass


def main() -> int:
	if len(sys.argv) < 2:
		print("usage: view.py <index> [index...]", file=sys.stderr)
		return 2
	rc = 0
	for arg in sys.argv[1:]:
		code = view_one(Path(arg))
		if code:
			rc = code
	return rc


if __name__ == "__main__":
	raise SystemExit(main())
