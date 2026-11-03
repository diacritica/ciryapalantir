extends Control

# The panels over the table: whose turn it is and the clocks, the moves
# played, the room code, a line of help and the buttons to confirm or undo a
# turn. Some parts have scripts of their own:
#
#   ui/MoveEntry.gd       the field to write a move, a node of the scene
#   ui/GameOverDialog.gd  the end of the game and the offer of a rematch
#   ui/DemoPanel.gd       the panels in the demo and the replay of a list

const DemoPanel = preload("res://ui/DemoPanel.gd")
const GameOverDialog = preload("res://ui/GameOverDialog.gd")

signal turn_confirmation(confirmed)
# Settings.STORY or Settings.SCHEMATIC, chosen by its buttons
signal view_chosen(view)

# Seconds a passing message stays before the help comes back
const MESSAGE_TIME = 4.0
# Space between the help and the turn buttons under it
const HELP_GAP = 8

# The clock that runs, the one that waits, and one with little time left
const CLOCK_RUNNING = Color(1, 0.690196, 0.258824)
const CLOCK_WAITING = Color(0.631373, 0.631373, 0.631373)
const CLOCK_SHORT = Color(0.95, 0.33, 0.27)
# Milliseconds under which the clock turns red, and shows tenths
const SHORT_TIME = 30000
const TENTHS_TIME = 10000

# The button of the view in use, and the other one
const VIEW_CHOSEN = Color(1, 0.690196, 0.258824)
const VIEW_OTHER = Color(0.631373, 0.631373, 0.631373, 0.7)
# In the schematic view the help is white on black with a thin amber edge,
# as the button to confirm, and without the dark outline that the story
# needs over the wood
const SCHEMATIC_HELP_BACKGROUND = Color(0.04, 0.04, 0.04, 0.92)
const SCHEMATIC_HELP_TEXT = Color(1, 1, 1)

# Room under the seals of the rules in the panel of the code
const SEAL_MARGIN = 10

onready var Match = get_node("/root/Match")
onready var Server = get_node("/root/Server")
onready var Settings = get_node("/root/Settings")
onready var inactive_style = load("res://assets/interface/background_inactive.tres")
onready var active_style = load("res://assets/interface/background_active.tres")

# Counts the passing messages, so an old one does not hide a newer one
var messages = 0
# The look of the help in the story, and in the schematic view
var story_help = {}
var schematic_help = {}
# The bottom of the panel of the code before the seals of the rules
var code_bottom = 0

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
    Match.connect("move_changed", self, "_on_move_changed")
    Match.connect("turn_refused", self, "_on_turn_refused")
    Match.connect("game_over", self, "_on_game_over")
    Match.connect("status_received", self, "_show_rules")
    $TurnPanel/Confirm.connect("pressed", self, "_on_confirm_pressed")
    $TurnPanel/Undo.connect("pressed", self, "_on_undo_pressed")
    # Invisible for now, in the bottom left corner
    $Exit.connect("pressed", self, "_ask_to_leave")
    $MoveEntry.connect("confirm_requested", self, "_on_confirm_requested")
    $View/Story.connect("pressed", self, "_choose_view", [Settings.STORY])
    $View/Schematic.connect("pressed", self, "_choose_view", [Settings.SCHEMATIC])
    show_view()

    _show_room()
    _show_rules()
    _on_phase_changed(Match.phase)

    # Opened in a game already started: the status came while in the menu
    if Match.status:
        _on_history(Match.status.get("moves", []))

    if Match.demo:
        var demo = DemoPanel.new()
        demo.name = "Demo"
        add_child(demo)

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

func _choose_view(view):
    emit_signal("view_chosen", view)
    show_view()

func show_view():
    $View/Story.modulate = VIEW_OTHER if Settings.schematic() else VIEW_CHOSEN
    $View/Schematic.modulate = VIEW_CHOSEN if Settings.schematic() else VIEW_OTHER

    if story_help.empty():
        _make_help_looks()

    var look = schematic_help if Settings.schematic() else story_help
    $HelpPanel.set("custom_styles/panel", look.panel)
    $HelpPanel/AdviceLavel.set("custom_fonts/font", look.font)
    $HelpPanel/AdviceLavel.set("custom_colors/font_color", look.color)

func _make_help_looks():
    var label = $HelpPanel/AdviceLavel
    story_help = {"panel": $HelpPanel.get("custom_styles/panel"), "font": label.get("custom_fonts/font"), "color": label.get("custom_colors/font_color")}

    var panel = StyleBoxFlat.new()
    panel.bg_color = SCHEMATIC_HELP_BACKGROUND
    panel.border_color = VIEW_CHOSEN
    panel.set_border_width_all(1)
    var font = story_help.font.duplicate()
    font.outline_size = 0
    schematic_help = {"panel": panel, "font": font, "color": SCHEMATIC_HELP_TEXT}

