extends SceneTree

# Runs every test_ method of the tests/test_*.gd files. From the client folder:
#
#   godot --no-window --path . -s tests/run.gd
#
# It exits with 1 when a test fails

func _init():
    var total = 0
    var failures = 0

    for path in _test_files():
        var script = load(path)

        for method in script.get_script_method_list():
            if !method.name.begins_with("test_"):
                continue

            var test = script.new()
            test.setup()
            test.call(method.name)
            total += 1

            for failure in test.failures:
                print("FAIL %s %s: %s" % [path.get_file(), method.name, failure])
                failures += 1

    print("%d tests, %d failures" % [total, failures])
    quit(1 if failures else 0)

func _test_files():
    var files = []
    var dir = Directory.new()
    dir.open("res://tests")
    dir.list_dir_begin(true)

    var name = dir.get_next()
    while name:
        if name.begins_with("test_") and name.ends_with(".gd"):
            files.append("res://tests/" + name)
        name = dir.get_next()

    files.sort()
    return files
