extends SceneTree

# Loads the game scene and plays through Game.gd without the mouse: a few
# turns in the sandbox, then turns of an opponent and a refused turn as the
# server would send them. It catches errors in the scene code that the rules
# tests cannot see. From the client folder:
#
#   godot --no-window --path . -s tests/smoke_game.gd

const Notation = preload("res://core/Notation.gd")
const Status = preload("res://core/Status.gd")

var game
var state
var failures = 0

func _initialize():
    state = get_root().get_node("Match")
    state.start_sandbox()
    change_scene("res://Game.tscn")
    call_deferred("_play")

func check(label, condition):
    if !condition:
        failures += 1
        print("FAIL ", label)

func _play():
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    game = current_scene
    _board()

    yield(_sandbox(), "completed")
    _online()
    _out_of_step()
    yield(_reopen(), "completed")
    yield(_back_to_menu(), "completed")

    print("smoke: %d failures" % failures)
    quit(1 if failures else 0)

# The tiles light up where the pieces would fall, so they have to be at the
# height Tile.tscn gives them, just over the board, and not hidden under it
func _board():
    var height = load("res://Tile.tscn").instance().translation.y
    var tile = game.get_node("Board").tile(Vector2(2, 3))

    check("the tiles keep the height of Tile.tscn", is_equal_approx(tile.translation.y, height))
    check("and the highlight is over the board", tile.global_transform.origin.y > game.get_node("Board").global_transform.origin.y)

func _sandbox():
    check("the opening hint", help_text().begins_with("Toma una cirya de tu oponente"))
    check("nothing to confirm yet", confirm_button().disabled)

    # Turn 1: white places a black cirya on c3, and c3 lights up under the hand
    take(fleet_piece(2))
    hover("c3")
    check("the tile under the hand lights up", tile("c3").visible)
    release("c3")
    check("and goes off after the drop", !tile("c3").visible)
    check("now it can be confirmed", !confirm_button().disabled)
    check("turn 1 is c3", state.move_notation() == "c3")
    game._on_turn_confirmation(true)

    # Turn 2: black places a white cirya on d3
    take(fleet_piece(1))
    release("d3")
    game._on_turn_confirmation(true)

    # Turn 3: white places a tampa on a1, changes its mind and undoes it
    var tampa = fleet_piece(1)
    take(tampa)
    game._rotate()
    release("a1")
    check("a tampa", state.move_notation() == "Ta1")
    game._on_turn_confirmation(false)
    check("undone", stack("a1").empty())
    check("the piece is flat again in the fleet", !tampa.block)

    # White moves d3 onto c3, after a drop two squares away flies back
    var cirya = instance_from_id(stack("d3")[0])
    take(cirya)
    release("a3")
    check("the rejected drop changes nothing", state.move_notation() == "")
    check("nothing can be taken while it flies back", game.drag == game.Drag.RETURNING)
    yield(create_timer(game.RETURN_TIME + 0.2), "timeout")

    take(cirya)
    release("c3")
    check("turn 3 is d3<", state.move_notation() == "d3<")
    game._on_turn_confirmation(true)
    check("turn 4 for black", state.turn == 4 and state.player == 2)
    check("the moves are written down", game.get_node("UI/Moves/MovesText").text.find("3. d3<") != -1)

# White online, against turns of black sent as the server sends them
func _online():
    state.sandbox = false
    state.player = 1
    state._next(4, 2)

    notify("Turn", {"player": 2.0, "turn": 4.0, "move": "Tb4", "nextPlayer": 1.0, "nextTurn": 5.0})
    var tampa = instance_from_id(stack("b4")[0])
    check("black places a tampa", stack("b4").size() == 1 and tampa.player == 2 and tampa.block)

    # The server refuses the turn of white: the piece goes back
    var cirya = fleet_piece(1)
    var tray = cirya.global_transform
    take(cirya)
    release("e1")
    state._set_phase(state.Phase.SUBMITTED)
    check("waiting for the server", help_text() == "Esperando al servidor…")
    notify("InvalidTurn", {"error": "refused"})
    check("the refusal is shown", help_text() == "Movimiento no válido: refused")
    check("the board is back", stack("e1").empty())
    check("the piece is back in the fleet", cirya.global_transform.origin.distance_to(tray.origin) < 0.01)
    check("white can move again", state.phase == state.Phase.MY_TURN)

    # Black brings the hallacirya over its tampa, which lies down
    notify("Turn", {"player": 2.0, "turn": 6.0, "move": "Hc4", "nextPlayer": 1.0, "nextTurn": 7.0})
    notify("Turn", {"player": 2.0, "turn": 8.0, "move": "c4<", "nextPlayer": 1.0, "nextTurn": 9.0})
    check("the hallacirya is on b4", stack("b4").size() == 2 and instance_from_id(stack("b4")[1]).get_notation_name() == "H")
    check("the tampa is flat", !tampa.block)

    # The last move comes in the status of GameFinished
    state._next(10, 2)
    state._on_notification({"type": "GameFinished", "params": {"result": "WIN_2", "winCondition": "FLAT", "turn": 10.0}, "status": {"moves": ["e5"]}})
    check("the winning move is shown", stack("e5").size() == 1)
    check("and written down", game.get_node("UI/Moves/MovesText").text.find("10. e5") != -1)
    var dialog = game_over_dialog()
    check("the result is shown", dialog != null and dialog.visible and dialog.dialog_text.begins_with("Ganan las negras por recuento de ciryar\nHas perdido"))

