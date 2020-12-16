extends Node

onready var global = get_node("/root/Global")

export(bool) var block = false

export(String, "CIRYA", "HALLACIRYA") var type = "CIRYA"

# Called when the node enters the scene tree for the first time.
func _ready():
    pass
    
func toggle_block():
    if type == "CIRYA":
        block = !block
        
        if block:
            self.transform.basis = self.transform.basis.rotated(Vector3(1, 0, 0), PI/2)
            self.transform.origin = Vector3(self.transform.origin.x, 1, self.transform.origin.z)
        else:
            self.transform.basis = self.transform.basis.rotated(Vector3(-1, 0, 0), PI/2)

func get_height():
    if type == "HALLACIRYA" or !block:
        return $CollisionShape.scale.y * 2

    return $CollisionShape.scale.z * 2
        
