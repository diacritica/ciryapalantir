extends Node

# The connection with the server: the user and the rooms over HTTP, and the
# websocket of the room, which comes back by itself when it drops.
#
# The server is, in this order: --server=host:port on the command line, the
# host of the page in a web build, the local server when running from the
# editor and play.cirya.me otherwise. The user is kept in user://, and
# --profile=name keeps another one, to run two clients on one computer:
#
#   godot --path client -- --server=127.0.0.1:3333 --profile=black

signal connection_error(error)
signal connection_success
signal connection_lost
signal notification_received(message)
signal room_created(id)
signal user_logged

const PUBLIC_SERVER = "play.cirya.me:3333"
const LOCAL_SERVER = "127.0.0.1:3333"
# Seconds between attempts to reconnect, the last one repeated
const RETRY_DELAYS = [1, 2, 4, 8, 10]

var server = PUBLIC_SERVER
var secure = false
var profile = "default"
var config = ConfigFile.new()
var ws = null
var retries = 0
# What this client knows of the session: the user, the room, the seat taken
# and the names of the players by colour
var context = {}

func _ready():
    set_process(false)
    _read_command_line()
    config.load(_config_path())

    if config.has_section_key("user", "id"):
        context["user_id"] = config.get_value("user", "id")

    login_user()

func _read_command_line():
    if OS.has_feature("editor"):
        server = LOCAL_SERVER

    if OS.has_feature("JavaScript"):
        server = JavaScript.eval("location.host")
        secure = JavaScript.eval("location.protocol") == "https:"

    for argument in OS.get_cmdline_args():
        if argument.begins_with("--server="):
            server = argument.trim_prefix("--server=")
        elif argument.begins_with("--profile="):
            profile = argument.trim_prefix("--profile=")

func _config_path():
    return "user://cirya-%s.cfg" % profile

func _url(path, websocket = false):
    var scheme = "ws" if websocket else "http"
    return "%s%s://%s%s" % [scheme, "s" if secure else "", server, path]

# The server keeps the user of the cookie, or gives a new one
func login_user():
    var headers = ["Cookie: cirya-user=%s" % context.user_id] if logged_in() else []
    $HttpClient.connect("request_completed", self, "_on_user_request", [], CONNECT_ONESHOT)
    $HttpClient.request(_url("/users"), headers, false, HTTPClient.METHOD_PUT)

func _on_user_request(_result, response_code, _headers, body):
    if response_code != 200:
        # Tries again until the server answers
        push_error("cannot log in at %s: HTTP %d" % [server, response_code])
        get_tree().create_timer(RETRY_DELAYS[-1]).connect("timeout", self, "login_user")
        return

    context["user_id"] = JSON.parse(body.get_string_from_utf8()).result["id"]
    config.set_value("user", "id", context.user_id)
    config.save(_config_path())
    emit_signal("user_logged")

func logged_in():
    return context.has("user_id")

func create_room():
    $HttpClient.connect("request_completed", self, "_on_room_request", [], CONNECT_ONESHOT)
    $HttpClient.request(_url("/rooms"), [], false, HTTPClient.METHOD_PUT)

func _on_room_request(_result, response_code, _headers, body):
    if response_code != 200:
        push_error("cannot create a room: HTTP %d" % response_code)
        return

    emit_signal("room_created", JSON.parse(body.get_string_from_utf8()).result["id"])

func join_room(code):
    if context.has("room_id"):
        return

    context["room_id"] = code
    retries = 0
    _open_socket()

# Closes the connection to the room, to join another one later
func leave_room():
    for key in ["room_id", "player", "color", "white", "black"]:
        context.erase(key)

    if ws:
        ws.disconnect_from_host()

    ws = null
    set_process(false)

# The seat this user took in a room, so it is taken again when coming back.
# 0 when it never sat there
func seat_in(code):
    return config.get_value("seats", code, 0)

func _open_socket():
    ws = WebSocketClient.new()
    ws.verify_ssl = false
    ws.connect("connection_closed", self, "_on_socket_closed")
    ws.connect("connection_error", self, "_on_socket_closed")
    ws.connect("connection_established", self, "_on_socket_open")
    ws.connect("data_received", self, "_on_data")

    var url = _url("/rooms/" + context.room_id, true)

    if ws.connect_to_url(url, [], false, ["Cookie: cirya-user=%s" % context.user_id]) != OK:
        emit_signal("connection_error", "Cannot connect to %s" % url)
        return

    set_process(true)

func _on_socket_open(_protocol = ""):
    retries = 0
    emit_signal("connection_success")

# The connection dropped: while the room is not left, it tries again. On
# connecting, the server sends the status of the room
func _on_socket_closed(_clean = false):
    set_process(false)

    if !context.has("room_id"):
        return

    emit_signal("connection_lost")
    var delay = RETRY_DELAYS[min(retries, RETRY_DELAYS.size() - 1)]
    retries += 1
    yield(get_tree().create_timer(delay), "timeout")

    if context.has("room_id"):
        _open_socket()

func _on_data():
    var message = JSON.parse(ws.get_peer(1).get_packet().get_string_from_utf8()).result

    match message.type:
        "PlayerJoined":
            context[message.params.color] = message.params.name
        "StatusResponse":
            for seat in message.status.get("players", {}).values():
                context[seat.color] = seat.name

    emit_signal("notification_received", message)

func _process(_delta):
    ws.poll()

func get_player_name(color):
    return context.get(color, "")

func get_code():
    return context.get("room_id", "")

func ws_send_message(data):
    ws.get_peer(1).put_packet(JSON.print(data).to_utf8())

func send_join_player(player, color, name):
    context["player"] = player
    context["color"] = color
    config.set_value("seats", context.room_id, player)
    config.save(_config_path())
    ws_send_message({"type": "JoinGame", "params": {"player": player, "color": color, "name": name}})

# Only what changes: {"clock": seconds} or {"hennethAnnun": true}
func send_change_config(changes):
    ws_send_message({"type": "ChangeConfig", "params": changes})

func send_set_ready(is_ready):
    ws_send_message({"type": "SetReady", "params": {"player": context.player, "ready": is_ready}})
