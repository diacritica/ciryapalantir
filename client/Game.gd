extends Spatial

onready var global = get_node("/root/Global")
var ray_length = 100

func _ready():
    global.game = self
    
    var camera = get_viewport().get_camera()
    global.ui = camera.get_node('GameUI')
    
    global.ui
    global.ui.connect("turn_confirmation", self, "_on_turn_confirmation")
    
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
    
    if exclude_current_piece and global.dragging_nosse:
        mouse_raycast_collision = global.dragging_nosse.get_children()[0].collision_mask
        exclude.append(global.dragging_nosse)
    
    # https://docs.godotengine.org/es/stable/classes/class_physicsdirectspacestate.html
    return camera.get_world().direct_space_state.intersect_ray(from, to, exclude, mouse_raycast_collision, true, false)

#var current_outline = null
#func _physics_process(delta):
#    if current_outline:
#        current_outline.hide_outline()
#
#    if global.dragging_nosse:
#        current_outline = global.dragging_nosse
#        current_outline.show_outline()
#    else:
#        var cast = get_mouse_cast()
#
#        if not cast.empty() and cast.collider.collision_layer == 2:
#            current_outline = cast.collider
#            current_outline.show_outline()
#        elif current_outline:
#            current_outline = null
      
var piece_cast_tile = null    
var piece_source_tile = null
var last_turn = null

func _input(event):
    if (event is InputEventMouseButton and event.button_index == BUTTON_LEFT) or (event is InputEventMouseMotion and global.dragging_nosse):    
        if piece_cast_tile and piece_cast_tile.collider != piece_source_tile:
            piece_cast_tile.collider.hideHighlight()
            
        if global.dragging_nosse:          
            var space_state = get_world().direct_space_state
            piece_cast_tile = space_state.intersect_ray(global.dragging_nosse.global_transform.origin, Vector3(0, -ray_length, 0), [], 2147483647, false, true)
            if piece_cast_tile:
                piece_cast_tile.collider.showHighlight()
        
        var cast = get_mouse_cast()

        if not cast.empty():
            if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
                # init drag
                if event.is_pressed() and cast.collider.collision_layer == 2: 
                    var piece = cast.collider
                    var tile = global.get_piece_tile(piece.get_instance_id())
                        
                    if !tile: 
                        global.move_to(piece, self)                                 
                        global.init_drag_drop([piece])    
                    else:
                        var pieces = global.get_top_pieces(piece.get_instance_id())
                        global.init_drag_drop(pieces)    
                        
                # stop drag
                elif global.dragging_nosse and not piece_cast_tile.empty():
                    var wrapper = global.dragging_nosse
                    var old_tile = global.get_piece_tile(wrapper.get_instance_id())
                    last_turn = {}
                    
                    if old_tile:
                        last_turn.old = Vector2(old_tile.row, old_tile.column)    
                    else:
                        last_turn.old = null
                    
                    global.stop_drag_drop(piece_cast_tile.collider)    

                    piece_cast_tile.collider.hideHighlight()
                    
                    #todo
                    #last_turn.new = Vector2(piece_cast_tile.collider.row, piece_cast_tile.collider.column)       
                    #last_turn.piece_type = piece.get_notation_name()
                    
                    if piece_source_tile:
                        piece_source_tile.hideHighlight()
                        piece_source_tile = null
            # drag movement
            elif global.dragging_nosse and event is InputEventMouseMotion:
                if not piece_source_tile and piece_cast_tile:
                    piece_source_tile = piece_cast_tile.collider
                    piece_source_tile.showHighlight()
                        
                var new_position = cast.position

                if piece_cast_tile:
                    var piece = global.dragging_nosse
                    
                    new_position.y = global.get_stack_height(piece_cast_tile.collider.row, piece_cast_tile.collider.column, global.get_dragging_nosse_pieces_ids()) + 0.2
                if new_position.y < 0.2:
                    new_position.y = 0.2
  
                global.dragging_nosse.set_translation(new_position)
        elif global.dragging_nosse:
            global.restore_initial_position()
            global.stop_drag_drop()
    elif global.dragging_nosse and Input.is_key_pressed(KEY_R):
        global.dragging_nosse.toggle_block()     
    
func _on_turn_confirmation(value):
    print(global.notation(last_turn))
