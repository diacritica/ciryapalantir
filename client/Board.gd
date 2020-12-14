tool
extends Spatial

export(int) var columns = 5
export(int) var rows = 5

var border_width = 0.16

# Called when the node enters the scene tree for the first time.
func _ready():
    print(columns)
    print(rows)

    var mainTile = $BaseTile
    var tiles = $Tiles
    
#    var new_tile = mainTile.duplicate()
#    new_tile.translation.x = mainTile.translation.x + 2 + 0.16
#    new_tile.translation.z = mainTile.translation.z + 1 + 0.16
#
#    self.add_child(new_tile)
#
    for row in range(rows):
        for column in range(columns):
            var new_tile = mainTile.duplicate()
            new_tile.translation.x = row * 2 + row * border_width
            new_tile.translation.z = column * 2 + column * border_width
            tiles.add_child(new_tile)
            new_tile.set_owner(get_tree().edited_scene_root)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
