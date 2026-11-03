extends SceneTree

# Plays random games with the board of the bot and writes them, with the
# board and the result at their end, where the tests of the server replay
# them with its own rules: every turn the bot thinks legal has to be legal
# there, and lead to the same board, as in test_shared.gd with the rules of
# the lists of the client. From the client folder:
#
#   godot --no-window --path . -s tests/dump_bot_games.gd

const BotBoard = preload("res://core/BotBoard.gd")
const GAMES = 40
const PATH = "res://../server/internal/cirya/testdata/bot_games.json"

func _init():
    seed(2026)
    var games = []

    for game in range(GAMES):
        var board = BotBoard.new(5)
        board.unlimited = game % 2 == 1
        var moves = []
        var result = {}

        while moves.size() < 400:
            var turns = board.moves()
            var mover = board.player()
            var move = turns[randi() % turns.size()]
            board.play(move)
            moves.append(move)
            result = board.result(mover)

            if result.over:
                break

        var stacks = {}

        for index in range(board.stacks.size()):
            if board.stacks[index]:
                stacks[board.square_name(index)] = board.stacks[index]

        games.append({"unlimited": board.unlimited, "moves": moves, "board": stacks, "result": result})

    var file = File.new()
    file.open(ProjectSettings.globalize_path(PATH), File.WRITE)
    file.store_string(JSON.print(games, "  "))
    file.close()
    print("%d games written" % GAMES)
    quit()
