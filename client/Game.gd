extends Spatial

# The table. It turns the mouse into taking and dropping pieces, shows the
# turns of the opponent and puts the pieces back when a turn is undone. What
# is legal is decided by Match and the rules in core/

const Rules = preload("res://core/Rules.gd")

# Collision layers as bit masks: the tiles, the pieces, and what the dragged
# pieces float over (pieces and the table)
const TILES_LAYER = 1
const PIECES_LAYER = 2
const UNDER_HAND_LAYERS = 6
const RAY_LENGTH = 200

# A stack starts this high over the tiles, and the hand floats this much over it
const STACK_BASE = 0.5
const HAND_GAP = 0.2
const HAND_MIN_HEIGHT = 2.2
# A piece shown for the opponent appears at least this high, and falls
const PLACE_MIN_HEIGHT = 1.0
const FALL_IMPULSE = Vector3(0, -0.1, 0)
# Seconds for rejected pieces to fly back
const RETURN_TIME = 0.35

# IDLE: nothing in the hand. DRAGGING: the hand follows the mouse.
# RETURNING: rejected pieces fly back and nothing can be taken
enum Drag { IDLE, DRAGGING, RETURNING }

onready var Match = get_node("/root/Match")
onready var Settings = get_node("/root/Settings")

var drag = Drag.IDLE
# The node carrying the pieces being dragged
var hand = null
# Where every piece of the hand was, to fly it back
var hand_origins = {}
# The tile the hand was taken from, and the tile under the hand
var origin_tile = null
var hover_tile = null
# Where every piece was when the turn started, to undo it (global transforms)
var turn_start = {}

func _ready():
    Settings.medium()
    Settings.apply_settings(self)
    Match.new_board($Board.rows)

    $UI.connect("turn_confirmation", self, "_on_turn_confirmation")
    Match.connect("opponent_played", self, "_on_opponent_played")
    Match.connect("turn_refused", self, "_on_turn_refused")

    # Player 1, the sandbox and spectators look from the side of player 1
    if Match.player != 2:
        $CameraPlayer1.current = true
        remove_child($CameraPlayer2)
        remove_child($Particles2)
    else:
        $CameraPlayer2.current = true
        remove_child($CameraPlayer1)
        remove_child($Particles)

    for fleet in [$Fleet, $Fleet2]:
        for piece in fleet.get_children():
            if piece.is_in_group("pieces"):
                var position = piece.global_transform.origin
                _reparent(piece, $Pieces)
                piece.translation = position

    $sandboxlogo.visible = Match.sandbox

func _input(event):
    if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
        if event.pressed and drag == Drag.IDLE:
            var cast = _mouse_cast()

            if cast and cast.collider.is_in_group("pieces") and Match.can_take(cast.collider.get_instance_id()):
                take(cast.collider)

        elif !event.pressed and drag == Drag.DRAGGING:
            release(_tile_under_hand())

    elif event is InputEventMouseMotion and drag == Drag.DRAGGING:
        _follow_mouse()

    elif event is InputEventKey and event.pressed and !event.echo and event.scancode == KEY_R and drag == Drag.DRAGGING:
        _rotate()

# Takes the piece and the ones above it
func take(piece):
    var piece_id = piece.get_instance_id()

    if !Match.move_started():
        Match.start_move(piece_id, _pieces())
        _remember_turn_start()

    var square = Match.board.square_of(piece_id)
    var ids = [piece_id] if square == null else Match.board.pieces_from(piece_id)

    hand = Spatial.new()
    hand.translation = piece.translation
    hand_origins = {}

    for id in ids:
        var each = instance_from_id(id)
        hand_origins[id] = each.global_transform
        each.get_node("CollisionShape").disabled = true
        # The locks stay after the drop, so the pieces do not slide off their stack
        each.axis_lock_linear_x = true
        each.axis_lock_linear_z = true
        each.mode = RigidBody.MODE_STATIC
        each.translation.x = 0
        each.translation.z = 0
        each.show_selected()
        each.add_to_group("hand")
        _reparent(each, hand)

    add_child(hand)
    drag = Drag.DRAGGING
    origin_tile = $Board.tile(square) if square != null else null

    if origin_tile:
        origin_tile.show_highlight()

    $select.play()

# Drops the hand on the tile when the move allows it, and otherwise sends the
# pieces back. The tile is null when the hand is not over the board
func release(tile):
    if tile and Match.can_drop(_hand_ids(), _square(tile)):
        drop(tile)
    else:
        cancel()

func drop(tile):
    var square = _square(tile)
    Match.board.put(_hand_ids(), square)

    for piece in hand.get_children():
        var height = piece.global_transform.origin.y
        _land(piece)
        _put_at(piece, Vector3(tile.global_transform.origin.x, height, tile.global_transform.origin.z))

    Match.move.sync_tampar(Match.board)
    _close_hand()

# The pieces fly back and the board does not change
func cancel():
    var tween = Tween.new()
    var pieces = hand.get_children()
    add_child(tween)

    for piece in pieces:
        var current = piece.global_transform
        piece.hide_selected()
        piece.remove_from_group("hand")
        _reparent(piece, $Pieces)
        piece.global_transform = current
        tween.interpolate_property(piece, "global_transform", current, hand_origins[piece.get_instance_id()], RETURN_TIME, Tween.TRANS_QUAD, Tween.EASE_OUT)

    tween.connect("tween_all_completed", self, "_on_returned", [tween, pieces], CONNECT_ONESHOT)
    tween.start()
    _close_hand()
    drag = Drag.RETURNING
    _lay_fleet_down()
    $undo.play()

