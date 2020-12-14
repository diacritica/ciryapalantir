extends Spatial

var ray_length = 100

#func _physics_process(delta):
#    var camera = $Camera2
#    var mouse = get_viewport().get_mouse_position()
#    var from = camera.project_ray_origin(mouse)
#    var to = from + camera.project_ray_normal(mouse) * ray_length
#
#    var cast = camera.get_world().direct_space_state.intersect_ray(from, to, [self], $cirya.collision_mask, true, true)
#
#    if not cast.empty():
#        print('eeeiii', cast.collider)

var current
        
func _input(event):
    if (event is InputEventMouseButton and event.button_index == BUTTON_LEFT) or (event is InputEventMouseMotion and current):
        var camera = $Camera2
        var mouse = get_viewport().get_mouse_position()
        var from = camera.project_ray_origin(mouse)
        var to = from + camera.project_ray_normal(mouse) * ray_length        
        var exclude = [self]
        
        if current:
            exclude.append(current)
            
        var cast = camera.get_world().direct_space_state.intersect_ray(from, to, exclude, $cirya.collision_mask, true, true)

        if not cast.empty():
            if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
                if event.is_pressed() and cast.collider.is_class("StaticBody"):     
                    current = cast.collider
                elif cast.collider.is_class("Area"):
                    var new_position = cast.collider.transform.origin
                    cast.collider.visible = true
                    new_position.y = 2
                    current.set_translation(new_position)
                    current = null
            elif current and event is InputEventMouseMotion:
                current.set_translation(cast.position)
