tool
extends Spatial

export(int) var columns = 5
export(int) var rows = 5
export(bool) var auto = true

var border_width = 0.04
var tile_size = 2.35
var offset_width = tile_size + border_width
var map_border = 2.58

onready var global = get_node("/root/Global")
var tile = preload("res://Tile.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
    global.board = self
    var tiles = get_node_or_null("Tiles")
    
    if tiles && auto:
        self.remove_child(tiles)
        
    tiles = get_node_or_null("Tiles")
    
    if !tiles:
        tiles = Spatial.new()
        tiles.name = 'Tiles'
        
        if auto:            
            tiles.translation.x = -(rows * offset_width) / 2 + (offset_width / 2)
            tiles.translation.z = -(columns * offset_width) / 2 + (offset_width / 2)
            tiles.translation.y = -0.7
        
        self.add_child(tiles)    
        tiles.set_owner(get_tree().edited_scene_root)
        
    if tiles.get_child_count() == 0:
        for row in range(rows):
            global.board_state.append([])
            for column in range(columns):
                global.board_state[row].append([])
                
                var new_tile = tile.instance()
                new_tile.translation.x = row * offset_width
                new_tile.translation.z = column * offset_width
                new_tile.visible = false
                new_tile.row = row
                new_tile.column = column
                tiles.add_child(new_tile)
                new_tile.set_owner(get_tree().edited_scene_root)
