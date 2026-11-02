extends SceneTree

# Loads the game scene and plays through Game.gd without the mouse: a few
# turns in the sandbox, then turns of an opponent and a refused turn as the
# server would send them. It catches errors in the scene code that the rules
# tests cannot see. From the client folder:
#
#   godot --no-window --path . -s tests/smoke_game.gd

const Notation = preload("res://core/Notation.gd")
const Status = preload("res://core/Status.gd")

var game
var state
var failures = 0

func _initialize():
    state = get_root().get_node("Match")
    state.start_sandbox()
    change_scene("res://Game.tscn")
    call_deferred("_play")

func check(label, condition):
    if !condition:
        failures += 1
        print("FAIL ", label)

func _play():
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    game = current_scene
    _board()

    yield(_sandbox(), "completed")
    _online()
    _out_of_step()
    yield(_clocks(), "completed")
    yield(_long_game(), "completed")
    yield(_reopen(), "completed")
    yield(_leave_from_the_corner(), "completed")
    yield(_back_to_menu(), "completed")

    print("smoke: %d failures" % failures)
    quit(1 if failures else 0)

# The tiles light up where the pieces would fall, so they have to be at the
# height Tile.tscn gives them, just over the board, and not hidden under it
func _board():
    var height = load("res://Tile.tscn").instance().translation.y
    var tile = game.get_node("Board").tile(Vector2(2, 3))

    check("the tiles keep the height of Tile.tscn", is_equal_approx(tile.translation.y, height))
    check("and the highlight is over the board", tile.global_transform.origin.y > game.get_node("Board").global_transform.origin.y)

func _sandbox():
    check("the opening hint", help_text().begins_with("Toma una cirya de tu oponente"))
    var help = game.get_node("UI/HelpPanel").get_global_rect()
    var undo = game.get_node("UI/TurnPanel/Undo").get_global_rect()
    check("the help is over the turn buttons", help.end.y <= undo.position.y and !help.intersects(undo))
    check("and centred", abs(help.get_center().x - game.get_node("UI/TurnPanel").get_global_rect().get_center().x) < 1)
    check("nothing to confirm yet", confirm_button().disabled)

    # Turn 1: white places a black cirya on c3, and c3 lights up under the hand
    take(fleet_piece(2))
    hover("c3")
    check("the tile under the hand lights up", tile("c3").visible)
    release("c3")
    check("and goes off after the drop", !tile("c3").visible)
    check("now it can be confirmed", !confirm_button().disabled)
    check("turn 1 is c3", state.move_notation() == "c3")
    game._on_turn_confirmation(true)

    # Turn 2: black places a white cirya on d3, and Enter confirms it
    take(fleet_piece(1))
    release("d3")
    _key(KEY_ENTER, false)
    check("Enter confirms the turn", state.turn == 3)

    # Turn 3: white places a tampa on a1, changes its mind and undoes it
    var tampa = fleet_piece(1)
    take(tampa)
    game._rotate()
    release("a1")
    check("a tampa", state.move_notation() == "Ta1")
    game._on_turn_confirmation(false)
    check("undone", stack("a1").empty())
    check("the piece is flat again in the fleet", !tampa.block)

    # White moves d3 onto c3, after a drop two squares away flies back
    var cirya = instance_from_id(stack("d3")[0])
    take(cirya)
    release("a3")
    check("the rejected drop changes nothing", state.move_notation() == "")
    check("nothing can be taken while it flies back", game.drag == game.Drag.RETURNING)
    yield(create_timer(game.RETURN_TIME + 0.2), "timeout")

    take(cirya)
    release("c3")
    check("turn 3 is d3<", state.move_notation() == "d3<")
    game._on_turn_confirmation(true)
    check("turn 4 for black", state.turn == 4 and state.player == 2)
    check("the moves are written down", game.get_node("UI/Moves/MovesText").text.find("3. d3<") != -1)

