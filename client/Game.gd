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

	var fleet = load("res://Fleet.tscn").instance()
	fleet.setup(5,"W","B") # 5, 6 or 7, W or B (missing), and B or V
	fleet.translation.x = 12
	fleet.translation.y = 0
	fleet.translation.z = 4
	add_child(fleet)
		
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
					global.init_drag_drop(cast.collider)    
					# global.current_piece.mode = RigidBody.MODE_STATIC
				elif global.current_piece and cast.collider.is_class("Area"):
					cast.collider.drop(global.current_piece)
					global.current_piece = null

			elif global.current_piece and event is InputEventMouseMotion:
				global.current_piece.set_translation(cast.position)
	elif global.current_piece and Input.is_key_pressed(KEY_R):
		global.current_piece.toggle_block()     
	
