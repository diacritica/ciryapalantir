extends Control

# The panels over the table: whose turn it is, the moves played, the room
# code, a line of help and the buttons to confirm or undo a turn

signal turn_confirmation(confirmed)
# A turn typed in the field, for the game to make it on the board
signal move_written(text)
# The field opened or closed: the board shows its coordinates while it is open
signal entry_shown(shown)
# Settings.STORY or Settings.SCHEMATIC, chosen by its buttons
signal view_chosen(view)
# A list of turns to replay in the demo, from the start or on the board as
# it is, with the player of its first turn; and the end of the replay
signal replay_requested(turns, clean, first_player)
signal replay_stopped

# Seconds a passing message stays before the help comes back
const MESSAGE_TIME = 4.0
# Seconds the help of the demo stays, so it does not get in the way after
const DEMO_HELP_TIME = 10.0
# Width of the panels on the left in the demo, with no names of players
const DEMO_WIDTH = 230
# Room in the moves for one line under the title, and in the panel of the
# logo for the link to play
const DEMO_MOVES_HEIGHT = 110
const INSERT_TEXT = "Insertar movimientos"
const STOP_TEXT = "Terminar la reproducción"
const REPLAY_KEYS = "→ avanza, ← retrocede"
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
# Milliseconds the server gives to accept a rematch
const REMATCH_TIME = 30000

# How much the field of the written move rises when it opens, and how fast
const ENTRY_HEIGHT = 72
const ENTRY_TIME = 0.15

const Notation = preload("res://core/Notation.gd")

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
# The bottom of the moves before the demo makes them short, to grow them
# back for a replay, and whether one is on the board
var moves_bottom = 0
var moves_right = 0
# The bottom of the panel of the code before the seals of the rules
var code_bottom = 0
# The offer of a rematch at the end of a game: what the dialog says of the
# result, the state of the offer, who accepted, and until when it is open
var result_text = ""
var rematch_state = ""
var rematch_accepted = []
var rematch_until = 0
var replaying = false
# The field of the written move is open, and stays so from turn to turn
var entry_open = false

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
    Match.connect("status_received", self, "_show_rules")
    Match.connect("rematch_changed", self, "_on_rematch_changed")
    $TurnPanel/Confirm.connect("pressed", self, "_on_confirm_pressed")
    $TurnPanel/Undo.connect("pressed", self, "_on_undo_pressed")
    # Invisible for now, in the bottom left corner
    $Exit.connect("pressed", self, "_ask_to_leave")
    $MoveEntry/Handle.connect("pressed", self, "_toggle_entry")
    $MoveEntry/Field/Text.connect("text_entered", self, "_on_move_text_entered")
    $MoveEntry/Field/Text.connect("gui_input", self, "_on_move_text_input")
    $MoveEntry/Field/Send.connect("pressed", self, "_send_written")
    $View/Story.connect("pressed", self, "_choose_view", [Settings.STORY])
    $View/Schematic.connect("pressed", self, "_choose_view", [Settings.SCHEMATIC])
    show_view()
    _shape_entry(false)

    _show_room()
    _show_rules()
    _on_phase_changed(Match.phase)

    # Opened in a game already started: the status came while in the menu
    if Match.status:
        _on_history(Match.status.get("moves", []))

# The clocks count down every frame between the messages of the server, and
# so does the time to accept a rematch
func _process(_delta):
    if rematch_state == "OPEN" and has_node("GameOver"):
        _show_rematch()

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
    _show_entry(phase == Match.Phase.MY_TURN and !Match.demo and Match.player != 0)

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
            elif Match.hallacirya_due():
                text = "Henneth Annûn: es tu turno de poner la Hallacirya"
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
    moves_bottom = moves.margin_bottom
    moves_right = moves.margin_right
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
    demo.margin_bottom = -DEMO_MOVES_HEIGHT / 2

    # The door to replay a game, at the bottom of the moves
    var insert = Button.new()
    insert.name = "Insert"
    insert.text = INSERT_TEXT
    insert.flat = true
    insert.focus_mode = FOCUS_NONE
    insert.mouse_default_cursor_shape = CURSOR_POINTING_HAND
    insert.set("custom_fonts/font", $MoveEntry/Handle/Label.get("custom_fonts/font"))
    insert.set("custom_colors/font_color", VIEW_CHOSEN)
    insert.set("custom_colors/font_color_hover", Color(1, 1, 1))
    moves.add_child(insert)
    insert.set_anchors_and_margins_preset(PRESET_BOTTOM_WIDE)
    insert.margin_top = -DEMO_MOVES_HEIGHT / 2
    insert.margin_bottom = -8
    insert.connect("pressed", self, "_on_insert_pressed")

    var code = $CodePanel
    code.get_node("CodeText").hide()
    code.get_node("ShareText/Label").text = "Juega en"
    code.margin_bottom = code.margin_top + DEMO_CODE_HEIGHT

