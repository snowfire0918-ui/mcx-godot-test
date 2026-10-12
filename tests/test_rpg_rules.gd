extends SceneTree

var checks := 0
var failures := 0
var rules: Script
const Campaign = preload("res://scripts/battle_campaign.gd")
const Roster = preload("res://scripts/prototype_roster.gd")

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: ", message)

func general() -> Dictionary:
    return {"id": "a", "hp": 20.0, "max_hp": 100.0, "mp": 10, "max_mp": 80,
        "might": 254, "intellect": 254, "loyalty": 95}

func fresh():
    var c = Campaign.new()
    var roster: Array = Roster.build(2, 2, 3)
    for army in roster:
        for squad in army:
            for g in squad["generals"]:
                g["max_hp"] = 999.0
                g["hp"] = 1.0
    c.configure(roster[0], roster[1])
    return c

func _initialize() -> void:
    if not ResourceLoader.exists("res://scripts/rpg_rules.gd"):
        check(false, "approved RPG effects module is missing")
    else:
        rules = load("res://scripts/rpg_rules.gd")
        test_items()
    if not Campaign.new().has_method("set_support"):
        check(false, "campaign support effects are missing")
    else:
        test_support()
    print("RPG_RULES_TESTS: ", checks - failures, "/", checks, " passed")
    quit(1 if failures else 0)

func test_items() -> void:
    check(rules.catalog().size() == 7, "seven distinct approved item categories")
    for key in ["attribute_pill", "intellect_pill"]:
        var g := general()
        var stock: Dictionary = rules.inventory()
        var stat: String = "might" if key == "attribute_pill" else "intellect"
        check(rules.use_item(g, stock, key) and g[stat] == 255, "attribute pill clamps to255: " + key)
        check(stock[key] == 1, "effective attribute pill consumes one")
        check(not rules.use_item(g, stock, key) and stock[key] == 1, "capped attribute does not consume another")
    for key in ["hp_pill", "mp_pill"]:
        var g := general()
        var stock: Dictionary = rules.inventory()
        var stat: String = "max_hp" if key == "hp_pill" else "max_mp"
        var current: String = "hp" if key == "hp_pill" else "mp"
        var before: float = g[current]
        g[stat] = 998
        check(rules.use_item(g, stock, key) and g[stat] == 999, "max stat capped at999: " + key)
        check(g[current] == before, "raising maximum never restores current value: " + key)
        check(not rules.use_item(g, stock, key) and stock[key] == 1, "maximum cap preserves stock")
    for pair in [["hp_elixir", "hp", "max_hp"], ["mp_elixir", "mp", "max_mp"]]:
        var g := general()
        var stock: Dictionary = rules.inventory()
        g[pair[1]] = g[pair[2]] - 1
        check(rules.use_item(g, stock, pair[0]) and g[pair[1]] == g[pair[2]], "restoration respects own maximum")
        check(not rules.use_item(g, stock, pair[0]) and stock[pair[0]] == 1, "full recipient preserves stock")
    var g := general()
    var stock: Dictionary = rules.inventory()
    check(rules.use_item(g, stock, "loyalty_jewel") and g["loyalty"] == 100, "jewel clamps loyalty100")
    check(not rules.use_item(g, stock, "loyalty_jewel") and stock["loyalty_jewel"] == 1, "capped loyalty preserves stock")
    g["hp"] = 0.0
    check(not rules.use_item(g, stock, "hp_elixir") and g["hp"] == 0.0, "restoration does not resurrect")
    check(not rules.use_item({}, stock, "hp_elixir"), "missing recipient rejected")
    check(not rules.use_item(general(), stock, "missing"), "unknown item rejected")
    stock["hp_elixir"] = 0
    check(not rules.use_item(general(), stock, "hp_elixir"), "empty inventory cannot produce an effect")
    g = general()
    g["might"] = NAN
    check(not rules.use_item(g, rules.inventory(), "attribute_pill"), "nonfinite recipient stats rejected")

func test_support() -> void:
    for level in [1, 2, 3]:
        var c = fresh()
        var g: Dictionary = c.armies[0][0]["generals"][0]
        check(c.set_support(g["id"], "regeneration", level), "valid regeneration configured")
        c.begin_round(0, 0)
        c.advance(0.5)
        check(g["hp"] == 1.0, "regen waits for full second")
        c.advance(0.5)
        check(g["hp"] == 1.0 + level, "regen level determines exact HP per second")
        check(not c.set_support(g["id"], "entry_heal", 1), "cannot change support during a fight")
        c.advance(98.0)
        check(g["hp"] == 1.0 + 99.0 * level and c.last_result == "timeout", "regen bounded to99 full seconds")
        c.advance(1.0)
        check(g["hp"] == 1.0 + 99.0 * level and c.round_support.is_empty(), "ended effect cannot tick again")
        c.set_support(g["id"], "none", 0)
        c.begin_round(0, 0)
        var before: float = g["hp"]
        c.advance(1.0)
        check(g["hp"] == before, "old round effect never leaks into next round")
    for level in [1, 2, 3]:
        var c = fresh()
        var g: Dictionary = c.armies[0][0]["generals"][0]
        c.set_support(g["id"], "entry_heal", level)
        c.begin_round(0, 0)
        var expected: float = 1.0 + [50, 100, 200][level - 1]
        check(g["hp"] == expected, "entry heal exact value for tier")
        check(not c.begin_round(0, 0) and g["hp"] == expected, "duplicate entry cannot heal again")
        c.advance(3.0)
        check(g["hp"] == expected, "entry heal is not regeneration")
    var c = fresh()
    var g: Dictionary = c.armies[0][0]["generals"][0]
    check(not c.set_support("missing", "regeneration", 1), "unknown support recipient rejected")
    check(not c.set_support(g["id"], "bad", 1), "unknown support type rejected")
    check(not c.set_support(g["id"], "regeneration", 4), "unapproved support tier rejected")
    c.set_support(g["id"], "entry_heal", 3)
    g["hp"] = 998.0
    c.begin_round(0, 0)
    check(g["hp"] == 999.0, "entry healing caps at own maximum")
    c = fresh()
    g = c.armies[0][0]["generals"][0]
    c.set_support(g["id"], "entry_heal", 3)
    g["hp"] = 0.0
    c.begin_round(0, 0)
    check(g["hp"] == 0.0, "entry healing cannot revive a dead deputy")
    c = fresh()
    g = c.armies[0][0]["generals"][0]
    c.set_support(g["id"], "regeneration", 3)
    c.begin_round(0, 0)
    g["hp"] = 998.0
    c.advance(1.0)
    check(g["hp"] == 999.0, "ongoing recovery caps at own maximum")
    for dead in c.armies[0][0]["generals"]:
        dead["hp"] = 0.0
    c.advance(1.0)
    check(c.last_result == "defender_victory" and g["hp"] == 0.0, "defeat precedes regeneration; no revival")
