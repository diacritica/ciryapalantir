extends Reference

# The board as the bot sees it, in the shape the server sends it: a stack of
# stones on every square, bottom first, each one its kind and its player,
# like "C1", "T2" or "H1", and what is left in each fleet. It knows the rules
# of Cirya as internal/cirya on the server does, so it can list every legal
# turn in notation, play it, take it back and tell when the game is over:
#
#   the opening places a flat cirya of the opponent, in turns 1 and 2
#   nothing goes over a hallacirya, and over a tampa only a lone hallacirya,
#   which flattens it
#   a nossë carries at most as many stones as the board is wide, and holds
#   no more than that, with a hallacirya on top (unless the variant T4K)
#   with Henneth Annûn, each hallacirya only comes into play in one turn
#   a player has at most as many tampar standing as the board is wide
#
# Squares are numbered row by row from a1: index = rank * size + file

const FILES = "abcdefghi"
# The steps of a nossë as the notation writes them: up and down a rank,
# right and left a file
const STEPS = {"+": [1, 0], "-": [-1, 0], ">": [0, 1], "<": [0, -1]}
# The turns of the hallaciryar with the Henneth Annûn rule
const HENNETH_ANNUN_BLACK = 32
const HENNETH_ANNUN_WHITE = 33
# Official fleets by board size: ciryar (tampar come from them) and hallaciryar
const FLEETS = {5: [21, 1], 6: [30, 2], 7: [40, 2]}

var size = 5
var stacks = []
# fleets[player] = {"ciryar": n, "hallaciryar": n}
var fleets = {}
# The turn about to be played, counting the turns of both players from 1
var turn = 1
var unlimited = false
var henneth_annun = false
# What every play changed, to take it back
var history = []

func _init(board_size = 5):
    size = board_size
    stacks = []

    for i in range(size * size):
        stacks.append([])

    var fleet = FLEETS.get(size, [size * size, 2])
    fleets = {1: {"ciryar": fleet[0], "hallaciryar": fleet[1]}, 2: {"ciryar": fleet[0], "hallaciryar": fleet[1]}}

# The board of a status of the server, with its rules
static func from_status(status):
    var config = status.get("config", {})
    var board = load("res://core/BotBoard.gd").new(int(config.get("size", 5)))
    board.unlimited = config.get("tak", false)
    board.henneth_annun = config.get("hennethAnnun", false)
    board.turn = int(status.get("turn", 1))

    for rank in status.get("board", {}):
        for file in status.board[rank]:
            board.stacks[(int(rank) - 1) * board.size + FILES.find(file)] = Array(status.board[rank][file]).duplicate()

    for player in status.get("fleets", {}):
        var fleet = status.fleets[player]
        board.fleets[int(player)] = {"ciryar": int(fleet.ciryar), "hallaciryar": int(fleet.hallaciryar)}

    return board

func square_name(index):
    return FILES[index % size] + str(index / size + 1)

func owner(index):
    var stack = stacks[index]
    return int(stack.back()[1]) if stack else 0

func opening():
    return turn <= 2

# The player whose turn it is: white plays the odd turns
func player():
    return 1 if turn % 2 == 1 else 2

# Every legal turn of the player whose turn it is, in notation
func moves():
    var player = player()
    var res = []

    if opening():
        if fleets[3 - player].ciryar > 0:
            for index in range(stacks.size()):
                if stacks[index].empty():
                    res.append(square_name(index))

        return res

    var fleet = fleets[player]
    var hallacirya = fleet.hallaciryar > 0 and hallacirya_allowed(player)
    var tampa = tampar(player) < size

    for index in range(stacks.size()):
        if stacks[index].empty():
            var name = square_name(index)

            if fleet.ciryar > 0:
                res.append(name)

                if tampa:
                    res.append("T" + name)

            if hallacirya:
                res.append("H" + name)
        elif owner(index) == player:
            _nosse_moves(index, res)

    return res

# The tampar of the player standing on the board
func tampar(player):
    var count = 0
    var stone = "T" + str(player)

    for stack in stacks:
        if stack and stack.back() == stone:
            count += 1

    return count

func hallacirya_allowed(player):
    return !henneth_annun or turn == (HENNETH_ANNUN_WHITE if player == 1 else HENNETH_ANNUN_BLACK)

# Every way to break the nossë of the square: how many stones it carries,
# where to, and how many it drops on each square on the way
func _nosse_moves(index, res):
    var stack = stacks[index]
    var row = index / size
    var column = index % size

    for direction in STEPS:
        var step = STEPS[direction]

        for count in range(1, min(stack.size(), size) + 1):
            var carried = stack.slice(stack.size() - count, stack.size() - 1)
            _drops(row + step[0], column + step[1], step, carried, [], res, square_name(index), direction, count)

func _drops(row, column, step, carried, drops, res, origin, direction, count):
    if row < 0 or column < 0 or row >= size or column >= size:
        return

    var under = stacks[row * size + column]

    for drop in range(1, carried.size() + 1):
        var dropped = carried.slice(0, drop - 1)

        if !_can_drop(under, dropped):
            continue

        var done = drops + [drop]

        if drop == carried.size():
            res.append(_write(origin, direction, count, done))
        else:
            _drops(row + step[0], column + step[1], step, carried.slice(drop, carried.size() - 1), done, res, origin, direction, count)

