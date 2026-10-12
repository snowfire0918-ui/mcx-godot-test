extends SceneTree

const Campaign = preload("res://scripts/battle_campaign.gd")
const Roster = preload("res://scripts/prototype_roster.gd")
const Rules = preload("res://scripts/rpg_rules.gd")
const SAVE := "user://store-test/campaign.json"
var checks := 0
var failures := 0
var store_script: Script

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: ", message)

func fresh():
    var c = Campaign.new()
    var roster: Array = Roster.build(2, 2, 3)
    c.configure(roster[0], roster[1])
    return c

func same_state(a, b) -> bool:
    # JSON integral numbers may become int instead of float; compare numeric state,
    # while retaining exact fractional HP, positions and proxy weights.
    return Campaign.normalize_json(a.snapshot()) == Campaign.normalize_json(b.snapshot())

func write_raw(value: String) -> void:
    var f := FileAccess.open(SAVE, FileAccess.WRITE)
    f.store_string(value)
    f.close()

func clean() -> void:
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        DirAccess.remove_absolute(SAVE + suffix)

func _initialize() -> void:
    DirAccess.make_dir_recursive_absolute("user://store-test")
    clean()
    if not ResourceLoader.exists("res://scripts/campaign_store.gd") or not Campaign.new().has_method("snapshot"):
        check(false, "validated campaign storage is missing")
    else:
        store_script = load("res://scripts/campaign_store.gd")
        test_round_trips()
        test_rejection()
        test_files()
    clean()
    DirAccess.remove_absolute("user://store-test/blocked")
    print("CAMPAIGN_STORE_TESTS: ", checks - failures, "/", checks, " passed")
    quit(1 if failures else 0)

func test_round_trips() -> void:
    var c = fresh()
    var stock: Dictionary = Rules.inventory()
    stock["hp_pill"] = 1
    c.armies[0][1]["generals"][1]["might"] = 91
    var store = store_script.new(SAVE)
    check(store.save(c, stock) == "", "selection state can be saved")
    var restored = fresh()
    var inventory := {}
    var result: Dictionary = store.load_into(restored, inventory)
    check(result.error == "" and result.found and not result.recovered, "valid primary save loads")
    check(same_state(restored, c) and inventory == stock, "selection and permanent stats/stock round-trip exactly")
    var g: Dictionary = c.armies[0][0]["generals"][0]
    g["hp"] = 17.5
    c.set_support(g["id"], "entry_heal", 1)
    c.set_support(c.armies[0][0]["generals"][1]["id"], "regeneration", 2)
    c.begin_round(0, 0)
    g.merge({"x": 222.25, "y": 75.0, "cooldown": 0.375}, true)
    c.armies[0][0]["generals"][1]["hp"] = 20.0
    c.armies[0][0]["soldiers"][0].merge({"hp": 2.25, "x": 415.125, "y": 101.0, "cooldown": 0.4}, true)
    c.advance(1.5)
    check(store.save(c, stock) == "", "active fight can be saved")
    result = store.load_into(restored, inventory)
    check(result.error == "" and same_state(restored, c), "fight HP, proxy weight, positions, cooldowns, effects and timer round-trip")
    check(restored.get("round_start_troops") == [1000, 1000], "resume retains opening troop counts for accurate casualty display")
    check(restored.armies[0][0]["generals"][0]["hp"] == 67.5, "loading does not repeat entry heal")
    restored.advance(0.5)
    check(restored.armies[0][0]["generals"][1]["hp"] == 24.0, "loaded partial second continues at exact next regeneration tick")
    c.advance(97.5)
    check(store.save(c, stock) == "", "completed round can be saved")
    result = store.load_into(restored, inventory)
    check(same_state(restored, c) and restored.round_support.is_empty(), "load after timeout grants no additional rest and no old effect")
    for squad in c.armies[1]:
        for dead in squad["generals"]:
            dead["hp"] = 0.0
    c.phase = "finished"
    c.last_result = "attacker_victory"
    check(store.save(c, stock) == "", "finished campaign saves")
    store.load_into(restored, inventory)
    check(restored.phase == "finished" and restored.campaign_result() == "attacker_victory", "finished state survives restart")

func test_rejection() -> void:
    var c = fresh()
    var before: Dictionary = c.snapshot()
    var bad: Dictionary = before.duplicate(true)
    bad["armies"][0][0]["generals"][0]["hp"] = 1000
    check(c.restore(bad) != "" and c.snapshot() == before, "failed restore leaves existing campaign untouched")
    for change in [
        {"elapsed": -1.0}, {"phase": "bad"}, {"selected": [99, 0]}, {"round_number": 1.5},
        {"phase": "fighting"}, {"phase": "finished"}, {"round_support": {"missing": 3}},
        {"support_choices": {"missing": {"kind": "regeneration", "level": 1}}}
    ]:
        bad = before.duplicate(true)
        bad.merge(change, true)
        check(c.restore(bad) != "" and c.snapshot() == before, "invalid state rejected atomically: " + str(change))
    bad = before.duplicate(true)
    bad["armies"][0][0]["soldiers"][0]["kind"] = 0.25
    check(c.restore(bad) != "", "fractional soldier kind is not silently rounded")
    bad = before.duplicate(true)
    bad["armies"][0][0]["generals"][0]["cooldown"] = "oops"
    check(c.restore(bad) != "", "corrupt actor state rejected")
    bad = before.duplicate(true)
    bad["armies"][0][0]["generals"][0]["level"] = -1
    check(c.restore(bad) != "", "invalid growth data rejected without a growth formula")

func test_files() -> void:
    clean()
    var c = fresh()
    var stock: Dictionary = Rules.inventory()
    var store = store_script.new(SAVE)
    check(not store.load_into(c, stock).found, "missing save is a normal first launch")
    store.save(c, stock)
    c.armies[0][0]["generals"][0]["hp"] = 123.5
    stock["attribute_pill"] = 1
    store.save(c, stock)
    write_raw("{truncated")
    var result: Dictionary = store.load_into(c, stock)
    check(result.error == "" and result.recovered, "corrupt primary recovers a valid previous save")
    check(c.armies[0][0]["generals"][0]["hp"] == 240.0 and stock["attribute_pill"] == 2, "backup restores its consistent state and matching inventory")
    check(store.save(c, stock) == "", "recovered backup can safely repair primary")
    write_raw('{"schema_version": 999}')
    var before: Dictionary = c.snapshot()
    result = store.load_into(c, stock)
    check(result.error != "" and c.snapshot() == before, "future schema does not silently roll back to older backup")
    check(store.save(c, stock) != "" and FileAccess.get_file_as_string(SAVE).contains("999"), "autosave cannot overwrite future version")
    check(store.save(c, stock, true) == "", "explicit confirmed new campaign can replace incompatible data")
    clean()
    write_raw('{"schema_version":1,"campaign":{},"inventory":{}}')
    result = store.load_into(c, stock)
    check(result.error != "" and c.snapshot() == before, "invalid primary without backup does not mutate active state")
    clean()
    var invalid_stock := Rules.inventory()
    invalid_stock["hp_pill"] = -1
    check(store.save(c, invalid_stock) != "" and not FileAccess.file_exists(SAVE), "invalid stock cannot become a save")
    var blocker := FileAccess.open("user://store-test/blocked", FileAccess.WRITE)
    blocker.store_string("file, not a directory")
    blocker.close()
    var blocked_store = store_script.new("user://store-test/blocked/campaign.json")
    check(blocked_store.save(c, stock) != "", "unwritable destination reports failure")
