extends Control

# The panels over the table: whose turn it is, the moves played, the room
# code, a line of help and the buttons to confirm or undo a turn

signal turn_confirmation(confirmed)

# Seconds a passing message stays before the help comes back
const MESSAGE_TIME = 4.0

const RESULTS = {"WIN_1": "Ganan las blancas", "WIN_2": "Ganan las negras", "DRAW": "Empate"}
const CONDITIONS = {"LONDI": "por Londë", "FLAT": "por recuento de ciryar"}

onready var Match = get_node("/root/Match")
onready var Server = get_node("/root/Server")
onready var inactive_style = load("res://assets/interface/background_inactive.tres")
onready var active_style = load("res://assets/interface/background_active.tres")

# Counts the passing messages, so an old one does not hide a newer one
var messages = 0

func _ready():
    mouse_filter = MOUSE_FILTER_IGNORE
    $CodePanel.visible = !Match.sandbox

    Server.connect("connection_success", self, "_show_room")
    Server.connect("notification_received", self, "_on_notification")
    Server.connect("connection_lost", self, "_on_connection_lost")
    Server.connect("connection_success", self, "_show_help")
    Match.connect("phase_changed", self, "_on_phase_changed")
    Match.connect("turn_played", self, "_on_turn_played")
    Match.connect("history", self, "_on_history")
    # The list of moves keeps the last one in sight as it grows
    $Moves/Scroll.get_v_scrollbar().connect("changed", self, "_show_last_move")
    Match.connect("move_changed", self, "_on_move_changed")
    Match.connect("turn_refused", self, "_on_turn_refused")
    Match.connect("game_over", self, "_on_game_over")
    $TurnPanel/Confirm.connect("pressed", self, "_on_confirm_pressed")
    $TurnPanel/Undo.connect("pressed", self, "_on_undo_pressed")

    _show_room()
    _on_phase_changed(Match.phase)

    # Opened in a game already started: the status came while in the menu
    if Match.status:
        _on_history(Match.status.get("moves", []))

func _show_room():
    $CodePanel/CodeText/Code.text = Server.get_code()
    $WhiteTurn/User.text = Server.get_player_name("white")
    $BlackTurn/User.text = Server.get_player_name("black")

func _on_phase_changed(phase):
    $TurnPanel.visible = phase == Match.Phase.MY_TURN
    $TurnPanel/Confirm.disabled = Match.move_notation() == ""

    var active = $WhiteTurn if Match.current == 1 else $BlackTurn
    var inactive = $BlackTurn if Match.current == 1 else $WhiteTurn

    active.set("custom_styles/panel", active_style)
    active.get_node("CurrentTurn").visible = true
    inactive.set("custom_styles/panel", inactive_style)
    inactive.get_node("CurrentTurn").visible = false

    _show_help()

# The help for the phase of the game
func _show_help():
    var text = ""

    match Match.phase:
        Match.Phase.WAITING:
            text = "Esperando a que empiece la partida"
        Match.Phase.MY_TURN:
            if Match.opening():
                text = "Toma una cirya de tu oponente y ubícala en un sat"
        Match.Phase.SUBMITTED:
            text = "Esperando al servidor…"
        Match.Phase.OPPONENT:
            text = "Turno de las blancas" if Match.current == 1 else "Turno de las negras"

    $HelpPanel/AdviceLavel.text = text
    $HelpPanel.visible = text != ""

# A message for a few seconds, then the help again
func _say(text):
    messages += 1
    var mine = messages
    $HelpPanel/AdviceLavel.text = text
    $HelpPanel.visible = true
    yield(get_tree().create_timer(MESSAGE_TIME), "timeout")

    if mine == messages:
        _show_help()

# It stays until the connection is back
func _on_connection_lost():
    messages += 1
    $HelpPanel/AdviceLavel.text = "Reconectando…"
    $HelpPanel.visible = true

func _on_move_changed(notation):
    $TurnPanel/Confirm.disabled = notation == ""

func _on_turn_refused(reason):
    _say("Movimiento no válido: %s" % reason)

func _on_notification(message):
    match message.type:
        "UserJoined":
            _say("Alguien ha entrado en la sala")
        "UserLeft":
            _say("Alguien ha salido de la sala")
        "PlayerJoined":
            _show_room()

func _on_game_over(result, condition):
    var text = RESULTS.get(result, result)

    if result != "DRAW":
        text += " " + CONDITIONS.get(condition, "")

    if Match.player == 0:
        text += "\n¡Esperamos que hayas disfrutado de la partida!"
    else:
        var mine = "WIN_%d" % Match.player
        text += "\n" + ("¡Has ganado!" if result == mine else ("Has empatado" if result == "DRAW" else "Has perdido"))

    var dialog = AcceptDialog.new()
    dialog.window_title = "Fin de la partida"
    dialog.dialog_text = text
    dialog.get_ok().text = "Volver al menú"
    # The button is the only way out: no close button, no click outside
    dialog.get_close_button().hide()
    dialog.popup_exclusive = true
    dialog.connect("confirmed", self, "_back_to_menu")
    add_child(dialog)
    dialog.popup_centered()

func _back_to_menu():
    Match.leave()
    Server.leave_room()
    get_tree().change_scene("res://menus/MainMenu.tscn")

func _on_confirm_pressed():
    emit_signal("turn_confirmation", true)

func _on_undo_pressed():
    emit_signal("turn_confirmation", false)

func _on_turn_played(turn, notation):
    $Moves/Scroll/MovesText.text += "\n%d. %s" % [turn, notation]

func _show_last_move():
    $Moves/Scroll.scroll_vertical = int($Moves/Scroll.get_v_scrollbar().max_value)

func _on_history(moves):
    $Moves/Scroll/MovesText.text = ""

    for i in range(moves.size()):
        _on_turn_played(i + 1, moves[i])
