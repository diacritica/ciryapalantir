extends Control

onready var Server = get_node("/root/Server")
onready var WhiteButton = get_node("/root/Menu/CreateGame/Panel/WhiteButton")
onready var BlackButton = get_node("/root/Menu/CreateGame/Panel/BlackButton")
onready var GameScene = preload("res://Game.tscn").instance()

func _ready():
    connect_button(WhiteButton, BlackButton)
    connect_button(BlackButton, WhiteButton)
    
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

func _on_JoinGameButton_pressed():
    get_node("/root/Menu/Background").visible = false
    get_node("/root/Menu/BackgroundBlur").visible = true
    get_node("/root/Menu/Welcome").visible = false
    get_node("/root/Menu/JoinGame").visible = true
    
func on_color_pressed(button, other):
    button.set_size(Vector2(141, 300))
    other.set_size(Vector2(141, 200))
    button.get_node("Edit").visible = true
    other.get_node("Edit").visible = false

func on_name_focus_enter(button):
    button.get_node("Edit/InputName/Label").visible = false

func on_name_focus_exit(button):
    if button.get_node("Edit/InputName").text == "":
        button.get_node("Edit/InputName/Label").visible = true

func on_play_pressed(button):
    var name = button.get_node("Edit/InputName").text
    #set_player_name(button, name)
    disconnect_handlers()
    
    if button == WhiteButton:
        Server.send_join_player(1, "white", name)
    else:
        Server.send_join_player(2, "black", name)

func disconnect_handlers():
    disconnect_button(WhiteButton)
    disconnect_button(BlackButton)

func set_player(color, name):
    get_node("/root/Menu/Welcome").visible = false
    get_node("/root/Menu/JoinGame").visible = false
    get_node("/root/Menu/Loading").visible = false
    get_node("/root/Menu/CreateGame").visible = true
    
    if color == "white":
        set_player_name(WhiteButton, name)
    else:
        set_player_name(BlackButton, name)

func set_player_name(button, name):
    disconnect_button(button)
    button.set_size(Vector2(141, 250))
    button.get_node("Display").visible = true
    button.get_node("Display/Label").text = name
    button.get_node("Edit").visible = false

func _on_JoinGameCode_pressed():
    get_node("/root/Menu/JoinGame").visible = false
    var code = get_node("/root/Menu/JoinGame/Panel/Code/InputCode").text
    _on_room_created(code)
