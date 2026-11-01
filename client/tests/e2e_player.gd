extends SceneTree

# Plays a whole game with white against a real server, through the real game
# scene. tests/e2e.sh starts the server and the bot that plays black

const Notation = preload("res://core/Notation.gd")
const Status = preload("res://core/Status.gd")

var server
var state
var game
var failures = 0

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

    server.join_room(_argument("--room="))
    yield(server, "connection_success")
    state.player = 1
    server.send_join_player(1, "white", "E2E")
    server.send_set_ready(true)

    while state.phase != state.Phase.MY_TURN:
        yield(self, "idle_frame")

    change_scene("res://Game.tscn")
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    game = current_scene

    var turns = 0
    var reconnected = false

    while state.phase != state.Phase.FINISHED and turns < 40:
        if state.phase == state.Phase.MY_TURN:
            _place_on_first_empty()
            turns += 1

        # The connection drops in the middle of the game, and comes back by itself
        if turns == 4 and !reconnected:
            server.ws.disconnect_from_host()
            yield(server, "connection_lost")
            yield(server, "connection_success")
            reconnected = true

        yield(self, "idle_frame")

    yield(create_timer(0.5), "timeout")
    check("the game is over", state.phase == state.Phase.FINISHED)
    check("it went on after reconnecting", reconnected)
    check("the board never went out of step", game.rebuilds == 0)
    check("the board is the one of the server", Status.matches(state.status.board, state.board))
    check("the result is shown", game.get_node("UI").get_children().back() is AcceptDialog)
    print("e2e player: %d turns, %d failures" % [turns, failures])
    quit(1 if failures else 0)

# Like the bot: a flat cirya on the first empty square, from the fleet of the
# opponent in the opening
func _place_on_first_empty():
    var owner = 2 if state.opening() else 1

    for piece in game._pieces():
        if piece.player == owner and piece.get_notation_name() == "C" and state.board.square_of(piece.get_instance_id()) == null:
            game.take(piece)
            break

    for row in range(state.board.size()):
        for column in range(state.board.size()):
            if state.board.stack(Vector2(row, column)).empty():
                game.release(game.get_node("Board").tile(Vector2(row, column)))
                game._on_turn_confirmation(true)
                return

func _argument(prefix):
    for argument in OS.get_cmdline_args():
        if argument.begins_with(prefix):
            return argument.trim_prefix(prefix)

    return ""
