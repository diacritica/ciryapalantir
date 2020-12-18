extends Node

onready var globalgame = get_node("/root/Game")

# Layers | Masks
# Tile: 1 | 2
# Piece: 2 | 1,2
# Board: 3 | 1,2,3

var dragging_nosse = null
var board_state = []
var cirya_height = 0.102
var board = null
var game = null
var ui = null
var undo_state = null
var player = null
var pieces = []
var turn = 1

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

func register_piece(piece): 
    pieces.append(piece)                
                
func get_dragging_nosse_pieces_ids():
    var pieces = dragging_nosse.get_children();
    var pieces_ids = []
    
    for piece in pieces:
        pieces_ids.append(piece.get_instance_id())
    
    return pieces_ids

func get_pieces_height(pieces):
    var height = 0
    
    for piece_id in pieces:
        var piece = instance_from_id(piece_id)
        height = height + piece.get_height()
        
    return height
                
func get_stack_height(row, column, exclude = []):
    var height = 0
    var pieces = []

    for piece_id in board_state[row][column]:
        if exclude.find(piece_id) == -1:
            pieces.append(piece_id)
        
    return 0.5 + get_pieces_height(pieces)
    
func get_piece_tile(piece_id):
    for row_index in  range(board_state.size()):
        var row = board_state[row_index]
        for column_index in range(row.size()):
            var column = row[column_index]
            var piece_index = column.find(piece_id, 0)
            
            if piece_index != -1:
                return get_tile(row_index, column_index)
                
    return null
    
func get_top_pieces(piece_id):
    var tile = get_piece_tile(piece_id)
    var piece_ids = board_state[tile.row][tile.column]
    var pieces = []
    
    var pice_index = piece_ids.find(piece_id, 0)
    piece_ids = piece_ids.slice(pice_index, piece_ids.size())
    
    for piece_id in piece_ids:
        pieces.append(instance_from_id(piece_id))
    
    return pieces    
    
func get_tile_pieces(row, column):
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

func valid_drop_tile(piece, row, column):
    var tile = board_state[row][column]
    
    for piece_id in tile:
        var piece_tile = instance_from_id(piece_id)
        
        if piece_tile.block and piece.get_notation_name() != 'H':
            return false
            
    return true

func save_pieces_translation():
    undo_state = {}
    for piece in pieces:
        undo_state[piece.get_instance_id()] = piece.translation    
    
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
        piece.show_selected()
        
        self.move_to(piece, dragging_nosse)

    self.game.add_child(dragging_nosse)

func stop_drag_drop(tile):                        
    for piece in dragging_nosse.get_children():
        piece.mode = RigidBody.MODE_RIGID
        piece.get_node("CollisionShape").disabled = false
        piece.translation.x = dragging_nosse.translation.x
        piece.translation.z = dragging_nosse.translation.z
        piece.translation.y = piece.global_transform.origin.y
        
        if tile:
            tile.drop(piece)
            piece.hide_selected()
        
        self.move_to(piece, game)
        
    game.remove_child(dragging_nosse)
    dragging_nosse = null
    
func restore_piece_position(piece_id):
    var piece = instance_from_id(piece_id)
    piece.translation = undo_state[piece.get_instance_id()]
    globalgame.get_node("undo").play()
    
func restore_initial_position():
    globalgame.get_node("undo").play()
    for piece in pieces:
        piece.translation = undo_state[piece.get_instance_id()]
    
func move_to(el, to):
    el.get_parent().remove_child(el)
    to.add_child(el)
    el.set_owner(to)  
    
func move_piece(piece_id, row, column):
    # print(piece_id,' ' , row, ' ', column)
    var piece = instance_from_id(piece_id)
    var tile = get_tile(row, column)
    
    if piece.get_notation_name() == 'H':
        var tile_pieces = get_tile_pieces(row, column)
        
        var finded_T = null
        
        for tile_piece in tile_pieces:
            if tile_piece.get_notation_name() == 'T':
                tile_piece.toggle_block()
    
    var new_position = tile.global_transform.origin
    new_position.y = get_stack_height(row, column) + 0.2

    if new_position.y < 1:
        new_position.y = 1
    piece.set_translation(new_position)
    piece.apply_central_impulse(Vector3(0, -0.1, 0))
    
    remove_piece_from_state(piece_id)
    board_state[row][column].append(piece_id)
    
func data_received(data):
    if "move" in data.params and int(data.params.player) != self.player:
        print('data received: ', data.params)
        turn = int(data.params.turn) + 1
        var player = int(data.params.player)
        notation_movement(player, data.params.move)
     
