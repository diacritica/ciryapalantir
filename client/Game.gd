extends Spatial

onready var global = get_node("/root/Global")
var ray_length = 100
        
func _input(event):
    if (event is InputEventMouseButton and event.button_index == BUTTON_LEFT) or (event is InputEventMouseMotion and global.current_piece):
        var camera = get_viewport().get_camera()
        var mouse = get_viewport().get_mouse_position()
        var from = camera.project_ray_origin(mouse)
        var to = from + camera.project_ray_normal(mouse) * ray_length        
        var exclude = [self]
        var collision = 2
        
        if global.current_piece:
            collision = global.current_piece.collision_mask
            exclude.append(global.current_piece)
            
        var cast = camera.get_world().direct_space_state.intersect_ray(from, to, exclude, collision, true, true)

        if not cast.empty():
            if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
                if event.is_pressed() and cast.collider.collision_layer == 2:     
                    global.current_piece = cast.collider
                    global.current_piece.mode = 1
                elif global.current_piece and cast.collider.is_class("Area"):
                    cast.collider.drop(global.current_piece)
                    global.current_piece = null

            elif global.current_piece and event is InputEventMouseMotion:
                global.current_piece.set_translation(cast.position)
