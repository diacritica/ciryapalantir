extends Node

onready var global = get_node("/root/Global")

export(bool) var block = false

export(String, "CIRYA", "HALLACIRYA") var type = "CIRYA"

# Called when the node enters the scene tree for the first time.
func _ready():
    pass
    
func toggle_block():
    print(type)
    if type == "CIRYA":
        block = !block
        
        if block:
            self.transform.basis = self.transform.basis.rotated(Vector3(1, 0, 0), PI/2)
        else:
            self.transform.basis = self.transform.basis.rotated(Vector3(-1, 0, 0), PI/2)

func get_height():
    if type == "HALLACIRYA" or !block:
        return $CollisionShape.scale.y * 2
    
    return $CollisionShape.scale.z * 2
        
