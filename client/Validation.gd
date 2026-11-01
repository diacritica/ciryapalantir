extends Node

onready var Global = get_node("/root/Global")

func can_move(piece_id):
    var piece = instance_from_id(piece_id)
    var is_piece = piece.collision_layer == 2
    var tile = Global.get_piece_tile(piece_id)

    if Global.disable_move or !is_piece:
        return false

    # Once the move has started only its pieces can be taken, to keep
    # breaking it or to take a drop back
    if Global.move_started():
        return Global.part_of_move(piece_id)

    # The opening only places a flat cirya from the fleet of the opponent
    if Global.opening():
        return !tile and piece.player != Global.player and piece.get_notation_name() == 'C'

    # Check if the player own the nosse
    var owner = piece.player
    if tile:
        owner = Global.tile_owner(tile.row, tile.column)

    if owner != Global.player and owner != null:
        return false

    # No more stones than the board size can be carried
    if tile:
        var piece_ids = Global.board_state[tile.row][tile.column]
        if piece_ids.size() - piece_ids.find(piece_id) > Global.board_state.size():
            return false

    return true

# A drop is valid when the board it leaves is a legal move, even half done
func can_drop(row, column):
    var state = Global.board_after_drop(Global.get_dragging_nosse_pieces_ids(), row, column)
    return move_state(Global.move, state) != null

# What the move does to the board, compared with the board when it started.
# The pieces moved are worked out from the difference, so the player can drop
# and take back as many times as wanted.
# Returns null when the state is not a legal move, even half done, {} when
# nothing has moved, {"placed", "square"} for a piece from the fleet and
# {"origin", "count", "direction", "drops"} for a nossë
func move_state(move, state):
    if !move:
        return null

    var before = move.before
    var size = before.size()
    var changed = []

    for row in range(size):
        for column in range(before[row].size()):
            if !same(state[row][column], before[row][column]):
                changed.append(Vector2(row, column))

    if changed.empty():
        return {}

    # A piece from the fleet on an empty square
    if move.placed != null:
        var square = changed[0]
        var now = state[square.x][square.y]

        if changed.size() != 1 or now.size() != 1 or now[0] != move.placed or !before[square.x][square.y].empty():
            return null

        var placed = instance_from_id(move.placed)

        if Global.opening():
            if placed.player == Global.player or placed.get_notation_name() != 'C':
                return null
        elif placed.player != Global.player:
            return null

        return {"placed": move.placed, "square": square}

    var origin = move.origin

    if origin == null or !changed.has(origin) or changed.size() < 2:
        return null

    # The origin keeps the bottom of its nossë and the rest is carried
    var left = state[origin.x][origin.y]
    var had = before[origin.x][origin.y]

    if left.size() >= had.size() or !same(left, head(had, left.size())):
        return null

    var carried = tail(had, left.size())

    if carried.size() > size:
        return null

    if instance_from_id(had.back()).player != Global.player:
        return null

    # The other squares changed go in a row from the origin, one after another,
    # each one with what it had plus at least one stone
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
        if !changed.has(square):
            return null

        var now = state[square.x][square.y]
        var was = before[square.x][square.y]

        if now.size() <= was.size() or !same(head(now, was.size()), was):
            return null

        var drop = tail(now, was.size())

        if !was.empty():
            var top = was.back()

            # Nothing goes over a hallacirya, and over a tampa only a lone
            # hallacirya, which flattens it
            if instance_from_id(top).get_notation_name() == 'H':
                return null

            if move.tampar.has(top) and !(drop.size() == 1 and instance_from_id(drop[0]).get_notation_name() == 'H'):
                return null

        drops.append(drop.size())
        dropped += drop
        square += direction

    # The stones are dropped in the order they were carried, the bottom ones first
    if !same(dropped, carried):
        return null

    return {"origin": origin, "count": carried.size(), "direction": direction, "drops": drops}

func same(a, b):
    if a.size() != b.size():
        return false

    for i in range(a.size()):
        if a[i] != b[i]:
            return false

    return true

func head(list, count):
    var res = []

    for i in range(count):
        res.append(list[i])

    return res

func tail(list, from):
    var res = []

    for i in range(from, list.size()):
        res.append(list[i])

    return res
