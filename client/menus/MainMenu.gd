extends Control

# The first screen: create a room, join one with its code, or open the sandbox
# or the demo.
# In a room each player picks a colour and a name, and the game starts when
# both are ready

onready var Server = get_node("/root/Server")
onready var Match = get_node("/root/Match")
onready var WhiteButton = $CreateGame/Panel/WhiteButton
onready var BlackButton = $CreateGame/Panel/BlackButton

func _ready():
    Server.connect("user_logged", self, "_on_user_logged")
    Server.connect("notification_received", self, "_on_notification_received")
    _connect_button(WhiteButton, BlackButton)
    _connect_button(BlackButton, WhiteButton)

    # Back from a game: the user logged in long ago
    if Server.logged_in():
        _on_user_logged()

func _on_user_logged():
    $Welcome/Panel/NewGameButton.disabled = false
    $Welcome/Panel/JoinGameButton.disabled = false

func _on_NewGameButton_pressed():
    Server.connect("room_created", self, "_enter_room", [], CONNECT_ONESHOT)
    Server.create_room()

func _on_JoinGameButton_pressed():
    _leave_welcome()
    $JoinGame.visible = true

func _on_JoinGameCode_pressed():
    $JoinGame.visible = false
    # Codes are uppercase: typed in lowercase they would open another, empty room
    _enter_room($JoinGame/Panel/Code/InputCode.text.strip_edges().to_upper())

func _on_SandboxButton_pressed():
    Match.start_sandbox()
    get_tree().change_scene("res://Game.tscn")

func _on_DemoButton_pressed():
    Match.start_demo()
    get_tree().change_scene("res://Game.tscn")

func _enter_room(code):
    Match.sandbox = false
    Match.demo = false
    # The seat taken here before, to play it again when the game has started
    Match.player = Server.seat_in(code)
    $CreateGame/Panel/Code/CodeLabel.text = code
    _leave_welcome()
    $CreateGame.visible = true
    Server.join_room(code)

func _leave_welcome():
    $Background.visible = false
    $BackgroundBlur.visible = true
    $Welcome.visible = false

func _on_notification_received(message):
    match message.type:
        "PlayerJoined":
            var params = message.params
            _show_player(WhiteButton if params.color == "white" else BlackButton, params.name)

            if int(params.player) == Match.player:
                Server.send_set_ready(true)

        # A game already started opens at once: for a player coming back or
        # for someone who comes to watch
        "StatusResponse":
            var players = message.status.get("players", {})

            if players.has("1"):
                _show_player(WhiteButton, players["1"].name)
            if players.has("2"):
                _show_player(BlackButton, players["2"].name)

            if message.status.state != "NOT_STARTED":
                get_tree().change_scene("res://Game.tscn")

        "StartGame":
            get_tree().change_scene("res://Game.tscn")

func _connect_button(button, other):
    button.connect("pressed", self, "_on_color_pressed", [button, other])
    button.get_node("Edit/PlayButton").connect("pressed", self, "_on_play_pressed", [button])

func _disconnect_button(button):
    if button.is_connected("pressed", self, "_on_color_pressed"):
        button.disconnect("pressed", self, "_on_color_pressed")
        button.get_node("Edit/PlayButton").disconnect("pressed", self, "_on_play_pressed")

func _on_color_pressed(button, other):
    button.set_size(Vector2(141, 300))

    if !other.get_node("Display").visible:
        other.set_size(Vector2(141, 200))

    button.get_node("Edit").visible = true
    other.get_node("Edit").visible = false

func _on_play_pressed(button):
    _disconnect_button(WhiteButton)
    _disconnect_button(BlackButton)

    Match.player = 1 if button == WhiteButton else 2
    Server.send_join_player(Match.player, "white" if Match.player == 1 else "black", button.get_node("Edit/InputName").text)

# The seat is taken: it shows the name and cannot be picked any more
func _show_player(button, name):
    _disconnect_button(button)
    button.set_size(Vector2(141, 250))
    button.get_node("Display").visible = true
    button.get_node("Display/Label").text = name
    button.get_node("Edit").visible = false