func unassigned_piece(player, stone):
    for piece in pieces:
        if piece.player == player and !get_piece_tile(piece.get_instance_id()):
            if stone: 
                if stone == 'T' and piece.get_notation_name() != 'H':
                    piece.toggle_block()
                    return piece  
                elif piece.get_notation_name() == stone:
                    return piece
            else:
                return piece
    
    return null
    
func notation_movement(player, move):
    var regex = RegEx.new()
    regex.compile("^(?P<stone>[HT])?(?P<position>[a-j][1-9])$")
    
    var result = regex.search(move)
    if result:
        var piece = unassigned_piece(player, result.get_string("stone"))
        var origin = notation_to_vector(result.get_string("position"))
        if piece:
            move_piece(piece.get_instance_id(), origin.x, origin.y)
    else:
        regex.compile("^(?P<count>[1-9])?(?P<position>[a-j][1-9])(?P<direction>[<>\\+\\-])(?P<dropCounts>[1-9]*)(?P<stone>[HT])?$")
        result = regex.search(move)
        
        if result:         
            var origin = notation_to_vector(result.get_string("position"))
            
            var pieces = get_tile_pieces(origin.x, origin.y)
                
            pieces.invert()
            pieces = pieces.slice(0, int(result.get_string("count")) - 1)

            pieces.invert()
            
            var dropCounts = result.get_string("dropCounts")
            if !dropCounts:
                dropCounts = [int(result.get_string("count"))]
            
            print('dropCounts: ', dropCounts)
            print('pieces above ', pieces.size())
            for drop in dropCounts:
                drop = int(drop)
                print('drop: ', drop)
                var to_drop = pieces.slice(0, drop - 1)
                pieces = pieces.slice(to_drop.size(), pieces.size())
                
                for piece in pieces:
                    print('remain ', piece.get_notation_name())                
                
                for piece in to_drop:
                    print('dropping ', piece.get_notation_name())
                    
                if result.get_string("direction") == '+':
                    origin.x += 1
                elif result.get_string("direction") == '-':
                    origin.x -= 1
                elif result.get_string("direction") == '>':
                    origin.y += 1
                elif result.get_string("direction") == '<':
                    origin.y -= 1     
                
                for piece_to_drop in to_drop:
                    move_piece(piece_to_drop.get_instance_id(), origin.x, origin.y)               
            
func notation_to_vector(notation):
    var letters = ['a', 'b', 'c', 'd', 'e', 'f', 'g']  
    var row = int(notation[1]) - 1
    var column = letters.find(notation[0])
    
    return Vector2(row, column)

func notation_tile(position):
    var letters = ['a', 'b', 'c', 'd', 'e', 'f', 'g']  
    var column = letters[position.y]
    var row = position.x + 1
    
    return column + str(row)
    
# [{from:(2, 4), pieces:[1559, 1552], to:(2, 3)}, {from:(2, 3), pieces:[1552], to:(2, 2)}]    
# (count)(square)(direction)(drop counts)(stone)
# Take 5 stones from square b4 and move them right dropping 2 stones, 1 stone, then 2 stones as you come to each square.
# 5b4>212
func notation(turn): 
    var old_notation = ''
    var origin = turn[0]
    var count = origin.pieces.size()

    if origin.from == null:
        var piece_from_tray = instance_from_id(origin.pieces[0])
        var piece_type = piece_from_tray.get_notation_name()
        
        var notation = notation_tile(origin.to)
        
        if piece_type != 'C':
            return piece_type + notation
        else:
            return notation
           
    var new_notation = ''
    
    if count > 1:
        new_notation += str(count)
        
    var from_notation = notation_tile(origin.from)
    
    new_notation += from_notation
    
    var move_symbol = null

    if origin.from.x < origin.to.x:
        move_symbol = '+'
    elif  origin.from.x > origin.to.x:
        move_symbol = '-'
    elif origin.from.y < origin.to.y:    
        move_symbol = '>'
    else:
        move_symbol = '<'
        
    new_notation += move_symbol
    
    if turn.size() > 1:
        var exclude = []
        var movement_drop_count = []
        var movements = turn
        movements.invert()
        for movement in movements:
            var dropped_count = 0
            
            for piece_id in movement.pieces:
                if exclude.find(piece_id) == -1:
                    dropped_count += 1
                    exclude.append(piece_id)
        
            movement_drop_count.append(dropped_count)
            
        movement_drop_count.invert()
        
        for drop in movement_drop_count:
            new_notation += str(drop)
    
    return new_notation
