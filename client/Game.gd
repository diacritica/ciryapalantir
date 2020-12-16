extends Spatial

onready var global = get_node("/root/Global")
var ray_length = 100

func _ready():
    global.game = self
    
#    var fleet = load("res://Fleet.tscn").instance()
#    fleet.setup(5,"W","B") # 5, 6 or 7, W or B (missing), and B or V
#    fleet.translation.x = 22
#    fleet.translation.y = 0
#    fleet.translation.z = 4
#    add_child(fleet)

func get_mouse_cast(exclude_current_piece = true):  
    var mouse_raycast_collision = 2
    
    var camera = get_viewport().get_camera()
    var mouse = get_viewport().get_mouse_position()
    var from = camera.project_ray_origin(mouse)
    var to = from + camera.project_ray_normal(mouse) * ray_length        
    var exclude = [self]
    
    if exclude_current_piece and global.current_piece:
        mouse_raycast_collision = global.current_piece.collision_mask
        exclude.append(global.current_piece)
    
    # https://docs.godotengine.org/es/stable/classes/class_physicsdirectspacestate.html
    return camera.get_world().direct_space_state.intersect_ray(from, to, exclude, mouse_raycast_collision, true, false)

var current_outline = null
func _physics_process(delta):
    if current_outline:
        current_outline.hide_outline()
    
    if global.current_piece:
        current_outline = global.current_piece
        current_outline.show_outline()
    else:
        var cast = get_mouse_cast()
        
        if not cast.empty() and cast.collider.collision_layer == 2:
            current_outline = cast.collider
            current_outline.show_outline()
        elif current_outline:
            current_outline = null
      
var piece_cast_tile = null    
var piece_source_tile = null

func _input(event):
    if (event is InputEventMouseButton and event.button_index == BUTTON_LEFT) or (event is InputEventMouseMotion and global.current_piece):    
        if piece_cast_tile and piece_cast_tile.collider != piece_source_tile:
            piece_cast_tile.collider.hideHighlight()
            
        if global.current_piece:          
            var space_state = get_world().direct_space_state
            piece_cast_tile = space_state.intersect_ray(global.current_piece.global_transform.origin, Vector3(0, -ray_length, 0), [], 2147483647, false, true)
            if piece_cast_tile:
                piece_cast_tile.collider.showHighlight()
        
        var cast = get_mouse_cast()

        if not cast.empty():
            if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
                # init drag
                if event.is_pressed() and cast.collider.collision_layer == 2: 
                    var target = cast.collider
                    $Fleet.remove_child(target)

                    target.set_translation(cast.position)
                    self.add_child(target)
                    self.set_owner(target)                    
                                        
                    global.init_drag_drop(target)    
                # stop drag
                elif global.current_piece and not piece_cast_tile.empty():
                    var piece = global.current_piece
                    global.stop_drag_drop()    
                    piece_cast_tile.collider.drop(piece)
                    
                    piece_cast_tile.collider.hideHighlight()
                    
                    if piece_source_tile:
                        piece_source_tile.hideHighlight()
                        piece_source_tile = null
            # drag movement
            elif global.current_piece and event is InputEventMouseMotion:
                if not piece_source_tile and piece_cast_tile:
                    piece_source_tile = piece_cast_tile.collider
                    piece_source_tile.showHighlight()
                        
                var new_position = cast.position
                var min_height = global.current_piece.get_height()
                
                if piece_cast_tile:
                    var piece = global.current_piece
                    
                    new_position.y = global.get_stack_height(piece_cast_tile.collider.row, piece_cast_tile.collider.column, global.current_piece.get_instance_id()) + 0.2
                if new_position.y < 0.2:
                    new_position.y = 0.2
  
                global.current_piece.set_translation(new_position)
        elif global.current_piece:
            global.restore_initial_position()
            global.stop_drag_drop()
    elif global.current_piece and Input.is_key_pressed(KEY_R):
        global.current_piece.toggle_block()     
    
