tool
extends Spatial

# The squares of the board: a tile (an Area) for every one, built when the
# scene starts so their size follows the board

export(int) var columns = 5
export(int) var rows = 5
export(bool) var auto = true

const TILE_SIZE = 2.35
const BORDER_WIDTH = 0.04
const TILE_STEP = TILE_SIZE + BORDER_WIDTH

var tile_scene = preload("res://Tile.tscn")
# tiles[row][column]
var tiles = []

func _ready():
    var old = get_node_or_null("Tiles")

    if old and auto:
        remove_child(old)
        old.queue_free()

    var container = get_node_or_null("Tiles")

    if container:
        return

    container = Spatial.new()
    container.name = "Tiles"

    if auto:
        container.translation = Vector3(-(rows * TILE_STEP) / 2 + TILE_STEP / 2, -0.7, -(columns * TILE_STEP) / 2 + TILE_STEP / 2)

    add_child(container)
    container.set_owner(get_tree().edited_scene_root)

    for row in range(rows):
        tiles.append([])

        for column in range(columns):
            var tile = tile_scene.instance()
            tile.translation = Vector3(row * TILE_STEP, 0, column * TILE_STEP)
            tile.visible = false
            tile.row = row
            tile.column = column
            container.add_child(tile)
            tile.set_owner(get_tree().edited_scene_root)
            tiles[row].append(tile)

func tile(square):
    return tiles[square.x][square.y]
