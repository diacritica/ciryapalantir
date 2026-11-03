extends Control

# The written move: a field that opens from the bottom edge by its handle.
# Enter or the arrow put the move on the board, and Enter on the empty
# field confirms it, so a whole turn can be played with the keyboard. It
# shows in the turns of the player; UI says when

# A turn typed in the field, for the game to make it on the board
signal move_written(text)
# Enter on the empty field, to confirm the turn as its button does
signal confirm_requested
# The field opened or closed: the board shows its coordinates while it is open
signal entry_shown(shown)

# Where the top of the handle sits with the field closed, how much it rises
# when it opens, and how fast
const CLOSED_TOP = -36
const ENTRY_HEIGHT = 72
const ENTRY_TIME = 0.15

# The field is open, and stays so from turn to turn
var open = false

func _ready():
    $Handle.connect("pressed", self, "toggle")
    $Field/Text.connect("text_entered", self, "_on_text_entered")
    $Field/Text.connect("gui_input", self, "_on_text_input")
    $Field/Send.connect("pressed", self, "_send")
    _shape(false)

func show_for_turn(shown):
    visible = shown
    emit_signal("entry_shown", shown and open)

    if shown and open:
        $Field/Text.grab_focus()
    elif !shown:
        $Field/Text.release_focus()

func toggle():
    open = !open
    _shape(true)
    emit_signal("entry_shown", open)

    if open:
        $Field/Text.grab_focus()
    else:
        $Field/Text.release_focus()

func _shape(animated):
    var top = CLOSED_TOP - (ENTRY_HEIGHT if open else 0)
    $Handle/Label.text = "Cerrar" if open else "Escribir jugada"

    if !animated:
        margin_top = top
        return

    var tween = Tween.new()
    add_child(tween)
    tween.interpolate_property(self, "margin_top", margin_top, top, ENTRY_TIME, Tween.TRANS_QUAD, Tween.EASE_OUT)
    tween.connect("tween_all_completed", tween, "queue_free")
    tween.start()

func _on_text_entered(text):
    if text.strip_edges() == "":
        emit_signal("confirm_requested")
        return

    emit_signal("move_written", text)

# The arrow only sends: confirming is for Enter or the button
func _send():
    if $Field/Text.text.strip_edges() != "":
        _on_text_entered($Field/Text.text)

# Escape closes the field, and does not ask to leave
func _on_text_input(event):
    if event.is_action_pressed("ui_cancel"):
        $Field/Text.accept_event()
        toggle()

# The move is on the board: the field is ready for the next one
func clear():
    $Field/Text.text = ""

# A no with the head, for a move that cannot be made
func shake():
    var field = $Field
    var x = field.rect_position.x
    var steps = [x, x + 10, x - 10, x + 6, x]
    var tween = Tween.new()
    add_child(tween)

    for i in range(steps.size() - 1):
        tween.interpolate_property(field, "rect_position:x", steps[i], steps[i + 1], 0.05, Tween.TRANS_SINE, Tween.EASE_IN_OUT, i * 0.05)

    tween.connect("tween_all_completed", tween, "queue_free")
    tween.start()
