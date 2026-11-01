extends "res://tests/TestCase.gd"

# Taking and dropping pieces as Game.gd does, against the rules in core/

const BoardState = preload("res://core/BoardState.gd")
const Move = preload("res://core/Move.gd")
const Notation = preload("res://core/Notation.gd")
const Rules = preload("res://core/Rules.gd")

var board
var move = null
var player = 1
# After the opening, unless the test says otherwise
var opening = false
var pieces = []
var hand = []

func setup():
    board = BoardState.new(5)

# A piece out of the board, like the ones in the fleet: "C1", "T2", "H1"
func piece(name):
    var p = Piece.new(name)
    pieces.append(p)
    return p.get_instance_id()

# Puts pieces on a square, bottom first
func put(square, names):
    var ids = []

    for name in names:
        ids.append(piece(name))

    board.put(ids, Notation.parse_square(square))
    return ids

func stack(square):
    return board.stack(Notation.parse_square(square))

func take(piece_id):
    if !Rules.can_take(piece_id, board, move, player, opening):
        return false

    if !move or !move.started(board):
        move = Move.new(board, piece_id, pieces)

    hand = board.pieces_from(piece_id) if board.square_of(piece_id) != null else [piece_id]
    return true

func drop(square):
    var target = Notation.parse_square(square)

    if !Rules.can_drop(hand, target, board, move, player, opening):
        return false

    board.put(hand, target)
    move.sync_tampar(board)
    return true

func play(piece_id, square):
    return take(piece_id) and drop(square)

func notation():
    var state = Rules.move_state(move, board, player, opening)
    return Notation.write(state) if state else ""

func end_turn():
    move = null
    player = 3 - player

# Pablo, 2026-11-01: 3 of a nossë of 4 to b1, the top one on to c1, and that
# one could be taken back to a1
func test_cannot_return_a_drop_over_the_carry():
    var p = put("a1", ["C1", "C1", "C1", "C1"])

    check("3 to b1", play(p[1], "b1"))
    check("the top one to c1", play(p[3], "c1"))
    check_equal("notation", "3a1>21", notation())
    check("c1 back to a1 is rejected", !play(p[3], "a1"))
    check_equal("board unchanged", [1, 2, 1], [stack("a1").size(), stack("b1").size(), stack("c1").size()])

func test_a_lower_stone_cannot_go_over_a_higher_one():
    var p = put("a1", ["C1", "C1", "C1"])

    check("3 to b1", play(p[0], "b1"))
    check("the top one to c1", play(p[2], "c1"))
    check("the middle one cannot go over it", !play(p[1], "c1"))
    check_equal("notation", "3a1>21", notation())

func test_redistribute_the_drops():
    var p = put("a1", ["C1", "C1", "C1", "C1"])

    check("1 to b1", play(p[1], "b1"))
    check("2 to c1", play(p[2], "c1"))
    check_equal("first", "3a1>12", notation())
    check("the 2 of c1 back to b1", play(p[2], "b1"))
    check_equal("all on b1", "3a1>", notation())
    check("the top one to c1 again", play(p[3], "c1"))
    check_equal("then", "3a1>21", notation())
    check("dropping on the same square changes nothing", play(p[3], "c1"))
    check_equal("at last", "3a1>21", notation())

func test_back_to_the_origin_carries_less():
    var p = put("a1", ["C1", "C1", "C1"])

    check("3 to a2", play(p[0], "a2"))
    check("the top 2 cannot go back under the one left in a2", !play(p[1], "a1"))
    check("all back to a1", play(p[0], "a1"))
    check("2 to a2", play(p[1], "a2"))
    check_equal("notation", "2a1+", notation())

func test_all_back_to_the_origin_undoes_the_move():
    var p = put("a1", ["C1", "C1"])
    var other = put("e5", ["C1"])

    check("2 to b1", play(p[0], "b1"))
    check("another nossë cannot be taken", !Rules.can_take(other[0], board, move, player, opening))
    check("back to a1", play(p[0], "a1"))
    check_equal("nothing to confirm", "", notation())
    check("now the other nossë can move", play(other[0], "e4"))
    check_equal("notation", "e5-", notation())

func test_only_the_pieces_of_the_move():
    var p = put("a1", ["C1", "C1"])
    var elsewhere = put("c1", ["C1"])

    check("2 to b1", play(p[0], "b1"))
    check("a piece where the move did not go", !Rules.can_take(elsewhere[0], board, move, player, opening))
    check("a piece of the fleet", !Rules.can_take(piece("C1"), board, move, player, opening))

func test_one_direction():
    var p = put("c3", ["C1", "C1", "C1"])

    check("3 to c4", play(p[0], "c4"))
    check("the top 2 cannot turn to d4", !play(p[1], "d4"))
    check("nor skip c4 and land on c5", !play(p[0], "c5"))
    check("nor go back to c2", !play(p[2], "c2"))

