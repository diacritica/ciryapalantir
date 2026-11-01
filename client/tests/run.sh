#!/bin/sh
# Runs the client tests and the smoke test of the game scene. A script error
# anywhere fails, even when it stops a test before its checks, and so does an
# autoload that cannot be loaded, as when the editor writes back old ones.
# Set GODOT to the Godot 3.5 binary if it is not on the PATH as godot.

cd "$(dirname "$0")/.." || exit 1
GODOT=${GODOT:-godot}
status=0

for script in tests/run.gd tests/smoke_game.gd; do
    output=$("$GODOT" --no-window --path . -s "$script" 2>&1) || status=1
    echo "$output" | grep -E "FAIL|SCRIPT ERROR|Can't autoload|tests,|smoke:"
    echo "$output" | grep -q "SCRIPT ERROR\|Can't autoload" && status=1
done

exit $status
