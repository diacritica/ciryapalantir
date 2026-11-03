extends SceneTree

# Plays turns in the sandbox by writing them in the field at the bottom, as
# with the keyboard: the field opens by its handle, Enter puts the move on
# the board and Enter on the empty field confirms it. Wrong moves are
# explained and leave the board as it was. From the client folder:
#
#   godot --no-window --path . -s tests/smoke_written.gd

const Notation = preload("res://core/Notation.gd")

var game
var ui
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
    ui = game.get_node("UI")

    yield(_the_field(), "completed")
    _openings()
    _placements()
    _nosse()
    yield(_onto_a_stack(), "completed")
    _wrong()
    _full_nosse()
    _five_tampar()
    _not_my_turn()

    print("smoke written: %d failures" % failures)
    quit(1 if failures else 0)

# Closed at the bottom edge, it opens by its handle above it and gets the keys
func _the_field():
    var entry = ui.get_node("MoveEntry")
    var field = entry.get_node("Field")
    check("the field shows on my turn", entry.visible)
    check("no coordinates on the board while it is closed", !coordinates_shown())
    check("closed: only the handle", entry.rect_size.y < field.rect_position.y)
    check("under the turn buttons", entry.get_global_rect().position.y >= ui.get_node("TurnPanel").get_global_rect().end.y)
    check("at the bottom edge", is_equal_approx(entry.get_global_rect().end.y, ui.get_viewport_rect().size.y))

    entry.get_node("Handle").emit_signal("pressed")
    yield(create_timer(ui.get_node("MoveEntry").ENTRY_TIME + 0.1), "timeout")
    check("open, the field shows whole", entry.rect_size.y >= field.rect_position.y + field.rect_size.y)
    check("and it has the keys", text().has_focus())
    check("the handle closes it now", entry.get_node("Handle/Label").text == "Cerrar")
    check("the board shows its coordinates", coordinates_shown())
    _coordinates_of_each_side()

    # Escape closes it instead of asking to leave
    _key(KEY_ESCAPE)
    yield(create_timer(ui.get_node("MoveEntry").ENTRY_TIME + 0.1), "timeout")
    check("Escape closes the field", !ui.get_node("MoveEntry").open and !text().has_focus())
    check("and hides the coordinates", !coordinates_shown())
    check("and does not ask to leave", !ui.has_node("Leave"))
    entry.get_node("Handle").emit_signal("pressed")
    yield(create_timer(ui.get_node("MoveEntry").ENTRY_TIME + 0.1), "timeout")

func _openings():
    write("ta1")
    check("no tampa in the opening", help_text() == "En la apertura no se puede poner una tampa" and stack("a1").empty())

    write("C3")
    check("the cirya of black is on c3", stack("c3").size() == 1 and instance_from_id(stack("c3")[0]).player == 2)
    check("the field is empty again", text().text == "")
    check("it says how to send it", help_text().begins_with("c3 en el tablero"))
    write("3a1>12")
    check("a wrong move leaves the one on the board", help_text() == "En a1 no hay 3 piezas" and stack("c3").size() == 1 and state.move_notation() == "c3")
    write("")
    check("Enter on the empty field confirms", state.turn == 2)

    write("d3")
    write("")
    check("turn 2 of black", state.turn == 3 and stack("d3").size() == 1)

func _placements():
    # A tampa, and then another move written instead
    write("Tb2")
    check("a tampa on b2", stack("b2").size() == 1 and instance_from_id(stack("b2")[0]).get_notation_name() == "T")
    write("hb2")
    check("written again, the tampa goes back", stack("b2").size() == 1 and instance_from_id(stack("b2")[0]).get_notation_name() == "H")
    check("and lies down in the fleet", _standing() == 0)
    game._on_turn_confirmation(false)
    write("d3<")
    check("d3 onto c3", stack("c3").size() == 2 and stack("d3").empty())
    ui.get_node("MoveEntry/Field/Send").emit_signal("pressed")
    check("the arrow with the empty field does nothing", state.turn == 3)
    game._on_turn_confirmation(true)

    write("b1")
    game._on_turn_confirmation(true)
    check("black placed b1", state.turn == 5 and stack("b1").size() == 1)

func _nosse():
    # c3 has the black cirya and the white one on top: two to the left, one by one
    write("3c3<12")
    check("not three of two", help_text() == "En c3 no hay 3 piezas" and stack("c3").size() == 2)
    write("2c3<1")
    check("the drops add up", help_text() == "Las piezas que se sueltan tienen que sumar 2")
    write("2c3<11")
    check("one on b3", stack("b3").size() == 1)
    check("and one on a3", stack("a3").size() == 1 and stack("c3").empty())
    check("as written", state.move_notation() == "2c3<11")
    game._on_turn_confirmation(true)

# A piece written onto a stack as high as its own square lands on top of it,
# as the board says, and not inside it
func _onto_a_stack():
    # The pieces of the last turn land first, as they would while playing
    yield(create_timer(1.0), "timeout")
    write("b3<")
    var white = stack("a3")[0]
    var black = stack("a3")[1]
    check("the black cirya on the white one", stack("a3").size() == 2 and state.move_notation() == "b3<")
    yield(create_timer(1.0), "timeout")
    var low = instance_from_id(white).global_transform.origin.y
    var high = instance_from_id(black).global_transform.origin.y
    check("is seen on top of it", high > low + 0.1)
    game._undo()