func test_hallacirya_flattens_and_releases_a_tampa():
    var p = put("a1", ["C1", "H1"])
    var tampa = put("c1", ["T2"])[0]

    check("2 to b1", play(p[0], "b1"))
    check("the hallacirya on to c1", play(p[1], "c1"))
    check("the tampa is flat", !instance_from_id(tampa).block)
    check_equal("over the tampa", "2a1>11", notation())
    check("the hallacirya back to b1", play(p[1], "b1"))
    check("the tampa stands again", instance_from_id(tampa).block)
    check_equal("back", "2a1>", notation())

func test_nothing_over_a_hallacirya_and_a_tampa_needs_it_alone():
    var p = put("a1", ["C1", "H1"])
    put("b1", ["T2"])
    var q = put("d4", ["C1"])
    put("d5", ["H2"])

    check("a cirya with the hallacirya over a tampa", !play(p[0], "b1"))
    check("a cirya over a hallacirya", !play(q[0], "d5"))

func test_nosse_of_the_opponent():
    var p = put("a1", ["C1", "C2"])

    check("player 1 cannot take it", !take(p[1]))
    player = 2
    check("player 2 can", play(p[1], "a2"))

func test_turns_alternate():
    var white = put("a1", ["C1"])
    var black = put("e5", ["C2"])

    check("player 1 moves", play(white[0], "a2"))
    end_turn()
    check("player 2 cannot take the cirya of player 1", !take(white[0]))
    check("player 2 moves", play(black[0], "e4"))

func test_carry_limit():
    var p = put("a1", ["C1", "C1", "C1", "C1", "C1", "C1"])

    check("6 stones cannot be taken", !take(p[0]))
    check("5 can", play(p[1], "a2"))

func test_placement():
    put("c3", ["C2"])
    var cirya = piece("C1")

    check("not on an occupied square", take(cirya) and !drop("c3"))
    check("on an empty one", drop("b2"))
    check_equal("notation", "b2", notation())
    check("no second piece from the fleet", !take(piece("C1")))
    check("the placed piece can change square", play(cirya, "d4"))
    check_equal("then", "d4", notation())

func test_placement_of_a_tampa():
    var cirya = piece("C1")

    check("taken", take(cirya))
    instance_from_id(cirya).toggle_block()
    check("placed standing", drop("b2"))
    check_equal("notation", "Tb2", notation())

func test_opening_places_a_cirya_of_the_opponent():
    opening = true

    check("not an own piece", !take(piece("C1")))
    check("not the hallacirya of the opponent", !take(piece("H2")))
    check("not a tampa", !take(piece("T2")))
    check("a cirya of the opponent", play(piece("C2"), "c3"))
    check_equal("written as a plain placement", "c3", notation())
    check("only one", !take(piece("C2")))

func test_opening_has_no_moves():
    opening = true
    player = 2
    var placed = put("a1", ["C2"])

    check("the cirya on the board cannot move", !take(placed[0]))
    check("a cirya of player 1 from the fleet can be placed", play(piece("C1"), "e5"))

# The opponent places a cirya of the other player in the opening: it comes
# from that fleet, and never the hallacirya
func test_replay_an_opening():
    var hallacirya = piece("H2")
    var cirya = piece("C2")
    piece("C1")

    check_equal("the cirya of player 2 goes to c3",
        [{"piece": cirya, "square": Vector2(2, 2), "stand": false}],
        Rules.replay("c3", 1, true, board, pieces))
    check("not the hallacirya", hallacirya != Rules.replay("c3", 1, true, board, pieces)[0].piece)

func test_replay_a_tampa_and_a_move():
    var cirya = piece("C1")
    check_equal("a tampa stands", [{"piece": cirya, "square": Vector2(1, 1), "stand": true}], Rules.replay("Tb2", 1, false, board, pieces))

    var p = put("a1", ["C2", "C1", "C1"])
    check_equal("the bottom of the carry goes first",
        [{"piece": p[1], "square": Vector2(1, 0), "stand": false}, {"piece": p[2], "square": Vector2(2, 0), "stand": false}],
        Rules.replay("2a1+11", 1, false, board, pieces))
    check_equal("not a turn", [], Rules.replay("x9", 1, false, board, pieces))

# move_state checks the nossë belongs to the player even when nothing stopped
# taking it
func test_move_state_of_a_nosse_of_the_opponent():
    var p = put("a1", ["C2"])
    move = Move.new(board, p[0], pieces)
    board.put([p[0]], Vector2(1, 0))

    check_equal("not a move of player 1", null, Rules.move_state(move, board, 1, false))
    check_equal("a move of player 2", "a1+", Notation.write(Rules.move_state(move, board, 2, false)))
