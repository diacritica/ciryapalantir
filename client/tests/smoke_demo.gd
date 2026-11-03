extends SceneTree

# Loads the game scene in the demo and moves pieces through Game.gd without
# the mouse: any piece goes to any square, tampar stand up at any time, and
# what is dropped off the board goes back to its fleet. From the client folder:
#
#   godot --no-window --path . -s tests/smoke_demo.gd

const Notation = preload("res://core/Notation.gd")

var game
var state
var failures = 0

func _initialize():
    state = get_root().get_node("Match")
    state.start_demo()
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

    _not_a_game()
    yield(_anything_anywhere(), "completed")
    yield(_back_to_the_fleet(), "completed")
    yield(_replay(), "completed")
    yield(_replay_on_the_board(), "completed")
    yield(_from_the_menu(), "completed")

    print("smoke demo: %d failures" % failures)
    quit(1 if failures else 0)

# No turns, no buttons and no room code, but it is dressed to be shown: the
# players with no names, the moves saying it is the demo, the logo and the
# link to play, and the help for a while
func _not_a_game():
    var ui = game.get_node("UI")

    check("no turn buttons", !ui.get_node("TurnPanel").visible)
    for panel in ["WhiteTurn", "BlackTurn"]:
        check("the %s panel stays" % panel, ui.get_node(panel).visible)
        check("with no name", !ui.get_node(panel + "/User").visible)
        check("and no turn", !ui.get_node(panel + "/CurrentTurn").visible)
        check("narrow", ui.get_node(panel).rect_size.x == ui.get_node("Demo").DEMO_WIDTH)
    check("the moves say it is the demo", ui.get_node("Moves").visible and ui.get_node("Moves/DemoText").text == "Modo Demo" and !ui.get_node("Moves/MovesText").visible)
    var demo = ui.get_node("Moves/DemoText")
    check("and it fits", demo.get_minimum_size().x < demo.rect_size.x and demo.get_global_rect().end.y <= ui.get_node("Moves").get_global_rect().end.y)
    check("the logo and the link to play", ui.get_node("CodePanel").visible and ui.get_node("CodePanel/ShareText/Link").text == "play.cirya.me")
    check("with no room code", !ui.get_node("CodePanel/CodeText").visible)
    check("the help of the demo", ui.get_node("HelpPanel").visible and ui.get_node("HelpPanel/AdviceLavel").text == ui.get_node("Demo").DEMO_HELP)
    check("not the sandbox", !game.get_node("sandboxlogo").visible)
    check("seen from the side of white", game.get_node("CameraPlayer1").current)

func _anything_anywhere():
    # A tampa at once, though in a game the first turns cannot have one
    var tampa = fleet_piece(1, "C")
    take(tampa)
    game._rotate()
    check("a tampa stands up from the start", tampa.get_notation_name() == "T")
    release("c3")
    check("dropped on c3", stack("c3") == [tampa.get_instance_id()])

    # A cirya of black on it, with no turn of black, lays it down
    var cirya = fleet_piece(2, "C")
    take(cirya)
    release("c3")
    check("the cirya is on the tampa", stack("c3") == [tampa.get_instance_id(), cirya.get_instance_id()])
    check("and the tampa lies down", tampa.get_notation_name() == "C")

    # The whole stack goes anywhere, not only in a line
    take(tampa)
    check("the stack is in the hand", game.hand.get_child_count() == 2)
    release("a1")
    check("the stack is on a1", stack("a1") == [tampa.get_instance_id(), cirya.get_instance_id()] and stack("c3").empty())

    # A piece on the board stands up too
    take(cirya)
    game._rotate()
    check("a cirya from the board stands up", cirya.get_notation_name() == "T")
    release("e5")
    check("and goes to e5", stack("e5") == [cirya.get_instance_id()])

    # Nothing goes on a hallacirya: it flies back to where it was taken
    var hallacirya = fleet_piece(1, "H")
    take(hallacirya)
    release("b4")
    take(cirya)
    check("the hallacirya does not light up", !state.can_drop([cirya.get_instance_id()], Notation.parse_square("b4")))
    release("b4")
    check("a cirya does not go on the hallacirya", stack("b4") == [hallacirya.get_instance_id()] and stack("e5") == [cirya.get_instance_id()])
    check("it flies back", game.drag == game.Drag.RETURNING)
    yield(create_timer(game.RETURN_TIME + 0.2), "timeout")
    var there = cirya.global_transform.origin
    var e5 = tile("e5").global_transform.origin
    check("to e5", Vector2(there.x, there.z).distance_to(Vector2(e5.x, e5.z)) < 0.05)
    take(instance_from_id(stack("a1")[0]))
    release("b4")
    check("nor the piece of a1", stack("b4") == [hallacirya.get_instance_id()] and stack("a1").size() == 1)
    yield(create_timer(game.RETURN_TIME + 0.2), "timeout")
    take(hallacirya)
    release("b4")
    check("but the hallacirya goes back on its own square", stack("b4") == [hallacirya.get_instance_id()])

    check("there is nothing to confirm", !state.confirm() and state.turn == 1)

