extends SceneTree

# Breaking a nossë in the client, with the real Global.gd and Validation.gd and
# no scene. Run it from the client folder:
#   godot --no-window --path . -s tests/test_moves.gd
# It exits with 1 when something fails

var G
var V
var piece_script
var failures = 0

func _init():
    piece_script = GDScript.new()
    piece_script.source_code = """extends Spatial
var player = 1
var type = 'CIRYA'
var block = false
var collision_layer = 2
func get_notation_name():
    if type == 'HALLACIRYA':
        return 'H'
    elif block:
        return 'T'
    return 'C'
func toggle_block():
    block = !block
func get_height():
    return 0.2
func apply_central_impulse(impulse):
    pass
"""
    piece_script.reload()

    for test in [
        "test_cannot_return_a_drop_over_the_carry",
        "test_a_lower_stone_cannot_go_over_a_higher_one",
        "test_redistribute_the_drops",
        "test_back_to_the_origin_carries_less",
        "test_all_back_to_the_origin_undoes_the_move",
        "test_only_the_pieces_of_the_move",
        "test_one_direction",
        "test_hallacirya_flattens_and_releases_a_tampa",
        "test_tampa_needs_a_lone_hallacirya",
        "test_nosse_of_the_opponent",
        "test_turns_alternate",
        "test_carry_limit",
        "test_placement",
        "test_opening_places_a_cirya_of_the_opponent",
        "test_opening_has_no_moves",
        "test_opening_ends_after_turn_2",
        "test_opening_of_the_opponent_is_replayed",
    ]:
        setup()
        print("- ", test)
        call(test)
        teardown()

    print("FAILURES: ", failures)
    quit(1 if failures else 0)

func check(label, condition):
    if !condition:
        failures += 1
        print("    FAIL ", label)

# Pieces and board ------------------------------------------------------------

func setup():
    V = load("res://Validation.gd").new()
    G = load("res://Global.gd").new()
    V.Global = G
    G.Validation = V
    G.sandbox = true
    G.player = 1
    # After the opening, unless the test says otherwise
    G.turn = 3

    var tile_script = GDScript.new()
    tile_script.source_code = "extends Spatial\nvar row = 0\nvar column = 0\n"
    tile_script.reload()

    G.board = Spatial.new()
    var tiles = Spatial.new()
    tiles.name = "Tiles"
    G.board.add_child(tiles)
    get_root().add_child(G.board)

    for row in range(5):
        G.board_state.append([])
        for column in range(5):
            G.board_state[row].append([])
            var tile = Spatial.new()
            tile.set_script(tile_script)
            tile.row = row
            tile.column = column
            tiles.add_child(tile)

func teardown():
    for piece in G.pieces:
        piece.free()
    G.board.free()
    G.free()
    V.free()

# "C1" a cirya of player 1, "T2" a tampa of player 2, "H1" a hallacirya
func piece(name):
    var p = Spatial.new()
    p.set_script(piece_script)
    p.player = int(name[1])
    p.type = "HALLACIRYA" if name[0] == "H" else "CIRYA"
    p.block = name[0] == "T"
    G.pieces.append(p)
    return p.get_instance_id()

# Puts pieces on a square, written as "a1"
func put(square, names):
    var ids = []
    var at = G.notation_to_vector(square)
    for name in names:
        var id = piece(name)
        ids.append(id)
        G.board_state[at.x][at.y].append(id)
    return ids

func stack(square):
    var at = G.notation_to_vector(square)
    return G.board_state[at.x][at.y]

# Game.gd: taking the piece and those above it, then dropping them --------------

func pick(piece_id):
    if !V.can_move(piece_id):
        return false

    if !G.move_started():
        G.start_move(piece_id)

    G.dragging_nosse = Spatial.new()
    var tile = G.get_piece_tile(piece_id)
    var taken = [piece_id]

    if tile:
        var ids = G.board_state[tile.row][tile.column]
        taken = V.tail(ids, ids.find(piece_id))

    for id in taken:
        var p = instance_from_id(id)
        if p.get_parent():
            p.get_parent().remove_child(p)
        G.dragging_nosse.add_child(p)

    return true

