extends Node

# The game being played: whose turn it is and the move of this turn. Online it
# follows the server; in the sandbox it plays both sides on one computer, and
# in the demo there are no rules nor turns, to set up a board and explain it

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
# The whole game as the server has it, after every turn and on connecting.
# catching_up is true for the status sent on connecting, which can differ
# from the board: turns may have been played meanwhile
signal status_received(status, catching_up)
# All the moves of the game, when joining one already started
signal history(moves)
# The move of this turn changed: its notation, "" when there is nothing to send
signal move_changed(notation)
# result: WIN_1, WIN_2 or DRAW. condition: LONDI or FLAT
signal game_over(result, condition)

# The same rules and turns, without the server
var sandbox = false
# Any piece goes anywhere, always from the side of player 1
var demo = false
# The seat of this client, 0 for a spectator. In the sandbox it changes every turn
var player = 0
var turn = 1
# The player whose turn it is
var current = 1
var phase = Phase.WAITING
var board = BoardState.new()
# The move of this turn, null until a piece is taken
var move = null
# The last status of a started game, for a game scene that opens later
var status = null
# Milliseconds left to each player when the last status came, and when it
# came; empty for a game without clock
var clocks = {}
var clock_running = 0
var clock_at = 0

onready var Server = get_node("/root/Server")

func _ready():
    Server.connect("notification_received", self, "_on_notification")

func start_sandbox():
    sandbox = true
    player = 1
    status = null
    clocks = {}
    clock_running = 0
    _next(1, 1)

func start_demo():
    start_sandbox()
    sandbox = false
    demo = true

# A new board for the game scene, which knows its size
func new_board(size):
    set_board(BoardState.new(size))

# The board changes as a whole, so the move of the turn is over
func set_board(value):
    board = value
    move = null

# Turns 1 and 2: each player places a flat cirya of the opponent, as in Tak
func opening():
    return turn <= 2 and !demo

func can_take(piece_id):
    if demo:
        return true

    if phase != Phase.MY_TURN or !Rules.can_take(piece_id, board, move, player, opening()):
        return false

    return hallacirya_playable(player) or !_hallacirya_in_fleet(piece_id)

# The Henneth Annûn rule, chosen for the game
func henneth_annun():
    return status != null and status.get("config", {}).get("hennethAnnun", false) and !demo

# Whether the hallacirya of the player can come into play in this turn
func hallacirya_playable(seat):
    return !henneth_annun() or turn == Rules.hallacirya_turn(seat)

# It is the turn of the hallacirya of this player and it is still in the
# fleet: the rule asks to play it, unless that loses the game
func hallacirya_due():
    if phase != Phase.MY_TURN or !henneth_annun() or turn != Rules.hallacirya_turn(player):
        return false

    var fleet = status.get("fleets", {}).get(str(player), {})
    return int(fleet.get("hallaciryar", 0)) > 0

# Confirming this move gives up the hallacirya for ever
func renounces_hallacirya():
    return hallacirya_due() and !move_notation().begins_with("H")

func _hallacirya_in_fleet(piece_id):
    return instance_from_id(piece_id).get_notation_name() == "H" and board.square_of(piece_id) == null

# Not even the demo puts anything on a hallacirya
func can_drop(hand, square):
    if demo:
        var stack = board.stack(square)
        return stack.empty() or hand.has(stack.back()) or instance_from_id(stack.back()).get_notation_name() != "H"

    return Rules.can_drop(hand, square, board, move, player, opening())

func move_started():
    return move != null and move.started(board)

# The demo has no turns, so no move to keep
func start_move(piece_id, pieces):
    if !demo:
        move = Move.new(board, piece_id, pieces)

# Puts the pieces of the hand on the square. The drop has been checked
func drop(hand, square):
    board.put(hand, square)

    if move:
        move.sync_tampar(board)

    emit_signal("move_changed", move_notation())

# In the demo, pieces taken off the board go back to their fleet
func take_off(hand):
    board.take_off(hand)

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
    emit_signal("move_changed", "")
    return true

# Milliseconds left to the player now, counted from the last status
func time_left(seat):
    var left = clocks.get(seat, 0)

    if seat == clock_running:
        left -= OS.get_ticks_msec() - clock_at

    return max(left, 0)

func has_clock():
    return !clocks.empty()

# The server sends the clocks with every status, as they are when it sends it
func _take_clocks(received):
    clocks = {}

    for seat in received.get("clocks", {}):
        clocks[int(seat)] = int(received.clocks[seat])

    clock_running = int(received.get("clockRunning", 0))
    clock_at = OS.get_ticks_msec()

# Back to the menu: no game, no seat
func leave():
    sandbox = false
    demo = false
    player = 0
    status = null
    clocks = {}
    clock_running = 0
    move = null
    turn = 1
    current = 1
    _set_phase(Phase.WAITING)

func _on_notification(message):
    var params = message.get("params", {})

    match message.type:
        # Asked for, or sent when connecting: it can be a game already started
        "StatusResponse":
            _follow(message.status)

        "StartGame":
            _next(params.nextTurn, params.nextPlayer)

        "Turn":
            _played(int(params.turn), int(params.player), params.move)
            _next(params.nextTurn, params.nextPlayer)

        # It comes instead of the Turn that ends the game, without the move:
        # the move is the last one of the status. Lost on time, no move ended it
        "GameFinished":
            var moves = message.get("status", {}).get("moves", [])

            if moves and params.winCondition != "TIME":
                _played(int(params.turn), current, moves.back())

            move = null
            _set_phase(Phase.FINISHED)
            emit_signal("game_over", params.result, params.winCondition)

        "InvalidTurn", "Error":
            # The phase first, so what shows the refusal is not hidden by the new phase
            if phase == Phase.SUBMITTED:
                _set_phase(Phase.MY_TURN)
                emit_signal("turn_refused", params.get("error", params.get("message", "")))

    var received = message.get("status", {})

    if received.get("state", "NOT_STARTED") != "NOT_STARTED":
        status = received
        _take_clocks(received)
        # A move sent too late is not played: the board goes back without a warning
        var late = message.type == "GameFinished" and params.get("winCondition") == "TIME"
        emit_signal("status_received", status, message.type == "StatusResponse" or late)

# Takes the turn and the phase of a status
func _follow(game):
    match game.state:
        "NOT_STARTED":
            status = null
            _set_phase(Phase.WAITING)
        "TURN_1", "TURN_2":
            emit_signal("history", game.get("moves", []))
            _next(game.turn, game.currentPlayer)
        _:
            emit_signal("history", game.get("moves", []))
            move = null
            _set_phase(Phase.FINISHED)

# A turn this client did not send is shown: one of the opponent, or one of
# the same user from another window
func _played(played_turn, by, notation):
    emit_signal("turn_played", played_turn, notation)

    if by != player or phase != Phase.SUBMITTED:
        emit_signal("opponent_played", by, notation, played_turn <= 2)

func _next(next_turn, next_player):
    turn = int(next_turn)
    current = int(next_player)
    move = null
    _set_phase(Phase.MY_TURN if current == player else Phase.OPPONENT)

func _set_phase(value):
    phase = value
    emit_signal("phase_changed", phase)
