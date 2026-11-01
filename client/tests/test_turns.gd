extends "res://tests/TestCase.gd"

# The phases of Match with the notifications of the server, and the sandbox

const FakeServer = preload("res://tests/fakes/Server.gd")
const Notation = preload("res://core/Notation.gd")

var game
var server
var played = []
var opponent = []
var refused = []
var pieces = []

func setup():
    server = FakeServer.new()
    game = load("res://Match.gd").new()
    game.Server = server
    game.new_board(5)
    game.connect("turn_played", self, "_on_turn_played")
    game.connect("opponent_played", self, "_on_opponent_played")
    game.connect("turn_refused", self, "_on_turn_refused")

func teardown():
    game.free()

func _on_turn_played(turn, move):
    played.append([turn, move])

func _on_opponent_played(player, move, opening):
    opponent.append([player, move, opening])

func _on_turn_refused(reason):
    refused.append(reason)

func notify(type, params = {}):
    game._on_notification({"type": type, "params": params})

# Places a piece of the fleet as the player would drag it
func place(name, square):
    var piece = Piece.new(name)
    pieces.append(piece)
    var piece_id = piece.get_instance_id()
    check("can take " + name, game.can_take(piece_id))
    game.start_move(piece_id, pieces)
    game.board.put([piece_id], Notation.parse_square(square))

func test_sandbox_alternates_players():
    game.start_sandbox()
    check_equal("player 1 starts", 1, game.player)
    check_equal("and can move", game.Phase.MY_TURN, game.phase)
    check("nothing to confirm yet", !game.confirm())

    place("C2", "c3")
    check("confirmed", game.confirm())
    check_equal("written down", [[1, "c3"]], played)
    check_equal("turn 2", 2, game.turn)
    check_equal("for player 2", 2, game.player)
    check_equal("who can move", game.Phase.MY_TURN, game.phase)
    check_equal("nothing is sent", [], server.sent)

func test_start_online():
    game.player = 2
    notify("StartGame", {"nextTurn": 1.0, "nextPlayer": 1.0})
    check_equal("player 2 waits", game.Phase.OPPONENT, game.phase)

    game.player = 1
    notify("StartGame", {"nextTurn": 1.0, "nextPlayer": 1.0})
    check_equal("player 1 moves", game.Phase.MY_TURN, game.phase)

func test_spectators_never_move():
    notify("StartGame", {"nextTurn": 1.0, "nextPlayer": 1.0})
    check_equal("not seated", game.Phase.OPPONENT, game.phase)

func test_submit_and_get_the_turn_back():
    game.player = 1
    notify("StartGame", {"nextTurn": 1.0, "nextPlayer": 1.0})
    place("C2", "a1")

    check("sent", game.confirm())
    check_equal("the move", {"type": "SubmitTurn", "params": {"player": 1, "turn": 1, "move": "a1"}}, server.sent[0])
    check_equal("waiting for the server", game.Phase.SUBMITTED, game.phase)
    check("no moving meanwhile", !game.can_take(Piece.new("C1").get_instance_id()))

    notify("Turn", {"player": 1.0, "turn": 1.0, "move": "a1", "nextPlayer": 2.0, "nextTurn": 2.0})
    check_equal("written down", [[1, "a1"]], played)
    check_equal("not shown again", [], opponent)
    check_equal("the opponent moves", game.Phase.OPPONENT, game.phase)

    notify("Turn", {"player": 2.0, "turn": 2.0, "move": "e5", "nextPlayer": 1.0, "nextTurn": 3.0})
    check_equal("shown, still in the opening", [[2, "e5", true]], opponent)
    check_equal("turn 3", 3, game.turn)
    check_equal("back to player 1", game.Phase.MY_TURN, game.phase)
    check("out of the opening", !game.opening())

func test_refused_turn():
    game.player = 1
    notify("StartGame", {"nextTurn": 1.0, "nextPlayer": 1.0})
    place("C2", "a1")
    game.confirm()

    notify("InvalidTurn", {"error": "a1 is not empty"})
    check_equal("told", ["a1 is not empty"], refused)
    check_equal("can move again", game.Phase.MY_TURN, game.phase)

    notify("Error", {"code": "NOT_YOUR_TURN", "message": "it is not your turn"})
    check_equal("an Error out of a submission changes nothing", 1, refused.size())

func test_undo_puts_the_board_back():
    game.start_sandbox()
    check("nothing to undo", !game.undo())

    place("C2", "b2")
    check("undone", game.undo())
    check_equal("empty again", [], game.board.stack(Vector2(1, 1)))
    check_equal("no move", null, game.move)

func test_game_over():
    game.player = 1
    notify("StartGame", {"nextTurn": 1.0, "nextPlayer": 1.0})
    notify("GameFinished", {"result": "WIN_2", "winCondition": "LONDI", "turn": 10.0})
    check_equal("finished", game.Phase.FINISHED, game.phase)
    check("nobody moves", !game.can_take(Piece.new("C1").get_instance_id()))
