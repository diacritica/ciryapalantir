extends Node

onready var global = get_node("/root/Global")

export(bool) var block = false

export(String, "CIRYA", "HALLACIRYA") var type = "CIRYA"

export(int) var pieceid = 0
export(bool) var fleetSelectable = false

# Called when the node enters the scene tree for the first time.
func _ready():
    print("I'm piece# ",pieceid)
    print("My ID is ",self.get_instance_id())
    
func toggle_block():
    print(type)
    if type == "CIRYA":
        block = !block
        
        if block:
            self.transform.basis = self.transform.basis.rotated(Vector3(1, 0, 0), PI/2)
        else:
            self.transform.basis = self.transform.basis.rotated(Vector3(-1, 0, 0), PI/2)
