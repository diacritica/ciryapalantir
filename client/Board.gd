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

# The schematic board: as big as the wooden one, light and plain, with thick
# black lines on the tiles and the names of the files and ranks outside the
# grid, as the player sees it. Lengths in units of the board
const BOARD_SIZE = 17.64
const BOARD_TOP = 0.355
const SCHEMATIC_BOARD_COLOR = Color(0.96, 0.95, 0.91)
const SCHEMATIC_LINE_COLOR = Color(0.03, 0.03, 0.03)
const SCHEMATIC_LINE = 0.06
const SCHEMATIC_FRAME = 0.14
const SCHEMATIC_NAMES_OUT = 0.6
const SCHEMATIC_FONT_SIZE = 110
# Seconds the pictures of the board are drawn on every frame
const RENDER_TIME = 0.5

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
# of the last rank, so its near edge and its left are the other ones. The
# schematic board has them printed
func show_coordinates(shown, player):
    shown = shown and !has_node("Schematic")

    if shown and !has_node("Coordinates"):
        _draw_coordinates(player)

    if has_node("Coordinates"):
        $Coordinates.visible = shown

# The schematic board takes the place of the wooden one, which stays as what
# the pieces rest on
func set_schematic(on, player):
    $"tabletop-5x5-wood/5x5-wood".visible = !on

    if on and !has_node("Schematic"):
        add_child(_schematic_board(player))
    elif !on and has_node("Schematic"):
        var board = $Schematic
        remove_child(board)
        board.queue_free()

    if has_node("Coordinates"):
        $Coordinates.visible = false

    for row in tiles:
        for tile in row:
            tile.set_schematic(on)

func _schematic_board(player):
    var board = Spatial.new()
    board.name = "Schematic"

    var plain = SpatialMaterial.new()
    plain.albedo_color = SCHEMATIC_BOARD_COLOR
    plain.roughness = 1.0

    # The grid lies on the body with room enough for the depth of the far
    # camera, or both would show through each other
    var body_top = BOARD_TOP - 0.03
    var box = CubeMesh.new()
    box.size = Vector3(BOARD_SIZE, body_top, BOARD_SIZE)
    var body = MeshInstance.new()
    body.mesh = box
    body.material_override = plain
    body.translation.y = body_top / 2
    board.add_child(body)

    var resolution = COORDINATES_RESOLUTION
    var viewport = Viewport.new()
    viewport.size = Vector2(BOARD_SIZE, BOARD_SIZE) * resolution
    viewport.usage = Viewport.USAGE_2D
    viewport.render_target_v_flip = true
    _render_for_a_while(viewport)

    var background = ColorRect.new()
    background.color = SCHEMATIC_BOARD_COLOR
    background.rect_size = viewport.size
    viewport.add_child(background)

    # The lines between the tiles, and a thicker frame around them
    var grid = Vector2(rows, columns) * TILE_STEP * resolution
    var corner = (viewport.size - grid) / 2
    var line = SCHEMATIC_LINE * resolution
    var frame = SCHEMATIC_FRAME * resolution

    for row in range(rows + 1):
        var width = frame if row == 0 or row == rows else line
        viewport.add_child(_bar(Vector2(corner.x + row * TILE_STEP * resolution - width / 2, corner.y - frame / 2), Vector2(width, grid.y + frame)))

    for column in range(columns + 1):
        var width = frame if column == 0 or column == columns else line
        viewport.add_child(_bar(Vector2(corner.x - frame / 2, corner.y + column * TILE_STEP * resolution - width / 2), Vector2(grid.x + frame, width)))

    # The files along the near edge and the ranks along the right one, in the
    # middle of their squares
    var font = DynamicFont.new()
    font.font_data = load("res://assets/interface/WorkSans-Regular.ttf")
    font.size = SCHEMATIC_FONT_SIZE
    var out = SCHEMATIC_NAMES_OUT * resolution
    var step = TILE_STEP * resolution
    var near = corner.x - out if player != 2 else corner.x + grid.x + out
    var right = corner.y + grid.y + out if player != 2 else corner.y - out

    for column in range(columns):
        viewport.add_child(_name(FILES[column], Vector2(near, corner.y + (column + 0.5) * step), font, player))

    for row in range(rows):
        viewport.add_child(_name(str(row + 1), Vector2(corner.x + (row + 0.5) * step, right), font, player))

    var material = SpatialMaterial.new()
    material.flags_albedo_tex_force_srgb = true
    material.roughness = 1.0
    material.albedo_texture = viewport.get_texture()

    var quad = QuadMesh.new()
    quad.size = Vector2(BOARD_SIZE, BOARD_SIZE)
    var top = MeshInstance.new()
    top.mesh = quad
    top.material_override = material
    top.rotation_degrees.x = -90
    top.translation.y = BOARD_TOP
    top.add_child(viewport)
    board.add_child(top)
    return board

# A picture that does not change is drawn once, but a single frame can be
# missed, as in a window that is not drawn just then: it is drawn on every
# frame for a while, and then once more
func _render_for_a_while(viewport):
    viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
    get_tree().create_timer(RENDER_TIME).connect("timeout", viewport, "set", ["render_target_update_mode", Viewport.UPDATE_ONCE])

func _bar(position, size):
    var bar = ColorRect.new()
    bar.color = SCHEMATIC_LINE_COLOR
    bar.rect_position = position
    bar.rect_size = size
    return bar

# A black name centred on that point, upright for the player
func _name(text, center, font, player):
    var label = Label.new()
    label.text = text
    label.set("custom_fonts/font", font)
    label.set("custom_colors/font_color", SCHEMATIC_LINE_COLOR)
    label.rect_size = label.get_minimum_size()
    label.rect_pivot_offset = label.rect_size / 2
    label.rect_rotation = -90 if player == 2 else 90
    label.rect_position = center - label.rect_size / 2
    return label

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
    _render_for_a_while(viewport)

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
