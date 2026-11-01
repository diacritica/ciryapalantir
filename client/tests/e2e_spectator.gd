extends SceneTree

# Comes to watch a game already started or finished through the real menu,
# which has to open the game scene with the board of the server

const Status = preload("res://core/Status.gd")

var failures = 0

func _initialize():
    call_deferred("_watch")

func check(label, condition):
    if !condition:
        failures += 1
        print("FAIL ", label)

func _watch():
    var server = get_root().get_node("Server")
    var state = get_root().get_node("Match")

    if !server.logged_in():
        yield(server, "user_logged")

    change_scene("res://menus/MainMenu.tscn")
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    current_scene._enter_room(_argument("--room="))

    var waited = 0.0
    while current_scene.name != "Game" and waited < 5:
        yield(create_timer(0.1), "timeout")
        waited += 0.1

    yield(self, "idle_frame")
    yield(self, "idle_frame")
    check("the menu opens the game", current_scene.name == "Game")
    check("as a spectator", state.player == 0)
    check("with the board of the server", state.status != null and Status.matches(state.status.board, state.board))
    check("and the moves", current_scene.get_node("UI/Moves/Scroll/MovesText").text.count("\n") == state.status.moves.size())
    print("e2e spectator: %d failures" % failures)
    quit(1 if failures else 0)

func _argument(prefix):
    for argument in OS.get_cmdline_args():
        if argument.begins_with(prefix):
            return argument.trim_prefix(prefix)

    return ""