# Replaying a list in the demo: it is pasted and checked, then the board is
# cleaned or kept as it is, and when it is kept and the list starts with a
# placement, which says nothing of its colour, the player of the first turn
# is asked
func _on_insert_pressed():
    if replaying:
        emit_signal("replay_stopped")
        _end_replay()
    else:
        _ask_for_list()

func _ask_for_list():
    var dialog = ConfirmationDialog.new()
    dialog.name = "InsertMoves"
    dialog.window_title = INSERT_TEXT
    dialog.dialog_hide_on_ok = false
    dialog.get_ok().text = "Seguir"
    dialog.get_cancel().text = "Cancelar"

    var column = VBoxContainer.new()
    var about = Label.new()
    about.text = "Pega la lista de movimientos, como se copia de una partida (1. c3, 2. a1…)"
    var list = TextEdit.new()
    list.name = "List"
    list.rect_min_size = Vector2(460, 300)
    var error = Label.new()
    error.name = "Error"
    error.set("custom_colors/font_color", CLOCK_SHORT)
    column.add_child(about)
    column.add_child(list)
    column.add_child(error)
    dialog.add_child(column)

    dialog.connect("confirmed", self, "_on_list_confirmed", [dialog])
    dialog.connect("popup_hide", dialog, "queue_free")
    add_child(dialog)
    dialog.popup_centered()
    list.grab_focus()

func _on_list_confirmed(dialog):
    var parsed = Notation.parse_list(dialog.find_node("List", true, false).text)

    if parsed.error:
        dialog.find_node("Error", true, false).text = parsed.error
        return

    dialog.hide()
    _ask_how(parsed.turns)

func _ask_how(turns):
    var dialog = ConfirmationDialog.new()
    dialog.name = "HowToPlay"
    dialog.window_title = INSERT_TEXT
    dialog.dialog_text = "%d jugadas. ¿Cómo se juegan?\nLimpiar el tablero: todas las piezas vuelven a su bandeja y se juega desde la apertura.\nRespetar el tablero: se juega sobre la posición que hay ahora." % turns.size()
    dialog.get_ok().text = "Limpiar el tablero"
    dialog.add_button("Respetar el tablero", false, "keep")
    dialog.get_cancel().text = "Cancelar"
    dialog.connect("confirmed", self, "emit_signal", ["replay_requested", turns, true, 1])
    dialog.connect("custom_action", self, "_on_keep_the_board", [turns, dialog])
    dialog.connect("popup_hide", dialog, "queue_free")
    add_child(dialog)
    dialog.popup_centered()

func _on_keep_the_board(_action, turns, dialog):
    dialog.hide()
    var first = Notation.parse(turns[0])
    var owner = Match.board.owner(first.from) if first.has("from") and _on_board(first.from) else 0

    if owner != 0:
        emit_signal("replay_requested", turns, false, owner)
        return

    var who = ConfirmationDialog.new()
    who.name = "WhoStarts"
    who.window_title = INSERT_TEXT
    who.dialog_text = "¿Quién hace la primera jugada, %s?" % turns[0]
    who.get_ok().text = "Ninquë (blancas)"
    who.add_button("Morqua (negras)", false, "black")
    who.get_cancel().text = "Cancelar"
    who.connect("confirmed", self, "emit_signal", ["replay_requested", turns, false, 1])
    who.connect("custom_action", self, "_on_black_starts", [turns, who])
    who.connect("popup_hide", who, "queue_free")
    add_child(who)
    who.popup_centered()

func _on_black_starts(_action, turns, dialog):
    dialog.hide()
    emit_signal("replay_requested", turns, false, 2)

