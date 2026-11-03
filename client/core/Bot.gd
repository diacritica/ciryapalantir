extends Reference

# Chooses the turn of the bot on a BotBoard, as the bots of Tak do on a small
# scale: a negamax search with alpha-beta pruning, deeper while there is time,
# over an evaluation that weighs above all how far each player is from a
# Londë, and then the count of flat ciryar, the stacks each one controls and
# the centre. A turn that wins is played at once, and the search sees the
# Londë the opponent would make next and blocks it.
#
# The rules of Cirya change the evaluation: a full nossë (as many stones as
# the board is wide) cannot be covered, so like a tampa or a hallacirya it is
# a wall in the way of the opponent. With Henneth Annûn a hallacirya not
# placed in its turn is lost.
#
# And it plays as the courtly Cirya, Aracirya, asks: bringing out the
# hallacirya first is a sign of weakness, so it holds it back while the
# opponent holds its own, and only brings it out first to win or not to lose.
# Once the opponent has brought out its hallacirya, it is free to bring out
# its own. With Henneth Annûn the rule says when each one comes out
#
# choose() returns the turn. With yield_every set and a tree to wait on, it
# waits a frame every so many positions, so the game does not freeze while it
# thinks, and then it returns a GDScriptFunctionState to wait for

const Rules = preload("res://core/Rules.gd")

const WIN = 100000
const BLOCKED = 1000
# The value of being that far from a Londë: the squares still to fill
const ROAD = [WIN, 600, 160, 50, 16, 5, 2, 1, 0, 0, 0]
const FLAT = 22
const CONTROL = 6
const OWN_IN_STACK = 3
const PRISONER = 4
const CENTRE = 2
const HALLACIRYA_ON_BOARD = 30
const HALLACIRYA_LOST = 150
# Bringing out the hallacirya first: more than any better position is worth,
# far less than a lost game
const HALLACIRYA_FIRST = 500

# Turns ahead at most, and the time for them
var depth = 2
var time_limit = 1500
# Every how many positions it waits a frame, 0 for never, and where
var yield_every = 0
var tree = null
# A small random amount added to the first order of the turns, so of two
# turns as good the one tried first, and played, is not always the same and
# two games are not the same; 0 in the tests
var noise = 3.0

var me = 1
var nodes = 0
var deadline = 0
var out_of_time = false

func choose(board):
    me = board.player()
    nodes = 0
    deadline = OS.get_ticks_msec() + time_limit
    out_of_time = false

    if board.opening():
        return _opening(board)

    var moves = board.moves()

    # A turn that ends the game won is played without thinking
    for move in moves:
        board.play(move)
        var result = board.result(me)
        board.undo()

        if result.over and result.winner == me:
            return move

    var ordered = _order(board, moves)
    var best = ordered[0]

    for level in range(1, depth + 1):
        var found = _root(board, ordered, level)

        if found is GDScriptFunctionState:
            found = yield(found, "completed")

        if out_of_time and level > 1:
            break

        best = found.move
        ordered = found.order

    return best

# The cirya of the opponent goes to a corner, as in Tak
func _opening(board):
    var size = board.size
    var corners = [0, size - 1, size * (size - 1), size * size - 1]

    if noise > 0:
        corners.shuffle()

    for index in corners:
        if board.stacks[index].empty():
            return board.square_name(index)

    return board.moves()[0]

# One search of the whole tree to that depth, from the best turns of the last
# one; it gives the best turn and the turns in their new order. A turn that
# cannot be better than the best one is cut short, and then its value is
# only a bound: the best turn only changes for one strictly better
func _root(board, moves, level):
    var scored = []
    var alpha = -WIN * 2
    var best = moves[0]

    for move in moves:
        board.play(move)
        var value = _negamax(board, level - 1, -WIN * 2, -alpha, 3 - me)

        if value is GDScriptFunctionState:
            value = yield(value, "completed")

        value = -value
        board.undo()
        scored.append([value, move])

        if value > alpha:
            alpha = value
            best = move

        if out_of_time and level > 1:
            break

    scored.sort_custom(self, "_by_value")
    var order = [best]

    for pair in scored:
        if pair[1] != best:
            order.append(pair[1])

    for move in moves:
        if !order.has(move):
            order.append(move)

    return {"move": best, "order": order}

func _by_value(a, b):
    return a[0] > b[0]

# The value of the position for the player to move, looking that many turns
# ahead; the player who just moved may have ended the game
func _negamax(board, level, alpha, beta, player):
    nodes += 1

    if yield_every > 0 and tree and nodes % yield_every == 0:
        yield(tree, "idle_frame")

    if nodes % 256 == 0 and OS.get_ticks_msec() > deadline:
        out_of_time = true

    var result = board.result(3 - player)

    if result.over:
        if result.winner == 0:
            return 0

        # Sooner wins and later losses are better
        return (WIN + level) if result.winner == player else -(WIN + level)

    if level == 0 or out_of_time:
        return evaluate(board, player)

    var best = -WIN * 2

    for move in board.moves():
        board.play(move)
        var value = _negamax(board, level - 1, -beta, -alpha, 3 - player)

        if value is GDScriptFunctionState:
            value = yield(value, "completed")

        value = -value
        board.undo()

        if value > best:
            best = value

        alpha = max(alpha, value)

        if alpha >= beta:
            break

    return best

