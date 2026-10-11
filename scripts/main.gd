extends Control

# MCX GAMES - Android battle prototype V0.0.2
# Deterministic, frame-rate independent demonstration (not final combat rules).
const START_TROOPS := 1000
const UNIT_SPEED := 135.0
const ATTACK_RANGE := 112.0
const ATTACK_INTERVAL := 0.6
const DAMAGE_PER_ATTACK := 55

var home_panel: VBoxContainer
var battle_panel: VBoxContainer
var battle_field: Control
var battle_status: Label
var troops_a: Label
var troops_b: Label
var message_label: Label
var a_count := START_TROOPS
var b_count := START_TROOPS
var a_x := 80.0
var b_x := 560.0
var attack_clock := 0.0
var fighting := false
var finished := false

func _ready() -> void:
    _build_ui()
    _show_home()

func _build_ui() -> void:
    var background := ColorRect.new()
    background.color = Color("#102b25")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var column := VBoxContainer.new()
    column.custom_minimum_size = Vector2(620, 0)
    column.add_theme_constant_override("separation", 26)
    center.add_child(column)

    var brand := Label.new()
    brand.text = "MCX GAMES"
    brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    brand.add_theme_font_size_override("font_size", 46)
    brand.add_theme_color_override("font_color", Color("#e8c36d"))
    column.add_child(brand)

    home_panel = VBoxContainer.new()
    home_panel.add_theme_constant_override("separation", 25)
    column.add_child(home_panel)
    var home_info := _make_label("PLAY · CREATE · KEEP THE DREAM\nGodot Android pipeline V0.0.2", 24)
    home_panel.add_child(home_info)
    var start_button := _make_button("START BATTLE TEST")
    start_button.pressed.connect(_show_battle)
    home_panel.add_child(start_button)

    battle_panel = VBoxContainer.new()
    battle_panel.add_theme_constant_override("separation", 20)
    column.add_child(battle_panel)
    battle_status = _make_label("BATTLE TEST", 32)
    battle_status.add_theme_color_override("font_color", Color("#e8c36d"))
    battle_panel.add_child(battle_status)
    var scoreboard := HBoxContainer.new()
    scoreboard.alignment = BoxContainer.ALIGNMENT_CENTER
    battle_panel.add_child(scoreboard)
    troops_a = _make_label("A 1000", 24)
    troops_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scoreboard.add_child(troops_a)
    troops_b = _make_label("B 1000", 24)
    troops_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scoreboard.add_child(troops_b)

    battle_field = Control.new()
    battle_field.custom_minimum_size = Vector2(620, 270)
    battle_field.draw.connect(_draw_battle)
    battle_panel.add_child(battle_field)
    message_label = _make_label("Tap START to begin", 22)
    battle_panel.add_child(message_label)

    var controls := HBoxContainer.new()
    controls.add_theme_constant_override("separation", 12)
    battle_panel.add_child(controls)
    var fight_button := _make_button("START / RESTART")
    fight_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fight_button.pressed.connect(_restart_battle)
    controls.add_child(fight_button)
    var back_button := _make_button("BACK")
    back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back_button.pressed.connect(_show_home)
    controls.add_child(back_button)
    battle_panel.visible = false

func _make_label(value: String, size: int) -> Label:
    var label := Label.new()
    label.text = value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", Color.WHITE)
    return label

func _make_button(value: String) -> Button:
    var button := Button.new()
    button.text = value
    button.custom_minimum_size = Vector2(0, 90)
    return button

func _show_home() -> void:
    fighting = false
    home_panel.visible = true
    battle_panel.visible = false

func _show_battle() -> void:
    home_panel.visible = false
    battle_panel.visible = true
    _restart_battle()

func _restart_battle() -> void:
    a_count = START_TROOPS
    b_count = START_TROOPS
    a_x = 80.0
    b_x = 540.0
    attack_clock = 0.0
    fighting = true
    finished = false
    battle_status.text = "BATTLE TEST"
    message_label.text = "Armies advancing..."
    _update_display()

func _process(delta: float) -> void:
    if not fighting:
        return
    if b_x - a_x > ATTACK_RANGE:
        var move_amount: float = minf(UNIT_SPEED * delta, (b_x - a_x - ATTACK_RANGE) / 2.0)
        a_x += move_amount
        b_x -= move_amount
    else:
        attack_clock += delta
        while attack_clock >= ATTACK_INTERVAL and fighting:
            attack_clock -= ATTACK_INTERVAL
            # Both sides strike in the same round, so ties are possible.
            a_count = maxi(0, a_count - DAMAGE_PER_ATTACK)
            b_count = maxi(0, b_count - DAMAGE_PER_ATTACK)
            if a_count == 0 or b_count == 0:
                fighting = false
                finished = true
                battle_status.text = "BATTLE COMPLETE"
                if a_count == b_count:
                    message_label.text = "DRAW - both armies defeated!"
                elif a_count > b_count:
                    message_label.text = "ARMY A WINS!"
                else:
                    message_label.text = "ARMY B WINS!"
    _update_display()

func _update_display() -> void:
    troops_a.text = "ARMY A  %d" % a_count
    troops_b.text = "ARMY B  %d" % b_count
    battle_field.queue_redraw()

func _draw_battle() -> void:
    if not battle_panel.visible:
        return
    var w: float = battle_field.size.x
    var h: float = battle_field.size.y
    var factor: float = w / 620.0
    battle_field.draw_rect(Rect2(0, 0, w, h), Color("#183d31"))
    battle_field.draw_line(Vector2(0, h * 0.75), Vector2(w, h * 0.75), Color("#a58b52"), 4.0)
    _draw_army(Vector2(a_x * factor, h * 0.64), Color("#5ea7e1"), a_count)
    _draw_army(Vector2(b_x * factor, h * 0.64), Color("#e46e68"), b_count)

func _draw_army(position: Vector2, color: Color, count: int) -> void:
    if count <= 0:
        return
    var visible_units: int = mini(6, ceili(float(count) / 170.0))
    for i in range(visible_units):
        var row: int = i / 3
        var col: int = i % 3
        var offset := Vector2((float(col) - 1.0) * 18.0, float(row) * 24.0)
        battle_field.draw_rect(Rect2(position + offset - Vector2(8, 20), Vector2(16, 20)), color)
        battle_field.draw_circle(position + offset - Vector2(0, 24), 7.0, Color("#f0d4a3"))
