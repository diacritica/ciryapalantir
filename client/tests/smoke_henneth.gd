extends SceneTree

# Writes a game in the sandbox with the Henneth Annûn rule, which the sandbox
# takes from a status made up here: each player moves its one cirya to the
# next square and back until black plays its hallacirya in its 16th turn,
# and white gives its own up in its 17th. From the client folder:
#
#   godot --no-window --path . -s tests/smoke_henneth.gd

var game
var ui
var state
var failures = 0

func _initialize():
    state = get_root().get_node("Match")
    state.start_sandbox()
    state.status = {"config": {"hennethAnnun": true}, "fleets": {"1": {"hallaciryar": 1}, "2": {"hallaciryar": 1}}}
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
    ui = game.get_node("UI")

    # The sandbox hides the panel of the code, but not the seal in it
    var seal = ui.get_node("CodePanel/HennethAnnun")
    check("the seal of the rule shows", seal.visible and seal.hint_tooltip.find("9+7") != -1)
    _until(3)
    _not_yet()
    _until(32)
    yield(_black_plays_it(), "completed")
    yield(_white_gives_it_up(), "completed")
    _gone()

    print("smoke henneth: %d failures" % failures)
    quit(1 if failures else 0)

# The shuffle of tests on the server, henneth_test.go
func shuffle(turn):
    if turn == 1:
        return "a1"
    if turn == 2:
        return "e5"
    if turn % 2 == 1:
        return ["e5<", "d5>"][(turn - 3) / 2 % 2]
    return ["a1>", "b1<"][(turn - 4) / 2 % 2]

func _until(turn):
    while state.turn < turn:
        var played = state.turn
        var error = game.play_written(shuffle(played))
        check("turn %d: %s" % [played, error], error == "" and state.confirm())

        if state.turn == played:
            return

func _not_yet():
    var hallacirya = fleet_hallacirya(1)
    check("the hallacirya cannot be taken before its turn", !state.can_take(hallacirya.get_instance_id()))
    check("a cirya can", state.can_take(fleet_cirya(1).get_instance_id()))
    check("it is faded", faded(hallacirya) and faded(fleet_hallacirya(2)))
    var error = game.play_written("Hc3")
    check("writing it says why", error.find("Henneth Annûn") != -1 and !state.move_started())
    check("nobody is asked to play it", !state.hallacirya_due())

# In its 16th turn black is told to play it, and asked before another move
func _black_plays_it():
    var black = fleet_hallacirya(2)
    check("turn 32 is of black", state.turn == 32 and state.player == 2)
    check("its hallacirya comes back", !faded(black) and state.can_take(black.get_instance_id()))
    check("but not the one of white", faded(fleet_hallacirya(1)))
    check("the help says so", ui.get_node("HelpPanel/AdviceLavel").text.find("Henneth Annûn") != -1)

    check("another move", game.play_written("c3") == "")
    check("would give it up", state.renounces_hallacirya())
    ui._on_confirm_pressed()
    yield(self, "idle_frame")
    check("so it is asked first", ui.has_node("Renounce") and state.turn == 32)
    ui.get_node("Renounce").get_cancel().emit_signal("pressed")
    yield(self, "idle_frame")
    check("going back to the board keeps the turn", state.turn == 32 and state.move_notation() == "c3")

    check("now the hallacirya", game.play_written("Hc3") == "" and !state.renounces_hallacirya())
    ui._on_confirm_pressed()
    yield(self, "idle_frame")
    check("goes without asking", state.turn == 33 and !ui.has_node("Renounce"))
    check("and is not faded on the board", !faded(black))
    state.status.fleets["2"].hallaciryar = 0

# White plays another move in its 17th turn and says it gives it up
func _white_gives_it_up():
    check("turn 33 is of white", state.turn == 33 and state.hallacirya_due())
    check("its hallacirya comes back", !faded(fleet_hallacirya(1)))
    check("another move", game.play_written(shuffle(33)) == "")
    ui._on_confirm_pressed()
    yield(self, "idle_frame")
    check("is asked", ui.has_node("Renounce"))
    ui.get_node("Renounce").get_ok().emit_signal("pressed")
    yield(self, "idle_frame")
    check("and played when it renounces", state.turn == 34)

# Never again
func _gone():
    # Black played its hallacirya instead of moving, so its cirya is on a1
    check("turn 34", game.play_written("a1>") == "" and state.confirm())
    var white = fleet_hallacirya(1)
    check("the hallacirya of white is gone for ever", !state.can_take(white.get_instance_id()) and faded(white))
    check("and nobody is asked", !state.hallacirya_due())

func faded(piece):
    return piece.get_node("Mesh").get_surface_material(0) != null

func fleet_hallacirya(player):
    return _fleet_piece(player, "H")

func fleet_cirya(player):
    return _fleet_piece(player, "C")

func _fleet_piece(player, kind):
    for piece in game._pieces():
        if piece.player == player and piece.get_notation_name() == kind and state.board.square_of(piece.get_instance_id()) == null:
            return piece
