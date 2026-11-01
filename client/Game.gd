extends Spatial

onready var Settings = get_node("/root/Settings")
onready var Server = get_node("/root/Server")
onready var Validation = get_node("/root/Validation")
onready var global = get_node("/root/Global")

var ray_length = 200

func _ready():     
    global.game = self
    Settings.medium()
    Settings.apply_settings(self)

    var camera = get_viewport().get_camera()

    $UI.connect("turn_confirmation", self, "_on_turn_confirmation")
    
    # $ambient.autoplay = false

    # simulation()
#    if 'connected' in Server && !Server.is_ws_connected():
#        Server.connect("connection_success", self, "_on_connection_success")
#        Server.join_room('test')

    # The player comes from the seat taken in the menu. Player 1, the sandbox
    # and spectators look from the side of player 1
    if global.player != 2:
        $CameraPlayer1.current = true
        self.remove_child($CameraPlayer2)
        self.remove_child($Particles2)
    else:
        $CameraPlayer2.current = true
        self.remove_child($CameraPlayer1)
        self.remove_child($Particles)
        
    move_fleet($Fleet)
    move_fleet($Fleet2)
    
    if global.sandbox:
        global.turn = 1
        $UI/CodePanel.visible = false
        $UI.show_turn_buttons()
        $sandboxlogo.visible = true

func simulation():
    global.simulation(['a3', 'c3', 'b3', 'd3', 'a3>', 'a1', 'b3>'])

func move_fleet(fleet):            
    for piece in fleet.get_children():
        if piece.get('pieceid'):
            var position = piece.global_transform.origin
            global.move_to(piece, $Pieces)
            piece.translation = position

func get_mouse_cast(exclude_current_piece = true):
    var mouse_raycast_collision = 2

    var camera = get_viewport().get_camera()
    var mouse = get_viewport().get_mouse_position()
    var from = camera.project_ray_origin(mouse)
    var to = from + camera.project_ray_normal(mouse) * ray_length
    var exclude = [self]

    if exclude_current_piece and global.dragging_nosse:
        mouse_raycast_collision = global.dragging_nosse.get_children()[0].collision_mask
        exclude.append(global.dragging_nosse)

    # https://docs.godotengine.org/es/stable/classes/class_physicsdirectspacestate.html
    return camera.get_world().direct_space_state.intersect_ray(from, to, exclude, mouse_raycast_collision, true, false)
                
var piece_cast_tile = null
var piece_source_tile = null
var show_fps = true

func _process(delta):
    if show_fps:
        OS.set_window_title("Cirya Online | fps: " + str(Engine.get_frames_per_second()))

func _input(event):
    if (event is InputEventMouseButton and event.button_index == BUTTON_LEFT) or (event is InputEventMouseMotion and global.dragging_nosse):
        if piece_cast_tile and piece_cast_tile.collider != piece_source_tile:
            piece_cast_tile.collider.hideHighlight()

        if global.dragging_nosse:
            # The tile right below the dragged pieces
            var space_state = get_world().direct_space_state
            var origin = global.dragging_nosse.global_transform.origin
            piece_cast_tile = space_state.intersect_ray(origin, origin + Vector3(0, -ray_length, 0), [], 2147483647, false, true)
            if piece_cast_tile and Validation.can_drop(piece_cast_tile.collider.row, piece_cast_tile.collider.column):
                piece_cast_tile.collider.showHighlight()

        var cast = get_mouse_cast()

        if not cast.empty():
            if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
                
                # init drag
                if event.is_pressed() and Validation.can_move(cast.collider.get_instance_id()):
                    if !global.move_started():
                        global.start_move(cast.collider.get_instance_id())
                    
                    get_node("select").play()
                    var piece = cast.collider
                    var tile = global.get_piece_tile(piece.get_instance_id())

                    if !tile:
                        global.move_to(piece, self)
                        global.init_drag_drop([piece])
                    else:
                        var pieces = global.get_top_pieces(piece.get_instance_id())
                        global.init_drag_drop(pieces)

                # stop drag
                elif global.dragging_nosse and not piece_cast_tile.empty() and Validation.can_drop(piece_cast_tile.collider.row, piece_cast_tile.collider.column):
                    var tile = piece_cast_tile.collider

                    global.stop_drag_drop(tile)
                    global.sync_tampar()
                    print('drop on ', global.notation_tile(Vector2(tile.row, tile.column)), ', move so far: ', global.move_notation())

                    piece_cast_tile.collider.hideHighlight()

                    if piece_source_tile:
                        piece_source_tile.hideHighlight()
                        piece_source_tile = null
                # Released where the pieces cannot go
                elif global.dragging_nosse and not event.is_pressed():
                    if not piece_cast_tile.empty():
                        print('drop on ', global.notation_tile(Vector2(piece_cast_tile.collider.row, piece_cast_tile.collider.column)), ' rejected')
                    cancel_drag()
            # drag movement
            elif global.dragging_nosse and event is InputEventMouseMotion:
                if not piece_source_tile and piece_cast_tile and Validation.can_drop(piece_cast_tile.collider.row, piece_cast_tile.collider.column):
                    piece_source_tile = piece_cast_tile.collider
                    piece_source_tile.showHighlight()

                var new_position = cast.position

                if piece_cast_tile:
                    var piece = global.dragging_nosse
                    new_position.y = global.get_stack_height(piece_cast_tile.collider.row, piece_cast_tile.collider.column, global.get_dragging_nosse_pieces_ids()) + 0.2
                    
                if new_position.y < 2.2:
                    new_position.y = 2.2

                global.dragging_nosse.set_translation(new_position)
                
        elif global.dragging_nosse and event is InputEventMouseButton and not event.is_pressed():
            cancel_drag()
    elif global.dragging_nosse and global.dragging_nosse.get_children().size() == 1 and Input.is_key_pressed(KEY_R):
        get_node("piecerotation").play()
        var tile = global.get_piece_tile(global.dragging_nosse.get_children()[0].get_instance_id())
        if !tile:
            global.dragging_nosse.get_children()[0].toggle_block()

func cancel_drag():
    if piece_cast_tile:
        piece_cast_tile.collider.hideHighlight()

    if piece_source_tile:
        piece_source_tile.hideHighlight()
        piece_source_tile = null

    global.cancel_drag_drop()

func _on_turn_confirmation(value):
    if value:
        var move = global.move_notation()

        # Nothing moved, or the move is not finished yet
        if !move:
            return

        var msg = {
            "type": "SubmitTurn",
            "params": {
                "player": global.player,
                "turn": global.turn,
                "move": move,
            }
        }
        print('sending: ')
        print(msg)
        
        if global.sandbox:
            $UI.add_move(move)
            global.next_sandbox_turn()
            $UI.set_turn_color("white" if global.player == 1 else "black")
        else:
            Server.ws_send_message(msg)
            global.end_move()
        
    else:
        global.restore_initial_position()
