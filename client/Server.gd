extends Node

export var server_host = "play.cirya.me"
export var server_port = 3333

# export var server_host = "127.0.0.1"
# export var server_port = 3333

onready var global = get_node("/root/Global")

signal connection_error(error)
signal connection_success
signal notification_received(message)
signal room_created(id)
signal user_logged

var ws

# Stores current session context data
# Like current turn, player assignment, color assignment...
var context = {
    "host": server_host,
    "port": server_port
}

func _ready():
    login_user()

func login_user():
    $HttpClient.connect("request_completed", self, "on_user_request", [], CONNECT_ONESHOT)
    var url = "http://{host}:{port}/users".format(context)
    $HttpClient.request(url, [], false, HTTPClient.METHOD_PUT)

func on_user_request(result, response_code, headers, body):
    if response_code == 200:
        var msg = JSON.parse(body.get_string_from_utf8())
        context["user_id"] = msg.result["id"]
        emit_signal("user_logged")
    else:
        # TODO: Show error message
        print("ERROR HTTP CONNECTION", response_code, body)
        var timer = Timer.new()
        timer.set_one_shot(true)
        timer.set_timer_process_mode(0)
        timer.set_wait_time(2)
        timer.connect("timeout", self, "login_user")
        self.add_child(timer)
        timer.start()

func create_room():
    $HttpClient.connect("request_completed", self, "on_room_request", [], CONNECT_ONESHOT)
    var url = "http://{host}:{port}/rooms".format(context)
    $HttpClient.request(url, [], false, HTTPClient.METHOD_PUT)

func on_room_request(result, response_code, headers, body):
    if response_code == 200:
        var msg = JSON.parse(body.get_string_from_utf8())
        context["room_id"] = msg.result["id"]
        emit_signal("room_created", context["room_id"])
    else:
        # TODO: Show error message
        print("ERROR HTTP CONNECTION", response_code, body)

func join_room(room_id):
    if context.get("connected", false):
        return

    print("Joining room %s" % room_id)
    context["room_id"] = room_id

    ws = WebSocketClient.new()
    ws.verify_ssl = false

    ws.connect("connection_closed", self, "ws_closed")
    ws.connect("connection_error", self, "ws_error")
    ws.connect("connection_established", self, "ws_connected")
    ws.connect("data_received", self, "ws_data_received")

    var ws_url = "ws://{host}:{port}/rooms/{room_id}".format(context)

    print("Connecting to {url} with {user}".format({
        "user": context["user_id"],
        "url": ws_url
    }))
    var err = ws.connect_to_url(ws_url, [], false, [
        "Cookie: cirya-user={user_id}; SameSite=None; Secure".format(context),
    ])

    if err != OK:
        print("Cannot connect to URL %s" % ws_url)
        set_process(false)
        emit_signal("connection_error", "Cannot connect to URL %s" )

func ws_closed(clean = false):
    set_process(false)

func ws_error():
    set_process(false)
    emit_signal("connection_error", "Error connecting to websocket" )

func ws_connected(proto = ""):
    emit_signal("connection_success")
    context["connected"] = true
    send_status_request()

func ws_data_received():
    var msg = ws.get_peer(1).get_packet().get_string_from_utf8()
    var data = JSON.parse(msg)
    
    if data.result["type"] == "PlayerJoined":
        var color = data.result["params"]["color"]
        context[color] = data.result["params"]["name"]
        
    if data.result["type"] == "StatusResponse":
        var players = data.result["status"].get("players", {})
        if players.get("1", null) != null:
            context[players["1"]["color"]] = players["1"]["name"]
        if players.get("2", null) != null:
            context[players["2"]["color"]] = players["2"]["name"]
    
    global.data_received(data.result)
    emit_signal("notification_received", data.result)

func _process(delta):
    if ws != null:
        ws.poll()

func is_ws_connected():
    return context["connected"]

func get_player():
    return context.get("player", 0)
    
func get_player_name(color):
    return context.get(color, "")
    
func get_code():
    return context.get("room_id", "")

# MESSAGES IMPLEMENTATION

func ws_send_message(data):
    """
    Generic method to send any kind of message. Will be used by the more specialized ones
    """
    var msg = JSON.print(data)
    ws.get_peer(1).put_packet(msg.to_utf8())

func send_join_player(player, color, name):
    var msg = {
        "type": "JoinGame",
        "params": {
            "player": player,
            "color": color,
            "name": name
        }
    }
    context["player"] = player
    global.player = player
    context["color"] = color
    context["turn"] = 1
    ws_send_message(msg)

func send_set_ready(is_ready):
    var msg = {
        "type": "SetReady",
        "params": {
            "player": context["player"],
            "ready": is_ready
        }
    }
    ws_send_message(msg)

func send_status_request():
    ws_send_message({ "type": "GetStatus" })
