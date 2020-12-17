extends Spatial

onready var global = get_node("/root/Global")
var ray_length = 100

var hover_selected = []

func _ready():
    global.game = self

    var camera = get_viewport().get_camera()
    global.ui = camera.get_node('GameUI')
    global.ui.connect("turn_confirmation", self, "_on_turn_confirmation")

    for piece in $Fleet.get_children():
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

var current_outline = null
func _physics_process(delta):
    if current_outline:
        var piece = current_outline
        if not hover_selected.has(piece):
            #piece.show_outline()
            piece.show_hover()
            hover_selected.append(piece)
#        for i in range(hover_selected.size()):
#            var p = hover_selected.pop_back()
#            p.hide_selected()

    if global.dragging_nosse:
        for piece in global.dragging_nosse.get_children():
            if not hover_selected.has(piece):
                #piece.show_outline()
                piece.show_hover()
                hover_selected.append(piece)
    else:
        var cast = get_mouse_cast()

        if not cast.empty() and cast.collider.collision_layer == 2:
            current_outline = cast.collider
            var piece = cast.collider
            if not hover_selected.has(piece):
                piece.show_hover()
                hover_selected.append(piece)
        elif current_outline:
            current_outline = null
            for i in range(hover_selected.size()):
                var piece = hover_selected.pop_back()
                piece.hide_hover()
var piece_cast_tile = null
var piece_source_tile = null
var movements = []

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
                if !global.undo_state:
                    global.save_pieces_translation()

                # init drag
                if event.is_pressed() and cast.collider.collision_layer == 2:
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
                elif global.dragging_nosse and not piece_cast_tile.empty():
                    
                        
                    var wrapper = global.dragging_nosse
                    var pieces_ids = global.get_dragging_nosse_pieces_ids()
                    var old_tile = global.get_piece_tile(pieces_ids[0])
                    var last_turn = {
                        "from": null,
                        "to": null,
                        "pieces": pieces_ids
                    }

                    if old_tile:
                        last_turn.from = Vector2(old_tile.row, old_tile.column)

                    last_turn.to = Vector2(piece_cast_tile.collider.row, piece_cast_tile.collider.column)
                    movements.append(last_turn)

                    global.stop_drag_drop(piece_cast_tile.collider)

                    piece_cast_tile.collider.hideHighlight()

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
                if new_position.y < 2.2:
                    new_position.y = 2.2

                global.dragging_nosse.set_translation(new_position)
                
               
                
        elif global.dragging_nosse:
            global.restore_initial_position()
            global.stop_drag_drop()


                
    elif global.dragging_nosse and global.dragging_nosse.get_children().size() == 1 and Input.is_key_pressed(KEY_R):
        get_node("piecerotation").play()
        var tile = global.get_piece_tile(global.dragging_nosse.get_children()[0].get_instance_id())
        if !tile:
            global.dragging_nosse.get_children()[0].toggle_block()

func _on_turn_confirmation(value):
    if value:
        print(movements)
        print(global.notation(movements))
        movements = []
        global.save_pieces_translation()
    else:
        global.restore_initial_position()

