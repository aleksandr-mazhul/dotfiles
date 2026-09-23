#!/usr/bin/env bash
# The Vial hidraw rule now lives in system/ with the other /etc files.
exec "$(readlink -f "$0" | sed 's#/hypr/\.config/hypr/scripts/.*##')/system/install.sh" "$@"
