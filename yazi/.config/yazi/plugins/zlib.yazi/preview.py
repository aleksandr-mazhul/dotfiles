#!/usr/bin/env python3
"""Format zlib-compressed Git objects (no git required). Shared by preview + view."""
from __future__ import annotations

import sys
import zlib
from pathlib import Path


def entry_kind(mode: str) -> str:
	m = mode.zfill(6)
	if m == "040000":
		return "tree"
	if m == "160000":
		return "commit"
	if m == "120000":
		return "link"
	return "blob"


def decode_tree(body: bytes) -> str:
	lines: list[str] = []
	i = 0
	n = len(body)
	while i < n:
		sp = body.find(b" ", i)
		if sp < 0:
			break
		mode = body[i:sp].decode("ascii", "replace")
		z = body.find(b"\0", sp)
		if z < 0 or z + 21 > n:
			break
		name = body[sp + 1 : z].decode("utf-8", "replace")
		sha = body[z + 1 : z + 21].hex()
		i = z + 21
		# Spaces (not tabs): yazi ui.Text collapses \\t to nothing.
		lines.append(f"{mode.zfill(6)} {entry_kind(mode)} {sha}  {name}")
	return "\n".join(lines)


def format_object(path: Path) -> tuple[str, str]:
	"""Return (kind, text). kind is git type or 'zlib'/'error'."""
	try:
		raw = path.read_bytes()
		data = zlib.decompress(raw)
	except Exception as e:
		return "error", f"not a zlib/git object: {e}\n"

	nul = data.find(b"\0")
	if nul < 0:
		preview = data[:4096]
		try:
			text = preview.decode("utf-8")
		except UnicodeDecodeError:
			text = f"<binary zlib, showing {len(preview)}/{len(data)} bytes>\n"
		else:
			text = "zlib ok, but not a git object (no header)\n---\n" + text
			if not text.endswith("\n"):
				text += "\n"
		return "zlib", text

	header = data[:nul].decode("ascii", "replace")
	parts = header.split(" ", 1)
	kind = parts[0]
	size = parts[1] if len(parts) > 1 else "?"
	body = data[nul + 1 :]

	head = f"type: {kind}\nsize: {size}\n---\n"

	if kind == "blob":
		try:
			text = body.decode("utf-8")
		except UnicodeDecodeError:
			return kind, head + f"<binary blob, {len(body)} bytes>\n"
		if len(text) > 512_000:
			text = text[:512_000] + "\n… truncated …\n"
		if not text.endswith("\n"):
			text += "\n"
		return kind, head + text

	if kind == "tree":
		return kind, head + decode_tree(body) + "\n"

	if kind in ("commit", "tag"):
		text = body.decode("utf-8", "replace")
		if not text.endswith("\n"):
			text += "\n"
		return kind, head + text

	return kind, head + body[:4096].decode("utf-8", "replace") + "\n"


def main() -> int:
	if len(sys.argv) < 2:
		print("usage: preview.py <file>", file=sys.stderr)
		return 2
	kind, text = format_object(Path(sys.argv[1]))
	sys.stdout.write(text)
	return 0 if kind != "error" else 1


if __name__ == "__main__":
	raise SystemExit(main())
