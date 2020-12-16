extends Node

# Layers | Masks
# Tile: 1 | 2
# Piece: 2 | 1,2
# Board: 3 | 1,2,3

var dragging_nosse = null
var piece_initial_position = null
var board_state = []
var cirya_height = 0.102
var board = null
var game = null
var ui = null

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

func get_pieces_height(pieces):
    var height = 0
    
    for piece_id in pieces:
        var piece = instance_from_id(piece_id)
        height = height + piece.get_height()
        
    return height
                
func get_stack_height(row, column, exclude = null):
    var height = 0
    var pieces = []

    for piece_id in board_state[row][column]:
        if !exclude or exclude != piece_id:
            pieces.append(piece_id)
        
    return get_pieces_height(pieces)
    
func get_piece_tile(piece_id):
    for row_index in  range(board_state.size()):
        var row = board_state[row_index]
        for column_index in range(row.size()):
            var column = row[column_index]
            var piece_index = column.find(piece_id, 0)
            
            if piece_index != -1:
                return get_tile(row_index, column_index)
                
    return null
    
func get_pieces_tile(row, column):
    var piece_ids = board_state[row][column]
    var pieces = []
    
    for piece_id in piece_ids:
        pieces.append(instance_from_id(piece_id))
    
    return pieces

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
    
func init_drag_drop(pieces): 
    dragging_nosse = Spatial.new()
    dragging_nosse.set_translation(pieces[0].get_translation())
    
    for piece_index in range(pieces.size()):
        var piece = pieces[piece_index]
        piece.get_node("CollisionShape").disabled = true
        piece.axis_lock_linear_z = true
        piece.axis_lock_linear_x = true
        piece.mode = RigidBody.MODE_STATIC
        piece.translation.x = 0
        piece.translation.z = 0
        
        self.move_to(piece, dragging_nosse)

    self.game.add_child(dragging_nosse)
    # TODO:
    #piece_initial_position = piece.global_transform.origin

func stop_drag_drop(tile):                        
    for piece in dragging_nosse.get_children():
        piece.mode = RigidBody.MODE_RIGID
        piece.get_node("CollisionShape").disabled = false
        piece.translation.x = dragging_nosse.translation.x
        piece.translation.z = dragging_nosse.translation.z
        piece.translation.y = piece.global_transform.origin.y
        
        tile.drop(piece)
        
        self.move_to(piece, game)
        
    game.remove_child(dragging_nosse)
    dragging_nosse = null
    
func restore_initial_position():
    dragging_nosse.set_translation(piece_initial_position)
    
func move_to(el, to):
    el.get_parent().remove_child(el)
    to.add_child(el)
    el.set_owner(to)  
      
func notation(turn): 
    print('in turn ', turn)
    var letters = ['a', 'b', 'c', 'd', 'e', 'f', 'g']
    var new_notation = ''
    var old_notation = ''
    # letters.invert()

    if turn.old != null:
        var from_column = letters[turn.old.y]
        var from_row = turn.old.x + 1
        old_notation = str(from_column) + str(from_row)
        
    if turn.new != null:
        var to_column = letters[turn.new.y]
        var to_row = turn.new.x + 1
        new_notation = str(to_column) + str(to_row)
        
    if turn.old == null:
        if turn.piece_type != 'C':
            return turn.piece_type + new_notation
        else:
            return new_notation
        
    var move_symbol = null
    
    if turn.old.x < turn.new.x:
        move_symbol = '+'
    elif turn.old.x < turn.new.x:
        move_symbol = '-'
    elif turn.old.y < turn.new.y:    
        move_symbol = '>'
    else:
        move_symbol = '<'
        
    old_notation  += move_symbol
        
    return old_notation
    
