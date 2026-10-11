extends SceneTree

var failures := 0
var checks := 0
var model_script: Script

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: ", message)

func squad(id: String, count: int = 3) -> Dictionary:
    var gs: Array = []
    for i in range(count):
        gs.append({"id": id + "-g%d" % i, "name": "測試將%d" % i,
            "hp": 80.0, "max_hp": 100.0, "mp": 40, "max_mp": 80,
            "might": 80, "intellect": 65, "loyalty": 70})
    return {"id": id, "name": id, "generals": gs,
        "soldiers": [{"kind": 0, "hp": 10.0, "max_hp": 10.0, "troop_weight": 10.0}]}

func fresh():
    var c = model_script.new()
    check(c.configure([squad("a0"), squad("a1")], [squad("d0"), squad("d1")]) == "", "valid campaign accepted")
    return c

func _initialize() -> void:
    if not ResourceLoader.exists("res://scripts/battle_campaign.gd"):
        check(false, "BattleCampaign model is missing")
        quit(1)
        return
    model_script = load("res://scripts/battle_campaign.gd")
    test_validation()
    test_outcomes()
    test_timeout_and_rest()
    test_proxies()
    print("CAMPAIGN_TESTS: ", checks - failures, "/", checks, " passed")
    quit(1 if failures > 0 else 0)

func test_validation() -> void:
    var c = model_script.new()
    check(c.configure([squad("a", 1)], [squad("d", 3)]) == "", "one general and three generals can face each other")
    var attackers: Array = []
    var defenders: Array = []
    for i in range(5):
        attackers.append(squad("a%d" % i))
    for i in range(10):
        defenders.append(squad("d%d" % i))
    check(c.configure(attackers, defenders) == "", "5 attackers and 10 defenders accepted")
    attackers.append(squad("a5"))
    check(c.configure(attackers, defenders) != "", "six attackers rejected")
    attackers.pop_back()
    defenders.append(squad("d10"))
    check(c.configure(attackers, defenders) != "", "eleven defenders rejected")
    check(c.configure([], [squad("d")]) != "", "empty army rejected")
    check(c.configure([squad("a", 0)], [squad("d")]) != "", "empty squad rejected")
    check(c.configure([squad("a", 4)], [squad("d")]) != "", "four generals rejected")
    check(c.configure([squad("same")], [squad("same")]) != "", "duplicate identities rejected")
    var invalid := squad("a")
    invalid["generals"][0]["might"] = 256
    check(c.configure([invalid], [squad("d")]) != "", "might above 255 rejected")
    invalid = squad("a")
    invalid["generals"][0]["hp"] = NAN
    check(c.configure([invalid], [squad("d")]) != "", "nonfinite HP rejected")
    check(c.configure([{}], [squad("d")]) != "", "malformed squad rejected")
    var original := squad("original")
    check(c.configure([original], [squad("d")]) == "", "fresh state configured")
    c.armies[0][0]["generals"][0]["hp"] = 20.0
    check(original["generals"][0]["hp"] == 80.0, "campaign owns state without corrupting prototype roster")
    check(not c.begin_round(-1, 0), "negative selection rejected")
    check(not c.begin_round(0, 1), "out of range selection rejected")
    check(c.begin_round(0, 0), "legal round starts")
    check(not c.begin_round(0, 0), "starting an active round again rejected")

func test_outcomes() -> void:
    var c = fresh()
    for side in range(2):
        c.armies[side][0]["soldiers"][0]["hp"] = 0.0
    c.begin_round(0, 0)
    check(c.advance(1.0) == "", "zero soldiers with living generals does not end round")
    c.armies[0][0]["generals"][0]["hp"] = 0.0
    check(c.advance(1.0) == "", "living deputy keeps squad fighting after commander death")
    for g in c.armies[1][0]["generals"]:
        g["hp"] = 0.0
    check(c.advance(0.0) == "attacker_victory", "all generals dead loses the round")
    check(c.campaign_result() == "", "a defeated squad does not defeat surviving reserve squads")
    check(not c.begin_round(0, 0), "dead squad cannot be selected again")
    check(c.begin_round(0, 1), "winning squad can continue against another squad")
    for g in c.armies[1][1]["generals"]:
        g["hp"] = 0.0
    check(c.advance(0.0) == "attacker_victory", "remaining enemy squad defeated")
    check(c.campaign_result() == "attacker_victory", "all enemy squads defeated ends campaign")
    check(c.phase == "finished", "campaign locks after final defeat")
    check(not c.begin_round(0, 1), "finished campaign cannot restart a round")
    c = model_script.new()
    c.configure([squad("a", 1)], [squad("d", 1)])
    c.begin_round(0, 0)
    c.armies[0][0]["generals"][0]["hp"] = 0.0
    c.armies[1][0]["generals"][0]["hp"] = 0.0
    check(c.advance(99.0) == "draw", "simultaneous general defeat is a draw even at the boundary")
    check(c.campaign_result() == "draw", "both complete armies defeated is a draw")

