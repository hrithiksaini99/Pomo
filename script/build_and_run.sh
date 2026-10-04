#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/Pomo.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/Pomo"

case "$MODE" in
  run|--debug|--logs|--telemetry|--verify|--smoke-test) ;;
  *) echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--smoke-test]" >&2; exit 2 ;;
esac

# Stop only our build or installed executable. No Apple events permission is needed.
while read -r app_pid; do
  [[ -z "$app_pid" ]] && continue
  app_path=$(ps -p "$app_pid" -o comm= 2>/dev/null || true)
  if [[ "$app_path" == "$APP_BINARY" || "$app_path" == "$HOME/Applications/Pomo.app/Contents/MacOS/Pomo" ]]; then
    kill -TERM "$app_pid" 2>/dev/null || true
  fi
done < <(pgrep -x Pomo || true)

"$ROOT_DIR/build.sh"

case "$MODE" in
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
  --debug) lldb -- "$APP_BINARY" ;;
  --logs)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate 'process == "Pomo"'
    ;;
  --telemetry)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.hrithik.pomo"'
    ;;
  --verify)
    /usr/bin/open -n "$APP_BUNDLE"
    sleep 1
    pgrep -f "^$APP_BINARY" >/dev/null
    echo "Pomo is running in the menu bar."
    ;;
  --smoke-test)
    mkdir -p "$ROOT_DIR/build"
    REPORT="$ROOT_DIR/build/smoke-test.log"
    rm -f "$REPORT"
    /usr/bin/open -n -W "$APP_BUNDLE" --args --smoke-test --diagnostics-path "$REPORT"
    test -s "$REPORT"
    cat "$REPORT"
    if /usr/bin/grep -q '^FAIL:' "$REPORT"; then exit 1; fi
    ;;
esac
