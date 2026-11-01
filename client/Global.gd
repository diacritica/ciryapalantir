extends Node

# Layers | Masks
# Tile: 1 | 2
# Piece: 2 | 1,2
# Board: 3 | 1,2,3

var dragging_nosse = null
# Where the dragged pieces were, to put them back when the drop is not valid
var drag_origins = {}
var board_state = []
var cirya_height = 0.102
var board = null
var game = null
var undo_state = null
var undo_board_state = null
var player = null
var pieces = []
var turn = 1
var disable_move = false
# The move of this turn: the board before it, where it started (the nossë, or
# the piece taken from the fleet) and the tampar standing then. Null until a
# piece is taken
var move = null
# A local game on one computer: the same rules and turns, without the server
var sandbox = false
onready var Validation = get_node("/root/Validation")

func render_board(board):    
    for row_index in  range(board.size()):
        var row = board[row_index]
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
    if !dragging_nosse:
        return []
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
    
func tile_owner(row, column):
    var piece_ids = board_state[row][column]
    var last_piece_id = piece_ids.back()
    var piece = instance_from_id(last_piece_id)
    
    if piece:
        return piece.player
    
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
    
# A move that starts by taking this piece, from the board as it is now
func new_move(piece_id):
    var tile = get_piece_tile(piece_id)
    var tampar = []

    for piece in pieces:
        if piece.get_notation_name() == 'T' and get_piece_tile(piece.get_instance_id()):
            tampar.append(piece.get_instance_id())

    return {
        "before": board_state.duplicate(true),
        "origin": Vector2(tile.row, tile.column) if tile else null,
        "placed": null if tile else piece_id,
        "tampar": tampar
    }

func start_move(piece_id):
    save_pieces_translation()
    move = new_move(piece_id)

# The turn is over: the next piece taken starts a new move
func end_move():
    move = null

# Turns 1 and 2: each player places a flat cirya of the opponent, as in Tak
func opening():
    return turn <= 2

# In the sandbox the turn goes to the other player when it is confirmed
func next_sandbox_turn():
    end_move()
    turn += 1
    player = 3 - player

func move_started():
    return move != null and var2str(board_state) != var2str(move.before)

# The pieces that can be taken once the move has started: the piece from the
# fleet, the nossë it started from and the stones dropped along the way
func part_of_move(piece_id):
    if !move:
        return false

    if move.placed != null:
        return piece_id == move.placed

    var tile = get_piece_tile(piece_id)

    if !tile:
        return false

    if tile.row == move.origin.x and tile.column == move.origin.y:
        return true

    var before = move.before[tile.row][tile.column]
    return board_state[tile.row][tile.column].find(piece_id) >= before.size()

# The board if the dragged pieces were dropped on this square
func board_after_drop(hand, row, column):
    var state = board_state.duplicate(true)

    for line in state:
        for stack in line:
            for piece_id in hand:
                stack.erase(piece_id)

    for piece_id in hand:
        state[row][column].append(piece_id)

    return state

# A tampa lies flat while the hallacirya of this move is on it, and stands up
# again when the hallacirya goes back
func sync_tampar():
    if !move:
        return

    for piece_id in move.tampar:
        var tile = get_piece_tile(piece_id)
        var stack = board_state[tile.row][tile.column]
        var covered = stack.find(piece_id) < stack.size() - 1
        var piece = instance_from_id(piece_id)

        if piece.block == covered:
            piece.toggle_block()

func init_drag_drop(pieces): 
    dragging_nosse = Spatial.new()
    dragging_nosse.set_translation(pieces[0].get_translation())

    drag_origins = {}
    for piece in pieces:
        drag_origins[piece.get_instance_id()] = piece.global_transform

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

# TODO, make sure the drag and drop stop works when outside the board and undos board state
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
    dragging_nosse.queue_free()
    dragging_nosse = null

# The drop is not valid: the dragged pieces go back to where they were, the
# board state does not change and the rest of the turn is kept
func cancel_drag_drop():
    var tween = Tween.new()
    var pieces = dragging_nosse.get_children()
    game.add_child(tween)

    # The pieces fly back so the player sees where they came from
    for piece in pieces:
        var current = piece.global_transform
        piece.hide_selected()
        self.move_to(piece, game)
        piece.global_transform = current
        tween.interpolate_property(piece, "global_transform", current, drag_origins[piece.get_instance_id()], 0.35, Tween.TRANS_QUAD, Tween.EASE_OUT)

    tween.connect("tween_all_completed", self, "_on_cancel_finished", [tween, pieces], CONNECT_ONESHOT)
    tween.start()

    game.remove_child(dragging_nosse)
    dragging_nosse.queue_free()
    dragging_nosse = null
    game.get_node("undo").play()

