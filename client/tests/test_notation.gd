extends "res://tests/TestCase.gd"

const Notation = preload("res://core/Notation.gd")

func test_squares():
    check_equal("a1", Vector2(0, 0), Notation.parse_square("a1"))
    check_equal("b3", Vector2(2, 1), Notation.parse_square("b3"))
    check_equal("e5", "e5", Notation.square_name(Vector2(4, 4)))
    check_equal("round trip", "c4", Notation.square_name(Notation.parse_square("c4")))

func test_placements():
    check_equal("a flat cirya", {"stone": "C", "square": Vector2(2, 2)}, Notation.parse("c3"))
    check_equal("a tampa", {"stone": "T", "square": Vector2(0, 0)}, Notation.parse("Ta1"))
    check_equal("a hallacirya", {"stone": "H", "square": Vector2(4, 4)}, Notation.parse("He5"))

func test_moves():
    check_equal("one stone up", {"from": Vector2(0, 0), "count": 1, "step": Vector2(1, 0), "drops": [1]}, Notation.parse("a1+"))
    check_equal("three to the right", {"from": Vector2(2, 2), "count": 3, "step": Vector2(0, 1), "drops": [2, 1]}, Notation.parse("3c3>21"))
    check_equal("the stone at the end is ignored", [1, 1], Notation.parse("2c3<11H").drops)

func test_typed():
    check_equal("a tampa in lowercase", "Ta1", Notation.normalize("ta1"))
    check_equal("a hallacirya with spaces", "Hc3", Notation.normalize(" h c3 "))
    check_equal("a square in uppercase", "c3", Notation.normalize("C3"))
    check_equal("a move", "3a1>12", Notation.normalize("3A1 > 12"))
    check_equal("as typed when right", "Tb2", Notation.normalize("Tb2"))

# The list of the moves, as it is copied, or turns one after another
func test_lists():
    check_equal("the moves as they are copied", ["c3", "a1", "Tb2", "2c3<11"], Notation.parse_list("1. c3\n2. a1\n3. Tb2\n4. 2c3<11\n").turns)
    check_equal("by commas and spaces, as typed", ["c3", "a1", "Hb2"], Notation.parse_list("c3, A1  hb2").turns)
    check_equal("numbers stuck to the turns", ["c3", "a1"], Notation.parse_list("1.c3 2.a1").turns)
    check_equal("no error", "", Notation.parse_list("1. c3").error)
    check_equal("the first that is not understood", "No entiendo «z9»", Notation.parse_list("1. c3\n2. z9\n3. a1").error)
    check_equal("nothing", "No hay ninguna jugada", Notation.parse_list(" \n ").error)

func test_not_turns():
    for turn in ["", "x1", "a0", "a1x", "10a1+", "j1"]:
        check_equal(turn, {}, Notation.parse(turn))

func test_write():
    check_equal("a flat cirya", "c3", Notation.write({"stone": "C", "square": Vector2(2, 2)}))
    check_equal("a tampa", "Tc3", Notation.write({"stone": "T", "square": Vector2(2, 2)}))
    check_equal("one stone", "a1+", Notation.write({"origin": Vector2(0, 0), "count": 1, "direction": Vector2(1, 0), "drops": [1]}))
    check_equal("all on one square", "3a1>", Notation.write({"origin": Vector2(0, 0), "count": 3, "direction": Vector2(0, 1), "drops": [3]}))
    check_equal("several drops", "3c3<21", Notation.write({"origin": Vector2(2, 2), "count": 3, "direction": Vector2(0, -1), "drops": [2, 1]}))