func test_timeout_and_rest() -> void:
    var c = fresh()
    c.armies[0][0]["generals"][0]["hp"] = 17.5
    c.armies[0][0]["soldiers"][0]["hp"] = 2.25
    c.armies[0][1]["generals"][0]["hp"] = 85.0
    c.armies[0][1]["generals"][1]["hp"] = 99.0
    c.armies[0][1]["generals"][2]["hp"] = 0.0
    c.begin_round(0, 0)
    check(c.advance(98.9) == "", "encounter remains active before 99 seconds")
    check(c.armies[0][1]["generals"][0]["hp"] == 85.0, "no rest before encounter completes")
    check(c.advance(0.1) == "timeout", "99 seconds withdraws despite unequal HP and troops")
    check(c.campaign_result() == "", "timeout never picks a campaign winner")
    check(c.armies[0][0]["generals"][0]["hp"] == 17.5, "active HP is preserved exactly")
    check(c.armies[0][0]["soldiers"][0]["hp"] == 2.25, "fractional proxy HP is preserved exactly")
    check(c.troops(c.armies[0][0]) == 23, "22.5 represented troops display as 23 without rebuilding state")
    check(c.armies[0][1]["generals"][0]["hp"] == 95.0, "resting survivor gains exactly 10")
    check(c.armies[0][1]["generals"][1]["hp"] == 100.0, "rest caps at own maximum")
    check(c.armies[0][1]["generals"][2]["hp"] == 0.0, "ordinary rest never revives")
    c.advance(99.0)
    check(c.armies[0][1]["generals"][0]["hp"] == 95.0, "duplicate finish cannot award extra rest")
    for i in range(4):
        check(c.begin_round(0, 0), "surviving squad can redeploy after timeout")
        check(c.advance(99.0) == "timeout", "repeated timeout remains a withdrawal")
    check(c.armies[0][0]["generals"][0]["hp"] == 17.5, "repeated deployments do not refill active HP")
    check(c.armies[0][0]["soldiers"][0]["hp"] == 2.25, "repeated deployments never round partial losses back up")
    check(c.armies[0][1]["generals"][0]["hp"] == 100.0, "rest accumulates across encounters")
    c.begin_round(1, 0)
    c.advance(99.0)
    check(c.armies[0][0]["generals"][0]["hp"] == 27.5, "previous fighter heals after resting an entire encounter")
    check(c.armies[0][0]["soldiers"][0]["hp"] == 2.25, "rest does not regenerate troops")
    check(c.round_number == 6, "round count advances on valid deployment only")

func test_proxies() -> void:
    var c = model_script.new()
    var thousand: Array = c.make_soldiers([300, 300, 400])
    check(thousand.size() == 100, "1000 troops fit within 100 visible proxies")
    check(c.troops({"soldiers": thousand}) == 1000, "proxy weights represent 1000 actual troops")
    var big: Array = c.make_soldiers([900, 900, 1200])
    check(big.size() == 100, "3000 troops do not create 300 visuals")
    check(c.troops({"soldiers": big}) == 3000, "large army retains actual troop strength")
    var small: Array = c.make_soldiers([7, 1, 9])
    check(small.size() <= 100, "small army remains under visual cap")
    check(c.troops({"soldiers": small}) == 17, "small mixed army conserves exact initial troop count")
    check(c.make_soldiers([0, 0, 0]).is_empty(), "zero troops creates no actors")
    check(c.make_soldiers([-1, 1, 0]).is_empty(), "invalid negative troop allocation rejected")
