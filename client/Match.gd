extends Node

# The game being played: whose turn it is and the move of this turn. Online it
# follows the server; in the sandbox it plays both sides on one computer

const BoardState = preload("res://core/BoardState.gd")
const Move = preload("res://core/Move.gd")
const Notation = preload("res://core/Notation.gd")
const Rules = preload("res://core/Rules.gd")

# WAITING      before the game starts
# MY_TURN      the player can move
# SUBMITTED    the turn was sent and the server has not answered yet
# OPPONENT     the other player is moving
# FINISHED     the game is over
enum Phase { WAITING, MY_TURN, SUBMITTED, OPPONENT, FINISHED }

signal phase_changed(phase)
# Any turn played, to write it down
signal turn_played(turn, notation)
# A turn of the other player that the board has to show
signal opponent_played(player, notation, opening)
# The server refused the turn sent: the board goes back to how it was
signal turn_refused(reason)

# The same rules and turns, without the server
var sandbox = false
# The seat of this client, 0 for a spectator. In the sandbox it changes every turn
var player = 0
var turn = 1
# The player whose turn it is
var current = 1
var phase = Phase.WAITING
var board = BoardState.new()
# The move of this turn, null until a piece is taken
var move = null

onready var Server = get_node("/root/Server")

func _ready():
    Server.connect("notification_received", self, "_on_notification")

func start_sandbox():
    sandbox = true
    player = 1
    _next(1, 1)

# A new board for the game scene, which knows its size
func new_board(size):
    board = BoardState.new(size)
    move = null

# Turns 1 and 2: each player places a flat cirya of the opponent, as in Tak
func opening():
    return turn <= 2

func can_take(piece_id):
    return phase == Phase.MY_TURN and Rules.can_take(piece_id, board, move, player, opening())

func can_drop(hand, square):
    return Rules.can_drop(hand, square, board, move, player, opening())

func move_started():
    return move != null and move.started(board)

func start_move(piece_id, pieces):
    move = Move.new(board, piece_id, pieces)

# The move worked out from the board, or "" when there is nothing to send yet
func move_notation():
    var state = Rules.move_state(move, board, player, opening())
    return Notation.write(state) if state else ""

# Sends the turn, or in the sandbox passes it to the other player. False when
# there is nothing to send
func confirm():
    var notation = move_notation()

    if phase != Phase.MY_TURN or notation == "":
        return false

    if sandbox:
        emit_signal("turn_played", turn, notation)
        player = 3 - player
        _next(turn + 1, player)
    else:
        Server.ws_send_message({"type": "SubmitTurn", "params": {"player": player, "turn": turn, "move": notation}})
        _set_phase(Phase.SUBMITTED)

    return true

# Puts the board back as it was when the turn started. False when nothing moved
func undo():
    if !move:
        return false

    board = move.before.copy()
    move.sync_tampar(board)
    move = null
    return true

func _on_notification(message):
    var params = message.get("params", {})

    match message.type:
        "StartGame":
            _next(params.nextTurn, params.nextPlayer)

        "Turn":
            _played(int(params.turn), int(params.player), params.move)
            _next(params.nextTurn, params.nextPlayer)

        # It comes instead of the Turn that ends the game, without the move:
        # the move is the last one of the status
        "GameFinished":
            var moves = message.get("status", {}).get("moves", [])

            if moves:
                _played(int(params.turn), current, moves.back())

            move = null
            _set_phase(Phase.FINISHED)

        "InvalidTurn", "Error":
            if phase == Phase.SUBMITTED:
                emit_signal("turn_refused", params.get("error", params.get("message", "")))
                _set_phase(Phase.MY_TURN)

func _played(played_turn, by, notation):
    emit_signal("turn_played", played_turn, notation)

    if by != player:
        emit_signal("opponent_played", by, notation, played_turn <= 2)

func _next(next_turn, next_player):
    turn = int(next_turn)
    current = int(next_player)
    move = null
    _set_phase(Phase.MY_TURN if current == player else Phase.OPPONENT)

func _set_phase(value):
    phase = value
    emit_signal("phase_changed", phase)
