extends Node

export var server_host = "127.0.0.1"
export var server_port = 3333

onready var global = get_node("/root/Global")

signal connection_error(error)
signal connection_success
signal notification_received(message)

signal room_created(id)

var ws

# Stores current session context data
# Like current turn, player assignment, color assignment...
var context = {
    "host": server_host,
    "port": server_port
}

func _ready():
    $HttpClient.connect("request_completed", self, "on_user_request", [], CONNECT_ONESHOT)
    var url = "http://{host}:{port}/users".format(context)
    $HttpClient.request(url, [], false, HTTPClient.METHOD_PUT)

func on_user_request(result, response_code, headers, body):
    if response_code == 200:
        var msg = JSON.parse(body.get_string_from_utf8())
        context["user_id"] = msg.result["id"]
    else:
        # TODO: Show error message
        print("ERROR HTTP CONNECTION", response_code, body)

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
    print("Joining room %s" % room_id)
    context["room_id"] = room_id

    ws = WebSocketClient.new()
    ws.verify_ssl = false

    ws.connect("connection_closed", self, "ws_closed")
    ws.connect("connection_error", self, "ws_error")
    ws.connect("connection_established", self, "ws_connected")
    ws.connect("data_received", self, "ws_data_received")

    var ws_url = "ws://{host}:{port}/rooms/{room_id}".format(context)

    print("Connecting to %s" % ws_url)
    var err = ws.connect_to_url(ws_url, [], false, ["Cookie: cirya-user={user_id}".format(context)])

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

func ws_data_received():
    print('ws_data_received')
    var msg = ws.get_peer(1).get_packet().get_string_from_utf8()
    var data = JSON.parse(msg)
    global.data_received(data.result)
    emit_signal("notification_received", data.result)

func _process(delta):
    if ws != null:
        ws.poll()

func get_player():
    return context["player"]

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
