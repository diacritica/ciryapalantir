extends SceneTree

# A scripted game against a real server, through the real game scene: white
# builds a mixed nossë with its hallacirya on top, breaks it in several steps
# over a tampa of black and wins by Londë down the file a. What the client
# lets through has to be what the server takes, and what the client stops,
# the server refuses too. The last two turns are written instead of dragged. tests/e2e.sh starts the server and the bot, which
# plays the turns of black in BLACK

const Notation = preload("res://core/Notation.gd")
const Status = preload("res://core/Status.gd")

# The turns of black, for the bot
const BLACK = "b1,Ta4,e5,e4,d5,c5,b5,d4,e3"

var server
var state
var game
var failures = 0
var refusals = []
var finished = {}

func _initialize():
    call_deferred("_play")

func check(label, condition):
    if !condition:
        failures += 1
        print("FAIL ", label)

func _play():
    server = get_root().get_node("Server")
    state = get_root().get_node("Match")

    if !server.logged_in():
        yield(server, "user_logged")

    server.connect("notification_received", self, "_on_notification")
    server.join_room(_argument("--room="))
    yield(server, "connection_success")
    state.player = 1
    server.send_join_player(1, "white", "E2E")
    server.send_set_ready(true)
    yield(_my_turn(), "completed")

    change_scene("res://Game.tscn")
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    game = current_scene

    # 1. a1 (a cirya of black)  2. b1 (one of white)
    _place(2, "C", "a1")
    yield(_confirm(), "completed")
    _place(1, "C", "c1")
    yield(_confirm(), "completed")
    _move("b1", 0, ["a1"])
    yield(_confirm(), "completed")
    _move("c1", 0, ["b1"])
    yield(_confirm(), "completed")
    _move("b1", 0, ["a1"])
    yield(_confirm(), "completed")
    _place(1, "H", "b1")
    yield(_confirm(), "completed")
    _move("b1", 0, ["a1"])
    yield(_confirm(), "completed")
    check("a mixed nossë of 4 with the hallacirya on top", _stones("a1") == ["C2", "C1", "C1", "H1"])
    check("the tampa of black on a4", _stones("a4") == ["T2"])

    yield(_break_the_nosse(), "completed")
    yield(_confirm(), "completed")
    check("the nossë is spread", _stones("a2") == ["C2", "C1"] and _stones("a3") == ["C1"])
    check("the hallacirya flattened the tampa", _stones("a4") == ["C2", "H1"])

    # The last two turns are written, as with the keyboard
    check("a1 written", game.play_written("a1") == "")
    yield(_confirm(), "completed")
    check("a5 written", game.play_written("A5") == "" and state.move_notation() == "a5")
    state.confirm()

    var waited = 0.0
    while state.phase != state.Phase.FINISHED and waited < 5:
        yield(create_timer(0.1), "timeout")
        waited += 0.1

    yield(create_timer(0.3), "timeout")
    check("the game is over", state.phase == state.Phase.FINISHED)
    check("white won by Londë", finished.get("result") == "WIN_1" and finished.get("winCondition") == "LONDI")
    check("the board never went out of step", game.rebuilds == 0)
    check("the board is the one of the server", Status.matches(state.status.board, state.board))
    check("the result is shown", game.get_node("UI").get_children().back() is AcceptDialog)
    print("e2e nossë: %d moves, %d failures" % [state.status.moves.size(), failures])
    quit(1 if failures else 0)

# The nossë of a1 goes up the file a: all to a2, the top two on to a3, back
# to a2, again to a3 and at last the hallacirya alone onto the tampa of a4.
# On the way, what the rules forbid is not let through
func _break_the_nosse():
    var nosse = _stack("a1")
    var hallacirya = nosse[3]

    check("it cannot skip a2", !state.can_drop(nosse, _square("a3")))
    _move("a1", 0, ["a2"])
    check("all to a2", state.move_notation() == "4a1+")
    _move("a2", 2, ["a3"])
    check("two on to a3", state.move_notation() == "4a1+22")
    _move("a3", 0, ["a2"])
    check("back to a2", state.move_notation() == "4a1+")
    _move("a2", 2, ["a3"])

    var pair = _stack("a3")
    check("it cannot turn", !state.can_drop([hallacirya], _square("b3")))
    check("it cannot skip a4", !state.can_drop([hallacirya], _square("a5")))
    check("the hallacirya cannot flatten the tampa with company", !state.can_drop(pair, _square("a4")))
    check("no other piece moves now", !state.can_take(_fleet_piece(1, "C").get_instance_id()))

    # What the client stops, the server refuses
    _submit("4a1+112")
    yield(_refusal(), "completed")
    check("the server refuses the hallacirya with company", refusals.size() == 1)
    refusals.clear()

    _move("a3", 1, ["a4"])
    check("the hallacirya alone onto the tampa", state.move_notation() == "4a1+211")

func _place(owner, stone, square):
    var piece = _fleet_piece(owner, "H" if stone == "H" else "C")
    game.take(piece)

    if stone == "T":
        game._rotate()

    game.release(_tile(square))

# Takes the stack from the stone at that height and drops it on the squares
func _move(square, height, squares):
    var piece = instance_from_id(_stack(square)[height])

    for each in squares:
        game.take(piece)
        game.release(_tile(each))

# Confirms the turn and waits until black has played
func _confirm():
    var notation = state.move_notation()
    state.confirm()
    yield(_my_turn(), "completed")
    check("%s went through" % notation, refusals.empty())
    check("after %s the board is the one of the server" % notation, Status.matches(state.status.board, state.board))

func _my_turn():
    var waited = 0.0

    while state.phase != state.Phase.MY_TURN and state.phase != state.Phase.FINISHED and waited < 5:
        yield(create_timer(0.05), "timeout")
        waited += 0.05

    yield(self, "idle_frame")

func _refusal():
    var waited = 0.0

    while refusals.empty() and waited < 5:
        yield(create_timer(0.05), "timeout")
        waited += 0.05

func _submit(move):
    server.ws_send_message({"type": "SubmitTurn", "params": {"player": 1, "turn": state.turn, "move": move}})

func _on_notification(message):
    if message.type in ["InvalidTurn", "Error"]:
        refusals.append(message)
    elif message.type == "GameFinished":
        finished = message.params

func _fleet_piece(owner, kind):
    for piece in game._pieces():
        if piece.player == owner and piece.get_notation_name() == kind and state.board.square_of(piece.get_instance_id()) == null:
            return piece

func _stack(square):
    return state.board.stack(_square(square))

# The stones on the square as the server writes them, like ["C2", "H1"]
func _stones(square):
    var stones = []

    for piece_id in _stack(square):
        var piece = instance_from_id(piece_id)
        stones.append(piece.get_notation_name() + str(piece.player))

    return stones

func _square(name):
    return Notation.parse_square(name)

func _tile(square):
    return game.get_node("Board").tile(_square(square))

func _argument(prefix):
    for argument in OS.get_cmdline_args():
        if argument.begins_with(prefix):
            return argument.trim_prefix(prefix)

    return ""