func drop(square):
    var at = G.notation_to_vector(square)
    var ok = V.can_drop(at.x, at.y)

    if ok:
        G.board_state = G.board_after_drop(G.get_dragging_nosse_pieces_ids(), at.x, at.y)
        G.sync_tampar()

    for p in G.dragging_nosse.get_children():
        G.dragging_nosse.remove_child(p)

    G.dragging_nosse.free()
    G.dragging_nosse = null
    return ok

func move(piece_id, square):
    return pick(piece_id) and drop(square)

# Tests ------------------------------------------------------------------------

# Pablo, 2026-11-01: 3 of a nossë of 4 to b1, the top one on to c1, and that
# one could be taken back to a1
func test_cannot_return_a_drop_over_the_carry():
    var p = put("a1", ["C1", "C1", "C1", "C1"])

    check("3 to b1", move(p[1], "b1"))
    check("top to c1", move(p[3], "c1"))
    check("notation 3a1>21", G.move_notation() == "3a1>21")
    check("c1 back to a1 is rejected", !move(p[3], "a1"))
    check("board unchanged", stack("a1").size() == 1 and stack("b1").size() == 2 and stack("c1").size() == 1)
    check("still 3a1>21", G.move_notation() == "3a1>21")

# The stones keep the order they were carried in
func test_a_lower_stone_cannot_go_over_a_higher_one():
    var p = put("a1", ["C1", "C1", "C1"])

    check("3 to b1", move(p[0], "b1"))
    check("the top one to c1", move(p[2], "c1"))
    check("the middle one cannot go over it", !move(p[1], "c1"))
    check("3a1>21", G.move_notation() == "3a1>21")

func test_redistribute_the_drops():
    var p = put("a1", ["C1", "C1", "C1", "C1"])

    check("1 to b1", move(p[1], "b1"))
    check("2 to c1", move(p[2], "c1"))
    check("3a1>12", G.move_notation() == "3a1>12")
    check("the 2 of c1 back to b1", move(p[2], "b1"))
    check("3a1>3", G.move_notation() == "3a1>")
    check("the top one to c1 again", move(p[3], "c1"))
    check("3a1>21", G.move_notation() == "3a1>21")
    check("dropping on the same square changes nothing", move(p[3], "c1") and G.move_notation() == "3a1>21")

func test_back_to_the_origin_carries_less():
    var p = put("a1", ["C1", "C1", "C1"])

    check("3 to a2", move(p[0], "a2"))
    check("the top 2 cannot go back under the one left in a2", !move(p[1], "a1"))
    check("all back to a1", move(p[0], "a1"))
    check("2 to a2", move(p[1], "a2"))
    check("2a1+", G.move_notation() == "2a1+")

func test_all_back_to_the_origin_undoes_the_move():
    var p = put("a1", ["C1", "C1"])
    var other = put("e5", ["C1"])

    check("2 to b1", move(p[0], "b1"))
    check("another nossë cannot be taken", !V.can_move(other[0]))
    check("back to a1", move(p[0], "a1"))
    check("nothing to confirm", G.move_notation() == "")
    check("now the other nossë can move", move(other[0], "e4"))
    check("e5-", G.move_notation() == "e5-")

func test_only_the_pieces_of_the_move():
    var p = put("a1", ["C1", "C1"])
    var below = put("c1", ["C1"])

    check("2 to b1", move(p[0], "b1"))
    check("a piece where the move did not go", !V.can_move(below[0]))
    var fleet = piece("C1")
    check("a piece of the fleet", !V.can_move(fleet))

func test_one_direction():
    var p = put("c3", ["C1", "C1", "C1"])

    check("3 to c4", move(p[0], "c4"))
    check("the rest cannot turn to d4", !move(p[1], "d4"))
    check("nor skip c4 and land on c5", !move(p[0], "c5"))
    check("nor go back to c2", !move(p[2], "c2"))

