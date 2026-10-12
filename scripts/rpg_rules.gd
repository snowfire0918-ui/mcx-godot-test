extends RefCounted

# Categories and caps are approved; amounts and starting stock are prototype fixtures.
const ITEMS := {
    "attribute_pill": {"name": "武力丹", "stat": "might", "amount": 5, "cap": 255},
    "intellect_pill": {"name": "智力丹", "stat": "intellect", "amount": 5, "cap": 255},
    "hp_pill": {"name": "生命仙丹", "stat": "max_hp", "amount": 30, "cap": 999},
    "mp_pill": {"name": "技力仙丹", "stat": "max_mp", "amount": 30, "cap": 999},
    "hp_elixir": {"name": "生命靈藥", "stat": "hp", "amount": 30, "cap_stat": "max_hp"},
    "mp_elixir": {"name": "技力靈藥", "stat": "mp", "amount": 30, "cap_stat": "max_mp"},
    "loyalty_jewel": {"name": "珠寶", "stat": "loyalty", "amount": 10, "cap": 100}
}

static func catalog() -> Dictionary:
    return ITEMS.duplicate(true)

static func inventory() -> Dictionary:
    var stock := {}
    for key in ITEMS:
        stock[key] = 2
    return stock

static func number_in_range(value: Variant, minimum: float, maximum: float) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func use_item(g: Dictionary, stock: Dictionary, key: String) -> bool:
    if not ITEMS.has(key) or not stock.get(key) is int or int(stock[key]) <= 0:
        return false
    if not number_in_range(g.get("hp"), 0.000001, 999):
        return false
    var item: Dictionary = ITEMS[key]
    var stat: String = item["stat"]
    var cap: Variant = g.get(item["cap_stat"]) if item.has("cap_stat") else item["cap"]
    if not number_in_range(cap, 0, 999) or not number_in_range(g.get(stat), 0, float(cap)):
        return false
    var value := minf(float(cap), float(g[stat]) + float(item["amount"]))
    if value == float(g[stat]):
        return false
    g[stat] = value
    stock[key] = int(stock[key]) - 1
    return true

static func valid_support(kind: String, level: int) -> bool:
    return (kind == "none" and level == 0) or (kind in ["regeneration", "entry_heal"] and level >= 1 and level <= 3)

static func entry_heal(level: int) -> float:
    return float([50, 100, 200][level - 1]) if level >= 1 and level <= 3 else 0.0

static func support_label(kind: String, level: int) -> String:
    if kind == "none":
        return "無軍師技"
    if not valid_support(kind, level):
        return "無效配置"
    var tier: String = ["初級", "中級", "高級"][level - 1]
    return ("恢復體力·%s（每秒+%d）" % [tier, level]) if kind == "regeneration" else ("增加體力·%s（進場+%d）" % [tier, entry_heal(level)])
