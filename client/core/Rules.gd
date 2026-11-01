extends Reference

# Which pieces a player can take and where they can go. Everything comes as
# arguments, so the rules can be tested without a scene

const Notation = preload("res://core/Notation.gd")

# Whether the player can take this piece, with the ones above it
static func can_take(piece_id, board, move, player, opening):
    var piece = instance_from_id(piece_id)
    var square = board.square_of(piece_id)

    # Once the move has started only its pieces can be taken, to keep
    # breaking it or to take a drop back
    if move and move.started(board):
        return move.includes(board, piece_id)

    # The opening only places a flat cirya from the fleet of the opponent
    if opening:
        return square == null and piece.player != player and piece.get_notation_name() == "C"

    if square == null:
        return piece.player == player

    # A nossë of the player, and no more stones than the board size
    var stack = board.stack(square)
    return board.owner(square) == player and stack.size() - stack.find(piece_id) <= board.size()

# Whether the pieces in the hand can go on the square: the board they leave
# has to be a legal move, even half done
static func can_drop(hand, square, board, move, player, opening):
    var after = board.copy()
    after.put(hand, square)
    return move_state(move, after, player, opening) != null

# What the move does to the board, compared with the board when it started.
# It is null when that is not a legal move, even half done, and {} when
# nothing has moved. Otherwise {"stone", "square"} for a piece from the fleet
# and {"origin", "count", "direction", "drops"} for a nossë
static func move_state(move, board, player, opening):
    if !move:
        return null

    var changed = []

    for row in range(board.size()):
        for column in range(board.size()):
            var square = Vector2(row, column)

            if board.stack(square) != move.before.stack(square):
                changed.append(square)

    if changed.empty():
        return {}

    if move.placed != null:
        return _placement(move, board, changed, player, opening)

    return _nosse(move, board, changed, player)

# A piece from the fleet on a square that was empty
static func _placement(move, board, changed, player, opening):
    var square = changed[0]
    var piece = instance_from_id(move.placed)

    if changed.size() != 1 or board.stack(square) != [move.placed]:
        return null

    if opening and (piece.player == player or piece.get_notation_name() != "C"):
        return null

    if !opening and piece.player != player:
        return null

    return {"stone": piece.get_notation_name(), "square": square}

static func _nosse(move, board, changed, player):
    var origin = move.origin

    if !changed.has(origin) or changed.size() < 2:
        return null

    # The origin keeps the bottom of its nossë and the rest is carried
    var left = board.stack(origin)
    var had = move.before.stack(origin)

    if left.size() >= had.size() or left != _head(had, left.size()):
        return null

    var carried = _tail(had, left.size())

    if carried.size() > board.size() or instance_from_id(had.back()).player != player:
        return null

    # The other squares changed go in a row from the origin, one after
    # another, each one with what it had plus at least one stone
    var direction = null

    for square in changed:
        if abs(square.x - origin.x) + abs(square.y - origin.y) == 1:
            direction = square - origin

    if direction == null:
        return null

    var drops = []
    var dropped = []
    var square = origin + direction

    for i in range(changed.size() - 1):
        var now = board.stack(square) if changed.has(square) else []
        var was = move.before.stack(square) if changed.has(square) else []

        if !changed.has(square) or now.size() <= was.size() or _head(now, was.size()) != was:
            return null

        var drop = _tail(now, was.size())

        if !was.empty() and !_can_cover(was.back(), drop, move.tampar):
            return null

        drops.append(drop.size())
        dropped += drop
        square += direction

    # The stones are dropped in the order they were carried, the bottom ones first
    if dropped != carried:
        return null

    return {"origin": origin, "count": carried.size(), "direction": direction, "drops": drops}

# Nothing goes over a hallacirya, and over a tampa only a lone hallacirya,
# which flattens it
static func _can_cover(top, drop, tampar):
    if instance_from_id(top).get_notation_name() == "H":
        return false

    if tampar.has(top):
        return drop.size() == 1 and instance_from_id(drop[0]).get_notation_name() == "H"

    return true

# Where the pieces go when the opponent plays a turn: a list of {"piece",
# "square"} in order, empty when the turn cannot be played. A placement takes
# a piece from the fleet, in the opening a flat cirya of the other player, and
# "stand" tells when it is a tampa
static func replay(turn, player, opening, board, fleet):
    var parsed = Notation.parse(turn)

    if parsed.has("stone"):
        var owner = 3 - player if opening else player
        var kind = "H" if parsed.stone == "H" else "C"

        for piece in fleet:
            var piece_id = piece.get_instance_id()

            if piece.player == owner and piece.get_notation_name() == kind and board.square_of(piece_id) == null:
                return [{"piece": piece_id, "square": parsed.square, "stand": parsed.stone == "T"}]

        return []

    if parsed.has("from"):
        var stack = board.stack(parsed.from)
        var carried = _tail(stack, max(stack.size() - parsed.count, 0))
        var steps = []
        var square = parsed.from

        for count in parsed.drops:
            square += parsed.step

            for piece_id in _head(carried, min(count, carried.size())):
                steps.append({"piece": piece_id, "square": square, "stand": false})

            carried = _tail(carried, min(count, carried.size()))

        return steps

    return []

static func _head(list, count):
    var res = []

    for i in range(count):
        res.append(list[i])

    return res

static func _tail(list, from):
    var res = []

    for i in range(from, list.size()):
        res.append(list[i])

    return res
