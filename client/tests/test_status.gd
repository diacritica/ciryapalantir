extends "res://tests/TestCase.gd"

# The board of the client rebuilt from a status of the server

const BoardState = preload("res://core/BoardState.gd")
const Notation = preload("res://core/Notation.gd")
const Status = preload("res://core/Status.gd")

var board
var pieces = []

func setup():
    board = BoardState.new(5)

func piece(name):
    var p = Piece.new(name)
    pieces.append(p)
    return p.get_instance_id()

func put(square, names):
    var ids = []

    for name in names:
        ids.append(piece(name))

    board.put(ids, Notation.parse_square(square))
    return ids

func fleet(names):
    for name in names:
        piece(name)

func test_stones_by_square():
    var data = {"3": {"c": ["C1", "T2"]}}

    check_equal("c3", ["C1", "T2"], Status.stones(data, Vector2(2, 2)))
    check_equal("an empty square", [], Status.stones(data, Vector2(0, 0)))

func test_the_same_board_changes_nothing():
    var c3 = put("c3", ["C1", "T2"])
    fleet(["C1", "C2"])
    var data = {"3": {"c": ["C1", "T2"]}}

    check("matches", Status.matches(data, board))
    var result = Status.board(data, board, pieces)
    check_equal("the same stack", c3, result.board.stack(Vector2(2, 2)))
    check_equal("nothing to turn over", [], result.turn_over)

func test_a_missing_placement_comes_from_the_fleet():
    put("c3", ["C2"])
    fleet(["H1", "C1"])
    var data = {"3": {"c": ["C2"]}, "1": {"a": ["C1"]}}

    check("does not match", !Status.matches(data, board))
    var a1 = Status.board(data, board, pieces).board.stack(Vector2(0, 0))
    check_equal("a cirya of player 1, not the hallacirya", "C", instance_from_id(a1[0]).get_notation_name())
    check_equal("of player 1", 1, instance_from_id(a1[0]).player)

func test_an_extra_piece_goes_back_to_the_fleet():
    var extra = put("b2", ["C1"])
    var data = {}

    var result = Status.board(data, board, pieces)
    check_equal("out of the board", null, result.board.square_of(extra[0]))

func test_a_moved_stack_keeps_its_order():
    # The client missed "2a1+": the two stones are still on a1
    var a1 = put("a1", ["C2", "C1"])
    var data = {"2": {"a": ["C2", "C1"]}}

    var result = Status.board(data, board, pieces)
    check_equal("a2 has them in order", a1, result.board.stack(Vector2(1, 0)))
    check_equal("a1 is empty", [], result.board.stack(Vector2(0, 0)))

func test_tampar_stand_and_ciryar_lie():
    var lying = put("b2", ["C1"])
    var standing = put("c3", ["T2"])
    var data = {"2": {"b": ["T1"]}}

    var result = Status.board(data, board, pieces)
    check("the cirya of b2 stands up", result.turn_over.has(lying[0]))
    check("the tampa going back to the fleet lies down", result.turn_over.has(standing[0]))

func test_a_flattened_tampa_is_a_cirya():
    var stack = put("b2", ["T2", "H1"])
    var data = {"2": {"b": ["C2", "H1"]}}

    var result = Status.board(data, board, pieces)
    check_equal("the same pieces", stack, result.board.stack(Vector2(1, 1)))
    check_equal("the tampa lies", [stack[0]], result.turn_over)

func test_not_enough_pieces():
    fleet(["C1"])
    var data = {"1": {"a": ["C1"], "b": ["C1"]}}

    check_equal("impossible", null, Status.board(data, board, pieces))

func test_fleets():
    put("a1", ["C1"])
    fleet(["C1", "H1", "C2"])

    check_equal("the same", [], Status.fleet_differences({"1": {"ciryar": 1, "hallaciryar": 1}, "2": {"ciryar": 1, "hallaciryar": 0}}, board, pieces))
    check_equal("one cirya more for player 2",
        ["player 2 has 1 ciryar, the server says 2"],
        Status.fleet_differences({"1": {"ciryar": 1, "hallaciryar": 1}, "2": {"ciryar": 2, "hallaciryar": 0}}, board, pieces))
