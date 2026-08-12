#!/usr/bin/env python3
"""Preview Git index: native `file` blurb first, then a decoded listing."""
from __future__ import annotations

import shutil
import struct
import subprocess
import sys
from pathlib import Path


def mode_str(mode: int) -> str:
	return f"{mode:o}"[-6:].zfill(6)


def kind_of(mode: int) -> str:
	m = mode & 0o170000
	if m == 0o040000:
		return "tree"
	if m == 0o160000:
		return "gitlink"
	if m == 0o120000:
		return "symlink"
	if mode & 0o111:
		return "executable"
	return "file"


def fmt_size(n: int) -> str:
	if n < 1000:
		return f"{n} B"
	if n < 1_000_000:
		s = f"{n / 1000:.1f}".rstrip("0").rstrip(".")
		return f"{s} KB"
	s = f"{n / 1_000_000:.1f}".rstrip("0").rstrip(".")
	return f"{s} MB"


def file_blurb(path: Path) -> str:
	"""Same fallback Yazi used before (file -bL)."""
	file_bin = shutil.which("file")
	if not file_bin:
		return ""
	try:
		out = subprocess.check_output(
			[file_bin, "-bL", str(path)],
			stderr=subprocess.DEVNULL,
			text=True,
		).strip()
		return out
	except (OSError, subprocess.CalledProcessError):
		return ""


def parse_entries(data: bytes) -> tuple[int, int, list[tuple[int, int, str, int, str]], list[str]]:
	"""Return version, nentries, rows(mode, stage, oid, size, path), extensions."""
	if len(data) < 12 or data[:4] != b"DIRC":
		raise ValueError("not a git index (missing DIRC signature)")

	version, nentries = struct.unpack(">II", data[4:12])
	hash_len = 20
	rows: list[tuple[int, int, str, int, str]] = []
	pos = 12
	parsed = 0

	while parsed < nentries and pos + 62 <= len(data):
		entry_start = pos
		(
			_ctime_s,
			_ctime_n,
			_mtime_s,
			_mtime_n,
			_dev,
			_ino,
			mode,
			_uid,
			_gid,
			size,
		) = struct.unpack(">IIIIIIIIII", data[pos : pos + 40])
		oid = data[pos + 40 : pos + 40 + hash_len].hex()
		flags_off = pos + 40 + hash_len
		flags = struct.unpack(">H", data[flags_off : flags_off + 2])[0]
		pos = flags_off + 2

		stage = (flags >> 12) & 0x3
		name_len = flags & 0x0FFF

		if version >= 3 and (flags & 0x4000):
			if pos + 2 > len(data):
				break
			pos += 2

		if name_len < 0x0FFF:
			end = pos + name_len
			if end + 1 > len(data):
				break
			name = data[pos:end].decode("utf-8", "replace")
			pos = end + 1
		else:
			z = data.find(b"\0", pos)
			if z < 0:
				break
			name = data[pos:z].decode("utf-8", "replace")
			pos = z + 1

		pad = (8 - ((pos - entry_start) % 8)) % 8
		pos += pad

		rows.append((mode, stage, oid, size, name))
		parsed += 1

	exts: list[str] = []
	if pos + 20 <= len(data):
		while pos + 8 <= len(data) - 20:
			sig = data[pos : pos + 4]
			if not all(48 <= b < 127 for b in sig):
				break
			(ext_len,) = struct.unpack(">I", data[pos + 4 : pos + 8])
			if ext_len < 0 or pos + 8 + ext_len > len(data) - 20:
				break
			exts.append(f"{sig.decode('ascii', 'replace')} ({ext_len} B)")
			pos += 8 + ext_len

	return version, nentries, rows, exts


def format_index(path: Path) -> str:
	blurb = file_blurb(path)
	try:
		data = path.read_bytes()
	except OSError as e:
		parts = [blurb] if blurb else []
		parts.append(f"cannot read: {e}")
		return "\n".join(parts) + "\n"

	lines: list[str] = []
	if blurb:
		lines.append(blurb)
		lines.append("")
		lines.append("── decoded ──")
		lines.append("")

	try:
		version, nentries, rows, exts = parse_entries(data)
	except ValueError as e:
		lines.append(str(e))
		return "\n".join(lines) + "\n"

	if not blurb:
		lines.append(f"Git index, version {version}, {nentries} entries")
		lines.append("")
		lines.append("── decoded ──")
		lines.append("")

	for i, (mode, stage, oid, size, name) in enumerate(rows, 1):
		stage_note = f"stage {stage}" if stage else "stage 0"
		lines.append(name)
		lines.append(
			f"  {mode_str(mode)}  ·  {kind_of(mode)}  ·  {stage_note}"
			f"  ·  {oid[:12]}  ·  {fmt_size(size)}"
		)
		if i < len(rows):
			lines.append("")

	if len(rows) != nentries:
		lines.append("")
		lines.append(f"(parsed {len(rows)}/{nentries} entries)")

	if exts:
		lines.append("")
		lines.append("extensions  " + " · ".join(exts))

	if len(data) >= 20:
		lines.append("")
		lines.append(f"checksum    {data[-20:].hex()[:16]}…")

	return "\n".join(lines) + "\n"


def main() -> int:
	if len(sys.argv) < 2:
		print("usage: preview.py <index>", file=sys.stderr)
		return 2
	sys.stdout.write(format_index(Path(sys.argv[1])))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
