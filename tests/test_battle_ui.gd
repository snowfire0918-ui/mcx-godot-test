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

func run_tests() -> void:
    # Test narrow logical layouts independently from the 720-wide stretch canvas.
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(720, 1280)
    var ui = load("res://scenes/main.tscn").instantiate()
    root.add_child(ui)
    ui.set_process(false)
    check(not quit_on_go_back, "Android Back must not automatically quit the in-memory campaign")
    if not ui.has_method("_new_campaign"):
        check(false, "selection and campaign integration is missing")
        ui.free()
        quit(1)
        return
    ui._new_campaign()
    check(ui.selection.visible and not ui.battle.visible, "new campaign opens selection before combat")
    ui._start_selected_round()
    check(ui.active and ui.generals.size() == 6, "one main and two deputies on each side deploy")
    check(ui.soldiers_visual.size() == 200, "only the selected armies have visible soldiers")
    check(ui._total_soldiers(0) == 1000 and ui._total_soldiers(1) == 1000, "opening proxy counts match both real armies")
    ui.generals[0]["hp"] = 17.5
    ui.soldiers_visual[0]["hp"] = 2.25
    # Complete exactly at the boundary, before any simulation step can move or attack.
    ui.campaign.elapsed = 99.0
    ui._process(0.016)
    check(not ui.active and ui.campaign.last_result == "timeout", "99 seconds returns both surviving squads")
    ui._show_selection()
    ui._show_selection()
    ui._start_selected_round()
    check(ui.generals[0]["hp"] == 17.5, "selecting same squad retains damaged HP")
    check(ui.soldiers_visual[0]["hp"] == 2.25, "selecting same squad retains partial soldier loss")
    ui._show_home()
    var saved_elapsed: float = ui.campaign.elapsed
    ui._process(5.0)
    check(ui.campaign.elapsed == saved_elapsed, "home navigation pauses the encounter")
    ui._resume_campaign()
    check(ui.active and ui.generals[0]["hp"] == 17.5, "resume preserves the same running encounter")
    # OS navigation must follow the same state-preserving path as the on-screen button.
    ui.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
    check(ui.home.visible and not ui.active, "Android Back pauses combat and returns home")
    ui._process(5.0)
    check(ui.campaign.elapsed == saved_elapsed and ui.generals[0]["hp"] == 17.5 and ui.soldiers_visual[0]["hp"] == 2.25,
        "Android Back preserves the exact clock, general HP and soldier injury")
    ui.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
    var exit_confirmation = ui.get("exit_dialog")
    check(exit_confirmation != null and exit_confirmation.visible, "Back from home asks before discarding a campaign")
    ui.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
    check(exit_confirmation != null and not exit_confirmation.visible, "Back cancels the exit confirmation")
    ui._resume_campaign()
    check(ui.active and ui.generals[0]["hp"] == 17.5, "cancelled exit can resume the same encounter")
    ui.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
    ui.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
    check(ui.home.visible and not ui.active, "background and foreground leave combat safely paused")
    ui._process(5.0)
    check(ui.campaign.elapsed == saved_elapsed, "background time is not counted as combat time")
    ui._request_new_campaign()
    ui.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
    check(not ui.reset_dialog.visible and ui.generals[0]["hp"] == 17.5, "Back cancels campaign reset without erasing state")
    ui._resume_campaign()
    ui.generals[0]["hp"] = 0.0
    check(not ui._team_defeated(0), "commander death with living deputy is not team defeat")
    for g in ui.generals:
        if g["team"] == 1:
            g["hp"] = 0.0
    ui._process(0.016)
    check(ui.campaign.last_result == "attacker_victory", "round resolves from all enemy generals")
    check(ui.campaign.campaign_result() == "", "reserves keep enemy campaign alive")
    ui._show_selection()
    check(ui.squad_pickers[1].is_item_disabled(0), "defeated enemy squad is disabled")
    check(ui.squad_pickers[1].selected == 1, "selection advances to a living enemy squad")
    # Regression: cached living list must not let a soldier killed earlier this frame retaliate.
    ui._new_campaign()
    ui._start_selected_round()
    for s in ui.soldiers_visual:
        s["hp"] = 0.0
    var a: Dictionary = ui.soldiers_visual[0]
    var b: Dictionary = ui.soldiers_visual[100]
    a.merge({"hp": 10.0, "x": 450.0, "y": 80.0, "cooldown": 0.0}, true)
    b.merge({"hp": 0.5, "x": 452.0, "y": 80.0, "cooldown": 0.0}, true)
    ui._process(0.016)
    check(b["hp"] == 0.0 and a["hp"] == 10.0, "dead cached soldier cannot attack later in the frame")
    # Soldier targeting and generals remain active with no enemy soldiers.
    for g in ui.generals:
        g["x"] = 800.0 if g["team"] == 0 else 453.0
        g["y"] = 80.0
        g["cooldown"] = 10.0
    a["cooldown"] = 0.0
    var before: float = ui.generals[3]["hp"]
    ui._process(0.016)
    check(ui.generals[3]["hp"] < before, "soldiers can damage generals after enemy soldiers are gone")
    # Exercise maximum-sized menus on a narrow viewport.
    ui.attacker_count.value = 5
    ui.defender_count.value = 10
    ui.general_count.value = 1
    ui._new_campaign()
    check(ui.squad_pickers[0].item_count == 5 and ui.squad_pickers[1].item_count == 10, "maximum 5/10 squads appear in menus")
    ui.squad_pickers[0].select(4)
    ui.squad_pickers[1].select(9)
    ui._start_selected_round()
    check(ui.generals.size() == 2, "one-general squads can fight")
    check(ui.campaign.selected == [4, 9], "selected final squads actually deploy")
    for width in [720, 360]:
        root.size = Vector2i(width, 1280)
        ui._show_home()
        await process_frame
        await process_frame
        check(ui.layout.size.x <= width, "home fits viewport width %d" % width)
        ui.active = false
        ui.campaign.advance(99.0)
        ui._show_selection()
        await process_frame
        await process_frame
        check(ui.layout.size.x <= width, "selection fits viewport width %d" % width)
        check(ui.deploy_button.size.x <= width, "deploy button fits viewport width %d" % width)
    ui.free()
    print("BATTLE_UI_TESTS: ", checks - failures, "/", checks, " passed")
    quit(1 if failures > 0 else 0)
