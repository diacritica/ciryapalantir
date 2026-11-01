extends Control

# The panels over the table: whose turn it is, the moves played, the room
# code and the buttons to confirm or undo a turn

signal turn_confirmation(confirmed)

onready var Match = get_node("/root/Match")
onready var Server = get_node("/root/Server")
onready var inactive_style = load("res://assets/interface/background_inactive.tres")
onready var active_style = load("res://assets/interface/background_active.tres")

func _ready():
    mouse_filter = MOUSE_FILTER_IGNORE
    $CodePanel.visible = !Match.sandbox

    Server.connect("connection_success", self, "_show_room")
    Match.connect("phase_changed", self, "_on_phase_changed")
    Match.connect("turn_played", self, "_on_turn_played")
    Match.connect("history", self, "_on_history")
    $TurnPanel/Confirm.connect("pressed", self, "_on_confirm_pressed")
    $TurnPanel/Undo.connect("pressed", self, "_on_undo_pressed")

    _show_room()
    _on_phase_changed(Match.phase)

func _show_room():
    $CodePanel/CodeText/Code.text = Server.get_code()
    $WhiteTurn/User.text = Server.get_player_name("white")
    $BlackTurn/User.text = Server.get_player_name("black")

func _on_phase_changed(phase):
    $TurnPanel.visible = phase == Match.Phase.MY_TURN

    var active = $WhiteTurn if Match.current == 1 else $BlackTurn
    var inactive = $BlackTurn if Match.current == 1 else $WhiteTurn

    active.set("custom_styles/panel", active_style)
    active.get_node("CurrentTurn").visible = true
    inactive.set("custom_styles/panel", inactive_style)
    inactive.get_node("CurrentTurn").visible = false

func _on_confirm_pressed():
    emit_signal("turn_confirmation", true)

func _on_undo_pressed():
    emit_signal("turn_confirmation", false)

func _on_turn_played(turn, notation):
    $Moves/MovesText.text += "\n%d. %s" % [turn, notation]

func _on_history(moves):
    $Moves/MovesText.text = ""

    for i in range(moves.size()):
        _on_turn_played(i + 1, moves[i])