func _on_cancel_finished(tween, pieces):
    for piece in pieces:
        piece.mode = RigidBody.MODE_RIGID
        piece.get_node("CollisionShape").disabled = false

    tween.queue_free()
    
# TODO    
func restore_piece_position(piece_id):
    render_board(undo_board_state)
    game.get_node("undo").play()
    
func save_pieces_translation():                        
    undo_board_state = str2var(var2str(board_state))
    undo_state = {}
    for piece in pieces:
        undo_state[piece.get_instance_id()] = piece.translation        
    
func restore_initial_position():
    if !move:
        return

    game.get_node("undo").play()         
    for piece in pieces:
        piece.translation = undo_state[piece.get_instance_id()]

    board_state = move.before.duplicate(true)
    sync_tampar()
    end_move()
    
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
    print('data_received', data)
    if "type" in data and data.type == 'StartGame' || data.type == 'Turn':
        end_move()

        if data.params.nextPlayer == self.player:
            self.disable_move = false
        else: 
            self.disable_move = true
        
    if "params" in data and "move" in data.params and int(data.params.player) != self.player:
        #print('data received: ', data.params)
        turn = int(data.params.turn) + 1
        var player = int(data.params.player)
        notation_movement(player, data.params.move, int(data.params.turn) <= 2)
     
func unassigned_piece(player, stone):
    for piece in pieces:
        if piece.player == player and !get_piece_tile(piece.get_instance_id()):
            if stone: 
                if stone == 'T' and piece.get_notation_name() != 'H':
                    piece.toggle_block()
                    return piece  
                elif piece.get_notation_name() == stone:
                    return piece
            elif piece.get_notation_name() == 'C':
                return piece
    
    return null
    
# In the opening the piece placed is one of the opponent
func notation_movement(player, move, opening = false):
    var regex = RegEx.new()
    regex.compile("^(?P<stone>[HT])?(?P<position>[a-j][1-9])$")
    
    var result = regex.search(move)
    if result:
        var owner = 3 - player if opening else player
        var piece = unassigned_piece(owner, result.get_string("stone"))
        var origin = notation_to_vector(result.get_string("position"))
        if piece:
            move_piece(piece.get_instance_id(), origin.x, origin.y)
    else:
        regex.compile("^(?P<count>[1-9])?(?P<position>[a-j][1-9])(?P<direction>[<>\\+\\-])(?P<dropCounts>[1-9]*)(?P<stone>[HT])?$")
        result = regex.search(move)
        
        if result:         
            var origin = notation_to_vector(result.get_string("position"))
            var pieces = get_tile_pieces(origin.x, origin.y)
            var count = int(result.get_string("count"))
            
            if !count:
                count = 1
                
            pieces.invert()
            pieces = pieces.slice(0, count - 1)

            pieces.invert()
            
            var dropCounts = result.get_string("dropCounts")
            if !dropCounts:
                dropCounts = [count]
            
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
    
func simulation(moves):
    var player = 1
    for move in moves:
        yield(get_tree().create_timer(1.0), "timeout")
        notation_movement(player, move)         
        if player == 1:
            player = 2
        else:
            player = 1
        
# (count)(square)(direction)(drop counts)(stone)
# Take 5 stones from square b4 and move them right dropping 2 stones, 1 stone, then 2 stones as you come to each square.
# 5b4>212
# Worked out from the board when the turn is confirmed, not from the drops made
func move_notation():
    var state = Validation.move_state(move, board_state)

    if !state:
        return ''

    if state.has("placed"):
        var stone = instance_from_id(state.placed).get_notation_name()
        return ('' if stone == 'C' else stone) + notation_tile(state.square)

    var symbols = {Vector2(1, 0): '+', Vector2(-1, 0): '-', Vector2(0, 1): '>', Vector2(0, -1): '<'}
    var text = ''

    if state.count > 1:
        text += str(state.count)

    text += notation_tile(state.origin) + symbols[state.direction]

    if state.drops.size() > 1:
        for drop in state.drops:
            text += str(drop)

    return text