func _on_returned(tween, pieces):
    for piece in pieces:
        piece.mode = RigidBody.MODE_RIGID
        piece.get_node("CollisionShape").disabled = false

    tween.queue_free()
    drag = Drag.IDLE

func _land(piece):
    piece.mode = RigidBody.MODE_RIGID
    piece.get_node("CollisionShape").disabled = false
    piece.hide_selected()
    piece.remove_from_group("hand")
    _reparent(piece, $Pieces)

func _close_hand():
    remove_child(hand)
    hand.queue_free()
    hand = null
    drag = Drag.IDLE

    for tile in [origin_tile, hover_tile]:
        if tile:
            tile.hide_highlight()

    origin_tile = null
    hover_tile = null

# The hand follows the mouse over the stacks, and the tile under it lights up
# when the pieces can go there
func _follow_mouse():
    if hover_tile and hover_tile != origin_tile:
        hover_tile.hide_highlight()

    hover_tile = _tile_under_hand()

    if hover_tile and Match.can_drop(_hand_ids(), _square(hover_tile)):
        hover_tile.show_highlight()

    var cast = _mouse_cast()

    if !cast:
        return

    var position = cast.position

    if hover_tile:
        position.y = _stack_height(_square(hover_tile), _hand_ids()) + HAND_GAP

    position.y = max(position.y, HAND_MIN_HEIGHT)
    hand.translation = position

# A piece from the fleet can be placed standing, as a tampa, except in the opening
func _rotate():
    var piece = hand.get_child(0)

    if hand.get_child_count() == 1 and piece.get_notation_name() != "H" and Match.board.square_of(piece.get_instance_id()) == null and !Match.opening():
        piece.toggle_block()
        $piecerotation.play()

func _on_turn_confirmation(confirmed):
    if confirmed:
        Match.confirm()
    else:
        _undo()

func _on_turn_refused(_reason):
    _undo()

func _undo():
    if !Match.undo():
        return

    for piece in _pieces():
        piece.global_transform = turn_start[piece.get_instance_id()]

    _lay_fleet_down()
    $undo.play()

func _remember_turn_start():
    turn_start = {}

    for piece in _pieces():
        turn_start[piece.get_instance_id()] = piece.global_transform

# Pieces in the fleet are always flat: one turned into a tampa lies down again
# when it goes back
func _lay_fleet_down():
    for piece in _pieces():
        if piece.block and Match.board.square_of(piece.get_instance_id()) == null:
            piece.toggle_block()

# Shows a turn of the other player
func _on_opponent_played(player, notation, opening):
    var fleet = []

    for piece in _pieces():
        if Match.board.square_of(piece.get_instance_id()) == null:
            fleet.append(piece)

    var steps = Rules.replay(notation, player, opening, Match.board, fleet)

    if steps.empty():
        push_error("cannot show the turn %s of player %d" % [notation, player])

    for step in steps:
        var piece = instance_from_id(step.piece)

        if step.stand:
            piece.toggle_block()

        _place(piece, step.square)

# Puts a piece on top of a square. A hallacirya flattens the tampa under it
func _place(piece, square):
    var stack = Match.board.stack(square)

    if piece.get_notation_name() == "H" and stack and instance_from_id(stack.back()).get_notation_name() == "T":
        instance_from_id(stack.back()).toggle_block()

    var position = $Board.tile(square).global_transform.origin
    position.y = max(_stack_height(square) + HAND_GAP, PLACE_MIN_HEIGHT)
    _put_at(piece, position)
    Match.board.put([piece.get_instance_id()], square)

# Leaves the piece there and lets it fall on what is below
func _put_at(piece, position):
    var transform = piece.global_transform
    transform.origin = position
    piece.global_transform = transform
    piece.apply_central_impulse(FALL_IMPULSE)

func _stack_height(square, exclude = []):
    var height = STACK_BASE

    for piece_id in Match.board.stack(square):
        if !exclude.has(piece_id):
            height += instance_from_id(piece_id).get_height()

    return height

func _mouse_cast():
    var camera = get_viewport().get_camera()
    var mouse = get_viewport().get_mouse_position()
    var from = camera.project_ray_origin(mouse)
    var to = from + camera.project_ray_normal(mouse) * RAY_LENGTH
    var exclude = []
    var mask = PIECES_LAYER

    if hand:
        mask = UNDER_HAND_LAYERS
        exclude = hand.get_children()

    var cast = get_world().direct_space_state.intersect_ray(from, to, exclude, mask, true, false)
    return cast if !cast.empty() else null

func _tile_under_hand():
    var origin = hand.global_transform.origin
    var cast = get_world().direct_space_state.intersect_ray(origin, origin + Vector3(0, -RAY_LENGTH, 0), [], TILES_LAYER, false, true)
    return cast.collider if !cast.empty() else null

func _hand_ids():
    var ids = []

    for piece in hand.get_children():
        ids.append(piece.get_instance_id())

    return ids

func _pieces():
    return get_tree().get_nodes_in_group("pieces")

func _square(tile):
    return Vector2(tile.row, tile.column)

func _reparent(node, parent):
    node.get_parent().remove_child(node)
    parent.add_child(node)
