extends Reference

# The base of the test files: every method starting with test_ is a test,
# run on a new instance between setup() and teardown()

const Piece = preload("res://tests/fakes/Piece.gd")

var failures = []

func setup():
    pass

func teardown():
    pass

func check(label, condition):
    if !condition:
        failures.append(label)

func check_equal(label, expected, actual):
    if !_same(expected, actual):
        failures.append("%s: expected %s, got %s" % [label, expected, actual])

# Godot 3 compares arrays by value but dictionaries by reference
func _same(a, b):
    if typeof(a) != typeof(b):
        return false

    if a is Dictionary:
        if a.size() != b.size():
            return false

        for key in a:
            if !b.has(key) or !_same(a[key], b[key]):
                return false

        return true

    if a is Array:
        if a.size() != b.size():
            return false

        for i in range(a.size()):
            if !_same(a[i], b[i]):
                return false

        return true

    return a == b