# Off the board, a piece goes back to where it sat in its fleet, flat
func _back_to_the_fleet():
    var tampa = instance_from_id(stack("e5")[0])
    take(tampa)
    game.release(null)
    check("it leaves the board", stack("e5").empty() and state.board.square_of(tampa.get_instance_id()) == null)
    check("and lies down", tampa.get_notation_name() == "C")
    yield(create_timer(game.RETURN_TIME + 0.2), "timeout")
    var home = game.home[tampa.get_instance_id()].origin
    var there = tampa.global_transform.origin
    check("it flies to its place in the fleet", Vector2(there.x, there.z).distance_to(Vector2(home.x, home.z)) < 0.05)
    check("and the hand is free again", game.drag == game.Drag.IDLE)

# A game pasted in the moves, played from the start: the arrows go through
# it until the turn that cannot be played, and back
func _replay():
    var ui = game.get_node("UI")
    var insert = ui.get_node("Moves/Insert")
    check("the door to insert moves", insert.visible and insert.text == ui.get_node("Demo").INSERT_TEXT)
    insert.emit_signal("pressed")
    yield(self, "idle_frame")
    var dialog = ui.get_node("InsertMoves")
    var list = dialog.find_node("List", true, false)

    list.text = "1. c3\n2. zz"
    dialog.get_ok().emit_signal("pressed")
    check("a list not understood is said", dialog.visible and dialog.find_node("Error", true, false).text == "No entiendo «zz»")

    # White places a cirya of black on c3 and black one of white on a1; white
    # places on b2, black moves its cirya to c2, and white cannot move c3
    list.text = "1. c3\n2. a1\n3. b2\n4. c3-\n5. c3+"
    dialog.get_ok().emit_signal("pressed")
    yield(self, "idle_frame")
    var how = ui.get_node("HowToPlay")
    check("then it asks how", how.visible)
    how.get_ok().emit_signal("pressed")
    yield(self, "idle_frame")

    var replay = game.get_node("Replay")
    check("the board is cleaned", _all_off())
    check("four turns can be played", replay.playable() == 4 and replay.wrong == 4)
    check("the list shows in the moves", ui.get_node("Moves/MovesText").visible and ui.get_node("Moves/MovesText").get_line_count() == 5)
    check("with the way to go through it", ui.get_node("HelpPanel/AdviceLavel").text.find(ui.get_node("Demo").REPLAY_KEYS) != -1)
    check("and the end of it", insert.text == ui.get_node("Demo").STOP_TEXT)

    for i in range(3):
        yield(_key(KEY_RIGHT), "completed")

    # Only the pieces of the turn move: the rest stay just where they were,
    # without falling, and so they do going back
    var still = _positions()
    yield(_key(KEY_RIGHT), "completed")
    var moved = _moved_since(still)
    check("only the cirya of the turn moves", moved.size() == 1 and moved[0] == stack("c2")[0])
    still = _positions()
    yield(_key(KEY_LEFT), "completed")
    check("going back, only it moves back", _moved_since(still) == moved)
    yield(_key(KEY_RIGHT), "completed")

    check("the four turns are on the board", replay.index == 4)
    check("a cirya of black went to c2", _owners("c2") == [2] and stack("c3").empty())
    check("the white ones on a1 and b2", _owners("a1") == [1] and _owners("b2") == [1])
    check("it stops at the turn that cannot be played", ui.get_node("HelpPanel/AdviceLavel").text.find("La jugada 5, c3+, no cabe") != -1)
    yield(_key(KEY_RIGHT), "completed")
    check("and goes no further", replay.index == 4)
    check("the pieces lie on their squares", _lies_on("c2"))

    yield(_key(KEY_LEFT), "completed")
    yield(_key(KEY_UP), "completed")
    check("back two turns", replay.index == 2 and stack("b2").empty() and _owners("c3") == [2])
    check("no piece is taken by hand meanwhile", game.drag == game.Drag.IDLE)

    insert.emit_signal("pressed")
    check("the replay ends", !game.has_node("Replay") and ui.get_node("Moves/DemoText").visible and insert.text == ui.get_node("Demo").INSERT_TEXT)
    check("and the board stays", _owners("c3") == [2] and _owners("a1") == [1])

