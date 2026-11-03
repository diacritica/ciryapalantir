extends Reference

# The look of the table of Game, story or schematic, changed at once without
# loading the scene again. The schematic view hides the tavern: its table and
# what is on it, the dust in the air and its lights, and lights all evenly
# from above over a plain grey table, with plain trays. The pieces and the
# board change their own looks

const TAVERN = ["table-tavern2", "candle-tavern3", "candle-tavern4", "wood-mug3", "wood-mug4", "Particles", "Particles2", "BakedLightmap", "SpotLight", "light2", "light4", "light5", "BlackFill"]
const SCHEMATIC_BACKGROUND = Color(0.16, 0.16, 0.17)
const SCHEMATIC_TABLE = Color(0.24, 0.24, 0.25)
const SCHEMATIC_TRAY = Color(0.46, 0.46, 0.48)
const SCHEMATIC_TABLE_HEIGHT = -0.42

var game = null
# What the story view shows, to come back to it: the environment of the
# tavern and which of its nodes were visible
var story_environment = null
var tavern_shown = {}

func _init(table):
    game = table
    story_environment = game.get_node("WorldEnvironment").environment

    for name in TAVERN:
        if game.has_node(name):
            tavern_shown[name] = game.get_node(name).visible

func show(schematic):
    for name in tavern_shown:
        game.get_node(name).visible = tavern_shown[name] and !schematic

    game.get_node("WorldEnvironment").environment = _schematic_environment() if schematic else story_environment

    if schematic and !game.has_node("SchematicTable"):
        _set_the_schematic_table()
    elif !schematic and game.has_node("SchematicTable"):
        for name in ["SchematicTable", "SchematicLight"]:
            var node = game.get_node(name)
            game.remove_child(node)
            node.queue_free()

    var tray = null

    if schematic:
        tray = SpatialMaterial.new()
        tray.albedo_color = SCHEMATIC_TRAY
        tray.roughness = 1.0

    for fleet in [game.get_node("Fleet"), game.get_node("Fleet2")]:
        _paint_meshes(fleet, tray)

# Even light and no effects: no glow, depth of field, ambient occlusion or fog
func _schematic_environment():
    var environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = SCHEMATIC_BACKGROUND
    environment.ambient_light_color = Color(1, 1, 1)
    environment.ambient_light_energy = 0.6
    environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    return environment

func _set_the_schematic_table():
    var plain = SpatialMaterial.new()
    plain.albedo_color = SCHEMATIC_TABLE
    plain.roughness = 1.0

    var plane = PlaneMesh.new()
    plane.size = Vector2(400, 400)
    var table = MeshInstance.new()
    table.name = "SchematicTable"
    table.mesh = plane
    table.material_override = plain
    table.translation.y = SCHEMATIC_TABLE_HEIGHT
    game.add_child(table)

    # From above and a little from the side of player 1, with soft shadows
    var light = DirectionalLight.new()
    light.name = "SchematicLight"
    light.light_energy = 0.7
    light.shadow_enabled = true
    light.shadow_color = Color(0.45, 0.45, 0.45)
    light.directional_shadow_mode = DirectionalLight.SHADOW_ORTHOGONAL
    light.rotation_degrees = Vector3(-70, 30, 0)
    game.add_child(light)

func _paint_meshes(node, material):
    for child in node.get_children():
        if child is MeshInstance:
            child.material_override = material

        if !child.is_in_group("pieces"):
            _paint_meshes(child, material)