# The seals of the Henneth Annûn rule and the variant T4K, one under the
# other below the code, when the game has them; the panel grows for them
func _show_rules(_status = null, _catching_up = false):
    if code_bottom == 0:
        code_bottom = $CodePanel.margin_bottom

    $CodePanel/HennethAnnun.visible = Match.henneth_annun()
    $CodePanel/Tak.visible = Match.tak()
    var top = $CodePanel/HennethAnnun.margin_top
    var seal_height = $CodePanel/HennethAnnun.rect_size.y

    for seal in [$CodePanel/HennethAnnun, $CodePanel/Tak]:
        if seal.visible:
            seal.margin_top = top
            seal.margin_bottom = top + seal_height
            top += seal_height

    if !Match.demo:
        $CodePanel.margin_bottom = max(code_bottom, $CodePanel.margin_top + top + SEAL_MARGIN)

func _on_phase_changed(phase):
    $TurnPanel.visible = phase == Match.Phase.MY_TURN and !Match.demo
    $MoveEntry.show_for_turn(phase == Match.Phase.MY_TURN and !Match.demo and Match.player != 0)

    # No turns in the demo
    if Match.demo:
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

    # DemoPanel says what there is to say
    if Match.demo:
        return

    match Match.phase:
        Match.Phase.WAITING:
            text = "Esperando a que empiece la partida"
        Match.Phase.MY_TURN:
            if Match.opening():
                text = "Toma una cirya de tu oponente y ubícala en un sat"
            elif Match.hallacirya_due():
                text = "Henneth Annûn: es tu turno de poner la Hallacirya"
        Match.Phase.SUBMITTED:
            text = "Esperando al servidor…"
        Match.Phase.OPPONENT:
            text = "Turno de las blancas" if Match.current == 1 else "Turno de las negras"

    help(text)

# The help sits where the turn buttons are, or just above them when they show
func help(text):
    var panel = $HelpPanel
    var height = panel.rect_size.y
    var bottom = $TurnPanel.margin_top - HELP_GAP if $TurnPanel.visible else $TurnPanel.margin_top + ($TurnPanel.rect_size.y + height) / 2

    panel.margin_bottom = bottom
    panel.margin_top = bottom - height
    panel.get_node("AdviceLavel").text = text
    panel.visible = text != ""

# A message for a few seconds, then the help again. A signal and not a
# yield, so leaving the game meanwhile does not resume it on a freed scene
func say(text):
    messages += 1
    help(text)
    get_tree().create_timer(MESSAGE_TIME).connect("timeout", self, "_after_message", [messages])

func _after_message(mine):
    if mine == messages:
        _show_help()

# It stays until the connection is back
func _on_connection_lost():
    messages += 1
    help("Reconectando…")

func _on_move_changed(notation):
    $TurnPanel/Confirm.disabled = notation == ""

func _on_turn_refused(reason):
    say("Movimiento no válido: %s" % reason)

func _on_notification(message):
    match message.type:
        "UserJoined":
            say("Alguien ha entrado en la sala")
        "UserLeft":
            say("Alguien ha salido de la sala")
        "PlayerJoined":
            _show_room()

func _on_game_over(result, condition):
    var dialog = GameOverDialog.new()
    dialog.name = "GameOver"
    dialog.connect("confirmed", self, "_back_to_menu")
    add_child(dialog)
    dialog.show_result(result, condition)

# Escape asks too, Enter confirms the turn like its button, and a click on
# the table leaves the moves, so their selection does not keep the keys
func _unhandled_input(event):
    if event.is_action_pressed("ui_cancel"):
        _ask_to_leave()
    elif event is InputEventKey and event.pressed and !event.echo and event.scancode in [KEY_ENTER, KEY_KP_ENTER]:
        if $TurnPanel.visible and !$TurnPanel/Confirm.disabled and !has_node("Leave") and !has_node("Renounce"):
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
    Settings.view = Settings.STORY
    Server.leave_room()
    get_tree().change_scene("res://menus/MainMenu.tscn")

# Enter on the empty field of the written move, as the button
func _on_confirm_requested():
    if $TurnPanel.visible and !$TurnPanel/Confirm.disabled:
        _on_confirm_pressed()

# Game answers with why the move could not be made, or "" when it is on the board
func move_written_result(error):
    if error != "":
        say(error)
        $MoveEntry.shake()
        return

    $MoveEntry.clear()
    say("%s en el tablero: ENTER o Confirmar para enviarla" % Match.move_notation())

# With Henneth Annûn, another move in the turn of the hallacirya gives it up
# for ever, so it is asked first
func _on_confirm_pressed():
    if Match.renounces_hallacirya():
        _ask_to_renounce()
    else:
        emit_signal("turn_confirmation", true)

func _ask_to_renounce():
    if has_node("Renounce"):
        return

    var dialog = ConfirmationDialog.new()
    dialog.name = "Renounce"
    dialog.window_title = "Henneth Annûn"
    dialog.dialog_text = "¿Renuncias para siempre a tu Hallacirya?\nSolo puede ponerse en juego en este turno."
    dialog.get_ok().text = "Renuncio"
    dialog.get_cancel().text = "Volver al tablero"
    dialog.connect("confirmed", self, "emit_signal", ["turn_confirmation", true])
    dialog.connect("popup_hide", dialog, "queue_free")
    add_child(dialog)
    dialog.popup_centered()

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
