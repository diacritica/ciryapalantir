#!/bin/sh
# Whole online games on this computer: the Go server, the bot playing black,
# a headless client playing white through the game scene and a spectator
# coming in through the menu. A second, scripted game breaks a nossë and ends
# by Londë, a third one is configured in the menu first, a fourth one
# reaches the turns of the hallaciryar with the Henneth Annûn rule, two more end with
# the offer of a rematch, accepted and refused, and in the last ones two bots of the client
# play each other. Set GODOT to the Godot 3.5 binary.

cd "$(dirname "$0")/../.." || exit 1
GODOT=${GODOT:-godot}
PORT=${PORT:-3399}
BIN=$(mktemp -d)
status=0

(cd server && go build -o "$BIN/server" ./cmd/cirya-server && go build -o "$BIN/bot" ./cmd/cirya-bot) || exit 1
"$BIN/server" -p "$PORT" > "$BIN/server.log" 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null; rm -rf "$BIN"' EXIT
sleep 1

# A room as the game makes it, by its code
new_room() {
    curl -s -X PUT "http://127.0.0.1:$PORT/rooms" | sed 's/.*"id":"\([^"]*\)".*/\1/'
}

ROOM=$(new_room)

"$BIN/bot" -server "127.0.0.1:$PORT" -room "$ROOM" > "$BIN/bot.log" 2>&1 &

for script in e2e_player e2e_spectator; do
    output=$("$GODOT" --no-window --path client -s "tests/$script.gd" -- --server="127.0.0.1:$PORT" --profile="$script" --room="$ROOM" 2>&1) || status=1
    echo "$output" | grep -E "FAIL|SCRIPT ERROR|e2e"
    echo "$output" | grep -q "SCRIPT ERROR" && status=1
done

# The turns of black for the scripted game are in tests/e2e_nosse.gd
ROOM=$(new_room)
MOVES=$(sed -n 's/^const BLACK = "\(.*\)"$/\1/p' client/tests/e2e_nosse.gd)
"$BIN/bot" -server "127.0.0.1:$PORT" -room "$ROOM" -moves "$MOVES" > "$BIN/bot-nosse.log" 2>&1 &
output=$("$GODOT" --no-window --path client -s tests/e2e_nosse.gd -- --server="127.0.0.1:$PORT" --profile=e2e_nosse --room="$ROOM" 2>&1) || status=1
echo "$output" | grep -E "FAIL|SCRIPT ERROR|e2e"
echo "$output" | grep -q "SCRIPT ERROR" && status=1

# The clock and the rule chosen in the menu, locked once the bot sits
ROOM=$(new_room)
output=$("$GODOT" --no-window --path client -s tests/e2e_config.gd -- --server="127.0.0.1:$PORT" --profile=e2e_config --room="$ROOM" --bot="$BIN/bot" 2>&1) || status=1
echo "$output" | grep -E "FAIL|SCRIPT ERROR|e2e"
echo "$output" | grep -q "SCRIPT ERROR" && status=1

# The Henneth Annûn rule up to the turns of the hallaciryar, against a bot started by the test
ROOM=$(new_room)
output=$("$GODOT" --no-window --path client -s tests/e2e_henneth.gd -- --server="127.0.0.1:$PORT" --profile=e2e_henneth --room="$ROOM" --bot="$BIN/bot" 2>&1) || status=1
echo "$output" | grep -E "FAIL|SCRIPT ERROR|e2e"
echo "$output" | grep -q "SCRIPT ERROR" && status=1

# The rematch at the end of a game, accepted and refused
for answer in yes no; do
    ROOM=$(new_room)
    output=$("$GODOT" --no-window --path client -s tests/e2e_rematch.gd -- --server="127.0.0.1:$PORT" --profile=e2e_rematch_$answer --room="$ROOM" --bot="$BIN/bot" --answer=$answer 2>&1) || status=1
    echo "$output" | grep -E "FAIL|SCRIPT ERROR|e2e"
    echo "$output" | grep -q "SCRIPT ERROR" && status=1
done

# Two bots of the client play each other through the server, with the usual rules and with T4K and Henneth Annûn
for rules in usual t4k; do
    ROOM=$(new_room)
    output=$("$GODOT" --no-window --path client -s tests/e2e_bots.gd -- --server="127.0.0.1:$PORT" --profile=e2e_bots_$rules --room="$ROOM" --rules=$rules 2>&1) || status=1
    echo "$output" | grep -E "FAIL|SCRIPT ERROR|e2e"
    echo "$output" | grep -q "SCRIPT ERROR" && status=1
done

echo "--- bots"
tail -n 2 "$BIN/bot.log" "$BIN/bot-nosse.log"
grep -i "panic\|race" "$BIN/server.log" && status=1
exit $status
