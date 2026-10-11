extends Control

# MCX GAMES V0.0.6: wider battlefield, independently moving visible soldiers.
# Visual and balance values are placeholders for Android prototype testing.
const MAX_HP := 100
const FIELD_W := 920.0
const SPEED := 90.0
const MAX_VISIBLE_PER_GROUP := 12
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
    home.add_child(_label("PLAY · CREATE · KEEP THE DREAM\nGodot Android battle V0.0.6", 24))
    var start := _button("START BATTLE TEST")
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

func _show_battle() -> void:
    home.visible = false
    battle.visible = true
    _restart()

func _restart() -> void:
    units.clear()
    soldiers_visual.clear()
    # Each side has one general and 3 distinct troop groups.
    for team in range(2):
        var base_x: float = 125.0 if team == 0 else 795.0
        for kind in range(4):
            var hp: int = 160 if kind == 3 else MAX_HP
            var soldiers: int = 0 if kind == 3 else (400 if kind == 2 else 300)
            units.append({
                "team": team, "kind": kind, "hp": hp, "max_hp": hp,
                "soldiers": soldiers, "starting_soldiers": soldiers,
                "x": base_x + (-35.0 if team == 0 else 35.0) * float(kind % 2),
                "lane": kind, "cooldown": 0.0
            })
            if kind != 3:
                var group_id: int = units.size() - 1
                for s in range(MAX_VISIBLE_PER_GROUP):
                    soldiers_visual.append({"group": group_id, "x": base_x + (-30.0 if team == 0 else 30.0) * float(kind % 2) + float(s % 4) * (13.0 if team == 0 else -13.0), "y": 70.0 + float(kind) * 75.0 + float(s / 4) * 13.0 - 13.0, "seed": float(s) * 0.9})
    active = true
    tick = 0.0
    status.text = "BATTLE TEST"
    _refresh()

func _process(delta: float) -> void:
    if not active:
        return
    var dt: float = minf(delta, 0.1)
    tick += dt
    for i in range(units.size()):
        var unit: Dictionary = units[i]
        if int(unit["hp"]) <= 0:
            continue
        var target_index: int = _nearest_enemy(i)
        if target_index < 0:
            continue
        var enemy: Dictionary = units[target_index]
        var distance: float = absf(float(enemy["x"]) - float(unit["x"]))
        var kind: int = int(unit["kind"])
        var reach: float = 205.0 if kind == 2 else (55.0 if kind == 3 else 38.0)
        if distance > reach:
            var direction: float = signf(float(enemy["x"]) - float(unit["x"]))
            var pace: float = 0.65 if kind == 2 else (1.1 if kind == 3 else 1.0)
            unit["x"] = clampf(float(unit["x"]) + direction * SPEED * pace * dt, 15.0, FIELD_W - 15.0)
        else:
            unit["cooldown"] = float(unit["cooldown"]) - dt
            if float(unit["cooldown"]) <= 0.0:
                var damage: int = 19 if kind == 3 else (16 if kind == 1 else (12 if kind == 2 else 14))
                var enemy_kind: int = int(enemy["kind"])
                # Infantry > archers > spears > infantry; generals are neutral.
                if (kind == 0 and enemy_kind == 2) or (kind == 2 and enemy_kind == 1) or (kind == 1 and enemy_kind == 0):
                    damage = int(round(float(damage) * 1.5))
                var previous_hp: int = int(enemy["hp"])
                enemy["hp"] = maxi(0, previous_hp - damage)
                if enemy_kind != 3:
                    var lost: int = mini(int(enemy["soldiers"]), maxi(1, int(ceil(float(damage) * 0.55))))
                    enemy["soldiers"] = maxi(0, int(enemy["soldiers"]) - lost)
                    if int(enemy["soldiers"]) == 0:
                        enemy["hp"] = 0
                unit["cooldown"] = ATTACK_TIME * (1.3 if kind == 2 else 1.0)
                units[target_index] = enemy
        units[i] = unit
    _move_visible_soldiers(dt)
    _refresh()
    var a_alive := _alive_count(0)
    var b_alive := _alive_count(1)
    if a_alive == 0 or b_alive == 0:
        active = false
        status.text = "DRAW!" if a_alive == b_alive else ("ARMY A WINS!" if a_alive > 0 else "ARMY B WINS!")
        details.text = "A survivors: %d  |  B survivors: %d\nTap RESTART to fight again." % [_total_soldiers(0), _total_soldiers(1)]

