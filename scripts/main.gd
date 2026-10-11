extends Control

# MCX GAMES V0.0.3: generals, infantry, spears, archers.
# Visual and balance values are placeholders for Android prototype testing.
const MAX_HP := 100
const FIELD_W := 620.0
const SPEED := 65.0
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
    home.add_child(_label("PLAY · CREATE · KEEP THE DREAM\nGodot Android battle V0.0.3", 24))
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
    field.custom_minimum_size = Vector2(620, 310)
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
    # Each side has one general and 3 distinct troop groups.
    for team in range(2):
        var base_x: float = 90.0 if team == 0 else 530.0
        for kind in range(4):
            var hp: int = 160 if kind == 3 else MAX_HP
            units.append({
                "team": team, "kind": kind, "hp": hp, "max_hp": hp,
                "x": base_x + (-35.0 if team == 0 else 35.0) * float(kind % 2),
                "lane": kind, "cooldown": 0.0
            })
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
                enemy["hp"] = maxi(0, int(enemy["hp"]) - damage)
                unit["cooldown"] = ATTACK_TIME * (1.3 if kind == 2 else 1.0)
                units[target_index] = enemy
        units[i] = unit
    _refresh()
    var a_alive := _alive_count(0)
    var b_alive := _alive_count(1)
    if a_alive == 0 or b_alive == 0:
        active = false
        status.text = "DRAW!" if a_alive == b_alive else ("ARMY A WINS!" if a_alive > 0 else "ARMY B WINS!")
        details.text = "Battle finished. Tap RESTART to fight again."

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

func _total_hp(team: int) -> int:
    var n := 0
    for u in units:
        if int(u["team"]) == team:
            n += int(u["hp"])
    return n

func _refresh() -> void:
    score.text = "ARMY A  %d HP     VS     ARMY B  %d HP" % [_total_hp(0), _total_hp(1)]
    if active:
        details.text = "Infantry · Spears · Archers · General\nA: %d alive    B: %d alive" % [_alive_count(0), _alive_count(1)]
    field.queue_redraw()

func _draw_field() -> void:
    if not battle.visible:
        return
    var w: float = field.size.x
    var h: float = field.size.y
    var scale_x: float = w / FIELD_W
    field.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color("#193c30"))
    for lane in range(4):
        var y: float = 65.0 + float(lane) * 58.0
        field.draw_line(Vector2(0, y), Vector2(w, y), Color("#315746"), 1.0)
    for u in units:
        if int(u["hp"]) <= 0:
            continue
        var x: float = float(u["x"]) * scale_x
        var y: float = 65.0 + float(u["lane"]) * 58.0
        var kind: int = int(u["kind"])
        var team: int = int(u["team"])
        var color: Color = COLORS[team]
        var size: float = 25.0 if kind == 3 else 19.0
        field.draw_rect(Rect2(x - size / 2.0, y - size / 2.0, size, size), color)
        if kind == 3:
            field.draw_circle(Vector2(x, y - 17.0), 10.0, Color("#e8c36d"))
        elif kind == 2:
            field.draw_line(Vector2(x - 9.0, y - 12.0), Vector2(x + 10.0, y + 12.0), Color.WHITE, 2.0)
        elif kind == 1:
            field.draw_line(Vector2(x, y - 21.0), Vector2(x, y + 5.0), Color("#e8c36d"), 3.0)
        var ratio: float = float(u["hp"]) / float(u["max_hp"])
        field.draw_rect(Rect2(x - 15.0, y + 17.0, 30.0, 4.0), Color("#3a2424"))
        field.draw_rect(Rect2(x - 15.0, y + 17.0, 30.0 * ratio, 4.0), Color("#8cdd81"))
