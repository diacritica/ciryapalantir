extends Control

onready var Server = get_node("/root/Server")
onready var Match = get_node("/root/Match")
onready var NewGameButton = get_node("Welcome/Panel/NewGameButton")
onready var JoinGameButton = get_node("Welcome/Panel/JoinGameButton")
onready var WhiteButton = get_node("/root/Menu/CreateGame/Panel/WhiteButton")
onready var BlackButton = get_node("/root/Menu/CreateGame/Panel/BlackButton")

func _ready():
    Server.connect("user_logged", self, "on_user_logged")
    connect_button(WhiteButton, BlackButton)
    connect_button(BlackButton, WhiteButton)
    
func on_user_logged():
    NewGameButton.disabled = false
    JoinGameButton.disabled = false
    
func connect_button(button, other):
    button.connect("pressed", self, "on_color_pressed", [ button, other ])
    button.get_node("Edit/PlayButton").connect("pressed", self, "on_play_pressed", [ button ])

func disconnect_button(button):
    button.disconnect("pressed", self, "on_color_pressed")
    button.get_node("Edit/PlayButton").disconnect("pressed", self, "on_play_pressed")

func _on_NewGameButton_pressed():
    Server.connect("room_created", self, "_on_room_created", [], CONNECT_ONESHOT)
    Server.create_room()
    
func _on_room_created(room_id):
    Match.sandbox = false
    get_node("/root/Menu/CreateGame/Panel/Code/CodeLabel").text = room_id
    get_node("/root/Menu/Background").visible = false
    get_node("/root/Menu/BackgroundBlur").visible = true
    get_node("/root/Menu/Welcome").visible = false
    get_node("/root/Menu/CreateGame").visible = true
    join_room(room_id)
    
func join_room(room_id):
    Server.connect("notification_received", self, "on_notification_received")
    Server.join_room(room_id)
    
func on_notification_received(message):
    if message["type"] == "PlayerJoined":
        var player = message["params"]["player"]
        var color = message["params"]["color"]
        var name = message["params"]["name"]
        
        if color == "white":
            set_player_name(WhiteButton, name)
        else:
            set_player_name(BlackButton, name)
        
        if Server.get_player() == player:
            Server.send_set_ready(true)

    if message["type"] == "StartGame":
        get_tree().change_scene("res://Game.tscn")
        
    if message["type"] == "StatusResponse":
        var players = message["status"].get("players", {})
        if players.get("1", null) != null:
            set_player_name(WhiteButton, players["1"]["name"])
        if players.get("2", null) != null:
            set_player_name(BlackButton, players["2"]["name"])

func _on_JoinGameButton_pressed():
    get_node("/root/Menu/Background").visible = false
    get_node("/root/Menu/BackgroundBlur").visible = true
    get_node("/root/Menu/Welcome").visible = false
    get_node("/root/Menu/JoinGame").visible = true
    
func on_color_pressed(button, other):
    button.set_size(Vector2(141, 300))
    if !other.get_node("Display").visible:
        other.set_size(Vector2(141, 200))
    button.get_node("Edit").visible = true
    other.get_node("Edit").visible = false

func on_play_pressed(button):
    var name = button.get_node("Edit/InputName").text
    disconnect_handlers()
    
    Match.player = 1 if button == WhiteButton else 2
    Server.send_join_player(Match.player, "white" if Match.player == 1 else "black", name)

func disconnect_handlers():
    disconnect_button(WhiteButton)
    disconnect_button(BlackButton)

func set_player_name(button, name):
    disconnect_button(button)
    button.set_size(Vector2(141, 250))
    button.get_node("Display").visible = true
    button.get_node("Display/Label").text = name
    button.get_node("Edit").visible = false

func _on_JoinGameCode_pressed():
    get_node("/root/Menu/JoinGame").visible = false
    var code = get_node("/root/Menu/JoinGame/Panel/Code/InputCode").text
    # Room codes are uppercase, someone typing them in lowercase would end in an empty room
    _on_room_created(code.strip_edges().to_upper())

# A local game on one computer: the same rules and turns, without the server
func _on_SandboxButton_pressed():
    Match.start_sandbox()
    get_tree().change_scene("res://Game.tscn")
