extends Spatial

var pieceid = -1
# Declare member variables here. Examples:
# var a = 2
# var b = "text"
export(bool) var fleetSelectable = true

# Called when the node enters the scene tree for the first time.
func _ready():
    print("I'm piece# ",pieceid)
    print("My ID is ",self.get_instance_id())


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#    pass
