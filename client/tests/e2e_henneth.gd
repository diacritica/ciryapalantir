extends SceneTree

# A game with the Henneth Annûn rule against a real server, through the real
# game scene, up to the turns of the hallaciryar: each player moves its one
# cirya to the next square and back, and the server refuses the hallacirya
# of white before its turn as the client does. Black plays its own in its
# 16th turn and white in its 17th, written. The bot plays black, started
# here once the rule is chosen; tests/e2e.sh passes it with --bot=

const Status = preload("res://core/Status.gd")

var server
var state
var game
var failures = 0
var refusals = []
var configs = 0

func _initialize():
    call_deferred("_play")

func check(label, condition):
    if !condition:
        failures += 1
        print("FAIL ", label)

# The shuffle of tests on the server, henneth_test.go, but black plays its
# hallacirya in its 16th turn instead of moving
func shuffle(turn):
    if turn == 1:
        return "a1"
    if turn == 2:
        return "e5"
    if turn == 32:
        return "Hc3"
    # So its cirya is still on a1
    if turn == 34:
        return "a1>"
    if turn % 2 == 1:
        return ["e5<", "d5>"][(turn - 3) / 2 % 2]
    return ["a1>", "b1<"][(turn - 4) / 2 % 2]

func _play():
    server = get_root().get_node("Server")
    state = get_root().get_node("Match")

    if !server.logged_in():
        yield(server, "user_logged")

    server.connect("notification_received", self, "_on_notification")
    var room = _argument("--room=")
    server.join_room(room)
    yield(server, "connection_success")
    server.send_change_config({"hennethAnnun": true})
    yield(_until("the rule", "_configured"), "completed")

    var black = []
    for turn in range(2, 35, 2):
        black.append(shuffle(turn))

    var bot = "%s -server %s -room %s -name Morqua -moves '%s' > /dev/null 2>&1 &" % [_argument("--bot="), _argument("--server="), room, PoolStringArray(black).join(",")]
    OS.execute("sh", ["-c", bot], false)
    state.player = 1
    server.send_join_player(1, "white", "E2E")
    server.send_set_ready(true)
    yield(_until("the first turn", "_my_turn"), "completed")

    change_scene("res://Game.tscn")
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    game = current_scene
    check("the game has the rule", state.henneth_annun())

    yield(_write(1), "completed")

    # What the client stops, the server refuses
    check("the client stops the hallacirya in turn 3", game.play_written("Hc4").find("Henneth Annûn") != -1)
    server.ws_send_message({"type": "SubmitTurn", "params": {"player": 1, "turn": 3, "move": "Hc4"}})
    yield(_until("the refusal", "_refused"), "completed")
    check("and the server too", refusals.size() == 1 and refusals[0].type == "InvalidTurn")
    refusals.clear()

    while state.turn < 33 and state.phase == state.Phase.MY_TURN and failures == 0:
        yield(_write(state.turn), "completed")

    check("black played its hallacirya in its 16th turn", state.status.moves[31] == "Hc3" and _stones("c3") == ["H2"])
    check("now white is told to play it", state.turn == 33 and state.hallacirya_due())
    check("as the help says", game.get_node("UI/HelpPanel/AdviceLavel").text.find("Henneth Annûn") != -1)
    check("Hc4 written", game.play_written("Hc4") == "" and !state.renounces_hallacirya())
    yield(_confirm(), "completed")
    check("the hallacirya of white is on c4", _stones("c4") == ["H1"] and state.turn == 35)
    check("the board never went out of step", game.rebuilds == 0)

    print("e2e henneth: %d moves, %d failures" % [state.status.moves.size(), failures])
    quit(1 if failures else 0)

func _write(turn):
    var error = game.play_written(shuffle(turn))
    check("turn %d: %s" % [turn, error], error == "")
    yield(_confirm(), "completed")

# Confirms the turn and waits until black has played
func _confirm():
    var notation = state.move_notation()
    var turn = state.turn
    state.confirm()
    yield(_until("black after %s" % notation, "_turn_after", [turn]), "completed")
    check("%s went through" % notation, refusals.empty())
    check("after %s the board is the one of the server" % notation, Status.matches(state.status.board, state.board))

func _on_notification(message):
    if message.type in ["InvalidTurn", "Error"]:
        refusals.append(message)
    elif message.type == "ConfigChanged":
        configs += 1

func _until(what, condition, arguments = []):
    var waited = 0.0

    while !callv(condition, arguments) and waited < 5:
        yield(create_timer(0.05), "timeout")
        waited += 0.05

    check("waiting for %s" % what, callv(condition, arguments))
    yield(self, "idle_frame")

func _configured():
    return configs > 0

func _my_turn():
    return state.phase == state.Phase.MY_TURN

func _turn_after(turn):
    return (state.phase == state.Phase.MY_TURN and state.turn > turn) or state.phase == state.Phase.FINISHED

func _refused():
    return !refusals.empty()

# The stones on the square as the server writes them, like ["C2", "H1"]
func _stones(square):
    var stones = []

    for piece_id in state.board.stack(game.Notation.parse_square(square)):
        var piece = instance_from_id(piece_id)
        stones.append(piece.get_notation_name() + str(piece.player))

    return stones

func _argument(prefix):
    for argument in OS.get_cmdline_args():
        if argument.begins_with(prefix):
            return argument.trim_prefix(prefix)

    return ""
