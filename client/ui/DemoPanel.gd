extends Node

# The panels of UI in the demo. The demo is not a game, but it is shown to
# others, as on a stream: the panels of the players stay, narrow, with no
# names and no turn; the moves say it is the demo, and the logo and the link
# to play stay, with no code. Under the moves there is the door to replay a
# list, which grows the moves back to follow it. UI adds it in the demo

# A list of turns to replay, from the start or on the board as it is, with
# the player of its first turn; and the end of the replay
signal replay_requested(turns, clean, first_player)
signal replay_stopped

# Seconds the help of the demo stays, so it does not get in the way after
const DEMO_HELP_TIME = 10.0
# Width of the panels on the left, with no names of players
const DEMO_WIDTH = 230
# Room in the moves for one line under the title, and in the panel of the
# logo for the link to play
const DEMO_MOVES_HEIGHT = 110
const DEMO_CODE_HEIGHT = 150
const INSERT_TEXT = "Insertar movimientos"
const STOP_TEXT = "Terminar la reproducción"
const REPLAY_KEYS = "→ avanza, ← retrocede"
const DEMO_HELP = "Demo: mueve cualquier pieza a cualquier sat. Fuera del tablero vuelve a su bandeja. Con R se levanta una tampa"

const Notation = preload("res://core/Notation.gd")

onready var Match = get_node("/root/Match")
onready var ui = get_parent()

# The size of the moves before they are made short, to grow them back for
# a replay, and whether one is on the board
var moves_bottom = 0
var moves_right = 0
var replaying = false

func _ready():
    _dress()
    ui.help(DEMO_HELP)
    get_tree().create_timer(DEMO_HELP_TIME).connect("timeout", self, "_end_help")

# Unless a replay says something else by then
func _end_help():
    if ui.get_node("HelpPanel/AdviceLavel").text == DEMO_HELP:
        ui.help("")

func _dress():
    for panel in [ui.get_node("WhiteTurn"), ui.get_node("BlackTurn")]:
        panel.margin_right = panel.margin_left + DEMO_WIDTH
        panel.set("custom_styles/panel", ui.inactive_style)
        panel.get_node("User").hide()
        panel.get_node("CurrentTurn").hide()
        var label = panel.get_node("Label")
        var width = label.margin_right - label.margin_left
        label.margin_left = panel.get_node("User").margin_left
        label.margin_right = label.margin_left + width

    var moves = ui.get_node("Moves")
    var title = moves.get_node("Title")
    var text = moves.get_node("MovesText")
    moves_bottom = moves.margin_bottom
    moves_right = moves.margin_right
    _make_moves_short()
    text.hide()

    var demo = Label.new()
    demo.name = "DemoText"
    demo.text = "Modo Demo"
    demo.align = Label.ALIGN_CENTER
    demo.valign = Label.VALIGN_CENTER
    demo.set("custom_fonts/font", text.get("custom_fonts/font"))
    demo.set("custom_colors/font_color", text.get("custom_colors/font_color_readonly"))
    moves.add_child(demo)
    demo.set_anchors_and_margins_preset(Control.PRESET_WIDE)
    demo.margin_top = title.margin_bottom
    demo.margin_bottom = -DEMO_MOVES_HEIGHT / 2

    var insert = Button.new()
    insert.name = "Insert"
    insert.text = INSERT_TEXT
    insert.flat = true
    insert.focus_mode = Control.FOCUS_NONE
    insert.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    insert.set("custom_fonts/font", ui.get_node("MoveEntry/Handle/Label").get("custom_fonts/font"))
    insert.set("custom_colors/font_color", ui.VIEW_CHOSEN)
    insert.set("custom_colors/font_color_hover", Color(1, 1, 1))
    moves.add_child(insert)
    insert.set_anchors_and_margins_preset(Control.PRESET_BOTTOM_WIDE)
    insert.margin_top = -DEMO_MOVES_HEIGHT / 2
    insert.margin_bottom = -8
    insert.connect("pressed", self, "_on_insert_pressed")

    var code = ui.get_node("CodePanel")
    code.get_node("CodeText").hide()
    code.get_node("ShareText/Label").text = "Juega en"
    code.margin_bottom = code.margin_top + DEMO_CODE_HEIGHT

func _make_moves_short():
    var moves = ui.get_node("Moves")
    var title = moves.get_node("Title")
    moves.margin_bottom = moves.margin_top + title.margin_bottom + DEMO_MOVES_HEIGHT
    moves.margin_right = moves.margin_left + DEMO_WIDTH
    title.margin_right = DEMO_WIDTH - title.margin_left

# Replaying a list: it is pasted and checked, then the board is cleaned or
# kept as it is, and when it is kept and the list starts with a placement,
# which says nothing of its colour, the player of the first turn is asked
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
    error.set("custom_colors/font_color", ui.CLOCK_SHORT)
    column.add_child(about)
    column.add_child(list)
    column.add_child(error)
    dialog.add_child(column)

    dialog.connect("confirmed", self, "_on_list_confirmed", [dialog])
    _popup(dialog)
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
    _popup(dialog)

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
    _popup(who)

func _on_black_starts(_action, turns, dialog):
    dialog.hide()
    emit_signal("replay_requested", turns, false, 2)

func _on_board(square):
    return square.x >= 0 and square.y >= 0 and square.x < Match.board.size() and square.y < Match.board.size()

# The dialogs go on UI, over everything, and go away once closed
func _popup(dialog):
    dialog.connect("popup_hide", dialog, "queue_free")
    ui.add_child(dialog)
    dialog.popup_centered()

# The list grows the moves back, with the last turn played marked and the
# one that cannot be played, if any, at its end
func show_replay(index, replay):
    replaying = true
    var moves = ui.get_node("Moves")
    var text = moves.get_node("MovesText")
    moves.margin_bottom = moves_bottom
    moves.margin_right = moves_right
    moves.get_node("Title").margin_right = moves_right - moves.margin_left - moves.get_node("Title").margin_left
    moves.get_node("DemoText").hide()
    moves.get_node("Insert").text = STOP_TEXT
    text.show()
    text.focus_mode = Control.FOCUS_NONE
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
        ui.help("La jugada %d, %s, no cabe: %s" % [replay.wrong + 1, replay.turns[replay.wrong], replay.error])
    else:
        ui.help("%s · %s" % [where, REPLAY_KEYS])

func _end_replay():
    replaying = false
    var moves = ui.get_node("Moves")
    _make_moves_short()
    moves.get_node("MovesText").hide()
    moves.get_node("DemoText").show()
    moves.get_node("Insert").text = INSERT_TEXT
    ui.help("")
