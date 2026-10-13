extends SceneTree

var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: ", message)

func _initialize() -> void:
    call_deferred("run_tests")

func clean_save() -> void:
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        DirAccess.remove_absolute("user://items-test.json" + suffix)

func run_tests() -> void:
    clean_save()
    var ui = load("res://scenes/main.tscn").instantiate()
    ui.save_path = "user://items-test.json"
    root.add_child(ui)
    ui.set_process(false)
    ui._new_campaign()
    var recipient: Dictionary = ui.rpg_panel.target()
    recipient["might"] = 254
    ui._use_item("attribute_pill")
    check(recipient["might"] == 255, "might 254 + prototype pill clamps to 255")
    check(ui.inventory["attribute_pill"] == 1, "effective pill consumes exactly one")
    ui._use_item("attribute_pill")
    check(ui.inventory["attribute_pill"] == 1, "no-effect pill does not consume stock")
    recipient["mp"] = 79
    recipient["max_mp"] = 80
    ui._use_item("mp_elixir")
    check(recipient["mp"] == 80, "MP restoration caps at recipient max 80, not 999")
    ui.rpg_panel.general_picker.select(-1)
    ui._use_item("hp_elixir")
    check(ui.inventory["hp_elixir"] == 2, "HP item without a recipient is not consumed")
    ui._use_item("unknown_item")
    check(not ui.inventory.has("unknown_item"), "unknown items cannot create inventory")
    ui.free()
    clean_save()
    print("ITEM_TESTS: ", checks - failures, "/", checks, " passed")
    quit(1 if failures > 0 else 0)

