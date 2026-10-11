extends Control

# MCX GAMES V0.0.9: generals decide victory, soldiers can damage generals, 99s rounds.
# Visual and balance values are placeholders for Android prototype testing.
const MAX_HP := 999
const ROUND_SECONDS := 99.0
const REST_HEAL := 10.0
const GENERAL_MAX_HP := 240.0
const GENERAL_ATTACK_INTERVAL := 0.65
const FIELD_W := 920.0
const SPEED := 90.0
const MAX_VISIBLE_PER_ARMY := 100
const SOLDIER_REACH := 15.0
const SOLDIER_SPEED := 58.0
const SOLDIER_ATTACK_INTERVAL := 0.75
const GENERAL_SPEED := 44.0
const GENERAL_REACH := 22.0
const GENERAL_DAMAGE := 2.0
const FIELD_DISPLAY_H := 350.0
const ATTACK_TIME := 0.8
const UNIT_NAMES := ["INFANTRY", "SPEARS", "ARCHERS"]
const COLORS := [Color("#5ba6e6"), Color("#e46d67")]

var home: VBoxContainer
var battle: VBoxContainer
var field: Control
var status: Label
var score: Label
var details: Label
var units: Array[Dictionary] = []
var active := false
var tick := 0.0
var starting_troops := [1000, 1000]
var soldiers_visual: Array[Dictionary] = []
var battle_elapsed := 0.0
var generals: Array[Dictionary] = []
var round_count := 1
var general_stats := [{"might": 80, "intellect": 65, "loyalty": 70, "mp": 80}, {"might": 75, "intellect": 70, "loyalty": 70, "mp": 90}]
# Prototype item stock: permanent attributes +1..10, loyalty jewels, and HP/MP elixirs +10..50.
var inventory := {"attribute_pill": 2, "loyalty_jewel": 2, "hp_elixir": 2, "mp_elixir": 2}
var item_info: Label

func _ready() -> void:
    _make_ui()
    _show_home()

func _make_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color("#102b25")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var layout := VBoxContainer.new()
    layout.custom_minimum_size = Vector2(620, 0)
    layout.add_theme_constant_override("separation", 18)
    center.add_child(layout)
    var brand := _label("MCX GAMES", 44)
    brand.add_theme_color_override("font_color", Color("#e8c36d"))
    layout.add_child(brand)
    home = VBoxContainer.new()
    home.add_theme_constant_override("separation", 25)
    layout.add_child(home)
    home.add_child(_label("PLAY · CREATE · KEEP THE DREAM\nGodot Android battle V0.0.9", 24))
    var start := _button("開始戰鬥")
    start.pressed.connect(_show_battle)
    home.add_child(start)
    battle = VBoxContainer.new()
    battle.add_theme_constant_override("separation", 14)
    layout.add_child(battle)
    status = _label("BATTLE TEST", 32)
    status.add_theme_color_override("font_color", Color("#e8c36d"))
    battle.add_child(status)
    score = _label("ARMY A vs ARMY B", 24)
    battle.add_child(score)
    field = Control.new()
    field.custom_minimum_size = Vector2(620, FIELD_DISPLAY_H)
    field.draw.connect(_draw_field)
    battle.add_child(field)
    details = _label("", 21)
    battle.add_child(details)
    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 12)
    battle.add_child(buttons)
    var restart := _button("RESTART")
    restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    restart.pressed.connect(_restart)
    buttons.add_child(restart)
    var back := _button("BACK")
    back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back.pressed.connect(_show_home)
    buttons.add_child(back)
    battle.visible = false
    item_info = _label("", 18)
    home.add_child(item_info)
    for item_key in ["attribute_pill", "loyalty_jewel", "hp_elixir", "mp_elixir"]:
        var item_button := _button("USE " + item_key.to_upper() + " (ARMY A)")
        item_button.custom_minimum_size.y = 48.0
        item_button.pressed.connect(_use_item.bind(item_key))
        home.add_child(item_button)
    _refresh_item_info()

func _use_item(item_key: String) -> void:
    if int(inventory.get(item_key, 0)) <= 0:
        return
    inventory[item_key] = int(inventory[item_key]) - 1
    var stats: Dictionary = general_stats[0]
    match item_key:
        "attribute_pill":
            stats["might"] = mini(999, int(stats["might"]) + 5) # Demo +5, legal item range +1..10.
        "loyalty_jewel":
            stats["loyalty"] = mini(100, int(stats["loyalty"]) + 10)
        "hp_elixir":
            if generals.size() > 0:
                generals[0]["hp"] = minf(float(generals[0]["max_hp"]), float(generals[0]["hp"]) + 30.0)
        "mp_elixir":
            stats["mp"] = mini(999, int(stats["mp"]) + 30)
    general_stats[0] = stats
    _refresh_item_info()

