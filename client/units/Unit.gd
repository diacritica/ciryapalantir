extends Node

onready var global = get_node("/root/Global")

export(bool) var block = false

export(String, "CIRYA", "HALLACIRYA") var type

# Called when the node enters the scene tree for the first time.
func _ready():
    pass
