extends "res://tests/TestCase.gd"

# Turns of a list played on a copy of the board, checked with the rules, as
# the replay of the demo does

const BoardState = preload("res://core/BoardState.gd")
const Notation = preload("res://core/Notation.gd")
const Rules = preload("res://core/Rules.gd")

var board
var pieces = []
var objects = []
var blocks = {}

func setup():
    board = BoardState.new(5)
    pieces = []
    objects = []
    blocks = {}

    # A small fleet for each player: three ciryar and a hallacirya
    for player in [1, 2]:
        for name in ["C", "C", "C", "H"]:
            fleet_piece(name + str(player))

func fleet_piece(name):
    var piece = load("res://tests/fakes/Piece.gd").new(name)
    objects.append(piece)
    pieces.append(piece.get_instance_id())
    return piece.get_instance_id()

func put(square, names):
    var ids = []

    for name in names:
        var id = fleet_piece(name)
        ids.append(id)

        if name[0] == "T":
            blocks[id] = true

    board.put(ids, Notation.parse_square(square))
    return ids

func apply(turn, player, opening = false):
    return Rules.apply_turn(turn, player, opening, board, blocks, pieces)

func names(result, square):
    var res = []

    for id in result.board.stack(Notation.parse_square(square)):
        var piece = instance_from_id(id)
        var kind = "H" if piece.type == "HALLACIRYA" else ("T" if result.blocks.has(id) else "C")
        res.append(kind + str(piece.player))

    return res

func test_openings():
    var result = apply("c3", 1, true)
    check_equal("no error", "", result.error)
    check_equal("a cirya of the opponent", ["C2"], names(result, "c3"))
    check_equal("the board is not touched", [], board.stack(Notation.parse_square("c3")))
    check_equal("no tampa in the opening", "La apertura pone una cirya plana del rival", apply("Tc3", 1, true).error)
    check_equal("nor a move", "La apertura pone una cirya plana del rival", apply("c3+", 1, true).error)

func test_placements():
    var result = apply("Tb2", 1)
    check_equal("a tampa of the player", ["T1"], names(result, "b2"))
    check_equal("one step, standing", true, result.steps[0].stand)
    check_equal("a hallacirya", ["H2"], names(apply("Hb2", 2), "b2"))
    put("a1", ["C1"])
    check_equal("not on a stack", "a1 no está libre", apply("a1", 1).error)

    for i in range(3):
        board.put([pieces[i]], Vector2(4, i))

    check_equal("not without ciryar", "No queda ninguna cirya en la bandeja", apply("e5", 1).error)

func test_moves():
    put("a1", ["C2", "C1", "C1"])
    var result = apply("3a1>12", 1)
    check_equal("no error", "", result.error)
    check_equal("one on b1", ["C2"], names(result, "b1"))
    check_equal("two on c1", ["C1", "C1"], names(result, "c1"))
    check_equal("a step for each piece, in order", 3, result.steps.size())
    check_equal("only the stack of the player", "a1 no es de quien juega", apply("a1+", 2).error)
    check_equal("not more than it has", "En a1 no hay 4 piezas que mover", apply("4a1+", 1).error)
    check_equal("the drops add up", "Las piezas que se sueltan tienen que sumar 2", apply("2a1+1", 1).error)
    check_equal("not off the board", "La jugada se sale del tablero", apply("a1-", 1).error)

func test_tampar_and_hallaciryar():
    put("c3", ["H1"])
    put("c4", ["C1"])
    check_equal("nothing on a hallacirya", "Nada cabe sobre la hallacirya de c3", apply("c4-", 1).error)

    put("a2", ["T2"])
    put("a1", ["C1", "H1"])
    check_equal("only a lone hallacirya on a tampa", "Sobre la tampa de a2 solo cabe la hallacirya sola", apply("2a1+", 1).error)
    var result = apply("a1+", 1)
    check_equal("the hallacirya flattens it", ["C2", "H1"], names(result, "a2"))

# A whole game of games/, played from the opening with the fleets of 5x5:
# every turn fits, as it did in the game
func test_a_whole_game():
    var file = File.new()
    var path = ProjectSettings.globalize_path("res://").plus_file("../games/simple.txt")
    check_equal("the game is there", OK, file.open(path, File.READ))
    var parsed = Notation.parse_list(file.get_as_text())
    file.close()
    check_equal("understood", "", parsed.error)

    board = BoardState.new(5)
    pieces = []
    objects = []
    blocks = {}

    for player in [1, 2]:
        for i in range(21):
            fleet_piece("C" + str(player))

        fleet_piece("H" + str(player))

    for i in range(parsed.turns.size()):
        var result = apply(parsed.turns[i], 1 if i % 2 == 0 else 2, i < 2)

        if result.error:
            check_equal("turn %d, %s" % [i + 1, parsed.turns[i]], "", result.error)
            return

        board = result.board
        blocks = result.blocks

    check_equal("all of it", 36, parsed.turns.size())
