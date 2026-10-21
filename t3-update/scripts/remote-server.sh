#!/bin/bash
# Status and update of a T3 Code CLI server that runs as a user service on a remote machine.
# Sent over SSH by t3-update.ps1 (`ssh <host> bash -s -- <args>`); bash 3.2 compatible for macOS.
#
#   remote-server.sh status
#   remote-server.sh update <version> [--allow-busy]
#
# Linux: systemd user unit ~/.config/systemd/user/t3code.service, T3 home ~/.t3.
# macOS: launchd agent ~/Library/LaunchAgents/com.t3code.server.plist, T3 home ~/.t3-server.
# The service definition names the runtime binary <home>/runtime/versions/<version>/t3, so an update
# installs that runtime with the npm launcher (t3@<version>), repoints the definition and restarts.
#
# Output is key=value lines. Exit codes: 0 ok, 3 update failed (rolled back), 4 not set up as expected,
# 10 skipped because threads are running.
set -u
export PATH="/opt/homebrew/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

MODE="${1:-status}"
TARGET="${2:-}"
ALLOW_BUSY=0
[ "${3:-}" = "--allow-busy" ] && ALLOW_BUSY=1

if [ "$(uname)" = "Darwin" ]; then
  OS=macos
  BASE="$HOME/.t3-server"
  DEF="$HOME/Library/LaunchAgents/com.t3code.server.plist"
  LABEL=com.t3code.server
else
  OS=linux
  BASE="$HOME/.t3"
  DEF="$HOME/.config/systemd/user/t3code.service"
  LABEL=t3code.service
fi
echo "os=$OS"
[ -f "$DEF" ] || { echo "error=service definition not found: $DEF"; exit 4; }

defined_binary() {
  if [ "$OS" = macos ]; then
    plutil -extract ProgramArguments.0 raw -o - "$DEF"
  else
    grep -E '^ExecStart=' "$DEF" | head -1 | sed -E 's/^ExecStart=([^ ]+).*/\1/' | sed "s#%h#$HOME#g"
  fi
}

defined_port() {
  local port
  if [ "$OS" = macos ]; then
    port=$(plutil -convert json -o - "$DEF" | python3 -c 'import json,sys;a=json.load(sys.stdin)["ProgramArguments"];print(a[a.index("--port")+1] if "--port" in a else "")')
  else
    port=$(grep -E '^ExecStart=' "$DEF" | grep -oE -- '--port [0-9]+' | awk '{print $2}')
  fi
  echo "${port:-3773}"
}

running_version() {
  curl -s -m 5 "http://127.0.0.1:$(defined_port)/.well-known/t3/environment" |
    python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("serverVersion",""))
except Exception: print("")' 2>/dev/null
}

active_runs() {
  python3 - "$BASE/userdata/statev2.sqlite" <<'PY'
import json, sqlite3, sys
try:
    db = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
    titles = {r[0]: json.loads(r[1]).get("title", "") for r in db.execute(
        "select thread_id, payload_json from orchestration_v2_projection_threads")}
    rows = db.execute(
        "select distinct thread_id from orchestration_v2_projection_runs where status in "
        "('queued','preparing','starting','running','waiting')").fetchall()
    print(len(rows))
    print("; ".join(titles.get(r[0], r[0])[:50] for r in rows))
except Exception as e:
    print(0)
    print(f"unknown ({e.__class__.__name__})")
PY
}

restart_service() {
  if [ "$OS" = macos ]; then
    local domain="gui/$(id -u)"
    launchctl bootout "$domain/$LABEL" 2>/dev/null
    local i=0
    while launchctl print "$domain/$LABEL" >/dev/null 2>&1 && [ $i -lt 30 ]; do sleep 1; i=$((i + 1)); done
    stop_foreign_servers >/dev/null
    launchctl bootstrap "$domain" "$DEF"
  else
    systemctl --user daemon-reload && systemctl --user stop "$LABEL"
    stop_foreign_servers >/dev/null
    systemctl --user start "$LABEL"
  fi
}

service_pid() {
  if [ "$OS" = macos ]; then
    launchctl print "gui/$(id -u)/$LABEL" 2>/dev/null | awk '/^\tpid = /{print $3; exit}'
  else
    systemctl --user show -p MainPID --value "$LABEL" 2>/dev/null
  fi
}

