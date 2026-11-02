extends Spatial

# The squares of the board: a tile (an Area) for every one, built when the
# game starts so their number follows the size of the board. Over them, the
# coordinates can be shown as if written on the board: the files along the
# near edge and the ranks along the left one, as each player sees it

export(int) var columns = 5
export(int) var rows = 5

const TILE_SIZE = 2.35
const BORDER_WIDTH = 0.04
const TILE_STEP = TILE_SIZE + BORDER_WIDTH
const TILES_HEIGHT = -0.7

const FILES = "abcdefghi"
# The coordinates lie this high, just over the board
const COORDINATES_HEIGHT = 0.39
# Pixels of their picture for every unit of the board, and the size of the
# letters in it, in the sans of the interface, whose figures stand on the
# line. Labels centre the whole line, so each name is raised to centre its
# own strokes: their height over the line, in parts of the size
const COORDINATES_RESOLUTION = 128
const COORDINATES_FONT_SIZE = 84
const SHORT_LETTERS = "aceimnorsuvwxz"
const SHORT_HEIGHT = 0.53
const TALL_HEIGHT = 0.72
const FIGURE_HEIGHT = 0.66
# A technical overlay, apart from the drawing of the board: white in the
# blue of the shield of Cirya, with a white ring, as the shield has
const COORDINATES_COLOR = Color(1, 1, 1)
const COORDINATES_BADGE_COLOR = Color(0.06, 0.27, 0.53)
const COORDINATES_RING = 4
# The grid drawn on the board is this much bigger than the tiles, from the
# corner of a1. The coordinates follow the drawing, out of the grid in the
# band of the frame, so no piece covers them: the files along the near edge
# and the ranks along the right one. Each is this part of a drawn square
# out of the grid, and in the middle of the first third of its square, from
# the left for the files and from the near edge for the ranks, so they keep
# clear of the ornaments in the middle of each side. The picture reaches
# this far out of the grid
const DRAWN_SCALE = 1.025
const COORDINATES_MARGIN = 0.28
const COORDINATES_ALONG = 1.0 / 6
const COORDINATES_REACH = 0.5

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

# The coordinates as the player sees the board: player 2 looks from the side
# of the last rank, so its near edge and its left are the other ones
func show_coordinates(shown, player):
    if shown and !has_node("Coordinates"):
        _draw_coordinates(player)

    if has_node("Coordinates"):
        $Coordinates.visible = shown

# A picture of the whole board, drawn once in a viewport and laid on it. Rows
# are the ranks, along x, and columns the files, along z. Player 1 has the
# first rank near and the first file on its left; player 2 the last ones,
# so for it everything is mirrored, and each name stays by its own file or
# rank. The top of the names points away from the player
func _draw_coordinates(player):
    var step = TILE_STEP * DRAWN_SCALE * COORDINATES_RESOLUTION
    var reach = step * COORDINATES_REACH
    var viewport = Viewport.new()
    viewport.size = Vector2(rows, columns) * step + Vector2(reach, reach) * 2
    viewport.transparent_bg = true
    viewport.usage = Viewport.USAGE_2D
    viewport.render_target_v_flip = true
    viewport.render_target_update_mode = Viewport.UPDATE_ONCE

    var font = DynamicFont.new()
    font.font_data = load("res://assets/interface/WorkSans-Regular.ttf")
    font.size = COORDINATES_FONT_SIZE

    var out = reach - step * COORDINATES_MARGIN
    var along = COORDINATES_ALONG if player != 2 else 1 - COORDINATES_ALONG
    var near = out if player != 2 else viewport.size.x - out
    var right = viewport.size.y - out if player != 2 else out

    for column in range(columns):
        viewport.add_child(_coordinate(FILES[column], Vector2(near, reach + (column + along) * step), font, player))

    for row in range(rows):
        viewport.add_child(_coordinate(str(row + 1), Vector2(reach + (row + along) * step, right), font, player))

    var material = SpatialMaterial.new()
    material.flags_transparent = true
    material.flags_unshaded = true
    # The viewport draws in sRGB, not in the linear colour of the scene
    material.flags_albedo_tex_force_srgb = true
    material.albedo_texture = viewport.get_texture()

    var quad = QuadMesh.new()
    quad.size = viewport.size / COORDINATES_RESOLUTION

    var picture = MeshInstance.new()
    picture.name = "Coordinates"
    picture.mesh = quad
    picture.material_override = material
    picture.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
    picture.rotation_degrees.x = -90
    picture.translation = Vector3(rows, 0, columns) * TILE_STEP * (DRAWN_SCALE - 1) / 2
    picture.translation.y = COORDINATES_HEIGHT
    picture.add_child(viewport)
    add_child(picture)

# A round badge with the name, centred on that point of the picture and
# upright for the player
func _coordinate(text, center, font, player):
    var label = Label.new()
    label.text = text
    label.align = Label.ALIGN_CENTER
    label.valign = Label.VALIGN_CENTER
    label.set("custom_fonts/font", font)
    label.set("custom_colors/font_color", COORDINATES_COLOR)

    var size = font.get_height() * 0.9
    var style = StyleBoxFlat.new()
    style.bg_color = COORDINATES_BADGE_COLOR
    style.border_color = COORDINATES_COLOR
    style.set_border_width_all(COORDINATES_RING)
    style.set_corner_radius_all(int(size / 2))
    style.anti_aliasing = true

    var badge = Panel.new()
    badge.name = text
    badge.set("custom_styles/panel", style)
    badge.rect_size = Vector2(size, size)
    badge.rect_pivot_offset = badge.rect_size / 2
    badge.rect_rotation = -90 if player == 2 else 90
    badge.rect_position = center - badge.rect_size / 2
    badge.add_child(label)

    var height = FIGURE_HEIGHT if text.is_valid_integer() else (SHORT_HEIGHT if text in SHORT_LETTERS else TALL_HEIGHT)
    var line_middle = (font.get_ascent() + font.get_descent()) / 2
    var strokes_middle = font.get_ascent() - height * font.size / 2
    label.rect_size = label.get_minimum_size()
    label.rect_position = (badge.rect_size - label.rect_size) / 2
    label.rect_position.y -= strokes_middle - line_middle
    return badge
