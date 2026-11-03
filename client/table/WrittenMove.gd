extends Reference

# A turn written in notation made on the board of Game as the mouse would,
# taking and dropping with the same checks, so what cannot be dragged cannot
# be written either. Game has one, for the field of the written move

const Notation = preload("res://core/Notation.gd")

var game = null
var Match = null

func _init(table):
    game = table
    Match = table.Match

# It takes the place of the move on the board, which comes back if the new
# one cannot be made. The answer is why not, or "" when it is on the board
# waiting to be confirmed
func play(text):
    var turn = Notation.normalize(text)
    var parsed = Notation.parse(turn)

    if parsed.empty():
        return "No entiendo «%s»" % text.strip_edges()

    if game.drag != game.Drag.IDLE:
        return "Suelta antes la pieza que llevas"

    var before = Match.move_notation()
    game._undo()
    var error = _write(parsed)

    # What the board ended up with has to be what was written
    if error == "" and str(Notation.parse(Match.move_notation())) != str(parsed):
        error = "«%s» no es una jugada válida ahora" % turn

    if error != "":
        game._undo()

        if before != "":
            _write(Notation.parse(before))

    return error

func _write(parsed):
    return _write_placement(parsed) if parsed.has("stone") else _write_nosse(parsed)

func _write_placement(parsed):
    if !_on_board(parsed.square):
        return "No hay ningún sat %s" % Notation.square_name(parsed.square)

    if parsed.stone == "T" and Match.opening():
        return "En la apertura no se puede poner una tampa"

    if parsed.stone == "T" and Match.tampar_full():
        return game.TAMPAR_FULL % Match.board.size()

    var owner = 3 - Match.player if Match.opening() else Match.player
    var kind = "H" if parsed.stone == "H" else "C"
    var piece = null

    for each in game._pieces():
        if each.player == owner and each.get_notation_name() == kind and Match.board.square_of(each.get_instance_id()) == null:
            piece = each
            break

    if !piece:
        return "No queda ninguna %s en la bandeja" % ("hallacirya" if kind == "H" else "cirya")

    if kind == "H" and !Match.hallacirya_playable(Match.player):
        return "Con Henneth Annûn la Hallacirya solo se juega en la jugada 16 de Morqua o en la 17 de Ninquë"

    if !Match.can_take(piece.get_instance_id()):
        return "Esa pieza no se puede poner ahora"

    game.take(piece)

    if parsed.stone == "T":
        game._rotate()

    return _write_drop(parsed.square)

func _write_nosse(parsed):
    var stack = Match.board.stack(parsed.from) if _on_board(parsed.from) else []
    var total = 0

    for drop in parsed.drops:
        total += drop

    if stack.size() < parsed.count:
        return "En %s no hay %d piezas" % [Notation.square_name(parsed.from), parsed.count]

    if total != parsed.count:
        return "Las piezas que se sueltan tienen que sumar %d" % parsed.count

    # All the carried pieces go to each square, and the ones left there are
    # taken again for the next, as with the mouse
    var square = parsed.from
    var carried = parsed.count

    for drop in parsed.drops:
        stack = Match.board.stack(square)
        var piece_id = stack[stack.size() - carried]

        if !Match.can_take(piece_id):
            return "Esas piezas de %s no se pueden mover ahora" % Notation.square_name(square)

        game.take(instance_from_id(piece_id))
        square += parsed.step

        var error = _write_drop(square)

        if error != "":
            return error

        carried -= drop

    return ""

func _write_drop(square):
    if !_on_board(square) or !Match.can_drop(game._hand_ids(), square):
        var name = Notation.square_name(square) if _on_board(square) else "fuera del tablero"
        var full = _on_board(square) and Match.overflows(game._hand_ids(), square)
        game._let_go()

        if full:
            return "En %s ya no cabe más: un nossë tiene %d piezas como mucho, y la hallacirya encima" % [name, Match.board.size()]

        return "No se puede soltar en %s" % name

    game.release(game.get_node("Board").tile(square))
    return ""

func _on_board(square):
    return square.x >= 0 and square.y >= 0 and square.x < Match.board.size() and square.y < Match.board.size()
