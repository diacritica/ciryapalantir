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
    print('drop in ', row, ' ', column)
    
    var new_position = self.global_transform.origin
    
    if !global.valid_drop_tile(row, column):
        print('not valid')
        piece.set_translation(global.piece_initial_position)
    else:
        global.remove_piece_from_state(piece.get_instance_id())
        global.board_state[row][column].append(piece.get_instance_id())
        new_position.y = global.board_state[row][column].size() * global.cirya_height + 5
        piece.set_translation(new_position)
        piece.apply_central_impulse(Vector3(0, -0.1, 0))
    
    # self.visible = true
