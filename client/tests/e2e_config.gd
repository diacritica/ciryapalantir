extends SceneTree

# Chooses the clock and the Henneth Annûn rule in the real menu against a
# real server: anyone can while nobody sits, but once the bot sits as black
# they are locked for this client, until it sits too and the game starts
# with them. tests/e2e.sh passes the bot with --bot=

var server
var state
var menu
var failures = 0
var errors = []
var statuses = 0

func _initialize():
    call_deferred("_choose")

func check(label, condition):
    if !condition:
        failures += 1
        print("FAIL ", label)

func _choose():
    server = get_root().get_node("Server")
    state = get_root().get_node("Match")

    if !server.logged_in():
        yield(server, "user_logged")

    server.connect("notification_received", self, "_on_notification")
    change_scene("res://menus/MainMenu.tscn")
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    menu = current_scene
    var room = _argument("--room=")
    menu._enter_room(room)
    yield(_until("the status", "_has_status"), "completed")

    var config = menu.get_node("CreateGame/Panel/Config")
    var value = config.get_node("Clock/Value")
    var rule = config.get_node("HennethAnnun")
    check("five minutes by default", value.text == "5 min")
    check("without Henneth Annûn", !rule.pressed)
    check("anyone can choose while nobody sits", menu.can_change_config() and !rule.disabled)

    config.get_node("Clock/More").emit_signal("pressed")
    yield(_until("ten minutes", "_shows", [value, "10 min"]), "completed")
    rule.pressed = true
    yield(_until("the rule", "_rule_is", [true]), "completed")
    check("the rule shows on", rule.pressed)

    # T4K typed out of any field takes away the limit of the nossë
    for key in [KEY_T, KEY_4, KEY_K]:
        var event = InputEventKey.new()
        event.scancode = key
        event.unicode = OS.get_scancode_string(key).to_lower().ord_at(0)
        event.pressed = true
        Input.parse_input_event(event)
        Input.flush_buffered_events()
        yield(self, "idle_frame")

    yield(_until("the variant T4K", "_tak_is", [true]), "completed")
    check("it shows", config.get_node("Tak").visible)

    # The bot sits as black and is ready: now only it could change them. It
    # runs apart, so the output of this script does not wait for it to end
    var bot = "%s -server %s -room %s -name Morqua > /dev/null 2>&1 &" % [_argument("--bot="), _argument("--server="), room]
    OS.execute("sh", ["-c", bot], false)
    yield(_until("the bot sits", "_seated", [2]), "completed")
    check("locked once another sits", !menu.can_change_config() and rule.disabled and config.get_node("Clock/More").disabled)

    server.send_change_config({"clock": 180})
    yield(_until("the refusal", "_refused"), "completed")
    check("the server refuses it", errors.size() == 1 and errors[0].params.code == "CONFIG_LOCKED")
    check("and it still shows ten minutes", value.text == "10 min")

    # This client sits as white and the game starts with what was chosen
    state.player = 1
    server.send_join_player(1, "white", "E2E")
    yield(_until("the game", "_in_game"), "completed")
    var chosen = state.status.get("config", {}) if state.status else {}
    check("the game has the clock chosen", int(chosen.get("clock", 0)) == 600)
    check("and the rule", chosen.get("hennethAnnun", false) == true)
    check("and the variant T4K", chosen.get("tak", false) == true)

    print("e2e config: %d failures" % failures)
    quit(1 if failures else 0)

func _on_notification(message):
    if message.type == "Error":
        errors.append(message)
    elif message.type == "StatusResponse":
        statuses += 1

func _until(what, condition, arguments = []):
    var waited = 0.0

    while !callv(condition, arguments) and waited < 5:
        yield(create_timer(0.05), "timeout")
        waited += 0.05

    check("waiting for %s" % what, callv(condition, arguments))
    yield(self, "idle_frame")

func _has_status():
    return statuses > 0

func _shows(label, text):
    return label.text == text

func _tak_is(on):
    return menu.config.get("tak", false) == on

func _rule_is(on):
    return menu.config.get("hennethAnnun", false) == on

func _seated(player):
    return menu.seats.has(player)

func _refused():
    return !errors.empty()

func _in_game():
    return current_scene.name == "Game" and state.status != null

func _argument(prefix):
    for argument in OS.get_cmdline_args():
        if argument.begins_with(prefix):
            return argument.trim_prefix(prefix)

    return ""
