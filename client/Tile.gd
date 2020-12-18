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
    var new_position = self.global_transform.origin
    
    # todo
    if !global.valid_drop_tile(piece, row, column):
        global.restore_piece_position(piece.get_instance_id())
    else:
        if piece.get_notation_name() == 'H':
            var tile_pieces = global.get_tile_pieces(row, column)
            
            var finded_T = null
            
            for tile_piece in tile_pieces:
                if tile_piece.get_notation_name() == 'T':
                    tile_piece.toggle_block()
                
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
