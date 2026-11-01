extends Reference

# The stacks on the board as piece instance ids, bottom piece first. It knows
# nothing about the scene: a piece only needs a player and get_notation_name()

# stacks[row][column]
var stacks = []

func _init(size = 0):
    for row in range(size):
        stacks.append([])

        for column in range(size):
            stacks[row].append([])

func size():
    return stacks.size()

func stack(square):
    return stacks[square.x][square.y]

# The square of the piece, or null when it is not on the board
func square_of(piece_id):
    for row in range(size()):
        for column in range(size()):
            if stacks[row][column].has(piece_id):
                return Vector2(row, column)

    return null

# The piece and the ones above it
func pieces_from(piece_id):
    var stack = stack(square_of(piece_id))
    return stack.slice(stack.find(piece_id), stack.size() - 1)

# The player with the piece on top of the square, and 0 when it is empty
func owner(square):
    var stack = stack(square)
    return instance_from_id(stack.back()).player if stack else 0

# Puts the pieces, in order, on top of the square
func put(piece_ids, square):
    for row in stacks:
        for stack in row:
            for piece_id in piece_ids:
                stack.erase(piece_id)

    for piece_id in piece_ids:
        stack(square).append(piece_id)

func copy():
    var board = get_script().new()
    board.stacks = stacks.duplicate(true)
    return board

func equals(other):
    return stacks == other.stacks
