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
        check("narrow", ui.get_node(panel).rect_size.x == ui.DEMO_WIDTH)
    check("the moves say it is the demo", ui.get_node("Moves").visible and ui.get_node("Moves/DemoText").text == "Modo Demo" and !ui.get_node("Moves/MovesText").visible)
    var demo = ui.get_node("Moves/DemoText")
    check("and it fits", demo.get_minimum_size().x < demo.rect_size.x and demo.get_global_rect().end.y <= ui.get_node("Moves").get_global_rect().end.y)
    check("the logo and the link to play", ui.get_node("CodePanel").visible and ui.get_node("CodePanel/ShareText/Link").text == "play.cirya.me")
    check("with no room code", !ui.get_node("CodePanel/CodeText").visible)
    check("the help of the demo", ui.get_node("HelpPanel").visible and ui.get_node("HelpPanel/AdviceLavel").text == ui.DEMO_HELP)
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
