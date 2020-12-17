extends Control

onready var WhiteButton = get_node("/root/Menu/CreateGame/Panel/WhiteButton")
onready var BlackButton = get_node("/root/Menu/CreateGame/Panel/BlackButton")

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
    get_node("/root/Menu/Background").visible = false
    get_node("/root/Menu/BackgroundBlur").visible = true
    get_node("/root/Menu/Welcome").visible = false
    get_node("/root/Menu/CreateGame").visible = true
    
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
    set_player_name(button, name)
    disconnect_handlers()

func disconnect_handlers():
    disconnect_button(WhiteButton)
    disconnect_button(BlackButton)

func set_player(color, name):
    get_node("/root/Menu/Welcome").visible = false
    get_node("/root/Menu/JoinGame").visible = false
    get_node("/root/Menu/Loading").visible = false
    get_node("/root/Menu/CreateGame").visible = true
    
    if color == "white":
        disconnect_button(WhiteButton)
        set_player_name(WhiteButton, name)
    else:
        disconnect_button(BlackButton)
        set_player_name(BlackButton, name)

func set_player_name(button, name):
    button.set_size(Vector2(141, 250))
    button.get_node("Display").visible = true
    button.get_node("Display/Label").text = name
    button.get_node("Edit").visible = false

func _on_JoinGameCode_pressed():
    get_node("/root/Menu/JoinGame").visible = false
    var code = get_node("/root/Menu/JoinGame/Panel/Code/InputCode").text
    print("CODE:", code)
    get_node("/root/Menu/CreateGame/Panel/Code/CodeLabel").text = code
    _on_NewGameButton_pressed()

