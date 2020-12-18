extends Control

onready var Global = get_node("/root/Global")
onready var Server = get_node("/root/Server")

onready var inactive_style = load("res://assets/interface/background_inactive.tres")
onready var active_style = load("res://assets/interface/background_active.tres")

signal turn_confirmation(value)

func _ready():
    Server.connect("notification_received", self, "on_notification_received")
    Server.connect("connection_success", self, "check_context")
    
    check_context()
    set_turn_color("white")
    if Server.get_player() == 1:
        show_turn_buttons()
        
    get_node("TurnPanel/Confirm").connect("pressed", self, "on_confirm_turn")
    get_node("TurnPanel/Undo").connect("pressed", self, "on_undo_turn")

func on_confirm_turn():
    emit_signal("turn_confirmation", true)

func on_undo_turn():
    emit_signal("turn_confirmation", false)

func on_notification_received(msg):
    if msg["type"] == "Turn":
        add_move(msg["params"]["move"])
        
        if msg["params"]["nextPlayer"] == 1:
            set_turn_color("white")
        else:
            set_turn_color("black")
            
        if msg["params"]["nextPlayer"] == Server.get_player():
            show_turn_buttons()
        else:
            hide_turn_buttons()

func show_turn_buttons():
    $TurnPanel.visible = true
    
func hide_turn_buttons():
    $TurnPanel.visible = false
    
func add_move(move):
    var move_str = str(Global.turn) + ". " + move
    get_node("Moves/MovesText").text = get_node("Moves/MovesText").text + "\n" + move_str

func check_context():
    get_node("CodePanel/CodeText/Code").text = Server.get_code()
    get_node("WhiteTurn/User").text = Server.get_player_name("white")
    get_node("BlackTurn/User").text = Server.get_player_name("black")

func set_turn_color(color):
    var active_turn
    var inactive_turn

    if color == "white":
        active_turn = $WhiteTurn
        inactive_turn = $BlackTurn
    else:
        active_turn = $BlackTurn
        inactive_turn = $WhiteTurn

    active_turn.set("custom_styles/panel", active_style)
    active_turn.get_node("CurrentTurn").visible = true
    inactive_turn.set("custom_styles/panel", inactive_style)
    inactive_turn.get_node("CurrentTurn").visible = false
