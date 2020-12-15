extends Area

var row = 0
var column = 0

# Called when the node enters the scene tree for the first time.
func _ready():
    self.connect("body_shape_entered", self, "_on_body_entered")

func _on_body_entered(body_id, body, body_shape, area):
    print(row, ' - ', column)
