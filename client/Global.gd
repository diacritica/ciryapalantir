extends Node

# Layers | Masks
# Tile: 1 | 2
# Piece: 2 | 1,2
# Board: 3 | 1,2,3

var current_piece = null
var board_state = []
var cirya_height = 0.102
var board = null

func render_board():
    for row_index in  range(board_state.size()):
        var row = board_state[row_index]
        for column_index in range(row.size()):
            var column = row[column_index]
            for piece_index in range(column.size()):
                var piece_id = row[column_index][piece_index]
                var piece = instance_from_id(piece_id)
                var tile = get_tile(row_index, column_index)
                print( column.size())
                
                var new_position = tile.global_transform.origin
                new_position.y = column.size() * cirya_height
                
                piece.set_translation(new_position)

func get_tile(row, column):
    var tiles = board.get_node('Tiles').get_children()
    
    print(tiles[0])

    for node in tiles:
        if node.row == row and node.column == column:
            return node
