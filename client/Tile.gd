tool
extends Area

var row = 0
var column = 0

onready var global = get_node("/root/Global")

func drop(piece):    
    print('drop row: ', row, ' column: ', column)
    var new_position = self.global_transform.origin

    # The tampa under a hallacirya is flattened by Global.sync_tampar
    global.remove_piece_from_state(piece.get_instance_id())
    global.board_state[row][column].append(piece.get_instance_id())
    new_position.y = piece.translation.y
    piece.set_translation(new_position)
    piece.apply_central_impulse(Vector3(0, -0.1, 0))
    
    # self.visible = true

func showHighlight():
    self.visible = true
    
func hideHighlight():
    self.visible = false
