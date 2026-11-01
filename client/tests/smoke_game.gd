extends SceneTree

# Loads the game scene in the sandbox and plays a few turns through Game.gd,
# without the mouse. It catches errors in the scene code that the rules tests
# cannot see. From the client folder:
#
#   godot --no-window --path . -s tests/smoke_game.gd

const Notation = preload("res://core/Notation.gd")

var game
var match_state
var failures = 0

func _initialize():
    match_state = get_root().get_node("Match")
    match_state.start_sandbox()
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

    # Turn 1: white places a black cirya on c3
    take(fleet_piece(2, "C"))
    drop("c3")
    check("turn 1 is c3", match_state.move_notation() == "c3")
    game._on_turn_confirmation(true)

    # Turn 2: black places a white cirya on d3
    take(fleet_piece(1, "C"))
    drop("d3")
    game._on_turn_confirmation(true)

    # Turn 3: white places a tampa on a1, changes its mind and undoes it
    var tampa = fleet_piece(1, "C")
    take(tampa)
    game._rotate()
    drop("a1")
    check("a tampa", match_state.move_notation() == "Ta1")
    game._on_turn_confirmation(false)
    check("undone", match_state.board.stack(Notation.parse_square("a1")).empty())

    # White moves d3 onto c3, but a drop two squares away flies back
    var cirya = instance_from_id(match_state.board.stack(Notation.parse_square("d3"))[0])
    take(cirya)
    drop("a3")
    check("the rejected drop changes nothing", match_state.move_notation() == "")
    take(cirya)
    drop("c3")
    check("turn 3 is d3<", match_state.move_notation() == "d3<")
    game._on_turn_confirmation(true)
    check("turn 4 for black", match_state.turn == 4 and match_state.player == 2)
    check("the moves are written down", game.get_node("UI/Moves/MovesText").text.find("3. d3<") != -1)

    print("smoke: %d failures" % failures)
    quit(1 if failures else 0)

func fleet_piece(player, kind):
    for piece in game._pieces():
        if piece.player == player and piece.get_notation_name() == kind and match_state.board.square_of(piece.get_instance_id()) == null:
            return piece

func take(piece):
    check("can take a piece", piece != null and match_state.can_take(piece.get_instance_id()))
    game.take(piece)

# Drops the hand on the square if it is legal, as a mouse release does
func drop(square):
    var tile = game.get_node("Board").tile(Notation.parse_square(square))

    if match_state.can_drop(game._hand_ids(), Notation.parse_square(square)):
        game.drop(tile)
    else:
        game.cancel()
