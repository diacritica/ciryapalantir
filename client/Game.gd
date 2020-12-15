extends Spatial

onready var global = get_node("/root/Global")
var ray_length = 100

func _ready():
    global.board_state[0][0] = [
        $"light-cirya-basic".get_instance_id(),
        $"light-cirya-basic2".get_instance_id(),
        $"light-hallacirya-ship".get_instance_id()
    ]
    global.render_board()
      
# Layers | Masks
# Tile: 1 | 2
# Piece: 2 | 1,2
# Board: 3 | 1,2,3    
      
func _input(event):
    if (event is InputEventMouseButton and event.button_index == BUTTON_LEFT) or (event is InputEventMouseMotion and global.current_piece):
        var camera = get_viewport().get_camera()
        var mouse = get_viewport().get_mouse_position()
        var from = camera.project_ray_origin(mouse)
        var to = from + camera.project_ray_normal(mouse) * ray_length        
        var exclude = [self]
        var mouse_raycast_collision = 2
        var piece_cast = null
        
        if global.current_piece:
            mouse_raycast_collision = global.current_piece.collision_mask
            exclude.append(global.current_piece)
            
            var space_state = get_world().direct_space_state
            piece_cast = space_state.intersect_ray(global.current_piece.global_transform.origin, Vector3(0, -ray_length, 0), [], 2147483647, false, true)
        
        # https://docs.godotengine.org/es/stable/classes/class_physicsdirectspacestate.html
        var cast = camera.get_world().direct_space_state.intersect_ray(from, to, exclude, mouse_raycast_collision, true, false)

        if not cast.empty():
            if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
                if event.is_pressed() and cast.collider.collision_layer == 2: 
                    global.init_drag_drop(cast.collider)    
                elif global.current_piece and not piece_cast.empty():
                    var piece = global.current_piece
                    global.stop_drag_drop()    
                    piece_cast.collider.drop(piece)
            elif global.current_piece and event is InputEventMouseMotion:
                var new_position = cast.position
                if piece_cast:
                    new_position.y = global.get_stack_height(piece_cast.collider.row, piece_cast.collider.column) + 0.2
                global.current_piece.set_translation(new_position)
        elif global.current_piece:
            global.restore_initial_position()
            global.stop_drag_drop()
    elif global.current_piece and Input.is_key_pressed(KEY_R):
        global.current_piece.toggle_block()     
    
