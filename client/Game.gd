extends Spatial

var ray_length = 100
var current
        
func _input(event):
    if (event is InputEventMouseButton and event.button_index == BUTTON_LEFT) or (event is InputEventMouseMotion and current):
        var camera = get_viewport().get_camera()
        var mouse = get_viewport().get_mouse_position()
        var from = camera.project_ray_origin(mouse)
        var to = from + camera.project_ray_normal(mouse) * ray_length        
        var exclude = [self]
        var collision = 2
        
        if current:
            collision = current.collision_mask
            exclude.append(current)
            
        var cast = camera.get_world().direct_space_state.intersect_ray(from, to, exclude, collision, true, true)

        if not cast.empty():
            if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
                if event.is_pressed() and cast.collider.collision_layer == 2:     
                    current = cast.collider
                elif current and cast.collider.is_class("Area"):
                    var new_position = cast.collider.global_transform.origin
                    new_position.y = cast.position.y
                    current.set_translation(new_position)
                    # cast.collider.visible = true
                    current = null
                elif current and cast.collider.collision_layer == 2:
                    var new_position = cast.collider.global_transform.origin
                    new_position.y = cast.position.y
                    current.set_translation(new_position)
                    current = null
            elif current and event is InputEventMouseMotion:
                current.set_translation(cast.position)
