extends Reference

# A piece without a scene: what the rules need from units/Unit.gd

var player = 1
var type = "CIRYA"
var block = false

func _init(name = "C1"):
    player = int(name[1])
    type = "HALLACIRYA" if name[0] == "H" else "CIRYA"
    block = name[0] == "T"

func get_notation_name():
    if type == "HALLACIRYA":
        return "H"
    elif block:
        return "T"

    return "C"

func toggle_block():
    block = !block
