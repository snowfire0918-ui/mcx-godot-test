extends Control

# MCX GAMES V0.0.7: 100 individually fighting soldiers per army.
# Visual and balance values are placeholders for Android prototype testing.
const MAX_HP := 100
const FIELD_W := 920.0
const SPEED := 90.0
const MAX_VISIBLE_PER_ARMY := 100
const SOLDIER_REACH := 15.0
const SOLDIER_SPEED := 58.0
const SOLDIER_ATTACK_INTERVAL := 0.75
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
    home.add_child(_label("PLAY · CREATE · KEEP THE DREAM\nGodot Android battle V0.0.7", 24))
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
    # One army has exactly 100 visual soldiers representing 1000 troops.
    # The three groups are 30 infantry, 30 spears and 40 archers.
    for team in range(2):
        var base_x: float = 125.0 if team == 0 else 795.0
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
    var living: Array[Array] = [[], []]
    for i in range(soldiers_visual.size()):
        if float(soldiers_visual[i]["hp"]) > 0.0:
            living[int(soldiers_visual[i]["team"])].append(i)
    if living[0].is_empty() or living[1].is_empty():
        active = false
        status.text = "ARMY A WINS!" if not living[0].is_empty() else ("ARMY B WINS!" if not living[1].is_empty() else "DRAW!")
        _recount_armies()
        details.text = "A survivors: %d  |  B survivors: %d\nTap RESTART to fight again." % [_total_soldiers(0), _total_soldiers(1)]
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
            if nearest < 0:
                continue
            var target: Dictionary = soldiers_visual[nearest]
            var kind: int = int(s["kind"])
            var reach: float = 125.0 if kind == 2 else SOLDIER_REACH
            var dist: float = sqrt(best)
            s["cooldown"] = maxf(0.0, float(s["cooldown"]) - dt)
            s["attack_flash"] = maxf(0.0, float(s["attack_flash"]) - dt)
            if dist > reach:
                var move_dir: Vector2 = Vector2(float(target["x"]) - sx, float(target["y"]) - sy).normalized()
                var speed: float = SOLDIER_SPEED * (0.7 if kind == 2 else 1.0)
                s["x"] = clampf(sx + move_dir.x * speed * dt, 8.0, FIELD_W - 8.0)
                s["y"] = clampf(sy + move_dir.y * speed * dt, 15.0, FIELD_DISPLAY_H - 20.0)
            elif float(s["cooldown"]) <= 0.0:
                var damage: float = 1.0
                var enemy_kind: int = int(target["kind"])
                if (kind == 0 and enemy_kind == 2) or (kind == 2 and enemy_kind == 1) or (kind == 1 and enemy_kind == 0):
                    damage = 1.5
                target["hp"] = maxf(0.0, float(target["hp"]) - damage)
                soldiers_visual[nearest] = target
                s["cooldown"] = SOLDIER_ATTACK_INTERVAL * (1.3 if kind == 2 else 1.0)
                s["attack_flash"] = 0.15
            soldiers_visual[index] = s
    _recount_armies()
    _refresh()

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
    score.text = "A %d / 1000 troops   VS   B %d / 1000" % [_total_soldiers(0), _total_soldiers(1)]
    if active:
        details.text = "100 independent soldiers per army\nInfantry > Archers > Spears > Infantry\nA losses: %d   B losses: %d" % [1000 - _total_soldiers(0), 1000 - _total_soldiers(1)]
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
    for team in range(2):
        var general_x: float = (95.0 if team == 0 else 825.0) * scale_x
        var general_y := 318.0
        field.draw_rect(Rect2(general_x - 9.0, general_y - 15.0, 18.0, 23.0), COLORS[team])
        field.draw_circle(Vector2(general_x, general_y - 19.0), 7.0, Color("#e8c36d"))
