extends SceneTree

const SAVE := "user://prebattle-setup-test.json"
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: ", message)

func clean() -> void:
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        DirAccess.remove_absolute(SAVE + suffix)

func scene():
    var ui = load("res://scenes/main.tscn").instantiate()
    ui.save_path = SAVE
    root.add_child(ui)
    ui.set_process(false)
    return ui

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    clean()
    var ui = scene()
    check(ui.manage_button.is_visible_in_tree(), "fresh launch exposes a setup entry before any battle")
    ui.manage_button.pressed.emit()
    check(ui.campaign_started and ui.rpg_panel.visible, "fresh setup click creates roster and opens skill configuration")
    if not ui.campaign_started or not ui.rpg_panel.visible:
        ui.free()
        finish()
        return
    check(ui.campaign.phase == "selection" and ui.campaign.round_number == 0 and not ui.active,
        "first setup does not start combat or spend a round")
    var g: Dictionary = ui.rpg_panel.target()
    g["hp"] = 80.0
    ui.rpg_panel.support_picker.select(4)
    ui.rpg_panel.support_button.pressed.emit()
    check(ui.campaign.support_choices.get(g["id"], {}).get("kind") == "entry_heal" and g["hp"] == 80,
        "first-launch support is configured without healing early")
    ui.rpg_panel.back_button.pressed.emit()
    check(ui.selection.visible and ui.squad_details[0].text.contains("增加體力"),
        "setup returns directly to selection with current skill summary")
    var prebattle = ui.get("prebattle_button")
    check(prebattle != null and prebattle.is_visible_in_tree(), "selection exposes prebattle configuration")
    if prebattle == null:
        ui.free()
        finish()
        return
    ui.squad_pickers[0].select(2)
    ui.squad_pickers[1].select(1)
    prebattle.pressed.emit()
    check(ui.rpg_panel.squad_picker.selected == 2 and ui.rpg_panel.side_picker.selected == 0,
        "prebattle setup opens the selected friendly squad")
    ui.rpg_panel.support_picker.select(2)
    ui.rpg_panel.support_button.pressed.emit()
    ui.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
    check(ui.selection.visible and ui.squad_pickers[0].selected == 2 and ui.squad_pickers[1].selected == 1,
        "Android Back retains both pending squad selections")
    check(ui.squad_details[0].text.contains("恢復體力"), "return refreshes the selected squad's support summary")
    ui.squad_pickers[0].select(0)
    ui._start_selected_round()
    check(g["hp"] == 130.0, "first round applies the configured entry heal exactly once")
    ui._show_home()
    ui.manage_button.pressed.emit()
    check(ui.rpg_panel.support_button.disabled, "paused combat still forbids support changes")
    ui.rpg_panel.back_button.pressed.emit()
    check(ui.home.visible, "home management returns to home")
    ui.free()
    ui = scene()
    check(ui.campaign_started and ui.campaign.general_by_id(g["id"])["hp"] == 130.0,
        "restart preserves configured support and does not repeat entry healing")
    ui.attacker_count.value = 5
    ui.defender_count.value = 1
    ui._new_campaign()
    ui._show_rpg()
    ui.rpg_panel.side_picker.select(1)
    ui.rpg_panel.side_picker.item_selected.emit(1)
    ui.rpg_panel.back_button.pressed.emit()
    ui._resume_campaign()
    ui.squad_pickers[0].select(4)
    ui.prebattle_button.pressed.emit()
    check(ui.rpg_panel.squad_picker.item_count == 5 and ui.rpg_panel.squad_picker.selected == 4,
        "setup switches from smaller enemy roster to the chosen final friendly squad")
    check(ui.rpg_panel.target()["id"] == "0-squad-4-general-0", "setup must not configure a different squad after switching sides")
    ui.free()
    clean()
    var file := FileAccess.open(SAVE, FileAccess.WRITE)
    file.store_string("damaged original")
    file.close()
    ui = scene()
    ui.manage_button.pressed.emit()
    check(ui.reset_dialog.visible and not ui.campaign_started, "setup cannot bypass confirmation for damaged save")
    ui.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
    check(FileAccess.get_file_as_string(SAVE) == "damaged original", "cancelling setup preserves damaged save")
    ui.manage_button.pressed.emit()
    ui.reset_dialog.confirmed.emit()
    ui.reset_dialog.hide()
    check(ui.rpg_panel.visible and ui.campaign.round_number == 0, "confirmed replacement enters setup before combat")
    ui.free()
    finish()

func finish() -> void:
    clean()
    print("PREBATTLE_SETUP_TESTS: ", checks - failures, "/", checks, " passed")
    quit(1 if failures else 0)
