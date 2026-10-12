class_name BattleCampaign
extends RefCounted

# Rules approved in the V1.2 order; no unapproved growth formula here.
const RpgRules = preload("res://scripts/rpg_rules.gd")
const ROUND_SECONDS := 99.0
const REST_HEAL := 10.0
const MAX_ATTRIBUTE := 255
const MAX_HP_MP := 999
const MAX_VISIBLE_PER_ARMY := 100

var armies: Array = [[], []]
var selected: Array = [-1, -1]
var elapsed := 0.0
var round_number := 0
var phase := "selection"
var last_result := ""
var support_choices: Dictionary = {}
var round_support: Dictionary = {}
var round_start_troops: Array = [0, 0]

func configure(attackers: Array, defenders: Array) -> String:
    if attackers.is_empty() or attackers.size() > 5:
        return "進攻方須有1～5隊。"
    if defenders.is_empty() or defenders.size() > 10:
        return "防守方須有1～10隊。"
    var identities := {}
    for army in [attackers, defenders]:
        for squad in army:
            var error := _validate_squad(squad, identities)
            if not error.is_empty():
                return error
    armies = [attackers.duplicate(true), defenders.duplicate(true)]
    selected = [-1, -1]
    elapsed = 0.0
    round_number = 0
    last_result = ""
    support_choices.clear()
    round_support.clear()
    round_start_troops = [0, 0]
    phase = "selection" if campaign_result().is_empty() else "finished"
    return ""

func _in_range(value: Variant, minimum: float, maximum: float) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func _take_id(record: Dictionary, identities: Dictionary) -> bool:
    var id: Variant = record.get("id")
    if not id is String or id.is_empty() or identities.has(id):
        return false
    identities[id] = true
    return true

func _validate_squad(squad: Variant, identities: Dictionary) -> String:
    if not squad is Dictionary or not _take_id(squad, identities):
        return "隊伍身分資料缺失或重複。"
    if not squad.get("name", "") is String:
        return "隊伍名稱無效。"
    var gs: Variant = squad.get("generals")
    if not gs is Array or gs.is_empty() or gs.size() > 3:
        return "每隊須有主將1名，副將0～2名。"
    for g in gs:
        if not g is Dictionary or not _take_id(g, identities):
            return "武將身分資料缺失或重複。"
        if not g.get("name", "") is String or not _integer(g.get("level", 1), 1) or not _integer(g.get("experience", 0), 0):
            return "武將名稱／成長資料無效。"
        if not _valid_actor(g):
            return "武將場上資料無效。"
        if not _in_range(g.get("max_hp"), 1, MAX_HP_MP) or not _in_range(g.get("max_mp"), 0, MAX_HP_MP):
            return "武將最大生命／技力超出範圍。"
        if not _in_range(g.get("hp"), 0, float(g["max_hp"])) or not _in_range(g.get("mp"), 0, float(g["max_mp"])):
            return "武將當前生命／技力超出範圍。"
        if not _in_range(g.get("might"), 0, MAX_ATTRIBUTE) or not _in_range(g.get("intellect"), 0, MAX_ATTRIBUTE) or not _in_range(g.get("loyalty"), 0, 100):
            return "武將屬性或忠誠超出範圍。"
    var soldiers: Variant = squad.get("soldiers")
    if not soldiers is Array or soldiers.size() > MAX_VISIBLE_PER_ARMY:
        return "可見士兵不得超過100名。"
    for s in soldiers:
        if not s is Dictionary or not s.get("kind") is int or not _in_range(s.get("kind"), 0, 2):
            return "兵種資料無效。"
        if not _in_range(s.get("max_hp"), 0.001, INF) or not _in_range(s.get("hp"), 0, float(s["max_hp"])) or not _in_range(s.get("troop_weight"), 0.001, INF):
            return "兵力代理資料無效。"
        if not _valid_actor(s):
            return "士兵場上資料無效。"
    return ""

func _integer(value: Variant, minimum: int) -> bool:
    return value is int and value >= minimum and value <= 9007199254740991

func _valid_actor(record: Dictionary) -> bool:
    for key in {"x": 920.0, "y": 350.0, "cooldown": 999.0, "attack_flash": 1.0}:
        var cap: float = {"x": 920.0, "y": 350.0, "cooldown": 999.0, "attack_flash": 1.0}[key]
        if record.has(key) and not _in_range(record[key], 0, cap):
            return false
    for key in {"team": 1, "slot": 2, "group": 5}:
        var cap: int = {"team": 1, "slot": 2, "group": 5}[key]
        if record.has(key) and (not _integer(record[key], 0) or record[key] > cap):
            return false
    return true