# The turns in the order worth trying first: by what each one leaves at once
func _order(board, moves):
    var scored = []

    for move in moves:
        board.play(move)
        scored.append([-evaluate(board, 3 - me) + (randf() * noise if noise > 0 else 0.0), move])
        board.undo()

    scored.sort_custom(self, "_by_value")
    var order = []

    for pair in scored:
        order.append(pair[1])

    return order

# How good the position is for the player to move, without looking ahead.
# It is the opposite for the other player, as negamax needs, but for the
# move: one empty square from a Londë, the player to move closes it
func evaluate(board, player):
    var other = 3 - player
    var mine = distance(board, player)

    if mine <= 1 and board.fleets[player].ciryar > 0:
        return WIN / 2

    var theirs = distance(board, other)

    # Two squares that each close a Londë of the other one cannot both be blocked
    if theirs == 1 and threats(board, other) >= 2:
        return -WIN / 2

    var value = ROAD[min(mine, ROAD.size() - 1)] - ROAD[min(theirs, ROAD.size() - 1)]

    # The count of flat ciryar matters more as the fleets run out
    var left = board.fleets[1].ciryar + board.fleets[2].ciryar
    var full = Rules.fleet(board.size)[0] * 2
    var flats = (board.flat_count(player) - board.flat_count(other)) * FLAT * (1.0 + 2.0 * (1.0 - float(left) / full))
    value += flats

    var centre = (board.size - 1) / 2.0

    for index in range(board.stacks.size()):
        var stack = board.stacks[index]

        if stack.empty():
            continue

        var top = int(stack.back()[1])
        var side = 1 if top == player else -1
        var own = 0

        for stone in stack:
            if int(stone[1]) == top:
                own += 1

        value += side * (CONTROL + own * OWN_IN_STACK + (stack.size() - own) * PRISONER)
        var away = abs(index / board.size - centre) + abs(index % board.size - centre)
        value += side * CENTRE * max(0, 2 - away)

        if stack.back()[0] == "H":
            value += side * HALLACIRYA_ON_BOARD

    # The courtly way: whoever brought out the hallacirya first pays for it
    if brought_out_first(board, player):
        value -= HALLACIRYA_FIRST
    elif brought_out_first(board, other):
        value += HALLACIRYA_FIRST

    # With Henneth Annûn, a hallacirya still in the fleet after its turn is lost
    if board.henneth_annun:
        for each in [player, other]:
            if board.turn > Rules.hallacirya_turn(each) and board.fleets[each].hallaciryar > 0:
                value -= HALLACIRYA_LOST if each == player else -HALLACIRYA_LOST

    return value

# The player has brought out a hallacirya while the opponent keeps all its
# own. With Henneth Annûn the rule says when each one comes out
func brought_out_first(board, player):
    if board.henneth_annun:
        return false

    var full = Rules.fleet(board.size)[1]
    return board.fleets[player].hallaciryar < full and board.fleets[3 - player].hallaciryar == full

# The empty squares where a cirya of the player would close a Londë
func threats(board, player):
    var count = 0

    for index in range(board.stacks.size()):
        if board.stacks[index].empty():
            board.stacks[index] = ["C" + str(player)]

            if distance(board, player) == 0:
                count += 1

            board.stacks[index] = []

    return count

# The squares the player still has to fill to make a Londë: the shortest way
# between two opposite sides, where its own squares cost nothing, empty ones
# one, and stacks of the opponent that can be covered two. A tampa, a
# hallacirya or a full nossë of the opponent cannot be crossed
func distance(board, player):
    var size = board.size
    var costs = []

    for index in range(board.stacks.size()):
        costs.append(_cost(board, index, player))

    return int(min(_shortest(costs, size, true), _shortest(costs, size, false)))

func _cost(board, index, player):
    var stack = board.stacks[index]

    if stack.empty():
        return 1

    var top = stack.back()

    if top[0] != "T" and int(top[1]) == player:
        return 0

    if top[0] == "H" or (top[0] == "T" and int(top[1]) != player):
        return BLOCKED

    if !board.unlimited and stack.size() >= board.size:
        return BLOCKED

    return 2

# A shortest path from one side to the other, by rank or by file, with a
# double-ended queue: costs are 0, 1, 2 or blocked
func _shortest(costs, size, by_rank):
    var best = []

    for i in range(costs.size()):
        best.append(BLOCKED)

    var queue = []

    for i in range(size):
        var index = i if by_rank else i * size

        if costs[index] < BLOCKED:
            best[index] = costs[index]
            queue.append(index)

    var answer = BLOCKED

    while queue:
        # Small queues: the cheapest first is enough
        var at = 0

        for i in range(1, queue.size()):
            if best[queue[i]] < best[queue[at]]:
                at = i

        var index = queue[at]
        queue.remove(at)
        var row = index / size
        var column = index % size

        if (row if by_rank else column) == size - 1:
            answer = min(answer, best[index])
            continue

        for step in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
            var next_row = row + step[0]
            var next_column = column + step[1]

            if next_row < 0 or next_column < 0 or next_row >= size or next_column >= size:
                continue

            var next = next_row * size + next_column

            if costs[next] >= BLOCKED:
                continue

            var cost = best[index] + costs[next]

            if cost < best[next]:
                best[next] = cost
                queue.append(next)

    return answer