func _on_board(square):
    return square.x >= 0 and square.y >= 0 and square.x < Match.board.size() and square.y < Match.board.size()

# The list grows the moves back, with the last turn played marked and the
# one that cannot be played, if any, at its end
func show_replay(index, replay):
    replaying = true
    var moves = $Moves
    var text = moves.get_node("MovesText")
    moves.margin_bottom = moves_bottom
    moves.margin_right = moves_right
    moves.get_node("Title").margin_right = moves_right - moves.margin_left - moves.get_node("Title").margin_left
    moves.get_node("DemoText").hide()
    moves.get_node("Insert").text = STOP_TEXT
    text.show()
    text.focus_mode = FOCUS_NONE
    text.margin_bottom = -DEMO_MOVES_HEIGHT / 2

    var lines = []
    var shown = replay.turns.size() if replay.wrong < 0 else replay.wrong + 1

    for i in range(shown):
        lines.append("%d. %s%s" % [i + 1, replay.turns[i], "  ← no cabe" if i == replay.wrong else ""])

    text.text = PoolStringArray(lines).join("\n")
    text.deselect()

    if index > 0:
        text.select(index - 1, 0, index - 1, lines[index - 1].length())
        text.cursor_set_line(index - 1)
        text.center_viewport_to_cursor()

    var where = "Jugada %d de %d" % [index, replay.playable()] if index > 0 else "%d jugadas" % replay.playable()

    if index == replay.playable() and replay.wrong >= 0:
        _help("La jugada %d, %s, no cabe: %s" % [replay.wrong + 1, replay.turns[replay.wrong], replay.error])
    else:
        _help("%s · %s" % [where, REPLAY_KEYS])

func _end_replay():
    replaying = false
    var moves = $Moves
    moves.margin_bottom = moves.margin_top + moves.get_node("Title").margin_bottom + DEMO_MOVES_HEIGHT
    moves.margin_right = moves.margin_left + DEMO_WIDTH
    moves.get_node("Title").margin_right = DEMO_WIDTH - moves.get_node("Title").margin_left
    moves.get_node("MovesText").hide()
    moves.get_node("DemoText").show()
    moves.get_node("Insert").text = INSERT_TEXT
    _help("")

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

# A message for a few seconds, then the help again. A signal and not a
# yield, so leaving the game meanwhile does not resume it on a freed scene
func _say(text):
    messages += 1
    _help(text)
    get_tree().create_timer(MESSAGE_TIME).connect("timeout", self, "_after_message", [messages])

func _after_message(mine):
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
    dialog.name = "GameOver"
    dialog.window_title = "Fin de la partida"
    dialog.dialog_text = text
    dialog.get_ok().text = "Volver al menú"
    # The button is the only way out, and it is not modal: the moves can
    # still be scrolled to see how the game went
    dialog.get_close_button().hide()
    dialog.connect("confirmed", self, "_back_to_menu")
    result_text = text

    # The players are offered another game, with the colours swapped
    if Match.player != 0 and !Match.sandbox:
        # Each one goes before the others, so they read Adelante, Ahora no
        dialog.add_button("Ahora no", false, "no_rematch").name = "NoRematch"
        dialog.add_button("Adelante", false, "rematch").name = "Rematch"
        dialog.connect("custom_action", self, "_on_rematch_answered")
        rematch_state = "OPEN"
        rematch_accepted = []
        rematch_until = OS.get_ticks_msec() + REMATCH_TIME

    add_child(dialog)
    dialog.show()

    if rematch_state == "OPEN":
        _show_rematch()

    _fit_dialog(dialog)

func _on_rematch_answered(action):
    var accept = action == "rematch"
    Server.send_rematch(accept)

    if accept:
        rematch_accepted.append(Match.player)
    else:
        rematch_state = "DECLINED"

    _show_rematch()

func _on_rematch_changed(state, accepted, left):
    rematch_state = state
    rematch_accepted = accepted
    rematch_until = OS.get_ticks_msec() + left

    if has_node("GameOver"):
        _show_rematch()

