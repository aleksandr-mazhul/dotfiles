#!/usr/bin/env python3
"""Open a zlib/Git object in nvim as read-only (does not modify the object file)."""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

# Same directory as this script
sys.path.insert(0, str(Path(__file__).resolve().parent))
from preview import format_object  # noqa: E402


FT = {
	"commit": "gitcommit",
	"tag": "git",
	"tree": "git",
	"blob": "",  # let nvim detect from content after header, or text
}


def view_one(path: Path) -> int:
	kind, text = format_object(path)
	ft = FT.get(kind, "")
	# Label shown in nvim statusline — not a real write path
	label = f"git-{kind}:{path.parent.name}{path.name}"

	# Temp file so nvim gets a normal buffer; -R -M keep it view-only.
	suffix = {
		"commit": ".gitcommit",
		"tag": ".git",
		"tree": ".git",
		"blob": ".txt",
	}.get(kind, ".txt")

	fd, tmp = tempfile.mkstemp(prefix="yazi-zlib-", suffix=suffix, text=True)
	try:
		with os.fdopen(fd, "w", encoding="utf-8") as f:
			f.write(text)
		cmd = [
			"nvim",
			"-R",  # readonly
			"-M",  # nomodifiable
			"-c",
			"setlocal noswapfile nobuflisted bufhidden=wipe",
			"-c",
			f"file {label}",
		]
		if ft:
			cmd.extend(["-c", f"setlocal filetype={ft}"])
		cmd.append(tmp)
		return subprocess.call(cmd)
	finally:
		try:
			os.unlink(tmp)
		except OSError:
			pass


def main() -> int:
	if len(sys.argv) < 2:
		print("usage: view.py <file> [file...]", file=sys.stderr)
		return 2
	rc = 0
	for arg in sys.argv[1:]:
		code = view_one(Path(arg))
		if code:
			rc = code
	return rc


if __name__ == "__main__":
	raise SystemExit(main())
