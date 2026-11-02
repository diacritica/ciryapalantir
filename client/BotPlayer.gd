extends Node

# A bot playing a seat of the room from this same client, without a scene: a
# second websocket to the room, with the same user as the player, which the
# server allows and which in the browser could not be otherwise, as it sends
# the same cookie. It sits, says it is ready, and plays its turns with Bot on
# the board of each status. It accepts every rematch and takes the other seat
# then, as the player does. Server starts it and stops it with the room
#
#   the server sees one more player; the player sees its turns as any other

const Bot = preload("res://core/Bot.gd")
const BotBoard = preload("res://core/BotBoard.gd")

# Seconds it waits at least before a turn, so it does not look instant
var delay = 0.6
var seat = 2
var bot_name = "Bot"
# Turns played and turns the server refused, for the tests
var played = 0
var refused = 0
var bot = Bot.new()

var ws = null
var url = ""
var headers = []
# The turn it is thinking about, so an old thought is not sent, and the
# last status of the game
var thinking = 0
var last_status = {}
var closed = false

signal finished(params)

func start(room_url, cookie_headers, player, name):
    url = room_url
    headers = cookie_headers
    seat = player
    bot_name = name
    bot.yield_every = 64
    bot.tree = get_tree()
    _connect()

func stop():
    closed = true
    set_process(false)

    if ws:
        ws.disconnect_from_host()

    queue_free()

func _connect():
    ws = WebSocketClient.new()
    ws.verify_ssl = false
    ws.connect("connection_established", self, "_on_open")
    ws.connect("data_received", self, "_on_data")
    ws.connect("connection_closed", self, "_on_closed")
    ws.connect("connection_error", self, "_on_closed")

    if ws.connect_to_url(url, [], false, headers) != OK:
        push_error("the bot cannot connect to %s" % url)
        return

    set_process(true)

func _process(_delta):
    ws.poll()

# Back again after a lost connection: the server keeps its seat
func _on_closed(_clean = false):
    set_process(false)

    if closed:
        return

    yield(get_tree().create_timer(1.0), "timeout")

    if !closed:
        _connect()

func _on_open(_protocol = ""):
    _send("JoinGame", {"player": seat, "color": "white" if seat == 1 else "black", "name": bot_name})
    _send("SetReady", {"player": seat, "ready": true})

func _send(type, params):
    ws.get_peer(1).put_packet(JSON.print({"type": type, "params": params}).to_utf8())

func _on_data():
    var message = JSON.parse(ws.get_peer(1).get_packet().get_string_from_utf8()).result
    var params = message.get("params", {})

    match message.type:
        "StartGame":
            if params.get("rematch", false):
                seat = 3 - seat
        # It should never happen; then any legal turn will do
        "InvalidTurn":
            refused += 1
            push_error("the server refused a turn of the bot: %s" % params.get("error", ""))
            var moves = BotBoard.from_status(last_status).moves()
            _send("SubmitTurn", {"player": seat, "turn": int(last_status.turn), "move": moves[randi() % moves.size()]})
            return
        "GameFinished":
            emit_signal("finished", params)
            _send("Rematch", {"player": seat, "accept": true})
            return

    var status = message.get("status", {})

    if status:
        last_status = status

    if status.get("state", "") in ["TURN_1", "TURN_2"] and int(status.get("currentPlayer", 0)) == seat:
        _think(status)

# Thinks over the board of the status, a little at a time, and sends the turn
# unless the game went on meanwhile
func _think(status):
    var turn = int(status.turn)

    if thinking == turn:
        return

    thinking = turn
    var board = BotBoard.from_status(status)
    var started = OS.get_ticks_msec()
    var move = bot.choose(board)

    if move is GDScriptFunctionState:
        move = yield(move, "completed")

    var left = delay - (OS.get_ticks_msec() - started) / 1000.0

    if left > 0:
        yield(get_tree().create_timer(left), "timeout")

    if closed or thinking != turn:
        return

    played += 1
    _send("SubmitTurn", {"player": seat, "turn": turn, "move": move})