# On the board as it is: a nossë says whose the first turn is, and a
# placement does not, so it is asked
func _replay_on_the_board():
    var ui = game.get_node("UI")
    yield(_insert("a1>"), "completed")
    _keep_the_board(ui)
    yield(self, "idle_frame")
    var replay = game.get_node("Replay")
    check("the nossë of a1 is of white", replay.first_player == 1 and replay.playable() == 1)
    yield(_key(KEY_RIGHT), "completed")
    check("it moves to b1", _owners("b1") == [1] and stack("a1").empty())
    ui.get_node("Moves/Insert").emit_signal("pressed")

    yield(_insert("d4\nd5"), "completed")
    _keep_the_board(ui)
    yield(self, "idle_frame")
    var who = ui.get_node("WhoStarts")
    check("a placement asks who plays first", who.visible)
    who.emit_signal("custom_action", "black")
    yield(self, "idle_frame")
    replay = game.get_node("Replay")
    check("black first, then white", replay.first_player == 2 and replay.player_of(1) == 1)
    yield(_key(KEY_RIGHT), "completed")
    yield(_key(KEY_RIGHT), "completed")
    check("not from the opening: their own ciryar", _owners("d4") == [2] and _owners("d5") == [1])
    ui.get_node("Moves/Insert").emit_signal("pressed")

func _insert(text):
    var ui = game.get_node("UI")
    ui.get_node("Moves/Insert").emit_signal("pressed")
    yield(self, "idle_frame")
    var dialog = ui.get_node("InsertMoves")
    dialog.find_node("List", true, false).text = text
    dialog.get_ok().emit_signal("pressed")
    yield(self, "idle_frame")

func _keep_the_board(ui):
    ui.get_node("HowToPlay").emit_signal("custom_action", "keep")

func _key(scancode):
    var event = InputEventKey.new()
    event.scancode = scancode
    event.pressed = true
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    yield(create_timer(0.9), "timeout")

func _positions():
    var res = {}

    for piece in game._pieces():
        res[piece.get_instance_id()] = piece.global_transform.origin

    return res

func _moved_since(positions):
    var res = []

    for piece in game._pieces():
        if piece.global_transform.origin.distance_to(positions[piece.get_instance_id()]) > 0.001:
            res.append(piece.get_instance_id())

    return res

func _all_off():
    for row in range(state.board.size()):
        for column in range(state.board.size()):
            if !state.board.stack(Vector2(row, column)).empty():
                return false

    return true

func _owners(square):
    var res = []

    for piece_id in stack(square):
        res.append(instance_from_id(piece_id).player)

    return res

# Laid out on the tile, not left in the air where the animation took it
func _lies_on(square):
    var piece = instance_from_id(stack(square)[0])
    var there = piece.global_transform.origin
    var tile_position = tile(square).global_transform.origin
    return Vector2(there.x, there.z).distance_to(Vector2(tile_position.x, tile_position.z)) < 0.1 and there.y < 1.0

# Leaving says the position is lost, and the menu opens the demo again
func _from_the_menu():
    var ui = game.get_node("UI")
    ui._ask_to_leave()
    check("the position of the demo is lost", ui.get_node("Leave").dialog_text.find("demo") != -1)
    ui._back_to_menu()
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    check("no demo in the menu", !state.demo)

    current_scene.get_node("Welcome/Panel/DemoButton").emit_signal("pressed")
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    check("the demo button opens the demo", state.demo and current_scene.has_node("Board"))

func take(piece):
    check("can take a piece", piece != null and state.can_take(piece.get_instance_id()))
    game.take(piece)

func release(square):
    game.release(tile(square))

func tile(square):
    return game.get_node("Board").tile(Notation.parse_square(square))

func stack(square):
    return state.board.stack(Notation.parse_square(square))

func fleet_piece(player, kind):
    for piece in game._pieces():
        if piece.player == player and piece.get_notation_name() == kind and state.board.square_of(piece.get_instance_id()) == null:
            return piece
