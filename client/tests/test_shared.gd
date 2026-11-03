extends "res://tests/TestCase.gd"

# The rules of the client checked against the files the tests of the server
# check too, so the three of them say the same: the server, the board of the
# bot (BotBoard) and the turns of a list (Rules.apply_turn). A rule changed in
# one and not in the others fails here or there
#
#   turns.json      small positions and a turn, legal or not
#   bot_games.json  whole games, with the board at their end

const BoardState = preload("res://core/BoardState.gd")
const BotBoard = preload("res://core/BotBoard.gd")
const Notation = preload("res://core/Notation.gd")
const Rules = preload("res://core/Rules.gd")

const TESTDATA = "res://../server/internal/cirya/testdata/"

# The fake pieces, kept so they are not freed while their ids are in use
var objects = []

func test_turns():
    for turn in _load("turns.json"):
        var label = "%s: %s" % [turn.name, turn.move]
        check_equal("the bot, " + label, turn.legal, _bot_board(turn).moves().has(turn.move))

        # The lists of the demo know no Henneth Annûn; Match checks it
        if !turn.get("hennethAnnun", false):
            var result = _apply(turn)
            check_equal("a list, %s (%s)" % [label, result.error], turn.legal, result.error == "")

func test_bot_games():
    var games = _load("bot_games.json")
    check("there are games", !games.empty())

    for g in range(games.size()):
        var game = games[g]
        var board = BoardState.new(5)
        var blocks = {}
        var pieces = _fleets({})
        var failed = false

        for i in range(game.moves.size()):
            var result = Rules.apply_turn(game.moves[i], 1 + i % 2, i < 2, board, blocks, pieces, game.unlimited)

            if result.error:
                check("game %d, turn %d: %s (%s)" % [g, i + 1, game.moves[i], result.error], false)
                failed = true
                break

            board = result.board
            blocks = result.blocks

        if !failed:
            check_equal("game %d: the board at the end" % g, game.board, _stacks(board, blocks))

func _load(name):
    var file = File.new()
    file.open(TESTDATA + name, File.READ)
    var data = JSON.parse(file.get_as_text()).result
    file.close()
    return data

func _bot_board(turn):
    var board = BotBoard.new(5)
    board.turn = int(turn.turn)
    board.unlimited = turn.get("unlimited", false)
    board.henneth_annun = turn.get("hennethAnnun", false)

    for square in turn.board:
        board.stacks[board._index(square)] = Array(turn.board[square]).duplicate()

    for player in turn.get("fleets", {}):
        var fleet = turn.fleets[player]
        board.fleets[int(player)] = {"ciryar": int(fleet.ciryar), "hallaciryar": int(fleet.hallaciryar)}

    return board

# The turn as a list plays it: the stones of the position on the board, and
# the rest of the fleets off it
func _apply(turn):
    var board = BoardState.new(5)
    var blocks = {}
    var pieces = _fleets(turn.get("fleets", {}))

    for square in turn.board:
        var ids = []

        for name in turn.board[square]:
            var id = _piece(name)
            ids.append(id)
            pieces.append(id)

            if name[0] == "T":
                blocks[id] = true

        board.put(ids, Notation.parse_square(square))

    var player = 1 if int(turn.turn) % 2 == 1 else 2
    return Rules.apply_turn(turn.move, player, int(turn.turn) <= 2, board, blocks, pieces, turn.get("unlimited", false))

func _fleets(fleets):
    var pieces = []

    for player in [1, 2]:
        var fleet = fleets.get(str(player), {"ciryar": Rules.fleet(5)[0], "hallaciryar": Rules.fleet(5)[1]})

        for i in range(int(fleet.ciryar)):
            pieces.append(_piece("C%d" % player))

        for i in range(int(fleet.hallaciryar)):
            pieces.append(_piece("H%d" % player))

    return pieces

func _piece(name):
    var piece = Piece.new(name)
    objects.append(piece)
    return piece.get_instance_id()

# The board as the server writes it, square by square, a tampa standing if
# it is in blocks
func _stacks(board, blocks):
    var res = {}

    for row in range(board.size()):
        for column in range(board.size()):
            var square = Vector2(row, column)
            var stones = []

            for id in board.stack(square):
                var piece = instance_from_id(id)
                var kind = "H" if piece.type == "HALLACIRYA" else ("T" if blocks.has(id) else "C")
                stones.append(kind + str(piece.player))

            if stones:
                res[Notation.square_name(square)] = stones

    return res
