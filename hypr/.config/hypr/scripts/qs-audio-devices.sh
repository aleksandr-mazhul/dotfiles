#!/usr/bin/env bash
# List PipeWire sinks/sources for Quickshell QS panel.
# Usage: qs-audio-devices.sh sinks|sources
# Output lines: id|label|default(0|1)
set -euo pipefail

kind="${1:-sinks}"

python3 - "$kind" <<'PY'
import subprocess, sys, re

kind = (sys.argv[1] if len(sys.argv) > 1 else "sinks").lower()
section = "Sinks" if kind.startswith("sink") else "Sources"
text = subprocess.check_output(["wpctl", "status"], text=True, stderr=subprocess.DEVNULL)
m = re.search(r"Audio\n(.*?)(?:\nVideo|\nSettings|\Z)", text, re.S)
block = m.group(1) if m else text
mm = re.search(rf"[├└]─ {section}:\n(.*?)(?:[├└]─ |\Z)", block, re.S)
if not mm:
    sys.exit(0)
for line in mm.group(1).splitlines():
    m = re.search(r"(\*?)\s*(\d+)\.\s+(.*)", line)
    if not m:
        continue
    default = "1" if m.group(1) == "*" else "0"
    label = re.sub(r"\s*\[.*$", "", m.group(3)).strip()
    print(f"{m.group(2)}|{label}|{default}")
PY
