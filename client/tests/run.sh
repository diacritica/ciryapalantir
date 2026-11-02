#!/bin/sh
# Runs the client tests and the smoke tests of the game scene, the demo, the written move, the Henneth Annûn rule and the views. A script error
# anywhere fails, even when it stops a test before its checks, and so does an
# autoload that cannot be loaded, as when the editor writes back old ones.
# Set GODOT to the Godot 3.5 binary if it is not on the PATH as godot. They
# run with a profile of their own, so what the player keeps in user:// is
# neither read nor changed.

cd "$(dirname "$0")/.." || exit 1
GODOT=${GODOT:-godot}
status=0

for script in tests/run.gd tests/smoke_game.gd tests/smoke_demo.gd tests/smoke_written.gd tests/smoke_henneth.gd tests/smoke_view.gd; do
    output=$("$GODOT" --no-window --path . -s "$script" -- --profile=tests 2>&1) || status=1
    echo "$output" | grep -E "FAIL|SCRIPT ERROR|Can't autoload|tests,|smoke"
    echo "$output" | grep -q "SCRIPT ERROR\|Can't autoload" && status=1
done

exit $status
