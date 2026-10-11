class_name BattleCampaign
extends RefCounted

# Rules approved in the V1.2 order; no character growth or item balance here.
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
    var gs: Variant = squad.get("generals")
    if not gs is Array or gs.is_empty() or gs.size() > 3:
        return "每隊須有主將1名，副將0～2名。"
    for g in gs:
        if not g is Dictionary or not _take_id(g, identities):
            return "武將身分資料缺失或重複。"
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
    elapsed = 0.0
    round_number += 1
    last_result = ""
    phase = "fighting"
    return true

func advance(delta: float) -> String:
    if phase != "fighting" or not is_finite(delta) or delta < 0.0:
        return ""
    elapsed = minf(ROUND_SECONDS, elapsed + delta)
    var a_alive := squad_alive(armies[0][selected[0]])
    var d_alive := squad_alive(armies[1][selected[1]])
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

