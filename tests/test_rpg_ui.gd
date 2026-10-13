extends SceneTree

const Campaign = preload("res://scripts/battle_campaign.gd")
const SAVE := "user://rpg-ui-test/campaign.json"
const BAD := "user://rpg-ui-test/bad.json"
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: ", message)

func clean(path: String) -> void:
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        DirAccess.remove_absolute(path + suffix)

func scene(path: String):
    var ui = load("res://scenes/main.tscn").instantiate()
    ui.save_path = path
    root.add_child(ui)
    ui.set_process(false)
    return ui

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var probe = load("res://scenes/main.tscn").instantiate()
    if not probe.has_method("_save_campaign") or not probe.has_method("_show_rpg"):
        check(false, "RPG controls and persistent scene integration are missing")
        probe.free()
        print("RPG_UI_TESTS: 0/1 passed")
        quit(1)
        return
    probe.free()
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(720, 1280)
    DirAccess.make_dir_recursive_absolute("user://rpg-ui-test")
    clean(SAVE)
    clean(BAD)
    var ui = scene(SAVE)
    check(not ui.campaign_started, "first launch does not fabricate a campaign")
    ui._new_campaign()
    ui._show_rpg()
    check(ui.rpg_panel.visible, "player can open RPG management")
    var panel = ui.rpg_panel
    panel.squad_picker.select(1)
    panel.squad_picker.item_selected.emit(1)
    panel.general_picker.select(2)
    panel.general_picker.item_selected.emit(2)
    var g: Dictionary = ui.campaign.armies[0][1]["generals"][2]
    check(panel.use_item("attribute_pill") and g["might"] == 85, "item applies to chosen squad2 deputy2")
    check(ui.campaign.armies[0][0]["generals"][0]["might"] == 80, "other generals are untouched")
    g["hp"] = 100.0
    check(panel.use_item("hp_pill") and g["max_hp"] == 270 and g["hp"] == 100, "maximum increase shown without extra current healing")
    panel.support_picker.select(6)
    check(panel.apply_support(), "explicit high-tier entry support can be assigned for testing")
    check(g["hp"] == 100, "assigning support does not activate it early")
    g["hp"] = 17.5
    ui._show_selection()
    ui.squad_pickers[0].select(1)
    ui._start_selected_round()
    check(g["hp"] == 217.5, "selected test recipient gets exactly200 entry HP")
    ui.campaign.elapsed = 1.5
    ui.generals[2].merge({"x": 222.25, "y": 80.0, "cooldown": 0.375}, true)
    ui.soldiers_visual[0]["hp"] = 2.25
    ui._show_home()
    var expected: Dictionary = Campaign.normalize_json(ui.campaign.snapshot())
    var stock: Dictionary = ui.inventory.duplicate()
    check(FileAccess.file_exists(SAVE), "return home writes a real campaign file")
    ui.free()
    ui = scene(SAVE)
    check(ui.campaign_started and ui.home.visible and not ui.active, "relaunch restores to a paused home screen")
    check(Campaign.normalize_json(ui.campaign.snapshot()) == expected and ui.inventory == stock, "relaunch retains exact canonical state and inventory")
    check(ui.generals[2]["hp"] == 217.5 and ui.generals[2]["cooldown"] == 0.375, "resume binding repeats neither entry healing nor actor cooldowns")
    check(ui.starting_troops == [1000, 1000], "casualty baseline survives relaunch")
    ui._resume_campaign()
    check(ui.active and ui.battle.visible, "player explicitly resumes saved fight")
    ui._show_home()
    ui._show_rpg()
    check(not ui.rpg_panel.use_item("hp_elixir") and ui.inventory == stock, "paused fight cannot use items")
    ui.rpg_panel.support_picker.select(1)
    check(not ui.rpg_panel.apply_support(), "paused fight cannot change support")
    ui.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
    check(ui.home.visible and not ui.active, "Back from RPG view returns safely home")
    ui._resume_campaign()
    ui.campaign.elapsed = 3.5
    ui.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
    var packet = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
    check(not ui.active and packet.campaign.elapsed == 3.5, "background notification saves exact current progress")
    ui._new_campaign()
    ui._start_selected_round()
    ui._process(5.0)
    packet = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
    check(packet.campaign.elapsed == 5.0, "running encounter checkpoints after5 seconds")
    ui.free()
    var f := FileAccess.open(BAD, FileAccess.WRITE)
    f.store_string("broken")
    f.close()
    ui = scene(BAD)
    check(not ui.campaign_started and ui.save_notice.text.contains("無法"), "invalid save is reported visibly")
    ui._request_new_campaign()
    check(ui.reset_dialog.visible, "replacing unreadable saved campaign still requires reset confirmation")
    ui.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
    check(FileAccess.get_file_as_string(BAD) == "broken", "cancelling reset preserves damaged original")
    ui._request_new_campaign()
    ui.reset_dialog.confirmed.emit()
    ui.reset_dialog.hide()
    check(ui.campaign_started and JSON.parse_string(FileAccess.get_file_as_string(BAD)) is Dictionary, "confirmed reset creates a valid replacement save")
    for width in [720, 360]:
        root.size = Vector2i(width, 800)
        ui._show_rpg()
        await process_frame
        await process_frame
        check(ui.layout.size.x <= width and ui.rpg_panel.support_picker.size.x <= width, "RPG layout fits width%d" % width)
        ui.scroll.scroll_vertical = int(ui.scroll.get_v_scroll_bar().max_value)
        await process_frame
        await process_frame
        check(ui.rpg_panel.back_button.get_global_rect().end.y <= 800, "RPG back button reachable by scrolling at width%d" % width)
    ui.free()
    f = FileAccess.open("user://rpg-ui-test/blocked", FileAccess.WRITE)
    f.store_string("not a directory")
    f.close()
    ui = scene("user://rpg-ui-test/blocked/save.json")
    ui._new_campaign()
    check(ui.save_notice.text.contains("失敗"), "write failure cannot be presented as saved")
    ui.free()
    clean(SAVE)
    clean(BAD)
    DirAccess.remove_absolute("user://rpg-ui-test/blocked")
    print("RPG_UI_TESTS: ", checks - failures, "/", checks, " passed")
    quit(1 if failures else 0)