func _refresh_item_info() -> void:
    if item_info == null:
        return
    var s: Dictionary = general_stats[0]
    item_info.text = "A Might %d  Int %d  Loyalty %d  MP %d/999\nItems: pill %d  jewel %d  HP %d  MP %d" % [int(s["might"]), int(s["intellect"]), int(s["loyalty"]), int(s["mp"]), int(inventory["attribute_pill"]), int(inventory["loyalty_jewel"]), int(inventory["hp_elixir"]), int(inventory["mp_elixir"])]

func _label(value: String, font_size: int) -> Label:
    var l := Label.new()
    l.text = value
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", Color.WHITE)
    return l

func _button(value: String) -> Button:
    var b := Button.new()
    b.text = value
    b.custom_minimum_size = Vector2(0, 90)
    return b

func _show_home() -> void:
    active = false
    home.visible = true
    battle.visible = false
    _refresh_item_info()

func _show_battle() -> void:
    home.visible = false
    battle.visible = true
    _restart()

func _restart() -> void:
    units.clear()
    soldiers_visual.clear()
    generals.clear()
    round_count = 1
    # One army has exactly 100 visual soldiers representing 1000 troops.
    # The three groups are 30 infantry, 30 spears and 40 archers.
    for team in range(2):
        var base_x: float = 125.0 if team == 0 else 795.0
        generals.append({"team": team, "x": base_x, "y": 315.0, "hp": GENERAL_MAX_HP, "max_hp": GENERAL_MAX_HP, "cooldown": 0.0})
        for kind in range(4):
            var count: int = 30 if kind < 2 else (40 if kind == 2 else 0)
            var group_id: int = units.size()
            units.append({
                "team": team, "kind": kind, "hp": 160 if kind == 3 else count * 10,
                "max_hp": 160 if kind == 3 else count * 10,
                "soldiers": count * 10, "starting_soldiers": count * 10,
                "x": base_x, "lane": kind
            })
            for n in range(count):
                var column: int = n % 8
                var row: int = int(n / 8)
                var direction: float = 1.0 if team == 0 else -1.0
                soldiers_visual.append({
                    "team": team, "group": group_id, "kind": kind,
                    "x": base_x - direction * float(row) * 13.0 + direction * float(column) * 3.0,
                    "y": 68.0 + float(kind) * 83.0 + float(column - 4) * 9.0,
                    "hp": 10.0, "cooldown": float(n % 5) * 0.13,
                    "attack_flash": 0.0
                })
    active = true
    tick = 0.0
    battle_elapsed = 0.0
    status.text = "BATTLE TEST"
    _refresh()

