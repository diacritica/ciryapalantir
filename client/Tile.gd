extends Area

# A square of the board. It lights up where the dragged pieces can go

# The strong colour of the schematic view, as the outline of a piece taken
const SCHEMATIC_HIGHLIGHT = Color(1, 0.42, 0)

var row = 0
var column = 0

func show_highlight():
    visible = true

func hide_highlight():
    visible = false

# In the schematic view the light is strong and plain, not the soft one of
# the tavern
func set_schematic(on):
    var material = null

    if on:
        material = SpatialMaterial.new()
        material.flags_unshaded = true
        material.albedo_color = SCHEMATIC_HIGHLIGHT

    $MeshInstance.material_override = material