# The client missed where a piece went: the status of the next turn says it
func _out_of_step():
    state._next(11, 2)
    var status = _status_of_board()
    status.board["2"] = status.board.get("2", {})
    status.board["2"]["d"] = ["C2"]
    status.turn = 12.0
    status.currentPlayer = 1.0

    # Black played d1 for this client, but the server has the cirya on d2
    state._on_notification({"type": "Turn", "params": {"player": 2.0, "turn": 11.0, "move": "d1", "nextPlayer": 1.0, "nextTurn": 12.0}, "status": status})
    check("d1 is empty, as the server says", stack("d1").empty())
    check("the cirya is on d2", stack("d2").size() == 1 and instance_from_id(stack("d2")[0]).player == 2)
    check("and it is there on the table", _over(instance_from_id(stack("d2")[0]), "d2"))

# A game scene opened in a game already started takes the board of the status
func _reopen():
    var status = _status_of_board()
    state.status = status
    change_scene("res://Game.tscn")
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    game = current_scene

    check("the board is back", Status.matches(status.board, state.board))
    check("b4 has its two pieces", stack("b4").size() == 2)
    check("on the table", _over(instance_from_id(stack("b4")[1]), "b4"))
    check("the tampa of b4 lies under the hallacirya", !instance_from_id(stack("b4")[0]).block)

# The board of the client as a status of the server
func _status_of_board():
    var data = {}

    for row in range(state.board.size()):
        for column in range(state.board.size()):
            var square = Vector2(row, column)
            var name = Notation.square_name(square)

            for piece_id in state.board.stack(square):
                var piece = instance_from_id(piece_id)
                if !data.has(name.substr(1)):
                    data[name.substr(1)] = {}
                if !data[name.substr(1)].has(name.substr(0, 1)):
                    data[name.substr(1)][name.substr(0, 1)] = []
                data[name.substr(1)][name.substr(0, 1)].append(piece.get_notation_name() + str(piece.player))

    return {"state": "TURN_1", "turn": 13.0, "currentPlayer": 1.0, "moves": [], "board": data}

# Whether the piece stands over the tile of the square
func _over(piece, square):
    var a = piece.global_transform.origin
    var b = tile(square).global_transform.origin
    return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) < 0.01

# The button of the game over dialog goes back to the menu, out of the room
func _back_to_menu():
    state._on_notification({"type": "GameFinished", "params": {"result": "WIN_1", "winCondition": "LONDI", "turn": 13.0}})
    game_over_dialog().emit_signal("confirmed")
    yield(self, "idle_frame")
    yield(self, "idle_frame")

    check("in the menu", current_scene.name == "Menu")
    check("without a seat", state.player == 0 and state.phase == state.Phase.WAITING)

func help_text():
    var panel = game.get_node("UI/HelpPanel")
    return panel.get_node("AdviceLavel").text if panel.visible else ""

func confirm_button():
    return game.get_node("UI/TurnPanel/Confirm")

func game_over_dialog():
    for child in game.get_node("UI").get_children():
        if child is AcceptDialog:
            return child

func notify(type, params):
    state._on_notification({"type": type, "params": params})

func stack(square):
    return state.board.stack(Notation.parse_square(square))

func fleet_piece(player):
    for piece in game._pieces():
        if piece.player == player and piece.get_notation_name() == "C" and state.board.square_of(piece.get_instance_id()) == null:
            return piece

func take(piece):
    check("can take a piece", piece != null and state.can_take(piece.get_instance_id()))
    game.take(piece)

func tile(square):
    return game.get_node("Board").tile(Notation.parse_square(square))

# Puts the hand over the square, as the mouse does
func hover(square):
    game.hand.global_transform.origin = tile(square).global_transform.origin + Vector3(0, game.HAND_MIN_HEIGHT, 0)
    game._follow_mouse()

func release(square):
    game.release(tile(square))
