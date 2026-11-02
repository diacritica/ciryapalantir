extends Control

# The panels over the table: whose turn it is, the moves played, the room
# code, a line of help and the buttons to confirm or undo a turn

signal turn_confirmation(confirmed)

# Seconds a passing message stays before the help comes back
const MESSAGE_TIME = 4.0
# Seconds the help of the demo stays, so it does not get in the way after
const DEMO_HELP_TIME = 10.0
# Width of the panels on the left in the demo, with no names of players
const DEMO_WIDTH = 230
# Room in the moves for one line under the title, and in the panel of the
# logo for the link to play
const DEMO_MOVES_HEIGHT = 70
const DEMO_CODE_HEIGHT = 150
const DEMO_HELP = "Demo: mueve cualquier pieza a cualquier sat. Fuera del tablero vuelve a su bandeja. Con R se levanta una tampa"
# Space between the help and the turn buttons under it
const HELP_GAP = 8

const RESULTS = {"WIN_1": "Ganan las blancas", "WIN_2": "Ganan las negras", "DRAW": "Empate"}
const CONDITIONS = {"LONDI": "por Londë", "FLAT": "por recuento de ciryar", "TIME": "por tiempo"}

# The clock that runs, the one that waits, and one with little time left
const CLOCK_RUNNING = Color(1, 0.690196, 0.258824)
const CLOCK_WAITING = Color(0.631373, 0.631373, 0.631373)
const CLOCK_SHORT = Color(0.95, 0.33, 0.27)
# Milliseconds under which the clock turns red, and shows tenths
const SHORT_TIME = 30000
const TENTHS_TIME = 10000

onready var Match = get_node("/root/Match")
onready var Server = get_node("/root/Server")
onready var inactive_style = load("res://assets/interface/background_inactive.tres")
onready var active_style = load("res://assets/interface/background_active.tres")

# Counts the passing messages, so an old one does not hide a newer one
var messages = 0

func _ready():
    mouse_filter = MOUSE_FILTER_IGNORE
    $CodePanel.visible = !Match.sandbox

    if Match.demo:
        _dress_for_demo()

    Server.connect("connection_success", self, "_show_room")
    Server.connect("notification_received", self, "_on_notification")
    Server.connect("connection_lost", self, "_on_connection_lost")
    Server.connect("connection_success", self, "_show_help")
    Match.connect("phase_changed", self, "_on_phase_changed")
    Match.connect("turn_played", self, "_on_turn_played")
    Match.connect("history", self, "_on_history")
    Match.connect("move_changed", self, "_on_move_changed")
    Match.connect("turn_refused", self, "_on_turn_refused")
    Match.connect("game_over", self, "_on_game_over")
    $TurnPanel/Confirm.connect("pressed", self, "_on_confirm_pressed")
    $TurnPanel/Undo.connect("pressed", self, "_on_undo_pressed")
    # Invisible for now, in the bottom left corner
    $Exit.connect("pressed", self, "_ask_to_leave")

    _show_room()
    _on_phase_changed(Match.phase)

    # Opened in a game already started: the status came while in the menu
    if Match.status:
        _on_history(Match.status.get("moves", []))

# The clocks count down every frame between the messages of the server
func _process(_delta):
    var shown = Match.has_clock() and !Match.sandbox and !Match.demo

    for seat in [1, 2]:
        var clock = (_turn_panel(seat)).get_node("Clock")
        clock.visible = shown

        if shown:
            _show_clock(clock, seat)

func _turn_panel(seat):
    return $WhiteTurn if seat == 1 else $BlackTurn

func _show_clock(clock, seat):
    var left = Match.time_left(seat)
    var running = Match.clock_running == seat
    var label = clock.get_node("Time")

    label.text = clock_text(left)
    clock.set("custom_styles/panel", active_style if running else inactive_style)

    if left < SHORT_TIME:
        label.set("custom_colors/font_color", CLOCK_SHORT)
    else:
        label.set("custom_colors/font_color", CLOCK_RUNNING if running else CLOCK_WAITING)

# 4:59 with whole seconds, and 9.4 with tenths at the end
static func clock_text(milliseconds):
    if milliseconds < TENTHS_TIME:
        return "%d.%d" % [milliseconds / 1000, (milliseconds % 1000) / 100]

    var seconds = milliseconds / 1000
    return "%d:%02d" % [seconds / 60, seconds % 60]

func _show_room():
    $CodePanel/CodeText/Code.text = Server.get_code()
    $WhiteTurn/User.text = Server.get_player_name("white")
    $BlackTurn/User.text = Server.get_player_name("black")

func _on_phase_changed(phase):
    $TurnPanel.visible = phase == Match.Phase.MY_TURN and !Match.demo

    # No turns in the demo
    if Match.demo:
        _show_help()
        return

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

    if Match.demo:
        _demo_help()
        return

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

    _help(text)