# Nothing over a hallacirya, over a tampa only a lone hallacirya, and no more
# stones than the board is wide apart from a hallacirya on top
func _can_drop(under, dropped):
    if under:
        var top = under.back()

        if top[0] == "H":
            return false

        if top[0] == "T" and (dropped.size() != 1 or dropped[0][0] != "H"):
            return false

    if unlimited:
        return true

    var stones = under.size() + dropped.size()

    if dropped.back()[0] == "H":
        stones -= 1

    return stones <= size

func _write(origin, direction, count, drops):
    if count == 1:
        return origin + direction

    var digits = ""

    for drop in drops:
        digits += str(drop)

    return "%d%s%s%s" % [count, origin, direction, digits]

# Plays the turn of the player whose turn it is. It has to be one of moves()
func play(move):
    var record = {"turn": turn, "fleets": fleets.duplicate(true), "stacks": {}}
    var player = player()

    if move[0] in "HT" or move.length() == 2:
        var stone = move[0] if move[0] in "HT" else "C"
        var index = _index(move.right(move.length() - 2))
        var owner = 3 - player if opening() else player
        record.stacks[index] = stacks[index].duplicate()
        stacks[index] = [stone + str(owner)]
        fleets[owner]["hallaciryar" if stone == "H" else "ciryar"] -= 1
    else:
        _play_nosse(move, record)

    history.append(record)
    turn += 1

func _play_nosse(move, record):
    var count = 1
    var at = 0

    if move[0].is_valid_integer():
        count = int(move[0])
        at = 1

    var index = _index(move.substr(at, 2))
    var step = STEPS[move[at + 2]]
    var digits = move.substr(at + 3, move.length())
    var drops = []

    for digit in digits:
        drops.append(int(digit))

    if drops.empty():
        drops = [count]

    var stack = stacks[index]
    record.stacks[index] = stack.duplicate()
    var carried = stack.slice(stack.size() - count, stack.size() - 1)
    stacks[index] = stack.slice(0, stack.size() - count - 1) if stack.size() > count else []
    var row = index / size
    var column = index % size

    for drop in drops:
        row += step[0]
        column += step[1]
        var target = row * size + column
        record.stacks[target] = stacks[target].duplicate()
        var dropped = carried.slice(0, drop - 1)
        var under = stacks[target]

        # A lone hallacirya flattens the tampa it covers
        if under and under.back()[0] == "T":
            under[under.size() - 1] = "C" + under.back()[1]

        stacks[target] = under + dropped
        carried = carried.slice(drop, carried.size() - 1) if carried.size() > drop else []

func _index(name):
    return (int(name[1]) - 1) * size + FILES.find(name[0])

# Takes back the last turn played
func undo():
    var record = history.pop_back()
    turn = record.turn
    fleets = record.fleets

    for index in record.stacks:
        stacks[index] = record.stacks[index]

# Whether the game is over after a turn of the mover, as the server tells:
# a turn that completes both londi is won by who made it; a full board or an
# empty fleet ends it by the count of flat ciryar on top
func result(mover):
    if londe(mover):
        return {"over": true, "winner": mover, "condition": "LONDI"}

    if londe(3 - mover):
        return {"over": true, "winner": 3 - mover, "condition": "LONDI"}

    var full = true

    for stack in stacks:
        if stack.empty():
            full = false
            break

    if full or _fleet_empty(1) or _fleet_empty(2):
        var flats = [flat_count(1), flat_count(2)]
        var winner = 1 if flats[0] > flats[1] else (2 if flats[1] > flats[0] else 0)
        return {"over": true, "winner": winner, "condition": "FLAT"}

    return {"over": false, "winner": 0, "condition": "NONE"}

func _fleet_empty(player):
    return fleets[player].ciryar == 0 and fleets[player].hallaciryar == 0

func flat_count(player):
    var count = 0

    for stack in stacks:
        if stack and stack.back() == "C" + str(player):
            count += 1

    return count

# A square in a Londë of the player: a cirya or a hallacirya of it on top
func in_londe(index, player):
    var stack = stacks[index]
    return stack and stack.back()[0] != "T" and int(stack.back()[1]) == player

# The player joins two opposite sides with squares in its Londë, orthogonally
func londe(player):
    return _connects(player, true) or _connects(player, false)

func _connects(player, by_rank):
    var visited = {}
    var pending = []

    for i in range(size):
        var index = i if by_rank else i * size

        if in_londe(index, player):
            visited[index] = true
            pending.append(index)

    while pending:
        var index = pending.pop_back()
        var row = index / size
        var column = index % size

        if (row if by_rank else column) == size - 1:
            return true

        for step in STEPS.values():
            var next_row = row + step[0]
            var next_column = column + step[1]
            var next = next_row * size + next_column

            if next_row >= 0 and next_column >= 0 and next_row < size and next_column < size and !visited.has(next) and in_londe(next, player):
                visited[next] = true
                pending.append(next)

    return false
