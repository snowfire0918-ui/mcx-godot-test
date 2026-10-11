extends RefCounted

# All initial values, troop composition, damage and names are prototype fixtures.
# This is not a historical roster, growth formula, or approved balance table.
const PROTOTYPE_GENERAL_HP := 240.0
const Campaign = preload("res://scripts/battle_campaign.gd")

static func build(attackers: int = 3, defenders: int = 3, generals_per_squad: int = 3) -> Array:
    var result: Array = [[], []]
    var model = Campaign.new()
    for side in range(2):
        var count: int = attackers if side == 0 else defenders
        for index in range(count):
            var id := "%d-squad-%d" % [side, index]
            var gs: Array = []
            for slot in range(generals_per_squad):
                var title: String = ["主將", "副將一", "副將二"][slot]
                gs.append({"id": id + "-general-%d" % slot, "name": "第%d隊%s" % [index + 1, title],
                    "hp": PROTOTYPE_GENERAL_HP, "max_hp": PROTOTYPE_GENERAL_HP,
                    "mp": 80 if side == 0 else 90, "max_mp": 80 if side == 0 else 90,
                    "might": 80 if side == 0 else 75, "intellect": 65 if side == 0 else 70,
                    "loyalty": 70})
            result[side].append({"id": id, "name": "第%d隊" % (index + 1), "generals": gs,
                "soldiers": model.make_soldiers([300, 300, 400])})
    return result