func _process(delta: float) -> void:
    if not active:
        return
    var dt: float = minf(delta, 0.08)
    tick += dt
    battle_elapsed += dt
    # Cache living enemy indices once each frame; 200 actors are the hard cap.
    var living: Array = [[], []]
    for i in range(soldiers_visual.size()):
        if float(soldiers_visual[i]["hp"]) > 0.0:
            living[int(soldiers_visual[i]["team"])].append(i)
    if _team_defeated(0) or _team_defeated(1):
        _end_battle()
        return
    if battle_elapsed >= ROUND_SECONDS:
        active = false
        status.text = "99s! BOTH TEAMS RETREAT"
        details.text = "Round %d ended. HP and surviving troops retained.\nRESTART begins a new test." % round_count
        field.queue_redraw()
        return
    # Each actor selects a nearby enemy, approaches or attacks independently.
    for team in range(2):
        var enemies: Array = living[1 - team]
        for index in living[team]:
            var s: Dictionary = soldiers_visual[index]
            var nearest := -1
            var best := INF
            var sx: float = float(s["x"])
            var sy: float = float(s["y"])
            for enemy_index in enemies:
                var e: Dictionary = soldiers_visual[enemy_index]
                if float(e["hp"]) <= 0.0:
                    continue
                var dx: float = float(e["x"]) - sx
                var dy: float = float(e["y"]) - sy
                var distance_sq: float = dx * dx + dy * dy
                if distance_sq < best:
                    best = distance_sq
                    nearest = enemy_index
            # Soldiers also target living enemy generals, even after enemy soldiers are gone.
            var general_target := -1
            for gi in range(generals.size()):
                var g: Dictionary = generals[gi]
                if int(g["team"]) != team and float(g["hp"]) > 0.0:
                    var gd: float = Vector2(float(g["x"]) - sx, float(g["y"]) - sy).length_squared()
                    if gd < best:
                        best = gd
                        general_target = gi
                        nearest = -1
            if nearest < 0 and general_target < 0:
                continue
            var target: Dictionary = generals[general_target] if general_target >= 0 else soldiers_visual[nearest]
            var kind: int = int(s["kind"])
            var reach: float = 125.0 if kind == 2 else SOLDIER_REACH
            var dist: float = sqrt(best)
            s["cooldown"] = maxf(0.0, float(s["cooldown"]) - dt)
            s["attack_flash"] = maxf(0.0, float(s["attack_flash"]) - dt)
            if dist > reach:
                var move_dir: Vector2 = Vector2(float(target["x"]) - sx, float(target["y"]) - sy).normalized()
                # Small separation steering prevents every actor stacking on one pixel.
                var repel := Vector2.ZERO
                for ally_index in living[team]:
                    if ally_index == index:
                        continue
                    var ally: Dictionary = soldiers_visual[ally_index]
                    var away := Vector2(sx - float(ally["x"]), sy - float(ally["y"]))
                    if away.length_squared() > 0.01 and away.length_squared() < 144.0:
                        repel += away.normalized() * (12.0 - away.length()) / 12.0
                move_dir = (move_dir + repel * 0.85).normalized()
                var speed: float = SOLDIER_SPEED * (0.7 if kind == 2 else 1.0)
                s["x"] = clampf(sx + move_dir.x * speed * dt, 8.0, FIELD_W - 8.0)
                s["y"] = clampf(sy + move_dir.y * speed * dt, 15.0, FIELD_DISPLAY_H - 20.0)
            elif float(s["cooldown"]) <= 0.0:
                var damage: float = 1.0
                var enemy_kind: int = int(target.get("kind", -1))
                if (kind == 0 and enemy_kind == 2) or (kind == 2 and enemy_kind == 1) or (kind == 1 and enemy_kind == 0):
                    damage = 1.5
                target["hp"] = maxf(0.0, float(target["hp"]) - damage)
                if general_target >= 0:
                    generals[general_target] = target
                else:
                    soldiers_visual[nearest] = target
                s["cooldown"] = SOLDIER_ATTACK_INTERVAL * (1.3 if kind == 2 else 1.0)
                s["attack_flash"] = 0.15
            soldiers_visual[index] = s
    _move_generals(dt)
    _recount_armies()
    _refresh()

func _team_defeated(team: int) -> bool:
    for g in generals:
        if int(g["team"]) == team and float(g["hp"]) > 0.0:
            return false
    return true

func _end_battle() -> void:
    active = false
    _recount_armies()
    if _team_defeated(0) and _team_defeated(1):
        status.text = "DRAW! ALL GENERALS FALLEN"
    elif _team_defeated(1):
        status.text = "ARMY A WINS! GENERALS DEFEATED"
    else:
        status.text = "ARMY B WINS! GENERALS DEFEATED"
    details.text = "A troops: %d | B troops: %d\nVictory is decided by generals, not soldiers." % [_total_soldiers(0), _total_soldiers(1)]
    field.queue_redraw()

