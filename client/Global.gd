extends Node

# Layers | Masks
# Tile: 1 | 2
# Piece: 2 | 1,2
# Board: 3 | 1,2,3

var current_piece = null
var piece_initial_position = null
var board_state = []
var cirya_height = 0.102
var board = null

func render_board():
    for row_index in  range(board_state.size()):
        var row = board_state[row_index]
        for column_index in range(row.size()):
            var column = row[column_index]
            for piece_index in range(column.size()):
                var piece_id = row[column_index][piece_index]
                var piece = instance_from_id(piece_id)
                var tile = get_tile(row_index, column_index)

                var new_position = tile.global_transform.origin
                new_position.y = get_stack_height(row_index, column_index)
                
                piece.set_translation(new_position)
                
func get_stack_height(row, column, exclude = null):
    var height = 0
    print('height for', row, column)
    
    for piece_id in board_state[row][column]:
        if !exclude or exclude != piece_id:
            var piece = instance_from_id(piece_id)
            height = height + piece.get_height()
            print('peice height', height)
        
    return height

func get_tile(row, column):
    var tiles = board.get_node('Tiles').get_children()

    for node in tiles:
        if node.row == row and node.column == column:
            return node
            
func remove_piece_from_state(piece_id):
    for row in board_state:
        for column in row:
            column.erase(piece_id)

func valid_drop_tile(row, column):
    var tile = board_state[row][column]
    
    for piece_id in tile:
        var piece = instance_from_id(piece_id)
        
        if piece.block:
            return false
            
    return true
    
func init_drag_drop(piece): 
    current_piece = piece
    current_piece.get_node("CollisionShape").disabled = true
    current_piece.axis_lock_linear_z = true
    current_piece.axis_lock_linear_x = true
    current_piece.mode = RigidBody.MODE_STATIC
    piece_initial_position = piece.global_transform.origin
    
func stop_drag_drop():
    current_piece.mode = RigidBody.MODE_RIGID
    current_piece.get_node("CollisionShape").disabled = false
    current_piece = null
    
func restore_initial_position():
    current_piece.set_translation(piece_initial_position)
