tool
extends Area

# A square of the board. It lights up where the dragged pieces can go

var row = 0
var column = 0

func show_highlight():
    visible = true

func hide_highlight():
    visible = false
