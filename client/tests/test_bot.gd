extends "res://tests/TestCase.gd"

# The bot chooses its turns: it wins when it can, blocks the Londë of the
# opponent, opens in a corner and plays its hallacirya in its turn

const Bot = preload("res://core/Bot.gd")
const BotBoard = preload("res://core/BotBoard.gd")

var bot
var board

func setup():
    bot = Bot.new()
    bot.noise = 0
    bot.time_limit = 5000

func position(stacks, turn = 3):
    board = BotBoard.new(5)

    for name in stacks:
        board.stacks[board._index(name)] = stacks[name]

    board.turn = turn
    return board

func test_opening_in_a_corner():
    board = BotBoard.new(5)
    check_equal("a corner", true, ["a1", "e1", "a5", "e5"].has(bot.choose(board)))

# White has four on the third rank: it closes it
func test_wins_in_one():
    position({"a3": ["C1"], "b3": ["C1"], "c3": ["C1"], "d3": ["C1"], "a1": ["C2"], "b1": ["C2"]})
    var move = bot.choose(board)
    board.play(move)
    check_equal("%s wins" % move, {"over": true, "winner": 1, "condition": "LONDI"}, board.result(1))

# Black threatens to close the second rank on e2: white stops it
func test_blocks_a_londe():
    position({"a2": ["C2"], "b2": ["C2"], "c2": ["C2"], "d2": ["C2"], "a5": ["C1"], "c5": ["C1"]})
    var move = bot.choose(board)
    board.play(move)
    var lost = false

    for answer in board.moves():
        board.play(answer)

        if board.result(2).over and board.result(2).winner == 2:
            lost = true

        board.undo()

    check_equal("after %s black cannot win at once" % move, false, lost)

# A full nossë of the opponent is a wall: the road goes round it
func test_full_nosse_is_a_wall():
    position({"a3": ["C1"], "b3": ["C1"], "d3": ["C1"], "e3": ["C1"], "c3": ["C1", "C1", "C1", "C2", "C2"]})
    check_equal("white still needs to go round", 3, bot.distance(board, 1))
    board.stacks[board._index("c3")] = ["C1", "C2"]
    check_equal("but a small one can be covered", 2, bot.distance(board, 1))
    board.unlimited = true
    board.stacks[board._index("c3")] = ["C1", "C1", "C1", "C2", "C2"]
    check_equal("and so can a big one with T4K", 2, bot.distance(board, 1))

func test_distance():
    position({})
    check_equal("an empty board, five squares", 5, bot.distance(board, 1))
    position({"a1": ["C1"], "b1": ["H1"], "c1": ["T1"]})
    # Its own tampa has to move or be flattened to be in a Londë: it costs two
    check_equal("its own tampa is not in a Londë", 4, bot.distance(board, 1))
    position({"a1": ["C1"], "b1": ["C1"], "c1": ["C1"], "d1": ["C1"], "e1": ["C1"]})
    check_equal("a Londë", 0, bot.distance(board, 1))

# With Henneth Annûn black places its hallacirya in its 16th turn
func test_hallacirya_in_its_turn():
    position({"a1": ["C2"], "e5": ["C1"], "c3": ["C2"]}, 32)
    board.henneth_annun = true
    var move = bot.choose(board)
    check_equal("%s is the hallacirya" % move, "H", move[0])

# Against random turns it wins, and every turn it plays is legal
func test_beats_random_turns():
    seed(3)
    bot.depth = 1
    var wins = 0

    for game in range(4):
        board = BotBoard.new(5)
        var result = {"over": false}

        while !result.over and board.turn < 200:
            var mover = board.player()
            var move = ""

            if mover == 1:
                move = bot.choose(board)
                check("game %d: %s is legal" % [game, move], board.moves().has(move))
            else:
                var moves = board.moves()
                move = moves[randi() % moves.size()]

            board.play(move)
            result = board.result(mover)

        if result.over and result.winner == 1:
            wins += 1

    check_equal("it wins every game", 4, wins)
