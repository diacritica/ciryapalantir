extends "res://tests/TestCase.gd"

# The board of the bot: every legal turn, played and taken back, and the end
# of the game, with the rules of Cirya as the server has them

const BotBoard = preload("res://core/BotBoard.gd")

var board

func setup():
    board = BotBoard.new(5)

# Stones on squares, bottom first, and the turn about to be played
func position(stacks, turn = 3):
    board = BotBoard.new(5)

    for name in stacks:
        board.stacks[board._index(name)] = stacks[name]

    board.turn = turn
    return board

func stack(name):
    return board.stacks[board._index(name)]

func sorted(list):
    var res = list.duplicate()
    res.sort()
    return res

func test_openings():
    var moves = board.moves()
    check_equal("any empty square", 25, moves.size())
    check_equal("only plain placements", true, moves.has("a1") and !moves.has("Ta1") and !moves.has("Ha1"))

    board.play("a1")
    check_equal("a cirya of black", ["C2"], stack("a1"))
    check_equal("from the fleet of black", 20, board.fleets[2].ciryar)
    check_equal("black places one of white", 24, board.moves().size())
    board.play("e5")
    check_equal("on e5", ["C1"], stack("e5"))
    check_equal("now white plays its own", 1, board.player())

# After the openings: three kinds of placement on every empty square, and the
# moves of the stacks of the player
func test_after_the_openings():
    position({"a1": ["C2"], "e5": ["C1"]})
    var moves = board.moves()
    check_equal("23 empty squares, three ways, and e5 left and down", 23 * 3 + 2, moves.size())
    check_equal("e5 moves to e4 and d5", true, moves.has("e5-") and moves.has("e5<"))
    check_equal("not the cirya of black", false, moves.has("a1+"))

# A nossë of three in the middle: one, two or three stones, dropped in every
# way that fits in the two squares to the edge, in four directions
func test_nosse_moves():
    position({"c3": ["C2", "C1", "C1"]})
    var moves = board.moves()
    var nosse = []

    for move in moves:
        if move.find("c3") != -1:
            nosse.append(move)

    check_equal("1, then 2 and 11, then 3, 21 and 12, four ways", 24, nosse.size())
    check_equal("written as the server reads them", sorted(["c3+", "2c3+2", "2c3+11", "3c3+3", "3c3+21", "3c3+12"]), sorted(_starting(nosse, "+")))

    board.play("3c3>12")
    check_equal("the whole nossë goes", [], stack("c3"))
    check_equal("the bottom one on d3", ["C2"], stack("d3"))
    check_equal("two on e3", ["C1", "C1"], stack("e3"))
    board.undo()
    board.play("2c3+11")
    check_equal("two of three leave the bottom one", ["C2"], stack("c3"))

func _starting(moves, direction):
    var res = []

    for move in moves:
        if move.find("c3" + direction) != -1:
            res.append(move)

    return res

# Nothing over a hallacirya, and over a tampa only a lone hallacirya, which
# flattens it
func test_tampar_and_hallaciryar():
    position({"b2": ["H2"], "a2": ["C1"], "c2": ["T2"], "d2": ["C1", "H1"]})
    var moves = board.moves()
    check_equal("not over the hallacirya", false, moves.has("a2>"))
    check_equal("nor the cirya over the tampa", false, moves.has("2d2<"))
    check_equal("but the hallacirya alone", true, moves.has("d2<"))

    board.play("d2<")
    check_equal("the tampa lies down under it", ["C2", "H1"], stack("c2"))
    board.undo()
    check_equal("and stands again when taken back", ["T2"], stack("c2"))

# A nossë holds five stones in 5x5, and a hallacirya on top, unless T4K
func test_height():
    position({"a1": ["C1"], "b1": ["C2", "C1", "C2", "C1", "C2"], "a2": ["H1"], "b2": ["C2", "C1", "C2", "C1", "C2"]})
    var moves = board.moves()
    check_equal("not a sixth stone", false, moves.has("a1>"))
    check_equal("but a hallacirya on top", true, moves.has("a2>"))

    board.unlimited = true
    check_equal("with T4K, a sixth stone", true, board.moves().has("a1>"))

    position({"a3": ["C1", "C1", "C1", "C1", "C1", "C1"]})
    var carried = 0

    for move in board.moves():
        if move.find("a3") != -1:
            carried = max(carried, int(move[0]) if move[0].is_valid_integer() else 1)

    check_equal("it carries five at most", 5, carried)

