#!/usr/bin/env bash
# Child of test-linux-gui.sh, within a private runtime directory and D-Bus session.
# Weston 13 cannot launch clients with `-- command`; manage its lifetime here.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
: "${XDG_RUNTIME_DIR:?Private runtime directory required}"
weston --backend=headless --renderer=pixman --no-config --idle-time=0 \
  --socket=tap-wayland --log="${XDG_RUNTIME_DIR}/weston.log" &
compositor=$!
trap 'kill "${compositor}" 2>/dev/null || true; wait "${compositor}" 2>/dev/null || true' EXIT
for _ in {1..100}
do
  [[ -S "${XDG_RUNTIME_DIR}/tap-wayland" ]] && break
  if ! kill -0 "${compositor}" 2>/dev/null
  then
    cat "${XDG_RUNTIME_DIR}/weston.log"
    exit 1
  fi
  sleep 0.1
done
[[ -S "${XDG_RUNTIME_DIR}/tap-wayland" ]] || {
  cat "${XDG_RUNTIME_DIR}/weston.log"
  exit 1
}
export WAYLAND_DISPLAY=tap-wayland
python3 "${root}/scripts/gui-smoke.py" --session wayland "$@"
