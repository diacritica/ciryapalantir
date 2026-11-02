extends Reference

# Turns are written as in Tak, the same way the server reads them:
#
#   c3, Tc3, Hc3   place a flat cirya, a tampa or a hallacirya on c3
#   3c3>21         take 3 stones from c3 and move them right, dropping 2 and then 1
#
# Without a count one stone is taken, and without drops all of them go to the
# next square. Squares are Vector2(row, column) counted from 0: a1 is (0, 0)
# and b3 is (2, 1)

const FILES = "abcdefghi"
const STEPS = {"+": Vector2(1, 0), "-": Vector2(-1, 0), ">": Vector2(0, 1), "<": Vector2(0, -1)}

static func square_name(square):
    return FILES[int(square.y)] + str(int(square.x) + 1)

static func parse_square(name):
    return Vector2(int(name[1]) - 1, FILES.find(name[0]))

# A turn as someone types it, written the way parse reads it: no spaces,
# squares in lowercase and the stone of a placement in uppercase
static func normalize(typed):
    var turn = typed.strip_edges().replace(" ", "").to_lower()
    var regex = RegEx.new()
    regex.compile("^[ht][a-i][1-9]$")

    if regex.search(turn):
        turn = turn[0].to_upper() + turn.substr(1)

    return turn

# {"stone", "square"} for a placement, {"from", "count", "step", "drops"} for
# a move and {} for anything else
static func parse(turn):
    var regex = RegEx.new()
    regex.compile("^([HT]?)([a-i][1-9])$")
    var found = regex.search(turn)

    if found:
        var stone = found.get_string(1) if found.get_string(1) else "C"
        return {"stone": stone, "square": parse_square(found.get_string(2))}

    regex.compile("^([1-9]?)([a-i][1-9])([-+<>])([1-9]*)[HT]?$")
    found = regex.search(turn)

    if !found:
        return {}

    var count = int(found.get_string(1)) if found.get_string(1) else 1
    var drops = []

    for digit in found.get_string(4):
        drops.append(int(digit))

    if drops.empty():
        drops = [count]

    return {"from": parse_square(found.get_string(2)), "count": count, "step": STEPS[found.get_string(3)], "drops": drops}

# Writes a move as Rules.move_state describes it
static func write(state):
    if state.has("stone"):
        return ("" if state.stone == "C" else state.stone) + square_name(state.square)

    var text = str(state.count) if state.count > 1 else ""

    for symbol in STEPS:
        if STEPS[symbol] == state.direction:
            text += square_name(state.origin) + symbol

    if state.drops.size() > 1:
        for drop in state.drops:
            text += str(drop)

    return text