func _move_generals(dt: float) -> void:
    for gi in range(generals.size()):
        var general: Dictionary = generals[gi]
        if float(general["hp"]) <= 0.0:
            continue
        var nearest := -1
        var enemy_general := -1
        var best := INF
        for si in range(soldiers_visual.size()):
            var soldier: Dictionary = soldiers_visual[si]
            if int(soldier["team"]) == int(general["team"]) or float(soldier["hp"]) <= 0.0:
                continue
            var dist_sq: float = Vector2(float(soldier["x"]) - float(general["x"]), float(soldier["y"]) - float(general["y"])).length_squared()
            if dist_sq < best:
                best = dist_sq
                nearest = si
                enemy_general = -1
        for other_gi in range(generals.size()):
            var opponent: Dictionary = generals[other_gi]
            if int(opponent["team"]) == int(general["team"]) or float(opponent["hp"]) <= 0.0:
                continue
            var dist_sq: float = Vector2(float(opponent["x"]) - float(general["x"]), float(opponent["y"]) - float(general["y"])).length_squared()
            if dist_sq < best:
                best = dist_sq
                enemy_general = other_gi
                nearest = -1
        if nearest < 0 and enemy_general < 0:
            continue
        var target: Dictionary = generals[enemy_general] if enemy_general >= 0 else soldiers_visual[nearest]
        var distance: float = sqrt(best)
        general["cooldown"] = maxf(0.0, float(general["cooldown"]) - dt)
        if distance > GENERAL_REACH:
            var direction: Vector2 = Vector2(float(target["x"]) - float(general["x"]), float(target["y"]) - float(general["y"])).normalized()
            general["x"] = clampf(float(general["x"]) + direction.x * GENERAL_SPEED * dt, 10.0, FIELD_W - 10.0)
            general["y"] = clampf(float(general["y"]) + direction.y * GENERAL_SPEED * dt, 12.0, FIELD_DISPLAY_H - 12.0)
        elif float(general["cooldown"]) <= 0.0:
            target["hp"] = maxf(0.0, float(target["hp"]) - GENERAL_DAMAGE)
            if enemy_general >= 0:
                generals[enemy_general] = target
            else:
                soldiers_visual[nearest] = target
            general["cooldown"] = GENERAL_ATTACK_INTERVAL
        generals[gi] = general

func _recount_armies() -> void:
    for i in range(units.size()):
        if int(units[i]["kind"]) == 3:
            continue
        var total_hp := 0.0
        for s in soldiers_visual:
            if int(s["group"]) == i:
                total_hp += float(s["hp"])
        var group: Dictionary = units[i]
        group["soldiers"] = int(ceil(total_hp))
        group["hp"] = int(ceil(total_hp))
        units[i] = group

func _total_soldiers(team: int) -> int:
    var total := 0
    for group in units:
        if int(group["team"]) == team and int(group["kind"]) != 3:
            total += int(group["soldiers"])
    return total

func _refresh() -> void:
    score.text = "A %d troops / %d HP  VS  B %d troops / %d HP" % [_total_soldiers(0), int(generals[0]["hp"]), _total_soldiers(1), int(generals[1]["hp"])]
    if active:
        details.text = "Time: %ds / 99s | Generals decide victory\nSoldiers can damage generals | A losses: %d B losses: %d" % [int(battle_elapsed), 1000 - _total_soldiers(0), 1000 - _total_soldiers(1)]
    field.queue_redraw()

func _draw_field() -> void:
    if not battle.visible:
        return
    var w: float = field.size.x
    var h: float = field.size.y
    var scale_x: float = w / FIELD_W
    field.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color("#193c30"))
    for lane in range(4):
        var y: float = 75.0 + float(lane) * 75.0
        field.draw_line(Vector2(0.0, y), Vector2(w, y), Color("#315746"), 1.0)
    for s in soldiers_visual:
        if float(s["hp"]) <= 0.0:
            continue
        var x: float = float(s["x"]) * scale_x
        var y: float = float(s["y"])
        var kind: int = int(s["kind"])
        var team: int = int(s["team"])
        var color: Color = Color.WHITE if float(s["attack_flash"]) > 0.0 else COLORS[team]
        field.draw_rect(Rect2(x - 3.0, y - 4.0, 6.0, 9.0), color)
        field.draw_circle(Vector2(x, y - 6.0), 2.5, Color("#f1d6ae"))
        if kind == 1:
            field.draw_line(Vector2(x + 4.0, y - 10.0), Vector2(x + 4.0, y + 5.0), Color("#e8c36d"), 1.0)
        elif kind == 2:
            field.draw_line(Vector2(x - 4.0, y - 7.0), Vector2(x + 4.0, y + 4.0), Color("#e9f4ff"), 1.0)
    # Generals are shown separately; their individual combat is a later milestone.
    for general in generals:
        if float(general["hp"]) <= 0.0:
            continue
        var team: int = int(general["team"])
        var general_x: float = float(general["x"]) * scale_x
        var general_y: float = float(general["y"])
        field.draw_rect(Rect2(general_x - 9.0, general_y - 15.0, 18.0, 23.0), COLORS[team])
        field.draw_circle(Vector2(general_x, general_y - 19.0), 7.0, Color("#e8c36d"))
