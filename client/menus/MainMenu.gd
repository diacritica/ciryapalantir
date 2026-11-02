extends Control

# The first screen: create a room, join one with its code, or open the sandbox
# or the demo.
# In a room each player picks a colour and a name, and the game starts when
# both are ready. Before that the clock and the Henneth Annûn rule are chosen
# by whoever sits first: the second one sees them and cannot change them.
# Typing T4K there, out of any field, takes away the limit to the height of
# a nossë, almost as in Tak, and typing it again brings it back.
# Once seated, the card of the other colour turns the bot of this client on
# and off for that seat; with it on, Comenzar sits it and the game starts

# The seconds for each player that the server takes, 0 for no clock
const CLOCKS = [0, 180, 300, 600, 900]
const TAK_CODE = "T4K"
const BOT_NAME = "Bot local"

onready var Server = get_node("/root/Server")
onready var Match = get_node("/root/Match")
onready var WhiteButton = $CreateGame/Panel/WhiteButton
onready var BlackButton = $CreateGame/Panel/BlackButton
onready var Config = $CreateGame/Panel/Config

# The configuration of the room as the server has it, and the seats taken
var config = {"clock": 300, "hennethAnnun": false, "tak": false, "size": 5}
var seats = {}
# The last keys typed, to find the code of the variant T4K
var typed = ""
# The bot of this client chosen for the other seat, and whether it was sent
var local_bot = false
var bot_started = false

func _ready():
    Server.connect("user_logged", self, "_on_user_logged")
    Server.connect("notification_received", self, "_on_notification_received")
    _connect_button(WhiteButton, BlackButton)
    _connect_button(BlackButton, WhiteButton)
    Config.get_node("Clock/Less").connect("pressed", self, "_change_clock", [-1])
    Config.get_node("Clock/More").connect("pressed", self, "_change_clock", [1])
    Config.get_node("HennethAnnun").connect("toggled", self, "_on_henneth_annun_toggled")
    $CreateGame/Panel/Start.connect("pressed", self, "_on_start_pressed")
    _show_config()

    # Back from a game: the user logged in long ago
    if Server.logged_in():
        _on_user_logged()

func _on_user_logged():
    $Welcome/Panel/NewGameButton.disabled = false
    $Welcome/Panel/JoinGameButton.disabled = false

func _on_NewGameButton_pressed():
    Server.connect("room_created", self, "_enter_room", [], CONNECT_ONESHOT)
    Server.create_room()

func _on_JoinGameButton_pressed():
    _leave_welcome()
    $JoinGame.visible = true

func _on_JoinGameCode_pressed():
    $JoinGame.visible = false
    # Codes are uppercase: typed in lowercase they would open another, empty room
    _enter_room($JoinGame/Panel/Code/InputCode.text.strip_edges().to_upper())

func _on_SandboxButton_pressed():
    Match.start_sandbox()
    get_tree().change_scene("res://Game.tscn")

func _on_DemoButton_pressed():
    Match.start_demo()
    get_tree().change_scene("res://Game.tscn")

func _enter_room(code):
    Match.sandbox = false
    Match.demo = false
    seats = {}
    # The seat taken here before, to play it again when the game has started
    Match.player = Server.seat_in(code)
    $CreateGame/Panel/Code/CodeLabel.text = code
    _leave_welcome()
    $CreateGame.visible = true
    Server.join_room(code)

func _leave_welcome():
    $Background.visible = false
    $BackgroundBlur.visible = true
    $Welcome.visible = false

func _on_notification_received(message):
    match message.type:
        "PlayerJoined":
            var params = message.params
            seats[int(params.player)] = true
            _show_player(WhiteButton if params.color == "white" else BlackButton, params.name)
            _show_config()

            if int(params.player) == Match.player:
                Server.send_set_ready(true)

            _offer_local_bot()

        # A game already started opens at once: for a player coming back or
        # for someone who comes to watch
        "StatusResponse":
            var players = message.status.get("players", {})

            seats = {}
            config = message.status.get("config", config)

            if players.has("1"):
                seats[1] = true
                _show_player(WhiteButton, players["1"].name)
            if players.has("2"):
                seats[2] = true
                _show_player(BlackButton, players["2"].name)

            _show_config()

            if message.status.state != "NOT_STARTED":
                get_tree().change_scene("res://Game.tscn")

        "StartGame":
            get_tree().change_scene("res://Game.tscn")

        "PlayerLeft":
            seats.erase(int(message.params.player))
            _show_config()
            _offer_local_bot()

        "ConfigChanged":
            config = message.params.config
            _show_config()

        # A change refused: what shows goes back to what the server has
        "Error":
            _show_config()

