extends RigidBody

# A cirya or a hallacirya. A cirya standing up (block) is a tampa

onready var Match = get_node("/root/Match")

export(bool) var block = false
export(String, "CIRYA", "HALLACIRYA") var type = "CIRYA"
export(int) var player = 0

var fleet = null
# The wooden material of the piece, shared with the others of its kind. It
# holds big textures, so the glow and the fade copy it shallowly, keeping
# them shared: a deep copy for every piece fills the memory of the GPU
var story_material = null
var glowing = false
var faded = false
var schematic = false

# How much is seen of a faded piece
const FADED = 0.35
# The schematic view, and the outline of a piece there: thin in the other
# colour, and thick and strong when it lights up
const SCHEMATIC_WHITE = Color(1, 1, 1)
const SCHEMATIC_BLACK = Color(0.03, 0.03, 0.03)
const HIGHLIGHT = Color(1, 0.42, 0)
const OUTLINE_WIDTH = 3.5
const HIGHLIGHT_WIDTH = 10.0
const OUTLINE = preload("res://units/outline.tres")

func _ready():
    story_material = $Mesh.mesh.surface_get_material(0)
    add_to_group("pieces")
    connect("mouse_entered", self, "_on_mouse_entered")
    connect("mouse_exited", self, "_on_mouse_exited")

func _on_mouse_entered():
    if !is_in_group("hand") and Match.can_take(get_instance_id()):
        _glow(true)

func _on_mouse_exited():
    if !is_in_group("hand"):
        _glow(false)

func show_selected():
    _glow(true)

func hide_selected():
    _glow(false)

func _glow(on):
    glowing = on
    _paint()

# A piece that cannot come into play yet is seen faded, over the glow
func fade(on):
    faded = on
    _paint()

# The schematic view: pure white or pure black, outlined in the other colour,
# and a thick outline of a strong colour when it lights up
func set_schematic(on):
    if on != schematic:
        schematic = on
        _paint()

func _paint():
    $Mesh/Outline.visible = schematic

    if schematic:
        var material = SpatialMaterial.new()
        material.albedo_color = SCHEMATIC_WHITE if fleet.white else SCHEMATIC_BLACK
        material.roughness = 0.9

        if faded:
            material.flags_transparent = true
            material.albedo_color.a = FADED

        var outline = OUTLINE.duplicate()
        outline.set_shader_param("outline_color", HIGHLIGHT if glowing else (SCHEMATIC_BLACK if fleet.white else SCHEMATIC_WHITE))
        outline.set_shader_param("outline_width", HIGHLIGHT_WIDTH if glowing else OUTLINE_WIDTH)
        $Mesh.material_override = material
        $Mesh/Outline.material_override = outline
        return

    $Mesh.material_override = null
    var material = story_material

    if glowing or faded:
        material = story_material.duplicate()

    if glowing:
        material.emission_enabled = true
        material.emission_energy = 0.2
        material.emission = Color(0.62, 0.27, 0.0) if fleet.white else Color(0.63, 0.34, 0.84)

    if faded:
        material.flags_transparent = true
        material.albedo_color.a = FADED

    $Mesh.set_surface_material(0, material)

func toggle_block():
    if type != "CIRYA":
        return

    block = !block

    var transform = $Mesh.transform
    transform.basis = transform.basis.rotated(Vector3(1, 0, 0), PI / 2 if block else -PI / 2)
    transform.origin.y += 1 if block else -1
    $Mesh.transform = transform

func get_height():
    if type == "HALLACIRYA" or !block:
        return $CollisionShape.scale.y * 2

    return $CollisionShape.scale.z * 2

func get_notation_name():
    if type == "HALLACIRYA":
        return "H"
    elif block:
        return "T"

    return "C"
