extends SceneTree

# A game against the bot of this client, through the real menu and the real
# server: white sits, the card of black turns the bot on, off and on again,
# Comenzar sits it, and the game starts with the bot playing black. White
# writes a few turns, each on a free square, and the bot answers each one.
# Back in the menu the bot is gone. tests/e2e.sh passes the room

const Notation = preload("res://core/Notation.gd")
const TURNS = 4

var server
var state
var menu
var failures = 0
var statuses = 0

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
    change_scene("res://menus/MainMenu.tscn")
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    menu = current_scene
    menu._enter_room(_argument("--room="))
    yield(_until("the status", "_has_status"), "completed")

    var panel = menu.get_node("CreateGame/Panel")
    var white = panel.get_node("WhiteButton")
    var black = panel.get_node("BlackButton")
    check("no bot before sitting", !panel.get_node("LocalBot").visible and !panel.get_node("Start").visible)

    white.emit_signal("pressed")
    white.get_node("Edit/InputName").text = "E2E"
    white.get_node("Edit/PlayButton").emit_signal("pressed")
    yield(_until("the seat", "_seated", [1]), "completed")

    black.emit_signal("pressed")
    check("the card of black turns the bot on", panel.get_node("LocalBot").visible and panel.get_node("Start").visible)
    check("under the card", panel.get_node("LocalBot").rect_position.y >= black.rect_position.y + black.rect_size.y)
    black.emit_signal("pressed")
    check("and off", !panel.get_node("LocalBot").visible and !panel.get_node("Start").visible)
    black.emit_signal("pressed")
    check("and on again", panel.get_node("LocalBot").visible)

    panel.get_node("Start").emit_signal("pressed")
    yield(_until("the game", "_in_game"), "completed")
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    var game = current_scene
    var bot = server.get_node("Bot")
    check("the bot plays black", bot.seat == 2 and server.get_player_name("black") == load("res://menus/MainMenu.gd").BOT_NAME)

    for i in range(TURNS):
        yield(_until("my turn %d" % i, "_my_turn"), "completed")
        var move = _free_square()
        check("%s written" % move, game.play_written(move) == "")
        state.confirm()
        yield(_until("the bot after %s" % move, "_turn_after_or_over", [state.turn], 10), "completed")

        if state.phase == state.Phase.FINISHED:
            break

    check("the bot answered every turn", bot.played >= 2 and bot.refused == 0)
    var moves = state.status.moves.size()
    print("e2e local bot: %d moves, %s" % [moves, PoolStringArray(state.status.moves).join(" ")])

    game.get_node("UI")._back_to_menu()
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    check("back in the menu the bot is gone", !server.has_node("Bot"))

    print("e2e local bot: %d failures" % failures)
    quit(1 if failures else 0)

func _on_notification(message):
    if message.type == "StatusResponse":
        statuses += 1

func _until(what, condition, arguments = [], seconds = 5):
    var waited = 0.0

    while !callv(condition, arguments) and waited < seconds:
        yield(create_timer(0.05), "timeout")
        waited += 0.05

    check("waiting for %s" % what, callv(condition, arguments))
    yield(self, "idle_frame")

func _has_status():
    return statuses > 0

func _seated(player):
    return menu.seats.has(player)

func _in_game():
    return current_scene.name == "Game" and state.status != null

func _my_turn():
    return state.phase == state.Phase.MY_TURN

func _turn_after_or_over(turn):
    return (state.phase == state.Phase.MY_TURN and state.turn > turn) or state.phase == state.Phase.FINISHED

func _free_square():
    for name in ["e5", "c3", "b3", "d3", "c2", "c4", "b2", "d4"]:
        if state.board.stack(Notation.parse_square(name)).empty():
            return name

    return "a5"

func _argument(prefix):
    for argument in OS.get_cmdline_args():
        if argument.begins_with(prefix):
            return argument.trim_prefix(prefix)

    return ""
