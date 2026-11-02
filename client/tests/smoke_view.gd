extends SceneTree

# Changes the view of a game in the sandbox with its buttons, from the story
# to the schematic one and back, at once and without touching the board:
# the tavern goes and comes back, the board and the pieces turn plain and
# high contrast, and what is taken and where it can go light up strongly.
# Leaving the game goes back to the story. From the client folder:
#
#   godot --no-window --path . -s tests/smoke_view.gd

const Notation = preload("res://core/Notation.gd")

var game
var ui
var state
var settings
var before
var failures = 0

func _initialize():
    state = get_root().get_node("Match")
    settings = get_root().get_node("Settings")
    state.start_sandbox()
    before = settings.view
    settings.view = settings.STORY
    change_scene("res://Game.tscn")
    call_deferred("_play")

func check(label, condition):
    if !condition:
        failures += 1
        print("FAIL ", label)

func _play():
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    game = current_scene
    ui = game.get_node("UI")

    # A placement on the board, to see that changing the view keeps it
    check("c3 written", game.play_written("c3") == "")
    var board = state.board.copy()
    var environment = game.get_node("WorldEnvironment").environment

    ui.get_node("View/Schematic").emit_signal("pressed")
    _schematic(board)
    yield(_strong_lights(), "completed")

    ui.get_node("View/Story").emit_signal("pressed")
    check("the story is chosen", settings.view == settings.STORY)
    check("the tavern comes back", game.get_node("table-tavern2").visible and game.get_node("SpotLight").visible)
    check("with its light", game.get_node("WorldEnvironment").environment == environment)
    check("the plain table goes", !game.has_node("SchematicTable") and !game.has_node("SchematicLight"))
    check("the wooden board comes back", !game.get_node("Board").has_node("Schematic") and game.get_node("Board/tabletop-5x5-wood/5x5-wood").visible)
    check("and the wooden pieces", game.get_node("Pieces").get_child(0).get_node("Mesh").material_override == null)
    check("the story button shows chosen", ui.get_node("View/Story").modulate == ui.VIEW_CHOSEN)
    check("the board is still the same", state.board.equals(board) and state.move_notation() == "c3")

    # The schematic view lasts while in the game
    ui.get_node("View/Schematic").emit_signal("pressed")
    ui._back_to_menu()
    check("leaving the game goes back to the story", settings.view == settings.STORY)
    yield(self, "idle_frame")
    yield(self, "idle_frame")

    settings.view = before
    print("smoke view: %d failures" % failures)
    quit(1 if failures else 0)

func _schematic(board):
    check("the schematic view is chosen", settings.view == settings.SCHEMATIC)
    check("the schematic button shows chosen", ui.get_node("View/Schematic").modulate == ui.VIEW_CHOSEN and ui.get_node("View/Story").modulate == ui.VIEW_OTHER)

    for name in ["table-tavern2", "candle-tavern3", "wood-mug3", "Particles", "SpotLight", "light2"]:
        check("no %s" % name, !game.get_node(name).visible)

    var environment = game.get_node("WorldEnvironment").environment
    check("no effects", !environment.glow_enabled and !environment.ssao_enabled and !environment.dof_blur_far_enabled and !environment.dof_blur_near_enabled and !environment.fog_enabled)
    check("a plain table and an even light", game.has_node("SchematicTable") and game.has_node("SchematicLight"))
    check("the plain board instead of the wooden one", game.get_node("Board").has_node("Schematic") and !game.get_node("Board/tabletop-5x5-wood/5x5-wood").visible)

    var white = true
    var black = true

    for piece in game._pieces():
        var color = piece.get_node("Mesh").material_override.albedo_color
        var outline = piece.get_node("Mesh/Outline").material_override.get_shader_param("outline_color")

        if piece.fleet.white:
            white = white and color == piece.SCHEMATIC_WHITE and outline == piece.SCHEMATIC_BLACK
        else:
            black = black and color == piece.SCHEMATIC_BLACK and outline == piece.SCHEMATIC_WHITE

    check("white pieces pure white outlined in black", white)
    check("black pieces pure black outlined in white", black)
    check("the board is the same", state.board.equals(board) and state.move_notation() == "c3")

    # The coordinates are printed: the ones over the board are not needed
    ui.get_node("MoveEntry/Handle").emit_signal("pressed")
    check("no coordinates over the schematic board", !game.get_node("Board").has_node("Coordinates") or !game.get_node("Board/Coordinates").visible)
    ui.get_node("MoveEntry/Handle").emit_signal("pressed")

# What is taken has a thick outline of a strong colour, and the squares it
# can go to light up plain in the same colour
func _strong_lights():
    var piece = instance_from_id(state.board.stack(Notation.parse_square("c3"))[0])
    game.take(piece)
    var outline = piece.get_node("Mesh/Outline").material_override
    check("the piece taken has the strong outline", outline.get_shader_param("outline_color") == piece.HIGHLIGHT and outline.get_shader_param("outline_width") == piece.HIGHLIGHT_WIDTH)

    var tile = game.get_node("Board").tile(Notation.parse_square("c3"))
    check("its square lights up", tile.visible)
    var light = tile.get_node("MeshInstance").material_override
    check("plain and strong", light != null and light.flags_unshaded and light.albedo_color == tile.SCHEMATIC_HIGHLIGHT)

    game.release(tile)
    yield(self, "idle_frame")
    check("dropped, it is outlined as before", piece.get_node("Mesh/Outline").material_override.get_shader_param("outline_color") == piece.SCHEMATIC_BLACK or piece.get_node("Mesh/Outline").material_override.get_shader_param("outline_color") == piece.SCHEMATIC_WHITE)
