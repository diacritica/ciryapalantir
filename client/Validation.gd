extends Node

onready var Global = get_node("/root/Global")

func can_move(piece_id):
    var piece = instance_from_id(piece_id)
    var is_piece = piece.collision_layer == 2
    var tile = Global.get_piece_tile(piece_id)
    
    if Global.sandbox:
        return true
        
    if Global.disable_move or !is_piece:
        return false
        
    # Check if the player own the nosse
    var owner = piece.player
    if tile:
        owner = Global.tile_owner(tile.row, tile.column)
    
    if owner != Global.player and owner != null:
        return false
        
    # You can't start dragging from the bottom piece
#    if tile:
#        var piece_ids = Global.board_state[tile.row][tile.column]
#        if piece_ids.size() > 1 and piece_ids[0] == piece_id:
#            return false
         
    # You only can drag again all pieces except the bottom one
    if Global.player_movement.dropped_pieces.size() > 0:
        var valid_pieces = Global.player_movement.dropped_pieces.slice(1, Global.player_movement.dropped_pieces.size() - 1)

        if !valid_pieces.has(piece_id):
            return false

    return true
 
func can_drop(row, column):
    var tile = Global.get_tile(row, column)
    var tile_pieces = Global.board_state[row][column]
    var pieces = Global.get_dragging_nosse_pieces_ids()
    
    # Table pieces can only be droppend on empty tiles
    var came_from_table = !Global.get_piece_tile(pieces[0])
    if came_from_table and Global.get_tile_pieces(row, column).size() > 0:
        return false
    
    # Check if the player is dragging an hallaciryar
    var dragging_hallaciryar = false
    for piece_id in pieces:
        var piece = instance_from_id(piece_id)
        
        if piece.get_notation_name() == 'H':
            dragging_hallaciryar = true
    
    # Can not drop if the opponent has an hallaciryar
    # Or the opponent has a tampar and the player is not dragging an hallaciryar
    for piece_id in tile_pieces:
        var piece_tile = instance_from_id(piece_id)
        
        if piece_tile.get_notation_name() == 'H':
            return false
        elif piece_tile.get_notation_name() == 'T' and !dragging_hallaciryar:
            return false
            
    var last_tile = Global.player_movement.last_tile
    var direction = Global.player_movement.direction
    
    # check if the new tile in one tile away in the correct direction
    if last_tile:
        if tile.column != last_tile.column and tile.row != last_tile.row:
            return false

        # One square at a time, also when the direction is already set
        if abs(tile.column - last_tile.column) + abs(tile.row - last_tile.row) > 1:
            return false

        if direction:
            if tile.column > last_tile.column and direction != '>':
                return false
            elif tile.column < last_tile.column and direction != '<':
                return false
            elif tile.row > last_tile.row and direction != '+':
                return false
            elif tile.row < last_tile.row and direction != '-':
                return false
        else: 
            if tile.column != last_tile.column and abs(tile.column - last_tile.column) != 1:
                return false
            elif tile.row != last_tile.row and abs(tile.row - last_tile.row) != 1:
                return false          
            
    return true
