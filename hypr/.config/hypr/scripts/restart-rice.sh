#!/usr/bin/env bash
# Restart rice quickshell so GroupStackBar picks up.
set -euo pipefail
pkill -f 'qs -c rice' 2>/dev/null || true
sleep 0.3
qs -c rice -n -d
echo "rice restarted"