func test_hallacirya_flattens_and_releases_a_tampa():
    var p = put("a1", ["C1", "H1"])
    var t = put("c1", ["T2"])[0]

    check("2 to b1", move(p[0], "b1"))
    check("the hallacirya on to c1", move(p[1], "c1"))
    check("the tampa is flat", !instance_from_id(t).block)
    check("2a1>11", G.move_notation() == "2a1>11")
    check("the hallacirya back to b1", move(p[1], "b1"))
    check("the tampa stands again", instance_from_id(t).block)
    check("2a1>", G.move_notation() == "2a1>")

func test_tampa_needs_a_lone_hallacirya():
    var p = put("a1", ["C1", "H1"])
    put("b1", ["T2"])

    check("a cirya with the hallacirya", !move(p[0], "b1"))
    var q = put("d4", ["C1"])
    put("d5", ["H2"])
    check("a cirya over a hallacirya", !move(q[0], "d5"))

func test_nosse_of_the_opponent():
    var p = put("a1", ["C1", "C2"])

    check("player 1 cannot take it", !V.can_move(p[1]))
    G.player = 2
    check("player 2 can", move(p[1], "a2"))

func test_turns_alternate():
    var one = put("a1", ["C1"])
    var two = put("e5", ["C2"])

    check("player 1 moves", move(one[0], "a2"))
    G.next_sandbox_turn()
    check("now it is player 2", G.player == 2 and G.turn == 4)
    check("player 2 cannot take the cirya of player 1", !V.can_move(one[0]))
    check("player 2 moves", move(two[0], "e4"))

func test_carry_limit():
    var p = put("a1", ["C1", "C1", "C1", "C1", "C1", "C1"])

    check("6 stones cannot be taken", !V.can_move(p[0]))
    check("5 can", move(p[1], "a2"))

func test_placement():
    var occupied = put("c3", ["C2"])
    var c = piece("C1")
    var other = piece("C1")

    check("not on an occupied square", pick(c) and !drop("c3"))
    G.end_move()
    check("on an empty one", move(c, "b2"))
    check("b2", G.move_notation() == "b2")
    check("no second piece from the fleet", !V.can_move(other))
    check("the placed piece can change square", move(c, "d4") and G.move_notation() == "d4")
    var mine = piece("C2")
    check("not a piece of the opponent", !V.can_move(mine))

func test_opening_places_a_cirya_of_the_opponent():
    G.turn = 1
    var own = piece("C1")
    var hallacirya = piece("H2")
    var tampa = piece("T2")
    var cirya = piece("C2")

    check("not an own piece", !V.can_move(own))
    check("not the hallacirya of the opponent", !V.can_move(hallacirya))
    check("not a tampa", !V.can_move(tampa))
    check("a cirya of the opponent", move(cirya, "c3"))
    check("written as a plain placement", G.move_notation() == "c3")
    check("only one", !V.can_move(piece("C2")))

func test_opening_has_no_moves():
    G.turn = 2
    G.player = 2
    var placed = put("a1", ["C2"])

    check("the cirya on the board cannot move", !V.can_move(placed[0]))
    check("a cirya of player 1 from the fleet can be placed", move(piece("C1"), "e5"))

func test_opening_ends_after_turn_2():
    G.turn = 1
    G.next_sandbox_turn()
    check("turn 2 is still the opening", G.opening() and G.player == 2)
    G.next_sandbox_turn()
    check("turn 3 is not", !G.opening() and G.player == 1)
    check("now the own pieces", V.can_move(piece("C1")))
    check("and not the ones of the opponent", !V.can_move(piece("C2")))

# Player 1 places a cirya of player 2: the other client has to take it from
# the fleet of player 2, and never the hallacirya
func test_opening_of_the_opponent_is_replayed():
    var hallacirya = piece("H2")
    var cirya = piece("C2")
    piece("C1")

    G.notation_movement(1, "c3", true)
    check("the cirya of player 2 is on c3", stack("c3") == [cirya])
    check("the hallacirya stays in the fleet", !G.get_piece_tile(hallacirya))

    G.notation_movement(1, "d3")
    check("after the opening the piece is of the player", instance_from_id(stack("d3")[0]).player == 1)