func _move_visible_soldiers(dt: float) -> void:
    # Visible soldiers move separately; casualties and damage remain group-simulated.
    for i in range(soldiers_visual.size()):
        var soldier: Dictionary = soldiers_visual[i]
        var group: Dictionary = units[int(soldier["group"])]
        if int(group["hp"]) <= 0:
            continue
        var team: int = int(group["team"])
        var kind: int = int(group["kind"])
        var target: float = float(group["x"]) + (float(i % 4) - 1.5) * 15.0
        var target_y: float = 75.0 + float(kind) * 75.0 + (float(i % 3) - 1.0) * 13.0
        if kind == 2:
            target -= 35.0 if team == 0 else -35.0
        var drift: float = sin(tick * 2.2 + float(soldier["seed"])) * 3.0
        soldier["x"] = move_toward(float(soldier["x"]), target + drift, (SPEED * 0.85 + float(i % 5) * 5.0) * dt)
        soldier["y"] = move_toward(float(soldier["y"]), target_y, 35.0 * dt)
        soldiers_visual[i] = soldier

func _nearest_enemy(index: int) -> int:
    var own: Dictionary = units[index]
    var closest := -1
    var best := INF
    for j in range(units.size()):
        var other: Dictionary = units[j]
        if int(other["team"]) == int(own["team"]) or int(other["hp"]) <= 0:
            continue
        var d: float = absf(float(other["x"]) - float(own["x"]))
        if d < best:
            best = d
            closest = j
    return closest

func _alive_count(team: int) -> int:
    var n := 0
    for u in units:
        if int(u["team"]) == team and int(u["hp"]) > 0:
            n += 1
    return n

func _total_soldiers(team: int) -> int:
    var n := 0
    for u in units:
        if int(u["team"]) == team and int(u["hp"]) > 0:
            n += int(u["soldiers"])
    return n

func _total_hp(team: int) -> int:
    var n := 0
    for u in units:
        if int(u["team"]) == team:
            n += int(u["hp"])
    return n

func _refresh() -> void:
    score.text = "A %d / 1000 troops   VS   B %d / 1000" % [_total_soldiers(0), _total_soldiers(1)]
    if active:
        details.text = "Infantry > Archers > Spears > Infantry\nA losses: %d   B losses: %d" % [1000 - _total_soldiers(0), 1000 - _total_soldiers(1)]
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
        field.draw_line(Vector2(0, y), Vector2(w, y), Color("#315746"), 1.0)
    # Independent visual actors (simulation remains group-based for this prototype).
    for s in soldiers_visual:
        var u: Dictionary = units[int(s["group"])]
        if int(u["hp"]) <= 0:
            continue
        var starting: int = int(u["starting_soldiers"])
        var current: int = int(u["soldiers"])
        var allowed: int = mini(MAX_VISIBLE_PER_GROUP, int(ceil(float(current) * MAX_VISIBLE_PER_GROUP / float(starting))))
        # Soldiers are appended only for non-general groups: use stable per-group index.
        var group_slot: int = int(soldiers_visual.find(s))
        var same_group_index: int = 0
        for earlier in range(group_slot):
            if int(soldiers_visual[earlier]["group"]) == int(s["group"]):
                same_group_index += 1
        if same_group_index >= allowed:
            continue
        var team: int = int(u["team"])
        var kind: int = int(u["kind"])
        var px: float = float(s["x"]) * scale_x
        var py: float = float(s["y"])
        var color: Color = COLORS[team]
        field.draw_rect(Rect2(px - 4.0, py - 5.0, 8.0, 10.0), color)
        field.draw_circle(Vector2(px, py - 8.0), 3.0, Color("#f1d6ae"))
        if kind == 1:
            field.draw_line(Vector2(px + 5.0, py - 12.0), Vector2(px + 5.0, py + 4.0), Color("#e8c36d"), 1.5)
        elif kind == 2:
            field.draw_line(Vector2(px - 5.0, py - 9.0), Vector2(px + 5.0, py + 3.0), Color("#e9f4ff"), 1.5)
    for u in units:
        if int(u["hp"]) <= 0:
            continue
        var x: float = float(u["x"]) * scale_x
        var kind: int = int(u["kind"])
        var y: float = 75.0 + float(kind) * 75.0
        if kind == 3:
            var color: Color = COLORS[int(u["team"])]
            field.draw_rect(Rect2(x - 12.0, y - 15.0, 24.0, 29.0), color)
            field.draw_circle(Vector2(x, y - 20.0), 10.0, Color("#e8c36d"))
        var ratio: float = float(u["hp"]) / float(u["max_hp"])
        field.draw_rect(Rect2(x - 20.0, y + 27.0, 40.0, 4.0), Color("#3a2424"))
        field.draw_rect(Rect2(x - 20.0, y + 27.0, 40.0 * ratio, 4.0), Color("#8cdd81"))
