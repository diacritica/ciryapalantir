extends Node

# A list of turns replayed on the board of the demo, to comment a game. The
# whole list is checked first with the rules, turn by turn, and stops at the
# first one that cannot be played. Then the arrows go through it: forward
# moves the pieces of the turn one square after another, lit as when taken,
# and back slides them to where they were. Meanwhile the pieces are still,
# out of the physics, each one resting just where it goes: only the ones of
# the turn move, and nothing falls

signal position_changed(index)

const BoardState = preload("res://core/BoardState.gd")
const Rules = preload("res://core/Rules.gd")

# Seconds for the pieces of a turn to reach each square, and how high over
# their place they arrive; then they settle on it, and going back they slide
const STEP_TIME = 0.35
const ARRIVAL_GAP = 0.3
const SETTLE_TIME = 0.12
const BACK_TIME = 0.25
# Where the pieces rest, measured on the board: a flat cirya or a standing
# tampa this high over its tile, each flat piece under it raising it, and a
# hallacirya that much under the top it lies on
const FLOOR = 0.232
const THICKNESS = 0.28
const HALLACIRYA_DROP = -0.116

onready var Match = get_node("/root/Match")

var game
var turns = []
# The player of the first turn of the list
var first_player = 1
# Played from the start, with the openings, or on the board as it was
var from_start = true
# The board and the tampar standing (their ids) before each turn, with the
# steps of the turn, and after the last one that can be played
var states = []
# The first turn that cannot be played and why, or -1
var wrong = -1
var error = ""
# Turns played on the board now
var index = 0
var moving = false

func start(scene, list, clean, player):
    game = scene
    turns = list
    from_start = clean
    first_player = player

    var board = BoardState.new(Match.board.size()) if clean else Match.board.copy()
    var blocks = {}
    var pieces = []

    for piece in game._pieces():
        pieces.append(piece.get_instance_id())

        if piece.block and !clean:
            blocks[piece.get_instance_id()] = true

    states = [{"board": board, "blocks": blocks}]

    for piece in game._pieces():
        piece.mode = RigidBody.MODE_STATIC

    for i in range(turns.size()):
        var result = Rules.apply_turn(turns[i], player_of(i), clean and i < 2, states.back().board, states.back().blocks, pieces)

        if result.error:
            wrong = i
            error = result.error
            break

        states.back()["steps"] = result.steps
        states.append({"board": result.board, "blocks": result.blocks})

    _show(0, BACK_TIME)

# The physics again for the pieces, to move them by hand
func _exit_tree():
    for piece in game._pieces():
        piece.mode = RigidBody.MODE_RIGID

# The player of the turn of the list, counted from 0
func player_of(turn):
    return first_player if turn % 2 == 0 else 3 - first_player

# The turns that can be played
func playable():
    return states.size() - 1

func forward():
    if moving or index >= playable():
        return

    moving = true
    yield(_move(states[index].steps, states[index + 1]), "completed")
    yield(_show(index + 1, SETTLE_TIME), "completed")
    moving = false

func back():
    if moving or index == 0:
        return

    moving = true
    yield(_show(index - 1, BACK_TIME), "completed")
    moving = false

func _unhandled_input(event):
    if !(event is InputEventKey) or !event.pressed:
        return

    if event.scancode in [KEY_RIGHT, KEY_DOWN]:
        get_tree().set_input_as_handled()
        forward()
    elif event.scancode in [KEY_LEFT, KEY_UP]:
        get_tree().set_input_as_handled()
        back()

# Every piece where the board says after so many turns, the tampar standing
# or flat: the ones that are elsewhere go there in that time
func _show(turn, time):
    index = turn
    var state = states[turn]
    Match.set_board(state.board.copy())
    var tween = Tween.new()
    add_child(tween)

    for piece in game._pieces():
        if piece.block != state.blocks.has(piece.get_instance_id()):
            piece.toggle_block()

        var target = _resting(piece)

        if piece.global_transform.origin.distance_to(target.origin) > 0.01:
            tween.interpolate_property(piece, "global_transform", piece.global_transform, target, time, Tween.TRANS_QUAD, Tween.EASE_OUT)

    tween.start()
    emit_signal("position_changed", index)

    if tween.is_active():
        yield(tween, "tween_all_completed")
    else:
        yield(get_tree(), "idle_frame")

    tween.queue_free()

# Where the piece rests on the board now: on its square, over the flat
# pieces under it, or in its place in the fleet
func _resting(piece):
    var piece_id = piece.get_instance_id()
    var square = Match.board.square_of(piece_id)

    if square == null:
        return game.home[piece_id]

    var transform = piece.global_transform
    transform.origin = _place_on(square, Match.board.stack(square).find(piece_id), piece)
    return transform

func _place_on(square, height, piece):
    var place = game.get_node("Board").tile(square).global_transform.origin
    place.y += FLOOR + THICKNESS * height

    if piece.type == "HALLACIRYA":
        place.y += HALLACIRYA_DROP

    return place

# The pieces of a turn go to their squares in order, the ones dropped on the
# same square together: from the fleet for a placement, and square after
# square in a nossë. They arrive lit over their place in the board after
func _move(steps, after):
    var drops = []

    for step in steps:
        if drops and drops.back().square == step.square:
            drops.back().pieces.append(step.piece)
        else:
            drops.append({"square": step.square, "pieces": [step.piece], "stand": step.stand})

    var moved = []

    for drop in drops:
        var tween = Tween.new()
        add_child(tween)

        for piece_id in drop.pieces:
            var piece = instance_from_id(piece_id)

            if !moved.has(piece):
                moved.append(piece)
                piece.show_selected()

            if drop.stand and !piece.block:
                piece.toggle_block()

            var target = _place_on(drop.square, after.board.stack(drop.square).find(piece_id), piece)
            target.y += ARRIVAL_GAP
            tween.interpolate_property(piece, "translation", piece.translation, target, STEP_TIME, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)

        tween.start()
        yield(tween, "tween_all_completed")
        tween.queue_free()

    for piece in moved:
        piece.hide_selected()
