#!/bin/sh
# A whole online game on this computer: the Go server, the bot playing black,
# a headless client playing white through the game scene and a spectator
# coming in through the menu. Set GODOT to the Godot 3.5 binary.

cd "$(dirname "$0")/../.." || exit 1
GODOT=${GODOT:-godot}
PORT=${PORT:-3399}
ROOM=E2E$(date +%s)
BIN=$(mktemp -d)
status=0

(cd server && go build -o "$BIN/server" ./cmd/cirya-server && go build -o "$BIN/bot" ./cmd/cirya-bot) || exit 1
"$BIN/server" -p "$PORT" > "$BIN/server.log" 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null; rm -rf "$BIN"' EXIT
sleep 1

"$BIN/bot" -server "127.0.0.1:$PORT" -room "$ROOM" > "$BIN/bot.log" 2>&1 &

for script in e2e_player e2e_spectator; do
    output=$("$GODOT" --no-window --path client -s "tests/$script.gd" -- --server="127.0.0.1:$PORT" --profile="$script" --room="$ROOM" 2>&1) || status=1
    echo "$output" | grep -E "FAIL|SCRIPT ERROR|e2e"
    echo "$output" | grep -q "SCRIPT ERROR" && status=1
done

echo "--- bot"
tail -3 "$BIN/bot.log"
exit $status
