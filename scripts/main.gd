extends Control

var title_label: Label
var info_label: Label
var start_button: Button
var back_button: Button

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
    column.custom_minimum_size = Vector2(580, 0)
    column.add_theme_constant_override("separation", 36)
    center.add_child(column)

    title_label = Label.new()
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 48)
    title_label.add_theme_color_override("font_color", Color("#e8c36d"))
    column.add_child(title_label)

    info_label = Label.new()
    info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info_label.add_theme_font_size_override("font_size", 26)
    info_label.add_theme_color_override("font_color", Color.WHITE)
    column.add_child(info_label)

    start_button = Button.new()
    start_button.text = "START TEST"
    start_button.custom_minimum_size = Vector2(0, 96)
    start_button.pressed.connect(_show_battle)
    column.add_child(start_button)

    back_button = Button.new()
    back_button.text = "BACK"
    back_button.custom_minimum_size = Vector2(0, 96)
    back_button.pressed.connect(_show_home)
    column.add_child(back_button)

func _show_home() -> void:
    title_label.text = "MCX GAMES"
    info_label.text = "PLAY · CREATE · KEEP THE DREAM\nGodot Android pipeline V0.0.1"
    start_button.visible = true
    back_button.visible = false

func _show_battle() -> void:
    title_label.text = "BATTLE TEST"
    info_label.text = "ARMY A  1000     VS     ARMY B  1000\nPrototype only — no combat logic yet"
    start_button.visible = false
    back_button.visible = true
