extends SceneTree

var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: ", message)

func _initialize() -> void:
    var ui = load("res://scripts/main.gd").new()
    ui.general_stats[0]["might"] = 254
    ui._use_item("attribute_pill")
    check(ui.general_stats[0]["might"] == 255, "might 254 + prototype pill clamps to 255")
    check(ui.inventory["attribute_pill"] == 1, "effective pill consumes exactly one")
    ui.general_stats[0]["might"] = 255
    ui._use_item("attribute_pill")
    check(ui.inventory["attribute_pill"] == 1, "no-effect pill does not consume stock")
    ui.general_stats[0]["mp"] = 79
    ui.general_stats[0]["max_mp"] = 80
    ui._use_item("mp_elixir")
    check(ui.general_stats[0]["mp"] == 80, "MP restoration caps at recipient max 80, not 999")
    ui._use_item("hp_elixir")
    check(ui.inventory["hp_elixir"] == 2, "HP item without a recipient is not consumed")
    ui._use_item("unknown_item")
    check(not ui.inventory.has("unknown_item"), "unknown items cannot create inventory")
    ui.free()
    print("ITEM_TESTS: ", checks - failures, "/", checks, " passed")
    quit(1 if failures > 0 else 0)

