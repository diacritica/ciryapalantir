extends Reference

# The move of a turn, kept as the board when it started. What has been moved
# is worked out from the difference with the board now (Rules.move_state), so
# the player can drop and take back as many times as wanted

# The board when the turn started
var before
# The square of the nossë taken, or null for a piece from the fleet
var origin
# The piece taken from the fleet, or null for a nossë
var placed
# The tampar standing when the turn started
var tampar = []

func _init(board, piece_id, pieces):
    before = board.copy()
    origin = board.square_of(piece_id)
    placed = piece_id if origin == null else null

    for piece in pieces:
        if piece.get_notation_name() == "T" and board.square_of(piece.get_instance_id()) != null:
            tampar.append(piece.get_instance_id())

func started(board):
    return !before.equals(board)

# The pieces that can be taken once the move has started: the piece from the
# fleet, or the nossë it started from and the stones dropped along the way
func includes(board, piece_id):
    if placed != null:
        return piece_id == placed

    var square = board.square_of(piece_id)

    if square == null:
        return false

    if square == origin:
        return true

    return board.stack(square).find(piece_id) >= before.stack(square).size()

# A tampa lies flat while the hallacirya of this move is on it, and stands up
# again when the hallacirya goes back
func sync_tampar(board):
    for piece_id in tampar:
        var ids = board.stack(board.square_of(piece_id))
        var covered = ids.find(piece_id) < ids.size() - 1
        var piece = instance_from_id(piece_id)

        if piece.block == covered:
            piece.toggle_block()
