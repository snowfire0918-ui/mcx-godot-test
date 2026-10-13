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
        DirAccess.remove_absolute("user://test_battle_simulation.json" + suffix)

func run_tests() -> void:
    clean_save()
    var ui = load("res://scenes/main.tscn").instantiate()
    ui.save_path = "user://test_battle_simulation.json"
    root.add_child(ui)
    ui.set_process(false)
    # A full encounter through the real movement, targeting and damage loop.
    ui._new_campaign()
    ui._start_selected_round()
    var previous := [1000, 1000]
    var valid := true
    var frames := 0
    while ui.active and frames < 2972:
        ui._process(1.0 / 30.0)
        for side in range(2):
            var count: int = ui._total_soldiers(side)
            valid = valid and count >= 0 and count <= previous[side]
            previous[side] = count
        for g in ui.generals:
            valid = valid and g["hp"] >= 0.0 and g["hp"] <= g["max_hp"]
        frames += 1
    check(not ui.active, "real encounter ends by 99 seconds")
    check(valid, "real combat never creates troops or out-of-range HP")
    check(previous[0] < 1000 and previous[1] < 1000, "both real armies engage and take damage")
    check(not ui.campaign.last_result.is_empty(), "real encounter yields a round result")
    print("SIMULATION: frames=", frames, " result=", ui.campaign.last_result, " troops=", previous)
    # The existing three counter advantages must retain their actual damage effect.
    for pairing in [[0, 2], [2, 1], [1, 0]]:
        ui._new_campaign()
        ui._start_selected_round()
        for s in ui.soldiers_visual:
            s["hp"] = 0.0
        var a: Dictionary = ui.soldiers_visual[0]
        var b: Dictionary = ui.soldiers_visual[100]
        a.merge({"kind": pairing[0], "hp": 10.0, "x": 450.0, "y": 80.0, "cooldown": 0.0}, true)
        b.merge({"kind": pairing[1], "hp": 10.0, "x": 452.0, "y": 80.0, "cooldown": 10.0}, true)
        ui._process(0.016)
        check(b["hp"] == 8.5, "troop counter %d against %d deals prototype 1.5 damage" % pairing)
    ui._new_campaign()
    ui._start_selected_round()
    for s in ui.soldiers_visual:
        s["hp"] = 0.0
    for g in ui.generals:
        g["x"] = 50.0 if g["team"] == 0 else 850.0
        g["y"] = 100.0
        g["cooldown"] = 10.0
    ui.generals[0].merge({"x": 450.0, "cooldown": 0.0}, true)
    ui.generals[3].merge({"x": 452.0, "hp": 20.0}, true)
    ui._process(0.016)
    check(ui.generals[3]["hp"] == 18.0, "generals attack enemy generals when all soldiers are gone")
    # A squad loses immediately when its final general falls, even mid-frame.
    ui.general_count.value = 1
    ui._new_campaign()
    ui.campaign.armies[0][1]["generals"][0]["hp"] = 100.0
    ui._start_selected_round()
    for s in ui.soldiers_visual:
        s["hp"] = 0.0
    ui.generals[0].merge({"hp": 0.5, "x": 100.0, "y": 80.0, "cooldown": 10.0}, true)
    ui.generals[1].merge({"hp": 0.5, "x": 800.0, "y": 80.0, "cooldown": 10.0}, true)
    ui.soldiers_visual[0].merge({"hp": 10.0, "x": 798.0, "y": 80.0, "cooldown": 0.0}, true)
    ui.soldiers_visual[100].merge({"hp": 10.0, "x": 102.0, "y": 80.0, "cooldown": 0.0}, true)
    ui._process(0.016)
    check(ui.campaign.last_result == "attacker_victory", "first final-general death ends the round, not a later false draw")
    check(ui.generals[0]["hp"] == 0.5, "defeated squad's soldiers cannot retaliate later in the frame")
    ui._process(0.016)
    check(ui.campaign.armies[0][1]["generals"][0]["hp"] == 110.0, "mid-frame settlement grants reserve healing exactly once")
    # A general's killing blow also stops later allies from damaging the defeated squad.
    ui.general_count.value = 3
    ui._new_campaign()
    ui._start_selected_round()
    for s in ui.soldiers_visual:
        s["hp"] = 0.0
    for g in ui.generals:
        g["hp"] = 0.0
    ui.generals[0].merge({"hp": 0.5, "x": 450.0, "y": 80.0, "cooldown": 0.0}, true)
    ui.generals[1].merge({"hp": 240.0, "x": 800.0, "y": 80.0, "cooldown": 0.0}, true)
    ui.generals[3].merge({"hp": 0.5, "x": 452.0, "y": 80.0, "cooldown": 10.0}, true)
    ui.soldiers_visual[100].merge({"hp": 10.0, "x": 802.0, "y": 80.0, "cooldown": 10.0}, true)
    ui._process(0.016)
    check(ui.campaign.last_result == "attacker_victory" and ui.soldiers_visual[100]["hp"] == 10.0,
        "general killing blow stops subsequent actors before extra casualties")
    ui.free()
    clean_save()
    print("BATTLE_SIMULATION_TESTS: ", checks - failures, "/", checks, " passed")
    quit(1 if failures > 0 else 0)
