tool
extends Area

var row = 0
var column = 0

onready var global = get_node("/root/Global")

# Called when the node enters the scene tree for the first time.
func _ready():
    self.connect("body_shape_entered", self, "_on_body_entered")

func _on_body_entered(_body_id, _body, _body_shape, _area):
    #     print(row, ' - ', column)
    pass

func drop(piece):
    print('drop in', row, ' ', column)

    var unit_height = 0.102
    global.board_state[row][column].append(piece.get_instance_id())
    
    var new_position = self.global_transform.origin
    new_position.y = global.board_state[row][column].size() * unit_height + 5
    
    # piece.get_node('CollisionShape').set_disabled(false)
    # piece.mode = RigidBody.MODE_RIGID
    # piece.axis_lock_linear_y = true
    piece.set_translation(new_position)

    # self.visible = true
