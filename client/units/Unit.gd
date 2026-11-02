extends RigidBody

# A cirya or a hallacirya. A cirya standing up (block) is a tampa

onready var Match = get_node("/root/Match")

export(bool) var block = false
export(String, "CIRYA", "HALLACIRYA") var type = "CIRYA"
export(int) var player = 0

var fleet = null

# How much is seen of a faded piece
const FADED = 0.35

func _ready():
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
    var material = $Mesh.mesh.surface_get_material(0).duplicate(true)
    material.emission_enabled = on

    if on:
        material.emission_energy = 0.2
        material.emission = Color(0.62, 0.27, 0.0) if fleet.white else Color(0.63, 0.34, 0.84)

    $Mesh.mesh.surface_set_material(0, material)

# A piece that cannot come into play yet is seen faded, over the glow
func fade(on):
    var material = null

    if on:
        material = $Mesh.mesh.surface_get_material(0).duplicate(true)
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
