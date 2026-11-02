extends SceneTree

# The rematch against a real server: white wins a short game by Londë and is
# offered another one, which the bot has already accepted. With --answer=yes
# it accepts too, and the new game starts with the seats swapped: this
# client plays black, sees the board from that side and waits for the bot.
# With --answer=no there is no new game, and the finished one stays there.
# The bot plays black, started here; tests/e2e.sh passes it with --bot=

# The turns of black: white makes a Londë along the first rank
const BLACK = "a1,a5,b5,c5"
const WHITE = ["e5", "b1", "c1", "d1", "e1"]

var server
var state
var failures = 0
var rematches = []

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
    var room = _argument("--room=")
    server.join_room(room)
    yield(server, "connection_success")

    var bot = "%s -server %s -room %s -name Morqua -rematch -moves '%s' > /dev/null 2>&1 &" % [_argument("--bot="), _argument("--server="), room, BLACK]
    OS.execute("sh", ["-c", bot], false)
    state.player = 1
    server.send_join_player(1, "white", "E2E")
    server.send_set_ready(true)
    yield(_until("the first turn", "_my_turn"), "completed")

    change_scene("res://Game.tscn")
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    var game = current_scene

    for move in WHITE:
        check("%s written" % move, game.play_written(move) == "")
        state.confirm()
        yield(_until("black after %s" % move, "_turn_after_or_over", [state.turn]), "completed")

    check("white won", state.phase == state.Phase.FINISHED)
    var ui = game.get_node("UI")
    yield(_until("the offer of the bot", "_bot_accepted"), "completed")
    var dialog = ui.get_node("GameOver")
    check("the other player wants another game", dialog.dialog_text.find("El otro jugador quiere otra partida") != -1)
    check("with the buttons to answer", dialog.find_node("Rematch", true, false).visible and dialog.find_node("NoRematch", true, false).visible)

    if _argument("--answer=") == "yes":
        dialog.emit_signal("custom_action", "rematch")
        yield(_until("the new game", "_new_scene", [game]), "completed")
        yield(self, "idle_frame")
        yield(self, "idle_frame")
        game = current_scene
        check("this client plays black now", state.player == 2 and server.context.get("color") == "black")
        check("and keeps that seat", server.seat_in(room) == 2)
        check("seen from the side of black", game.has_node("CameraPlayer2") and game.get_node("CameraPlayer2").current)
        check("the bot plays white", server.get_player_name("white") == "Morqua" and server.get_player_name("black") == "E2E")
        yield(_until("the turn of black", "_my_turn"), "completed")
        check("after the opening of the bot", state.turn == 2 and state.status.moves.size() == 1)
        check("on a new board", state.status.board.size() <= 1 and !game.get_node("UI").has_node("GameOver"))
        check("a new list of moves", game.get_node("UI/Moves/MovesText").get_line_count() == 1)
    else:
        dialog.emit_signal("custom_action", "no_rematch")
        yield(_until("the end of the offer", "_declined"), "completed")
        check("there will be no new game", dialog.dialog_text.find("No habrá una nueva partida") != -1)
        check("no more buttons to answer", !dialog.find_node("Rematch", true, false).visible)
        check("the game stays there", state.phase == state.Phase.FINISHED and state.player == 1 and current_scene == game)
        check("and its moves", game.get_node("UI/Moves/MovesText").get_line_count() == 9)

    print("e2e rematch (%s): %d failures" % [_argument("--answer="), failures])
    quit(1 if failures else 0)

func _on_notification(message):
    if message.type == "RematchChanged":
        rematches.append(message.params)

func _until(what, condition, arguments = []):
    var waited = 0.0

    while !callv(condition, arguments) and waited < 5:
        yield(create_timer(0.05), "timeout")
        waited += 0.05

    check("waiting for %s" % what, callv(condition, arguments))
    yield(self, "idle_frame")

func _my_turn():
    return state.phase == state.Phase.MY_TURN

func _turn_after_or_over(turn):
    return (state.phase == state.Phase.MY_TURN and state.turn > turn) or state.phase == state.Phase.FINISHED

func _bot_accepted():
    return !rematches.empty() and rematches.back().accepted.has(2.0)

func _declined():
    return !rematches.empty() and rematches.back().state == "DECLINED"

func _new_scene(old):
    return current_scene != old and current_scene != null and current_scene.name == "Game"

func _argument(prefix):
    for argument in OS.get_cmdline_args():
        if argument.begins_with(prefix):
            return argument.trim_prefix(prefix)

    return ""