# A T3 desktop client with an SSH-launched connection to this machine starts its own `t3 serve` (with an
# old runtime) as soon as the service goes down. It then owns the T3 home, and the service fails with
# ServerAlreadyRunningError. Stop any `t3 serve` on this T3 home that the service manager didn't start.
stop_foreign_servers() {
  local main pid stopped=""
  main=$(service_pid)
  for pid in $(pgrep -f "/runtime/versions/[^ ]*/t3 serve"); do
    [ "$pid" = "$main" ] && continue
    ps -o args= -p "$pid" | grep -qE -- "--base-dir $BASE( |$)" || continue
    pkill -TERM -P "$pid" 2>/dev/null
    kill -TERM "$pid" 2>/dev/null && stopped="$stopped $pid"
  done
  [ -n "$stopped" ] || return 1
  sleep 3
  for pid in $stopped; do kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null; done
  echo "stopped_foreign_server=${stopped# }"
  return 0
}

wait_for_version() {
  local want="$1" i=0 got="" retries=0
  while [ $i -lt 90 ]; do
    got=$(running_version)
    [ "$got" = "$want" ] && return 0
    if [ $((i % 10)) -eq 9 ] && [ $retries -lt 2 ] && stop_foreign_servers; then
      retries=$((retries + 1))
      restart_service
    fi
    sleep 2
    i=$((i + 1))
  done
  echo "error=server reports '${got:-nothing}' after 180 s, expected $want"
  return 1
}

BIN=$(defined_binary)
SERVICE_VERSION=$(echo "$BIN" | sed -nE 's#.*/runtime/versions/([^/]+)/t3$#\1#p')
echo "service_version=${SERVICE_VERSION:-unknown}"
echo "running_version=$(running_version)"
RUNS=$(active_runs)
ACTIVE=$(echo "$RUNS" | sed -n 1p)
echo "active_runs=$ACTIVE"
echo "active_titles=$(echo "$RUNS" | sed -n 2p)"

[ "$MODE" = status ] && exit 0
[ "$MODE" = update ] && [ -n "$TARGET" ] || { echo "error=usage: update <version> [--allow-busy]"; exit 4; }
[ -n "$SERVICE_VERSION" ] || { echo "error=cannot read the runtime version from $DEF ($BIN)"; exit 4; }

if [ "$SERVICE_VERSION" = "$TARGET" ] && [ "$(running_version)" = "$TARGET" ]; then
  echo "result=current"
  exit 0
fi
if [ "$ACTIVE" != "0" ] && [ $ALLOW_BUSY -eq 0 ]; then
  echo "result=skipped-busy"
  exit 10
fi

# 1. Launcher and runtime for the target version, installed into the service's own T3 home.
npm install --global --prefix "$HOME/.local" "t3@$TARGET" --no-fund --no-audit --loglevel=error >/dev/null 2>&1 ||
  { echo "error=npm install t3@$TARGET failed"; exit 3; }
T3CODE_HOME="$BASE" "$HOME/.local/bin/t3" --version >/dev/null 2>&1
DIR="$BASE/runtime/versions/$TARGET"
if [ "$(cat "$DIR/.install-complete" 2>/dev/null)" != "$TARGET" ] || [ ! -x "$DIR/t3" ]; then
  echo "error=runtime $TARGET did not install into $DIR"
  exit 3
fi

# 2. Repoint the service definition, keeping a backup for rollback.
BACKUP="$BASE/t3-update-backup"
mkdir -p "$BACKUP"
SAVED="$BACKUP/$(basename "$DEF").$SERVICE_VERSION"
cp "$DEF" "$SAVED"
REPOINTED=1
if [ "$OS" = macos ]; then
  # `plutil -replace` on an array index inserts instead of replacing, which left the old binary as the
  # first argument of `serve` and rolled back every update. Remove, insert, and check the count held.
  ARGS=$(plutil -extract ProgramArguments raw -o - "$DEF")
  { plutil -remove ProgramArguments.0 "$DEF" && plutil -insert ProgramArguments.0 -string "$DIR/t3" "$DEF" &&
    [ "$(plutil -extract ProgramArguments raw -o - "$DEF")" = "$ARGS" ] && plutil -lint "$DEF" >/dev/null; } ||
    REPOINTED=0
else
  sed -i "s#/runtime/versions/$SERVICE_VERSION/t3 #/runtime/versions/$TARGET/t3 #" "$DEF"
fi
if [ $REPOINTED -eq 0 ] || [ "$(defined_binary)" != "$DIR/t3" ]; then
  cp "$SAVED" "$DEF"
  echo "error=could not repoint $DEF"
  exit 3
fi

# 3. Restart and verify; roll back to the saved definition on failure.
restart_service
if wait_for_version "$TARGET"; then
  echo "result=updated"
  echo "from=$SERVICE_VERSION"
  echo "to=$TARGET"
  exit 0
fi
cp "$SAVED" "$DEF"
restart_service
if wait_for_version "$SERVICE_VERSION"; then
  echo "result=rolled-back"
else
  echo "result=rollback-failed"
fi
exit 3
