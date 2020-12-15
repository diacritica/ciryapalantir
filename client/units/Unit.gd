extends Node

onready var global = get_node("/root/Global")

# Called when the node enters the scene tree for the first time.
func _ready():
    global.units[self.get_instance_id()] = self