static func normalize_json(value: Variant) -> Variant:
    if value is float and is_finite(value) and absf(value) <= 9007199254740991.0 and floor(value) == value:
        return int(value)
    if value is Array:
        var values: Array = []
        for item in value:
            values.append(normalize_json(item))
        return values
    if value is Dictionary:
        var values := {}
        for key in value:
            values[key] = normalize_json(value[key])
        return values
    return value

func snapshot() -> Dictionary:
    return {"armies": armies.duplicate(true), "selected": selected.duplicate(),
        "elapsed": elapsed, "round_number": round_number, "phase": phase,
        "last_result": last_result, "support_choices": support_choices.duplicate(true),
        "round_support": round_support.duplicate(true), "round_start_troops": round_start_troops.duplicate()}

func restore(state: Dictionary) -> String:
    var data: Dictionary = normalize_json(state)
    var rosters: Variant = data.get("armies")
    if not rosters is Array or rosters.size() != 2 or not rosters[0] is Array or not rosters[1] is Array:
        return "存檔隊伍結構無效。"
    var candidate = get_script().new()
    var error: String = candidate.configure(rosters[0], rosters[1])
    if not error.is_empty():
        return error
    var chosen: Variant = data.get("selected")
    if not chosen is Array or chosen.size() != 2:
        return "存檔選隊資料無效。"
    for side in range(2):
        if not _integer(chosen[side], -1) or chosen[side] >= rosters[side].size():
            return "存檔選隊超出範圍。"
    if not _in_range(data.get("elapsed"), 0, ROUND_SECONDS) or not _integer(data.get("round_number"), 0):
        return "存檔場次／時間無效。"
    var opening: Variant = data.get("round_start_troops")
    if not opening is Array or opening.size() != 2 or not _integer(opening[0], 0) or not _integer(opening[1], 0):
        return "存檔開場兵力無效。"
    for side in range(2):
        if chosen[side] >= 0 and opening[side] < candidate.troops(candidate.armies[side][chosen[side]]):
            return "存檔兵力增加不一致。"
    if data.get("phase") not in ["selection", "fighting", "finished"] or data.get("last_result") not in ["", "timeout", "attacker_victory", "defender_victory", "draw"]:
        return "存檔戰役階段無效。"
    if chosen.has(-1):
        if chosen != [-1, -1] or data["round_number"] != 0 or data["elapsed"] != 0 or data["last_result"] != "":
            return "存檔尚未開戰資料不一致。"
    elif data["round_number"] == 0:
        return "存檔場次不一致。"
    if data["phase"] == "fighting":
        if chosen.has(-1) or data["elapsed"] >= ROUND_SECONDS or data["last_result"] != "":
            return "存檔交戰狀態不一致。"
        for side in range(2):
            if not candidate.squad_alive(candidate.armies[side][chosen[side]]):
                return "存檔交戰隊伍已失能。"
    elif (data["phase"] == "finished") != (not candidate.campaign_result().is_empty()):
        return "存檔戰役結果不一致。"
    var choices: Variant = data.get("support_choices")
    var running: Variant = data.get("round_support")
    if not choices is Dictionary or not running is Dictionary:
        return "存檔軍師技資料無效。"
    for id in choices:
        var choice: Variant = choices[id]
        if not id is String or candidate.general_by_id(id).is_empty() or not choice is Dictionary:
            return "存檔軍師技對象無效。"
        if not choice.get("kind") is String or not _integer(choice.get("level"), 1) or not RpgRules.valid_support(choice["kind"], choice["level"]):
            return "存檔軍師技等級無效。"
    if data["phase"] != "fighting" and not running.is_empty():
        return "已結束場次不得保留持續效果。"
    var eligible := {}
    if data["phase"] == "fighting":
        for side in range(2):
            for g in candidate.armies[side][chosen[side]]["generals"]:
                var choice: Dictionary = choices.get(g["id"], {})
                if choice.get("kind") == "regeneration":
                    eligible[g["id"]] = choice["level"]
                    if float(g["hp"]) > 0.0 and running.get(g["id"]) != choice["level"]:
                        return "存檔持續效果缺失。"
    for id in running:
        if not eligible.has(id) or running[id] != eligible[id]:
            return "存檔持續效果對象無效。"
    # Publish only after the entire candidate, including transient effects, is validated.
    armies = candidate.armies
    selected = chosen
    elapsed = float(data["elapsed"])
    round_number = int(data["round_number"])
    phase = data["phase"]
    last_result = data["last_result"]
    support_choices = choices
    round_support = running
    round_start_troops = opening
    return ""

func squad_alive(squad: Dictionary) -> bool:
    for g in squad["generals"]:
        if float(g["hp"]) > 0.0:
            return true
    return false

func _army_alive(side: int) -> bool:
    for squad in armies[side]:
        if squad_alive(squad):
            return true
    return false