# With Henneth Annûn each hallacirya only comes into play in its turn
func test_henneth_annun():
    position({"a1": ["C2"], "e5": ["C1"]}, 31)
    board.henneth_annun = true
    check_equal("not before", false, board.moves().has("Hc3"))
    board.turn = 32
    check_equal("black in its 16th turn", true, board.moves().has("Hc3"))
    board.turn = 33
    check_equal("white in its 17th", true, board.moves().has("Hc3"))
    board.turn = 34
    check_equal("never after", false, board.moves().has("Hc3"))

func test_end_by_londe():
    position({"a3": ["C1"], "b3": ["C1"], "c3": ["H1"], "d3": ["C1"]})
    board.play("e3")
    check_equal("white joins the files", {"over": true, "winner": 1, "condition": "LONDI"}, board.result(1))

    position({"a3": ["C1"], "b3": ["C1"], "c3": ["T1"], "d3": ["C1"], "e3": ["C1"]})
    check_equal("not through a tampa", false, board.result(1).over)

# A move that completes both londi is won by who made it: black drops a
# white cirya on e2, which joins the second rank of white, and a black one
# on e1, which joins its first rank
func test_both_londi():
    position({"a1": ["C2"], "b1": ["C2"], "c1": ["C2"], "d1": ["C2"], "a2": ["C1"], "b2": ["C1"], "c2": ["C1"], "d2": ["C1"], "e3": ["C1", "C2"]}, 4)
    board.play("2e3-11")
    check_equal("both londi, black moved", {"over": true, "winner": 2, "condition": "LONDI"}, board.result(2))

func test_end_by_count():
    position({"a1": ["C1"], "b1": ["C1"], "c1": ["C2"]})
    board.fleets[2] = {"ciryar": 0, "hallaciryar": 0}
    check_equal("an empty fleet counts the flat ciryar", {"over": true, "winner": 1, "condition": "FLAT"}, board.result(2))

# Every turn played and taken back leaves the board as it was
func test_undo():
    position({"c3": ["C2", "T1"], "a1": ["C2"]})
    var before = str(board.stacks) + str(board.fleets) + str(board.turn)

    for move in board.moves():
        board.play(move)
        board.undo()

    check_equal("as it was", before, str(board.stacks) + str(board.fleets) + str(board.turn))
    check_equal("the tampa is carried standing", true, _played_has("c3>", "d3", ["T1"]))

func _played_has(move, square, stones):
    board.play(move)
    var res = stack(square) == stones
    board.undo()
    return res

func test_from_a_status():
    var status = {
        "config": {"size": 5, "tak": true, "hennethAnnun": false},
        "turn": 7,
        "board": {"1": {"a": ["C1", "C2"]}, "3": {"d": ["H1"]}},
        "fleets": {"1": {"ciryar": 18, "hallaciryar": 0}, "2": {"ciryar": 19, "hallaciryar": 1}},
    }
    board = BotBoard.from_status(status)
    check_equal("the stacks", ["C1", "C2"], stack("a1"))
    check_equal("and d3", ["H1"], stack("d3"))
    check_equal("the fleets", {"ciryar": 18, "hallaciryar": 0}, board.fleets[1])
    check_equal("the turn", 7, board.turn)
    check_equal("and the rules", true, board.unlimited)

# Whole games of random turns: they all end, and on the way no square holds
# more than it can and no stone is lost or made
func test_random_games():
    seed(7)

    for game in range(20):
        board = BotBoard.new(5)
        var mover = 1
        var played = 0

        while played < 300:
            var moves = board.moves()
            check("game %d turn %d has turns" % [game, board.turn], !moves.empty())

            if moves.empty():
                return

            mover = board.player()
            board.play(moves[randi() % moves.size()])
            played += 1

            if !_sound():
                check("game %d after turn %d, the board is sound" % [game, played], false)
                return

            if board.result(mover).over:
                break

        check("game %d ends" % game, board.result(mover).over)

# The stones on the board and in the fleets are always the whole fleets, and
# no square holds more than five apart from a hallacirya on top
func _sound():
    var counts = {1: [0, 0], 2: [0, 0]}

    for stack in board.stacks:
        var stones = stack.size()

        for i in range(stack.size()):
            var stone = stack[i]
            counts[int(stone[1])][1 if stone[0] == "H" else 0] += 1

            if stone[0] == "H":
                stones -= 1

                if i != stack.size() - 1:
                    return false

            if stone[0] == "T" and i != stack.size() - 1:
                return false

        if stones > 5:
            return false

    for player in [1, 2]:
        if counts[player][0] + board.fleets[player].ciryar != 21 or counts[player][1] + board.fleets[player].hallaciryar != 1:
            return false

    return true
