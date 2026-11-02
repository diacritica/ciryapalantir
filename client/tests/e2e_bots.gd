extends SceneTree

# Two bots of this client play each other in a room of the real server, which
# is the referee: whole games, the second one after the rematch they both
# accept, with the seats swapped, and not one turn refused. With --rules=t4k
# the room has the variant T4K and the Henneth Annûn rule, and no clock.
# tests/e2e.sh passes the room

const BotPlayer = preload("res://BotPlayer.gd")
const GAMES = 2

var server
var failures = 0
var finished = []
var configs = 0
var rematches = 0

func _initialize():
    call_deferred("_play")

func check(label, condition):
    if !condition:
        failures += 1
        print("FAIL ", label)

func _play():
    server = get_root().get_node("Server")

    if !server.logged_in():
        yield(server, "user_logged")

    server.connect("notification_received", self, "_on_notification")
    var room = _argument("--room=")
    server.join_room(room)
    yield(server, "connection_success")

    if _argument("--rules=") == "t4k":
        server.send_change_config({"tak": true, "hennethAnnun": true, "clock": 0})
        yield(_until("the rules", "_configured", [], 5), "completed")

    var bots = []

    for seat in [1, 2]:
        var bot = BotPlayer.new()
        get_root().add_child(bot)
        bot.delay = 0
        bot.bot.depth = 1
        bot.start(server._url("/rooms/" + room, true), ["Cookie: cirya-user=%s" % server.context.user_id], seat, "Bot %d" % seat)
        bots.append(bot)

    yield(_until("%d games" % GAMES, "_games_over", [], 240), "completed")

    for bot in bots:
        check("%s played" % bot.bot_name, bot.played > 0)
        check("and the server took every turn of %s" % bot.bot_name, bot.refused == 0)
        bot.stop()

    # They accept every rematch, so by now a third game may have started
    check("a rematch started", rematches >= 1)
    var swapped = rematches % 2 == 1
    check("and the bots swapped their seats each time", bots[0].seat == (2 if swapped else 1) and bots[1].seat == (1 if swapped else 2))
    var lengths = []

    for params in finished:
        lengths.append("%s by %s at %d" % [params.result, params.winCondition, int(params.turn)])

    print("e2e bots (%s): %s, %d failures" % [_argument("--rules="), PoolStringArray(lengths).join("; "), failures])
    quit(1 if failures else 0)

func _on_notification(message):
    if message.type == "GameFinished":
        finished.append(message.params)
    elif message.type == "StartGame" and message.params.get("rematch", false):
        rematches += 1
    elif message.type == "ConfigChanged":
        configs += 1

func _until(what, condition, arguments, seconds):
    var waited = 0.0

    while !callv(condition, arguments) and waited < seconds:
        yield(create_timer(0.1), "timeout")
        waited += 0.1

    check("waiting for %s" % what, callv(condition, arguments))
    yield(self, "idle_frame")

func _configured():
    return configs > 0

func _games_over():
    return finished.size() >= GAMES

func _argument(prefix):
    for argument in OS.get_cmdline_args():
        if argument.begins_with(prefix):
            return argument.trim_prefix(prefix)

    return ""
