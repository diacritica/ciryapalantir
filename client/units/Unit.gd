extends Node

onready var global = get_node("/root/Global")

export(bool) var block = false

export(String, "CIRYA", "HALLACIRYA") var type = "CIRYA"

export(int) var pieceid = 0
export(bool) var fleetSelectable = false
export(int) var player = 0

# Called when the node enters the scene tree for the first time.
func _ready():
    global.register_piece(self)

func toggle_block():
    if type == "CIRYA":
        block = !block

        var mesh = self.get_node('Mesh')
        var outline_mesh = self.get_node('Mesh')

        if block:
            mesh.transform.basis = mesh.transform.basis.rotated(Vector3(1, 0, 0), PI/2)
            mesh.transform.origin = Vector3(mesh.transform.origin.x, mesh.transform.origin.y + 1, mesh.transform.origin.z)
        else:
            mesh.transform.basis = mesh.transform.basis.rotated(Vector3(-1, 0, 0), PI/2)
            mesh.transform.origin = Vector3(mesh.transform.origin.x, mesh.transform.origin.y - 1, mesh.transform.origin.z)

func get_height():
    if type == "HALLACIRYA" or !block:
        return $CollisionShape.scale.y * 2

    return $CollisionShape.scale.z * 2

func show_selected():
    var m = $Mesh.mesh.surface_get_material(0)
    var m2 = m.duplicate(true)
    m2.emission_enabled = true
    m2.emission_energy = 0.5
    m2.emission = Color(0.5,0.2,0.05)
    print(m2)
    $Mesh.mesh.surface_set_material(0,m2)

func hide_selected():
    var m = $Mesh.mesh.surface_get_material(0)
    var m2 = m.duplicate(true)
    m2.emission_enabled = false
    print(m2)
    $Mesh.mesh.surface_set_material(0,m2)
    
func show_outline():
    pass
#    if $Mesh/Outline:
        #$Mesh/Outline.visible = true

func hide_outline():
    var m = $Mesh.mesh.surface_get_material(0)
    var m2 = m.duplicate(true)
    m2.emission_enabled = false
    print(m2)
    $Mesh.mesh.surface_set_material(0,m2)
        
func get_notation_name():
    if type == "HALLACIRYA":
        return 'H'
    elif block:
        return 'T'

    return 'C'
