extends AcceptDialog

# The end of the game: who won and how, and for the players the offer of
# another game with the colours swapped, which the server keeps open a while.
# Its button is the only way out, and it is not modal: the moves can still be
# scrolled to see how the game went. UI adds it and takes "confirmed" back to
# the menu

const RESULTS = {"WIN_1": "Ganan las blancas", "WIN_2": "Ganan las negras", "DRAW": "Empate"}
const CONDITIONS = {"LONDI": "por Londë", "FLAT": "por recuento de ciryar", "TIME": "por tiempo"}
# Milliseconds the server gives to accept a rematch
const REMATCH_TIME = 30000

onready var Match = get_node("/root/Match")
onready var Server = get_node("/root/Server")

# What it says of the result, the state of the offer, who accepted, and
# until when it is open
var result_text = ""
var rematch_state = ""
var accepted = []
var until = 0

func _ready():
    window_title = "Fin de la partida"
    get_ok().text = "Volver al menú"
    get_close_button().hide()
    Match.connect("rematch_changed", self, "_on_rematch_changed")
    set_process(false)

func show_result(result, condition):
    result_text = RESULTS.get(result, result)

    if result != "DRAW":
        result_text += " " + CONDITIONS.get(condition, "")

    if Match.player == 0:
        result_text += "\n¡Esperamos que hayas disfrutado de la partida!"
    else:
        var mine = "WIN_%d" % Match.player
        result_text += "\n" + ("¡Has ganado!" if result == mine else ("Has empatado" if result == "DRAW" else "Has perdido"))

    dialog_text = result_text

    if Match.player != 0 and !Match.sandbox:
        # Each one goes before the others, so they read Adelante, Ahora no
        add_button("Ahora no", false, "no_rematch").name = "NoRematch"
        add_button("Adelante", false, "rematch").name = "Rematch"
        connect("custom_action", self, "_on_answered")
        rematch_state = "OPEN"
        until = OS.get_ticks_msec() + REMATCH_TIME
        set_process(true)

    show()

    if rematch_state == "OPEN":
        _show_rematch()

    _fit()

# The time left counts down every frame
func _process(_delta):
    if rematch_state == "OPEN":
        _show_rematch()

func _on_answered(action):
    var accept = action == "rematch"
    Server.send_rematch(accept)

    if accept:
        accepted.append(Match.player)
    else:
        rematch_state = "DECLINED"

    _show_rematch()

func _on_rematch_changed(state, players, left):
    rematch_state = state
    accepted = players
    until = OS.get_ticks_msec() + left
    _show_rematch()

# What it says of the rematch: the time left, who is waiting for whom, and
# that there will be no new game as soon as one does not want it
func _show_rematch():
    var mine = accepted.has(Match.player)
    var theirs = accepted.has(3 - Match.player)
    var seconds = int(ceil(max(until - OS.get_ticks_msec(), 0) / 1000.0))
    var line = ""

    match rematch_state:
        "OPEN":
            if mine:
                line = "Esperando al otro jugador… %d s" % seconds
            elif theirs:
                line = "El otro jugador quiere otra partida · %d s" % seconds
            else:
                line = "¿Otra partida? Os cambiáis los colores · %d s" % seconds
        "DECLINED":
            line = "No habrá una nueva partida"
        "EXPIRED":
            line = "No habrá una nueva partida: se acabó el tiempo"

    var text = result_text + "\n\n" + line

    if dialog_text == text:
        return

    dialog_text = text

    # One no is enough at any time, even after a yes
    for name in ["Rematch", "NoRematch"]:
        var button = find_node(name, true, false)

        if button:
            button.visible = rematch_state == "OPEN"

    var rematch = find_node("Rematch", true, false)

    if rematch:
        rematch.disabled = mine

    _fit()

# As big as what it says now, in the middle of the screen
func _fit():
    var size = get_combined_minimum_size()

    if size != rect_size:
        rect_size = size
        rect_position = (get_viewport_rect().size - size) / 2
