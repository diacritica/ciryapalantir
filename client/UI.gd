extends Control

onready var Server = get_node("/root/Server")
onready var ConnectButton = get_node("ButtonContainer/ConnectButton")
onready var PlayerButton = get_node("ButtonContainer/PlayerButton")
onready var ReadyButton = get_node("ButtonContainer/ReadyButton")

func _ready():
    ConnectButton.connect("pressed", self, "connect_pressed")
    PlayerButton.connect("pressed", self, "player_pressed")
    ReadyButton.connect("pressed", self, "ready_pressed")
    
    Server.connect("connection_success", self, "on_connection_success")
    Server.connect("connection_error", self, "on_connection_error")

func connection_error():
    ConnectButton.disabled = false
    PlayerButton.disabled = true
    ReadyButton.disabled = true
    
func on_connection_success():
    ConnectButton.disabled = true
    PlayerButton.disabled = false
    ReadyButton.disabled = false

func connect_pressed():
    Server.join_room("test")

func player_pressed():
    Server.send_join_player(1, "white", "Ada")

func ready_pressed():
    print("ready_pressed")
    Server.send_set_ready(true)