# The demo is not a game, but it is shown to others, as on a stream: the
# panels of the players stay, narrow, with no names and no turn; the moves
# say it is the demo, and the logo and the link to play stay, with no code
func _dress_for_demo():
    for panel in [$WhiteTurn, $BlackTurn]:
        panel.margin_right = panel.margin_left + DEMO_WIDTH
        panel.set("custom_styles/panel", inactive_style)
        panel.get_node("User").hide()
        panel.get_node("CurrentTurn").hide()
        var label = panel.get_node("Label")
        var width = label.margin_right - label.margin_left
        label.margin_left = panel.get_node("User").margin_left
        label.margin_right = label.margin_left + width

    var moves = $Moves
    var title = moves.get_node("Title")
    var text = moves.get_node("MovesText")
    moves.margin_right = moves.margin_left + DEMO_WIDTH
    moves.margin_bottom = moves.margin_top + title.margin_bottom + DEMO_MOVES_HEIGHT
    title.margin_right = DEMO_WIDTH - title.margin_left
    text.hide()

    var demo = Label.new()
    demo.name = "DemoText"
    demo.text = "Modo Demo"
    demo.align = Label.ALIGN_CENTER
    demo.valign = Label.VALIGN_CENTER
    demo.set("custom_fonts/font", text.get("custom_fonts/font"))
    demo.set("custom_colors/font_color", text.get("custom_colors/font_color_readonly"))
    moves.add_child(demo)
    demo.set_anchors_and_margins_preset(PRESET_WIDE)
    demo.margin_top = title.margin_bottom

    var code = $CodePanel
    code.get_node("CodeText").hide()
    code.get_node("ShareText/Label").text = "Juega en"
    code.margin_bottom = code.margin_top + DEMO_CODE_HEIGHT

# Once, when the demo opens
func _demo_help():
    if messages > 0:
        return

    messages += 1
    _help(DEMO_HELP)
    yield(get_tree().create_timer(DEMO_HELP_TIME), "timeout")
    _help("")

# The help sits where the turn buttons are, or just above them when they show
func _help(text):
    var panel = $HelpPanel
    var height = panel.rect_size.y
    var bottom = $TurnPanel.margin_top - HELP_GAP if $TurnPanel.visible else $TurnPanel.margin_top + ($TurnPanel.rect_size.y + height) / 2

    panel.margin_bottom = bottom
    panel.margin_top = bottom - height
    panel.get_node("AdviceLavel").text = text
    panel.visible = text != ""

# A message for a few seconds, then the help again
func _say(text):
    messages += 1
    var mine = messages
    _help(text)
    yield(get_tree().create_timer(MESSAGE_TIME), "timeout")

    if mine == messages:
        _show_help()

# It stays until the connection is back
func _on_connection_lost():
    messages += 1
    _help("Reconectando…")

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
    # The button is the only way out, and it is not modal: the moves can
    # still be scrolled to see how the game went
    dialog.get_close_button().hide()
    dialog.connect("confirmed", self, "_back_to_menu")
    add_child(dialog)
    dialog.show()
    dialog.rect_size = dialog.get_combined_minimum_size()
    dialog.rect_position = (get_viewport_rect().size - dialog.rect_size) / 2

# Escape asks too, Enter confirms the turn like its button, and a click on
# the table leaves the moves, so their selection does not keep the keys
func _unhandled_input(event):
    if event.is_action_pressed("ui_cancel"):
        _ask_to_leave()
    elif event is InputEventKey and event.pressed and !event.echo and event.scancode in [KEY_ENTER, KEY_KP_ENTER]:
        if $TurnPanel.visible and !$TurnPanel/Confirm.disabled and !has_node("Leave"):
            get_tree().set_input_as_handled()
            _on_confirm_pressed()
    elif event is InputEventMouseButton and event.pressed:
        $Moves/MovesText.release_focus()

func _ask_to_leave():
    if has_node("Leave"):
        return

    var dialog = ConfirmationDialog.new()
    dialog.name = "Leave"
    dialog.window_title = "Salir de la partida"
    dialog.dialog_text = "¿Volver al menú de inicio?"

    if Match.sandbox:
        dialog.dialog_text += "\nLa partida de sandbox se pierde."
    elif Match.demo:
        dialog.dialog_text += "\nLa posición de la demo se pierde."
    elif Match.player != 0 and Match.phase != Match.Phase.FINISHED:
        dialog.dialog_text += "\nTu asiento te espera: entra con el código %s para seguir." % Server.get_code()

    dialog.get_ok().text = "Salir"
    dialog.get_cancel().text = "Seguir jugando"
    dialog.connect("confirmed", self, "_back_to_menu")
    dialog.connect("popup_hide", dialog, "queue_free")
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

# A new move shows at the bottom of the list, which the wheel can scroll
# back; the mouse selects the moves and Ctrl+A and Ctrl+C copy them
func _on_turn_played(turn, notation):
    var moves = $Moves/MovesText

    if moves.text != "":
        moves.text += "\n"

    moves.text += "%d. %s" % [turn, notation]
    call_deferred("_show_last_move")

# Deferred, once the list has grown
func _show_last_move():
    yield(get_tree(), "idle_frame")
    $Moves/MovesText.scroll_vertical = $Moves/MovesText.get_line_count()

func _on_history(moves):
    $Moves/MovesText.text = ""

    for i in range(moves.size()):
        _on_turn_played(i + 1, moves[i])