# White online, against turns of black sent as the server sends them
func _online():
    state.sandbox = false
    state.player = 1
    state._next(4, 2)

    notify("Turn", {"player": 2.0, "turn": 4.0, "move": "Tb4", "nextPlayer": 1.0, "nextTurn": 5.0})
    var tampa = instance_from_id(stack("b4")[0])
    check("black places a tampa", stack("b4").size() == 1 and tampa.player == 2 and tampa.block)

    # The server refuses the turn of white: the piece goes back
    var cirya = fleet_piece(1)
    var tray = cirya.global_transform
    take(cirya)
    release("e1")
    state._set_phase(state.Phase.SUBMITTED)
    check("waiting for the server", help_text() == "Esperando al servidor…")
    notify("InvalidTurn", {"error": "refused"})
    check("the refusal is shown", help_text() == "Movimiento no válido: refused")
    check("the board is back", stack("e1").empty())
    check("the piece is back in the fleet", cirya.global_transform.origin.distance_to(tray.origin) < 0.01)
    check("white can move again", state.phase == state.Phase.MY_TURN)

    # Black brings the hallacirya over its tampa, which lies down
    notify("Turn", {"player": 2.0, "turn": 6.0, "move": "Hc4", "nextPlayer": 1.0, "nextTurn": 7.0})
    notify("Turn", {"player": 2.0, "turn": 8.0, "move": "c4<", "nextPlayer": 1.0, "nextTurn": 9.0})
    check("the hallacirya is on b4", stack("b4").size() == 2 and instance_from_id(stack("b4")[1]).get_notation_name() == "H")
    check("the tampa is flat", !tampa.block)

    # The last move comes in the status of GameFinished
    state._next(10, 2)
    state._on_notification({"type": "GameFinished", "params": {"result": "WIN_2", "winCondition": "FLAT", "turn": 10.0}, "status": {"moves": ["e5"]}})
    check("the winning move is shown", stack("e5").size() == 1)
    check("and written down", game.get_node("UI/Moves/MovesText").text.find("10. e5") != -1)
    var dialog = game_over_dialog()
    check("the result is shown", dialog != null and dialog.visible and dialog.dialog_text.begins_with("Ganan las negras por recuento de ciryar\nHas perdido"))
    var screen = game.get_viewport().get_visible_rect()
    check("in the middle of the screen", dialog.get_global_rect().get_center().distance_to(screen.get_center()) < 2)
    check("with room for its text", dialog.rect_size.x >= dialog.get_label().get_combined_minimum_size().x)

# The client missed where a piece went: the status of the next turn says it
func _out_of_step():
    state._next(11, 2)
    var status = _status_of_board()
    status.board["2"] = status.board.get("2", {})
    status.board["2"]["d"] = ["C2"]
    status.turn = 12.0
    status.currentPlayer = 1.0

    # Black played d1 for this client, but the server has the cirya on d2
    state._on_notification({"type": "Turn", "params": {"player": 2.0, "turn": 11.0, "move": "d1", "nextPlayer": 1.0, "nextTurn": 12.0}, "status": status})
    check("d1 is empty, as the server says", stack("d1").empty())
    check("the cirya is on d2", stack("d2").size() == 1 and instance_from_id(stack("d2")[0]).player == 2)
    check("counted as out of step", game.rebuilds == 1)
    check("and it is there on the table", _over(instance_from_id(stack("d2")[0]), "d2"))

# The clocks of the server count down beside the players, and a clock that
# runs out ends the game without playing any move
func _clocks():
    var ui = game.get_node("UI")
    var white = ui.get_node("WhiteTurn/Clock")
    var black = ui.get_node("BlackTurn/Clock")
    check("no clocks in a game without clock", !white.visible and !black.visible)

    check("whole seconds", ui.clock_text(600000) == "10:00" and ui.clock_text(59999) == "0:59" and ui.clock_text(10000) == "0:10")
    check("tenths at the end", ui.clock_text(9999) == "9.9" and ui.clock_text(0) == "0.0")

    var status = _status_of_board()
    status["clocks"] = {"1": 254300.0, "2": 9400.0}
    status["clockRunning"] = 1.0
    state._on_notification({"type": "StatusResponse", "status": status})
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    check("the clocks show", white.visible and black.visible)
    check("white runs", white.get_node("Time").text == "4:14" and white.get_node("Time").get("custom_colors/font_color") == ui.CLOCK_RUNNING)
    check("in a lit frame", white.get("custom_styles/panel") == ui.active_style and black.get("custom_styles/panel") == ui.inactive_style)
    check("black is short of time", black.get_node("Time").text == "9.4" and black.get_node("Time").get("custom_colors/font_color") == ui.CLOCK_SHORT)
    check("beside the players, not over them", white.get_global_rect().position.x >= ui.get_node("WhiteTurn/CurrentTurn").get_global_rect().end.x)

    yield(create_timer(1.1), "timeout")
    check("the clock of white counts down", white.get_node("Time").text == "4:13")
    check("the other one waits", black.get_node("Time").text == "9.4")

    # White lost on time: the last move of the status is not played again
    var moves = ui.get_node("Moves/MovesText").get_line_count()
    var rebuilds = game.rebuilds
    status = _status_of_board()
    status["moves"] = ["e5"]
    status["clocks"] = {"1": 0.0, "2": 9400.0}
    status["clockRunning"] = 0.0
    state._on_notification({"type": "GameFinished", "params": {"result": "WIN_2", "winCondition": "TIME", "turn": 13.0}, "status": status})
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    check("no move is played", ui.get_node("Moves/MovesText").get_line_count() == moves and game.rebuilds == rebuilds)
    check("white is at 0", white.get_node("Time").text == "0.0" and white.get_node("Time").get("custom_colors/font_color") == ui.CLOCK_SHORT)
    var dialog = ui.get_children().back()
    check("lost on time", dialog is AcceptDialog and dialog.dialog_text.begins_with("Ganan las negras por tiempo\nHas perdido"))

    if dialog is AcceptDialog:
        dialog.free()

