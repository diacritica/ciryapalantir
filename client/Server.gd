extends Node

export var server_host = "127.0.0.1"
export var server_port = 3333

signal connection_error(error)
signal connection_success
signal notification_received(message)

var ws

# Stores current session context data
# Like current turn, player assignment, color assignment...
var context = {}

func join_room(room_id):
    print("Joining room %s" % room_id)
    ws = WebSocketClient.new()
    ws.verify_ssl = false
    
    ws.connect("connection_closed", self, "ws_closed")
    ws.connect("connection_error", self, "ws_error")
    ws.connect("connection_established", self, "ws_connected")
    ws.connect("data_received", self, "ws_data_received")

    var params = {
        "host": server_host,
        "port": server_port,
        "room_id": room_id
    }
    var ws_url = "ws://{host}:{port}/rooms/{room_id}".format(params)
    
    print("Connecting to %s" % ws_url)
    var err = ws.connect_to_url(ws_url, [], false, ["Cookie: cirya-user=godot"])
    
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
    var msg = ws.get_peer(1).get_packet().get_string_from_utf8()
    var data = JSON.parse(msg)
    
func _process(delta):
    if ws != null:
        ws.poll()

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