# What the dialog says of the rematch: the time left, who is waiting for
# whom, and that there will be no new game as soon as one does not want it
func _show_rematch():
    var dialog = $GameOver
    var mine = rematch_accepted.has(Match.player)
    var theirs = rematch_accepted.has(3 - Match.player)
    var seconds = int(ceil(max(rematch_until - OS.get_ticks_msec(), 0) / 1000.0))
    var line = ""

    match rematch_state:
        "OPEN":
            if mine:
                line = "Esperando al otro jugador… %d s" % seconds
            elif theirs:
                line = "El otro jugador quiere otra partida · %d s" % seconds
            else:
                line = "¿Otra partida? Os cambiáis los colores · %d s" % seconds
        "DECLINED":
            line = "No habrá una nueva partida"
        "EXPIRED":
            line = "No habrá una nueva partida: se acabó el tiempo"

    var text = result_text + "\n\n" + line

    if dialog.dialog_text == text:
        return

    dialog.dialog_text = text

    # One no is enough at any time, even after a yes
    for name in ["Rematch", "NoRematch"]:
        var button = dialog.find_node(name, true, false)

        if button:
            button.visible = rematch_state == "OPEN"

    dialog.find_node("Rematch", true, false).disabled = mine
    _fit_dialog(dialog)

# The dialog as big as what it says now, in the middle of the screen
func _fit_dialog(dialog):
    var size = dialog.get_combined_minimum_size()

    if size != dialog.rect_size:
        dialog.rect_size = size
        dialog.rect_position = (get_viewport_rect().size - size) / 2

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

# The written move: a field that opens from the bottom edge by its handle.
# Enter or the arrow put the move on the board, and Enter on the empty
# field confirms it, so a whole turn can be played with the keyboard
func _show_entry(shown):
    $MoveEntry.visible = shown
    emit_signal("entry_shown", shown and entry_open)

    if shown and entry_open:
        $MoveEntry/Field/Text.grab_focus()
    elif !shown:
        $MoveEntry/Field/Text.release_focus()

func _toggle_entry():
    entry_open = !entry_open
    _shape_entry(true)
    emit_signal("entry_shown", entry_open)

    if entry_open:
        $MoveEntry/Field/Text.grab_focus()
    else:
        $MoveEntry/Field/Text.release_focus()

func _shape_entry(animated):
    var top = -36 - (ENTRY_HEIGHT if entry_open else 0)
    $MoveEntry/Handle/Label.text = "Cerrar" if entry_open else "Escribir jugada"

    if !animated:
        $MoveEntry.margin_top = top
        return

    var tween = Tween.new()
    add_child(tween)
    tween.interpolate_property($MoveEntry, "margin_top", $MoveEntry.margin_top, top, ENTRY_TIME, Tween.TRANS_QUAD, Tween.EASE_OUT)
    tween.connect("tween_all_completed", tween, "queue_free")
    tween.start()

func _on_move_text_entered(text):
    if text.strip_edges() == "":
        if $TurnPanel.visible and !$TurnPanel/Confirm.disabled:
            _on_confirm_pressed()
        return

    emit_signal("move_written", text)

# The arrow only sends: confirming is for Enter or the button
func _send_written():
    if $MoveEntry/Field/Text.text.strip_edges() != "":
        _on_move_text_entered($MoveEntry/Field/Text.text)

# Escape closes the field, and does not ask to leave
func _on_move_text_input(event):
    if event.is_action_pressed("ui_cancel"):
        $MoveEntry/Field/Text.accept_event()
        _toggle_entry()

# Game answers with why the move could not be made, or "" when it is on the board
func move_written_result(error):
    var text = $MoveEntry/Field/Text

    if error != "":
        _say(error)
        _shake($MoveEntry/Field)
        return

    text.text = ""
    _say("%s en el tablero: ENTER o Confirmar para enviarla" % Match.move_notation())

# A no with the head
func _shake(control):
    var x = control.rect_position.x
    var steps = [x, x + 10, x - 10, x + 6, x]
    var tween = Tween.new()
    add_child(tween)

    for i in range(steps.size() - 1):
        tween.interpolate_property(control, "rect_position:x", steps[i], steps[i + 1], 0.05, Tween.TRANS_SINE, Tween.EASE_IN_OUT, i * 0.05)

    tween.connect("tween_all_completed", tween, "queue_free")
    tween.start()

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