func _wrong():
    var before = state.board.copy()

    for typed in ["z9", "", "a1++"]:
        if typed != "":
            write(typed)
            check("%s is not understood" % typed, help_text() == "No entiendo «%s»" % typed)

    write("e6")
    check("no square e6", help_text() == "No hay ningún sat e6")
    write("a3+")
    check("black cannot move white", help_text() == "Esas piezas de a3 no se pueden mover ahora")
    write("a3-3")
    check("not off the board", help_text().begins_with("Las piezas") or help_text().begins_with("No se puede soltar"))
    check("the wrong text stays to fix it", text().text == "a3-3")
    check("the board is as it was", state.board.equals(before) and state.move_notation() == "")

# A nossë holds five pieces in 5x5: a turn that drops more on it is refused,
# and says why. Black plays now, with a cirya next to five on d5
func _full_nosse():
    var free = []

    for piece in game._pieces():
        if piece.get_notation_name() == "C" and state.board.square_of(piece.get_instance_id()) == null:
            free.append(piece)

    for i in range(5):
        game._place(free[i], Notation.parse_square("d5"))

    for piece in free:
        if piece.player == 2 and state.board.square_of(piece.get_instance_id()) == null:
            game._place(piece, Notation.parse_square("d4"))
            break

    game._remember_turn_start()
    write("d4+")
    check("not on a full nossë", help_text() == "En d5 ya no cabe más: un nossë tiene 5 piezas como mucho, y la hallacirya encima")
    check("which stays as it was", stack("d5").size() == 5 and stack("d4").size() == 1)

# Five tampar of black standing on the board, the most there can be: a sixth
# is refused, written or turned with R, and says why
func _five_tampar():
    var tampar = []

    for piece in game._pieces():
        if piece.player == 2 and piece.get_notation_name() == "C" and state.board.square_of(piece.get_instance_id()) == null and tampar.size() < 6:
            tampar.append(piece)

    for i in range(5):
        tampar[i].toggle_block()
        game._place(tampar[i], Notation.parse_square(["a5", "b5", "c5", "e5", "e4"][i]))

    game._remember_turn_start()
    write("Tb4")
    check("no sixth tampa written", help_text() == "Ya tienes 5 tampar en el tablero: no caben más" and stack("b4").empty())

    game.take(tampar[5])
    game._rotate()
    check("nor turned with R", tampar[5].get_notation_name() == "C" and help_text() == "Ya tienes 5 tampar en el tablero: no caben más")
    game.cancel()

func _not_my_turn():
    state.sandbox = false
    state.player = 2
    state._next(7, 1)
    check("no field when it is not my turn", !ui.get_node("MoveEntry").visible and !text().has_focus())
    check("nor coordinates", !coordinates_shown())
    state.player = 0
    state._next(7, 1)
    check("nor for a spectator", !ui.get_node("MoveEntry").visible)

# Out of the grid, the files go along the near edge and the ranks along the
# right one, each name by its own file or rank: player 1 has a near and 1 on
# its right, and player 2 has them the other way round
func _coordinates_of_each_side():
    for player in [1, 2]:
        var board = load("res://Board.tscn").instance()
        get_root().add_child(board)
        board.show_coordinates(true, player)
        var names = {}
        var viewport = board.get_node("Coordinates").get_child(0)

        for badge in viewport.get_children():
            names[badge.name] = badge.rect_position + badge.rect_size / 2

        var size = viewport.size
        var near = names.a.x < size.x / 4 if player == 1 else names.a.x > size.x * 3 / 4
        var right = names["1"].y > size.y * 3 / 4 if player == 1 else names["1"].y < size.y / 4
        check("player %d: the files along its near edge" % player, near and is_equal_approx(names.a.x, names.e.x))
        check("player %d: each file by its own column" % player, names.a.y < names.e.y)
        check("player %d: the ranks along its right edge" % player, right and is_equal_approx(names["1"].y, names["5"].y))
        check("player %d: each rank by its own row" % player, names["1"].x < names["5"].x)
        board.queue_free()

func coordinates_shown():
    var board = game.get_node("Board")
    return board.has_node("Coordinates") and board.get_node("Coordinates").visible

func write(typed):
    text().text = typed
    text().emit_signal("text_entered", typed)

func text():
    return ui.get_node("MoveEntry/Field/Text")

func help_text():
    return ui.get_node("HelpPanel/AdviceLavel").text

func stack(square):
    return state.board.stack(Notation.parse_square(square))

func _standing():
    var count = 0

    for piece in game._pieces():
        if piece.get_notation_name() == "T" and state.board.square_of(piece.get_instance_id()) == null:
            count += 1

    return count

func _key(scancode):
    for pressed in [true, false]:
        var event = InputEventKey.new()
        event.scancode = scancode
        event.pressed = pressed
        Input.parse_input_event(event)
        Input.flush_buffered_events()
