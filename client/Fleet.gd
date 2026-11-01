tool
extends Spatial

# The tray of a player with the pieces still to place. Each row of the layout
# lists its stacks: the number of ciryar in each one, or -1 for a hallacirya

const TRAYS = {
    5: ["res://assets/tray/tray-5x5.tscn", [[3, 3, 3, -1], [3, 3, 3, 3]]],
    6: ["res://assets/tray/tray-6x6.tscn", [[3, 3, -1, -1], [3, 3, 3, 3], [3, 3, 3, 3]]],
    7: ["res://assets/tray/tray-7x7.tscn", [[3, 3, 3, 3, -1], [3, 3, 3, 3, 3], [3, 3, 3, 4, -1]]],
}
const HALLACIRYA = -1

const FIRST_STACK = Vector3(2, 2, -4)
const ROW_OFFSET = -2.5
const STACK_OFFSET = 2.2
const PIECE_HEIGHT = 0.3

export(int) var traysize = 5
export(String) var colour = "W"
# "B" for the basic pieces. The VIP ones are not finished: CiryaLV.tscn does not exist
export(String) var style = "B"

var white = true

func _ready():
    white = colour == "W"
    add_child(load(TRAYS[traysize][0]).instance())

    for row in range(TRAYS[traysize][1].size()):
        var stacks = TRAYS[traysize][1][row]

        for column in range(stacks.size()):
            var base = FIRST_STACK + Vector3(ROW_OFFSET * row, 0, STACK_OFFSET * column)

            if stacks[column] == HALLACIRYA:
                var hallacirya = _new_piece(true)
                hallacirya.translation = base + Vector3(rand_range(-0.002, 0.002), 0, rand_range(-0.02, 0.02))
                hallacirya.rotation.y = 110
                add_child(hallacirya)
                continue

            for level in range(stacks[column]):
                var cirya = _new_piece(false)
                cirya.translation = base + Vector3(rand_range(-0.002, 0.002), PIECE_HEIGHT * level, rand_range(-0.02, 0.02))
                cirya.rotation.y = randi() % 5 + 1
                add_child(cirya)

func _new_piece(hallacirya):
    var scene

    if style != "B":
        scene = "res://HallaciryaLV.tscn" if hallacirya else "res://CiryaLV.tscn"
    elif hallacirya:
        scene = "res://units/light-hallacirya-tree.tscn" if white else "res://units/hallacirya-b-basic.tscn"
    else:
        scene = "res://units/cirya-w-basic.tscn" if white else "res://units/cirya-b-basic.tscn"

    var piece = load(scene).instance()
    piece.player = 1 if white else 2
    piece.fleet = self
    return piece
