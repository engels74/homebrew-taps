#!/usr/bin/env bash
# Isolated virtual displays; does not install or enable desktop services.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
apps=("$@")
if [[ "${#apps[@]}" -eq 0 ]]; then apps=(qview fredtv fcast-sender); fi
XDG_DATA_DIRS="$(brew --prefix)/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export XDG_DATA_DIRS
dbus-run-session -- xvfb-run -a -s '-screen 0 1280x720x24 -nolisten tcp' \
  python3 "${root}/scripts/gui-smoke.py" --session x11 "${apps[@]}"
# Keep one application's compositor state and teardown out of the next check.
for app in "${apps[@]}"
do
  runtime="$(mktemp -d)"
  trap 'rm -rf "${runtime}"' EXIT
  XDG_RUNTIME_DIR="${runtime}" dbus-run-session -- bash "${root}/scripts/test-wayland.sh" "${app}"
  rm -rf "${runtime}"
done
