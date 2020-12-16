extends Spatial

var hallaciryaid = null
# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
    print("I'm piece# ",hallaciryaid)
    print("My ID is ",self.get_instance_id())
    print($Piece.get_instance_id())


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#    pass