# A long list of moves stays in its frame and shows the last one, and a
# spectator is not told it won or lost
func _long_game():
    var ui = game.get_node("UI")
    var scroll = ui.get_node("Moves/MovesText")
    var moves = []

    for i in range(60):
        moves.append("a1")

    ui._on_history(moves)
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    var bar = _scrollbar(scroll)
    check("the moves scroll", bar.visible and bar.max_value > bar.page)
    check("down to the last one", bar.value + bar.page >= bar.max_value - 1)
    check("inside the frame", scroll.get_global_rect().end.y <= ui.get_node("Moves").get_global_rect().end.y)

    # The wheel goes back up to the first moves, and it stays there
    var bottom = bar.value
    for i in range(5):
        _wheel(scroll, BUTTON_WHEEL_UP)
        yield(self, "idle_frame")
    yield(self, "idle_frame")
    check("the wheel scrolls up", bar.value < bottom)
    var up = bar.value
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    check("and the list stays there", bar.value == up)

    # Until a new move comes
    ui._on_turn_played(61, "b1")
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    check("a new move shows at the bottom", bar.value + bar.page >= bar.max_value - 1)
    check("one move a line, with nothing before", scroll.text.begins_with("1. a1\n2. a1") and scroll.get_line_count() == 61)

    # The moves can be selected and copied, to take the game somewhere else

    _click(scroll)
    check("a click gives the moves the keys", scroll.has_focus())
    _key(KEY_A, true)
    check("Ctrl+A selects them all", scroll.get_selection_text() == scroll.text)
    OS.clipboard = ""
    _key(KEY_C, true)
    check("Ctrl+C copies them", OS.clipboard == scroll.text)
    scroll.deselect()
    _key(KEY_ESCAPE, false)
    check("Escape still asks to leave", ui.has_node("Leave"))
    if ui.has_node("Leave"):
        ui.get_node("Leave").free()
    check("they cannot be changed", scroll.readonly)

    var player = state.player
    state.player = 0
    ui._on_game_over("WIN_2", "LONDI")
    var dialog = ui.get_children().back()
    check("a spectator just enjoyed the game", dialog.dialog_text == "Ganan las negras por Londë\n¡Esperamos que hayas disfrutado de la partida!")
    dialog.free()
    state.player = player

# Turns the mouse wheel over the control
func _scrollbar(text):
    for child in text.get_children():
        if child is VScrollBar:
            return child

func _click(control):
    for pressed in [true, false]:
        var event = InputEventMouseButton.new()
        event.button_index = BUTTON_LEFT
        event.pressed = pressed
        event.button_mask = BUTTON_MASK_LEFT if pressed else 0
        event.position = control.get_global_rect().get_center()
        event.global_position = event.position
        Input.parse_input_event(event)
        Input.flush_buffered_events()

func _key(scancode, control):
    for pressed in [true, false]:
        var event = InputEventKey.new()
        event.scancode = scancode
        event.control = control
        event.pressed = pressed
        Input.parse_input_event(event)
        Input.flush_buffered_events()

