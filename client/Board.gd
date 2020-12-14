tool
extends Spatial

export(int) var columns = 5
export(int) var rows = 5
export(bool) var auto = true

var border_width = 0.16
var tile_size = 2

# Called when the node enters the scene tree for the first time.
func _ready():
    var mainTile = $BaseTile
    var tiles = get_node_or_null("Tiles")
    
    if tiles && auto:
        self.remove_child(tiles)
        
    tiles = get_node_or_null("Tiles")
    
    if !tiles:
        tiles = Spatial.new()
        tiles.name = 'Tiles'
        
        if auto:            
            tiles.translation.x = -(rows * (tile_size + border_width)) / 2 + 1 + border_width / 2
            tiles.translation.z = -(columns * (tile_size + border_width)) / 2 + 1 + border_width / 2
        
        self.add_child(tiles)    
        tiles.set_owner(get_tree().edited_scene_root)
    
    for row in range(rows):
        for column in range(columns):
            var new_tile = mainTile.duplicate()
            new_tile.translation.x = row * (tile_size + border_width)
            new_tile.translation.z = column * (tile_size + border_width)
            new_tile.visible = true
            tiles.add_child(new_tile)
            new_tile.set_owner(get_tree().edited_scene_root)