func _connect_button(button, other):
    button.connect("pressed", self, "_on_color_pressed", [button, other])
    button.get_node("Edit/PlayButton").connect("pressed", self, "_on_play_pressed", [button])

func _disconnect_button(button):
    if button.is_connected("pressed", self, "_on_color_pressed"):
        button.disconnect("pressed", self, "_on_color_pressed")
        button.get_node("Edit/PlayButton").disconnect("pressed", self, "_on_play_pressed")

func _on_color_pressed(button, other):
    button.set_size(Vector2(141, 300))

    if !other.get_node("Display").visible:
        other.set_size(Vector2(141, 200))

    button.get_node("Edit").visible = true
    other.get_node("Edit").visible = false

func _on_play_pressed(button):
    _disconnect_button(WhiteButton)
    _disconnect_button(BlackButton)

    Match.player = 1 if button == WhiteButton else 2
    Server.send_join_player(Match.player, "white" if Match.player == 1 else "black", button.get_node("Edit/InputName").text)

# Seated, with the other seat free, its card turns the bot on and off; when
# someone else sits there it is gone
func _offer_local_bot():
    var free = seats.has(Match.player) and !seats.has(3 - Match.player)
    var card = _card(3 - Match.player) if Match.player != 0 else null

    if card and free and !card.is_connected("pressed", self, "_toggle_local_bot"):
        card.connect("pressed", self, "_toggle_local_bot")
    elif card and !free and !bot_started and card.is_connected("pressed", self, "_toggle_local_bot"):
        card.disconnect("pressed", self, "_toggle_local_bot")

    if !free and !bot_started:
        local_bot = false

    _show_local_bot()

func _card(player):
    return WhiteButton if player == 1 else BlackButton

func _toggle_local_bot():
    local_bot = !local_bot
    _show_local_bot()

# The label under the card of the bot, and the button to start above the
# options of the game
func _show_local_bot():
    var label = $CreateGame/Panel/LocalBot
    var start = $CreateGame/Panel/Start
    label.visible = local_bot
    start.visible = local_bot
    start.disabled = bot_started

    if local_bot:
        var card = _card(3 - Match.player)
        label.rect_position = Vector2(card.rect_position.x, card.rect_position.y + card.rect_size.y + 4)
        label.rect_size.x = card.rect_size.x

func _on_start_pressed():
    bot_started = true
    _show_local_bot()
    Server.start_bot(3 - Match.player, BOT_NAME)

# The seat is taken: it shows the name and cannot be picked any more
func _show_player(button, name):
    _disconnect_button(button)
    button.set_size(Vector2(141, 250))
    button.get_node("Display").visible = true
    button.get_node("Display/Label").text = name
    button.get_node("Edit").visible = false

# The configuration can change while nobody sits, or by the one sitting alone
func can_change_config():
    if seats.size() == 0:
        return true

    return seats.size() == 1 and seats.has(Match.player)

func _show_config():
    var clock = int(config.get("clock", 300))
    var index = CLOCKS.find(clock)
    var editable = can_change_config()
    var rule = Config.get_node("HennethAnnun")

    Config.get_node("Clock/Value").text = "Sin reloj" if clock == 0 else "%d min" % (clock / 60)
    Config.get_node("Clock/Less").disabled = !editable or index <= 0
    Config.get_node("Clock/More").disabled = !editable or index < 0 or index >= CLOCKS.size() - 1
    rule.set_pressed_no_signal(config.get("hennethAnnun", false))
    rule.disabled = !editable
    # A rule of the Rangers of Ithilien, who only played on 5×5
    rule.visible = int(config.get("size", 5)) == 5
    Config.get_node("Tak").visible = config.get("tak", false)

# Only keys that no field took arrive here
func _unhandled_input(event):
    if !(event is InputEventKey) or !event.pressed or event.echo or event.unicode == 0 or !$CreateGame.visible:
        return

    typed = (typed + char(event.unicode).to_upper()).right(max(0, typed.length() + 1 - TAK_CODE.length()))

    if typed == TAK_CODE and can_change_config():
        typed = ""
        Server.send_change_config({"tak": !config.get("tak", false)})

func _change_clock(step):
    var index = CLOCKS.find(int(config.get("clock", 300)))
    Server.send_change_config({"clock": CLOCKS[clamp(index + step, 0, CLOCKS.size() - 1)]})

func _on_henneth_annun_toggled(on):
    Server.send_change_config({"hennethAnnun": on})