func campaign_result() -> String:
    var attacker_alive := _army_alive(0)
    var defender_alive := _army_alive(1)
    if not attacker_alive and not defender_alive:
        return "draw"
    if not defender_alive:
        return "attacker_victory"
    if not attacker_alive:
        return "defender_victory"
    return ""

func begin_round(attacker: int, defender: int) -> bool:
    if phase != "selection" or not campaign_result().is_empty():
        return false
    var choices := [attacker, defender]
    for side in range(2):
        var index: int = choices[side]
        if index < 0 or index >= armies[side].size() or not squad_alive(armies[side][index]):
            return false
    selected = choices
    round_start_troops = [troops(armies[0][selected[0]]), troops(armies[1][selected[1]])]
    elapsed = 0.0
    round_number += 1
    last_result = ""
    phase = "fighting"
    round_support.clear()
    for side in range(2):
        for g in armies[side][selected[side]]["generals"]:
            if float(g["hp"]) <= 0.0:
                continue
            var choice: Dictionary = support_choices.get(g["id"], {})
            if choice.get("kind") == "entry_heal":
                g["hp"] = minf(float(g["max_hp"]), float(g["hp"]) + RpgRules.entry_heal(int(choice["level"])))
            elif choice.get("kind") == "regeneration":
                round_support[g["id"]] = int(choice["level"])
    return true

func general_by_id(id: String) -> Dictionary:
    for army in armies:
        for squad in army:
            for g in squad["generals"]:
                if g["id"] == id:
                    return g
    return {}

func set_support(general_id: String, kind: String, level: int) -> bool:
    if phase == "fighting" or not RpgRules.valid_support(kind, level) or general_by_id(general_id).is_empty():
        return false
    if kind == "none":
        support_choices.erase(general_id)
    else:
        support_choices[general_id] = {"kind": kind, "level": level}
    return true

func advance(delta: float) -> String:
    if phase != "fighting" or not is_finite(delta) or delta < 0.0:
        return ""
    var previous_second := int(floor(elapsed + 0.0000001))
    elapsed = minf(ROUND_SECONDS, elapsed + delta)
    var a_alive := squad_alive(armies[0][selected[0]])
    var d_alive := squad_alive(armies[1][selected[1]])
    # Resolve lethal damage first. Recovery cannot bring an incapacitated general back.
    if a_alive and d_alive:
        var ticks := int(floor(elapsed + 0.0000001)) - previous_second
        if ticks > 0:
            for id in round_support:
                var g := general_by_id(id)
                if float(g["hp"]) > 0.0:
                    g["hp"] = minf(float(g["max_hp"]), float(g["hp"]) + float(round_support[id]) * ticks)
    var result := ""
    if not a_alive and not d_alive:
        result = "draw"
    elif not d_alive:
        result = "attacker_victory"
    elif not a_alive:
        result = "defender_victory"
    elif elapsed >= ROUND_SECONDS:
        result = "timeout"
    if result.is_empty():
        return ""
    # Transition before awarding rest, so duplicate calls cannot heal twice.
    phase = "selection"
    round_support.clear()
    last_result = result
    for side in range(2):
        for index in range(armies[side].size()):
            if index == selected[side]:
                continue
            for g in armies[side][index]["generals"]:
                if float(g["hp"]) > 0.0:
                    g["hp"] = minf(float(g["max_hp"]), float(g["hp"]) + REST_HEAL)
    if not campaign_result().is_empty():
        phase = "finished"
    return result

func troops(squad: Dictionary) -> int:
    # Round only for display; retain every fractional proxy loss in state.
    var total := 0.0
    for s in squad["soldiers"]:
        total += float(s["hp"]) * float(s["troop_weight"])
    return maxi(0, int(ceil(total - 0.000001)))

func make_soldiers(counts: Array) -> Array:
    if counts.size() != 3:
        return []
    var total := 0
    var allocation := [0, 0, 0]
    var allocated := 0
    for kind in range(3):
        if not counts[kind] is int or counts[kind] < 0:
            return []
        total += int(counts[kind])
        if counts[kind] > 0:
            allocation[kind] = 1
            allocated += 1
    if total == 0:
        return []
    var target := mini(MAX_VISIBLE_PER_ARMY, maxi(allocated, int(ceil(float(total) / 10.0))))
    while allocated < target:
        var best := -1
        var priority := -1.0
        for kind in range(3):
            var weight: float = float(counts[kind]) / float(allocation[kind] + 1)
            if counts[kind] > 0 and weight > priority:
                best = kind
                priority = weight
        allocation[best] += 1
        allocated += 1
    var result: Array = []
    for kind in range(3):
        for _index in range(allocation[kind]):
            result.append({"kind": kind, "hp": 10.0, "max_hp": 10.0,
                "troop_weight": float(counts[kind]) / (float(allocation[kind]) * 10.0)})
    return result

