extends Spatial

# The squares of the board: a tile (an Area) for every one, built when the
# game starts so their number follows the size of the board

export(int) var columns = 5
export(int) var rows = 5

const TILE_SIZE = 2.35
const BORDER_WIDTH = 0.04
const TILE_STEP = TILE_SIZE + BORDER_WIDTH
const TILES_HEIGHT = -0.7

var tile_scene = preload("res://Tile.tscn")
# tiles[row][column]
var tiles = []

func _ready():
    var container = Spatial.new()
    container.name = "Tiles"
    container.translation = Vector3((TILE_STEP - rows * TILE_STEP) / 2, TILES_HEIGHT, (TILE_STEP - columns * TILE_STEP) / 2)
    add_child(container)

    for row in range(rows):
        tiles.append([])

        for column in range(columns):
            var tile = tile_scene.instance()
            # Tile.tscn sets the height that puts the highlight just over the board
            tile.translation.x = row * TILE_STEP
            tile.translation.z = column * TILE_STEP
            tile.row = row
            tile.column = column
            tile.hide_highlight()
            container.add_child(tile)
            tiles[row].append(tile)

func tile(square):
    return tiles[square.x][square.y]