func _wheel(control, button):
    for pressed in [true, false]:
        var event = InputEventMouseButton.new()
        event.button_index = button
        event.pressed = pressed
        event.button_mask = (1 << (button - 1)) if pressed else 0
        event.position = control.get_global_rect().get_center()
        event.global_position = event.position
        Input.parse_input_event(event)
        Input.flush_buffered_events()

# A game scene opened in a game already started takes the board of the status
func _reopen():
    var status = _status_of_board()
    state.status = status
    change_scene("res://Game.tscn")
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    game = current_scene

    check("the board is back", Status.matches(status.board, state.board))
    check("b4 has its two pieces", stack("b4").size() == 2)
    check("on the table", _over(instance_from_id(stack("b4")[1]), "b4"))
    check("the tampa of b4 lies under the hallacirya", !instance_from_id(stack("b4")[0]).block)
    check("catching up is not out of step", game.rebuilds == 0)

# The board of the client as a status of the server
func _status_of_board():
    var data = {}

    for row in range(state.board.size()):
        for column in range(state.board.size()):
            var square = Vector2(row, column)
            var name = Notation.square_name(square)

            for piece_id in state.board.stack(square):
                var piece = instance_from_id(piece_id)
                if !data.has(name.substr(1)):
                    data[name.substr(1)] = {}
                if !data[name.substr(1)].has(name.substr(0, 1)):
                    data[name.substr(1)][name.substr(0, 1)] = []
                data[name.substr(1)][name.substr(0, 1)].append(piece.get_notation_name() + str(piece.player))

    return {"state": "TURN_1", "turn": 13.0, "currentPlayer": 1.0, "moves": [], "board": data}

# Whether the piece stands over the tile of the square
func _over(piece, square):
    var a = piece.global_transform.origin
    var b = tile(square).global_transform.origin
    return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) < 0.01

# The button of the game over dialog goes back to the menu, out of the room
# The corner at the bottom left asks before leaving, and staying changes nothing
func _leave_from_the_corner():
    var ui = game.get_node("UI")
    var exit = ui.get_node("Exit")
    var screen = game.get_viewport().get_visible_rect()
    check("the exit is in the bottom left corner", exit.get_global_rect().position.x == 0 and is_equal_approx(exit.get_global_rect().end.y, screen.end.y))

    exit.emit_signal("pressed")
    var dialog = ui.get_node_or_null("Leave")
    check("it asks first", dialog != null and dialog.visible and dialog.dialog_text.begins_with("¿Volver al menú de inicio?"))
    exit.emit_signal("pressed")
    check("only once", ui.get_children().count(dialog) == 1 and _count_dialogs(ui, "Leave") == 1)

    dialog.get_cancel().emit_signal("pressed")
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    check("staying closes it", !ui.has_node("Leave"))
    check("and the game goes on", current_scene == game)

func _count_dialogs(ui, prefix):
    var count = 0

    for child in ui.get_children():
        if child.name.begins_with(prefix):
            count += 1

    return count

func _back_to_menu():
    state._on_notification({"type": "GameFinished", "params": {"result": "WIN_1", "winCondition": "LONDI", "turn": 13.0}})
    game_over_dialog().emit_signal("confirmed")
    yield(self, "idle_frame")
    yield(self, "idle_frame")

    check("in the menu", current_scene.name == "Menu")
    check("without a seat", state.player == 0 and state.phase == state.Phase.WAITING)

func help_text():
    var panel = game.get_node("UI/HelpPanel")
    return panel.get_node("AdviceLavel").text if panel.visible else ""

func confirm_button():
    return game.get_node("UI/TurnPanel/Confirm")

func game_over_dialog():
    for child in game.get_node("UI").get_children():
        if child is AcceptDialog:
            return child

func notify(type, params):
    state._on_notification({"type": type, "params": params})

func stack(square):
    return state.board.stack(Notation.parse_square(square))

func fleet_piece(player):
    for piece in game._pieces():
        if piece.player == player and piece.get_notation_name() == "C" and state.board.square_of(piece.get_instance_id()) == null:
            return piece

func take(piece):
    check("can take a piece", piece != null and state.can_take(piece.get_instance_id()))
    game.take(piece)

func tile(square):
    return game.get_node("Board").tile(Notation.parse_square(square))

# Puts the hand over the square, as the mouse does
func hover(square):
    game.hand.global_transform.origin = tile(square).global_transform.origin + Vector3(0, game.HAND_MIN_HEIGHT, 0)
    game._follow_mouse()

func release(square):
    game.release(tile(square))
