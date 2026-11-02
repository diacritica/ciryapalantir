extends Reference

# Which pieces a player can take and where they can go. Everything comes as
# arguments, so the rules can be tested without a scene

const Notation = preload("res://core/Notation.gd")

# With the Henneth Annûn rule each hallacirya only comes into play in one turn
# of the game: the 16th of black, who plays second, and right after it the
# 17th of white. Every turn of the game counts, so they are the 32nd and 33rd
const HENNETH_ANNUN_BLACK = 32
const HENNETH_ANNUN_WHITE = 33

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

# A square holds at most as many pieces as the board is wide, and a
# hallacirya on top, unless the variant T4K takes the limit away
static func fits(stack, size):
    var pieces = stack.size()

    if stack and instance_from_id(stack.back()).type == "HALLACIRYA":
        pieces -= 1

    return pieces <= size

# The tampar of the player standing on the board: there can be as many as
# the board is wide. Standing are the pieces in blocks, or that say so
static func tampar(board, blocks, player):
    var count = 0

    for row in range(board.size()):
        for column in range(board.size()):
            var stack = board.stack(Vector2(row, column))

            if stack:
                var top = instance_from_id(stack.back())

                if top.player == player and (blocks.has(stack.back()) if blocks != null else top.block):
                    count += 1

    return count

# The turn of the game in which the hallacirya of the player comes into play
# with the Henneth Annûn rule
static func hallacirya_turn(player):
    return HENNETH_ANNUN_WHITE if player == 1 else HENNETH_ANNUN_BLACK

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

# A turn written in a list, played on a copy of the board and checked with
# the rules, as nobody dragged it: {"error"} says why it cannot be played,
# and otherwise there are the "steps" as replay gives them, and the "board"
# and the tampar standing ("blocks", their ids) after it. Pieces are all of
# them: the ones off the board are in their fleets
static func apply_turn(turn, player, opening, board, blocks, pieces, unlimited = false):
    var parsed = Notation.parse(turn)
    var after = board.copy()
    var standing = blocks.duplicate()

    if parsed.empty():
        return {"error": "No entiendo «%s»" % turn}

    if parsed.has("stone"):
        var square = parsed.square

        if !_on(square, board):
            return {"error": "No hay ningún sat %s" % Notation.square_name(square)}

        if !board.stack(square).empty():
            return {"error": "%s no está libre" % Notation.square_name(square)}

        if opening and parsed.stone != "C":
            return {"error": "La apertura pone una cirya plana del rival"}

        if parsed.stone == "T" and tampar(board, standing, player) >= board.size():
            return {"error": "Ya hay %d tampar de quien juega en el tablero, las que puede haber" % board.size()}

        var owner = 3 - player if opening else player
        var hallacirya = parsed.stone == "H"
        var piece = null

        for piece_id in pieces:
            var each = instance_from_id(piece_id)

            if each.player == owner and (each.type == "HALLACIRYA") == hallacirya and board.square_of(piece_id) == null:
                piece = piece_id
                break

        if piece == null:
            return {"error": "No queda ninguna %s en la bandeja" % ("hallacirya" if hallacirya else "cirya")}

        after.put([piece], square)

        if parsed.stone == "T":
            standing[piece] = true

        return {"error": "", "steps": [{"piece": piece, "square": square, "stand": parsed.stone == "T"}], "board": after, "blocks": standing}

    if opening:
        return {"error": "La apertura pone una cirya plana del rival"}

    var origin = parsed.from
    var name = Notation.square_name(origin) if _on(origin, board) else ""
    var stack = board.stack(origin) if name else []
    var total = 0

    for drop in parsed.drops:
        total += drop

    if stack.empty() or instance_from_id(stack.back()).player != player:
        return {"error": "%s no es de quien juega" % name if name else "No hay ningún sat así"}

    if parsed.count > stack.size() or parsed.count > board.size():
        return {"error": "En %s no hay %d piezas que mover" % [name, parsed.count]}

    if total != parsed.count:
        return {"error": "Las piezas que se sueltan tienen que sumar %d" % parsed.count}

    var carried = _tail(stack, stack.size() - parsed.count)
    var square = origin
    var steps = []

    for count in parsed.drops:
        square += parsed.step

        if !_on(square, board):
            return {"error": "La jugada se sale del tablero"}

        var dropped = _head(carried, count)
        var under = after.stack(square)

        if under:
            var top = under.back()

            if instance_from_id(top).type == "HALLACIRYA":
                return {"error": "Nada cabe sobre la hallacirya de %s" % Notation.square_name(square)}

            if standing.has(top):
                if count != 1 or instance_from_id(dropped[0]).type != "HALLACIRYA":
                    return {"error": "Sobre la tampa de %s solo cabe la hallacirya sola" % Notation.square_name(square)}

                standing.erase(top)

        after.put(dropped, square)

        if !unlimited and !fits(after.stack(square), board.size()):
            return {"error": "En %s ya no cabe más: un nossë tiene %d piezas como mucho, y la hallacirya encima" % [Notation.square_name(square), board.size()]}

        for piece_id in dropped:
            steps.append({"piece": piece_id, "square": square, "stand": false})

        carried = _tail(carried, count)

    return {"error": "", "steps": steps, "board": after, "blocks": standing}

static func _on(square, board):
    return square.x >= 0 and square.y >= 0 and square.x < board.size() and square.y < board.size()

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
