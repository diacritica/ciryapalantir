extends Reference

# The board of a status of the server, made with the pieces of this client.
# The server is the reference: when the boards differ, the client takes its
# board. The status writes the board by rank and file, bottom stone first, and
# a stone is its kind and its owner: status.board["3"]["c"] = ["C1", "T2"]

const BoardState = preload("res://core/BoardState.gd")
const Notation = preload("res://core/Notation.gd")

# The stones of the status on a square, like ["C1", "T2"]
static func stones(board_data, square):
    var name = Notation.square_name(square)
    return board_data.get(name.substr(1), {}).get(name.substr(0, 1), [])

# Whether the board has the same stones as the status
static func matches(board_data, board):
    for row in range(board.size()):
        for column in range(board.size()):
            var square = Vector2(row, column)
            var wanted = stones(board_data, square)
            var have = board.stack(square)

            if wanted.size() != have.size():
                return false

            for i in range(have.size()):
                if _stone(have[i]) != wanted[i]:
                    return false

    return true

# The board of the status with these pieces, and the pieces to turn over
# (toggle_block) so that tampar stand and ciryar lie: {"board", "turn_over"}.
# Pieces already at the bottom of the right stack stay there. Null when the
# client has not enough pieces for the status
static func board(board_data, current, pieces):
    var target = BoardState.new(current.size())
    var used = {}

    # The pieces already in place
    for row in range(current.size()):
        for column in range(current.size()):
            var square = Vector2(row, column)
            var wanted = stones(board_data, square)
            var have = current.stack(square)

            for i in range(min(wanted.size(), have.size())):
                if !_fits(have[i], wanted[i]):
                    break

                target.stack(square).append(have[i])
                used[have[i]] = true

    # The rest, with pieces from the board first and then from the fleet
    var spare = []

    for piece in pieces:
        if !used.has(piece.get_instance_id()) and current.square_of(piece.get_instance_id()) != null:
            spare.append(piece.get_instance_id())

    for piece in pieces:
        if !used.has(piece.get_instance_id()) and current.square_of(piece.get_instance_id()) == null:
            spare.append(piece.get_instance_id())

    for row in range(current.size()):
        for column in range(current.size()):
            var square = Vector2(row, column)
            var wanted = stones(board_data, square)

            for i in range(target.stack(square).size(), wanted.size()):
                var found = null

                for piece_id in spare:
                    if _fits(piece_id, wanted[i]):
                        found = piece_id
                        break

                if found == null:
                    return null

                spare.erase(found)
                target.stack(square).append(found)

    # Tampar stand on the board, and every other cirya lies
    var turn_over = []

    for piece in pieces:
        var piece_id = piece.get_instance_id()
        var square = target.square_of(piece_id)
        var standing = square != null and stones(board_data, square)[target.stack(square).find(piece_id)][0] == "T"

        if piece.type == "CIRYA" and piece.block != standing:
            turn_over.append(piece_id)

    return {"board": target, "turn_over": turn_over}

# Differences between the fleets of the status and the pieces out of the
# board, as text. Empty when they match
static func fleet_differences(fleets, board, pieces):
    var differences = []

    for player in [1, 2]:
        var counts = {"ciryar": 0, "hallaciryar": 0}

        for piece in pieces:
            if piece.player == player and board.square_of(piece.get_instance_id()) == null:
                counts["hallaciryar" if piece.type == "HALLACIRYA" else "ciryar"] += 1

        var fleet = fleets.get(str(player), {})

        for kind in counts:
            if int(fleet.get(kind, counts[kind])) != counts[kind]:
                differences.append("player %d has %d %s, the server says %d" % [player, counts[kind], kind, int(fleet[kind])])

    return differences

# A piece as the status writes it, like "T2"
static func _stone(piece_id):
    var piece = instance_from_id(piece_id)
    return piece.get_notation_name() + str(piece.player)

# Whether the piece can be that stone: the same owner, and a hallacirya for an
# H or a cirya, lying or standing, for a C or a T
static func _fits(piece_id, stone):
    var piece = instance_from_id(piece_id)
    var hallacirya = piece.type == "HALLACIRYA"
    return piece.player == int(stone[1]) and hallacirya == (stone[0] == "H")
