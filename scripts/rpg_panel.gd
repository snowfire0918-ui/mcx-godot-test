extends VBoxContainer

signal state_changed
signal return_requested
const Rules = preload("res://scripts/rpg_rules.gd")

var campaign
var inventory: Dictionary = {}
var side_picker: OptionButton
var squad_picker: OptionButton
var general_picker: OptionButton
var support_picker: OptionButton
var support_button: Button
var item_buttons: Dictionary = {}
var info: Label
var message: Label
var back_button: Button

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 12)
    add_child(_label("武將／道具／軍師技測試", 25))
    side_picker = _picker()
    side_picker.add_item("我軍武將")
    side_picker.add_item("敵軍武將（僅軍師技測試）")
    side_picker.item_selected.connect(_side_changed)
    squad_picker = _picker()
    squad_picker.item_selected.connect(_squad_changed)
    general_picker = _picker()
    general_picker.item_selected.connect(_general_changed)
    info = _label("", 20)
    add_child(info)
    add_child(_label("軍師技效果測試：指定目前武將。\n正式作用範圍、耗費及配備限制待核定。", 18))
    support_picker = _picker()
    support_picker.add_item(Rules.support_label("none", 0))
    for kind in ["regeneration", "entry_heal"]:
        for level in [1, 2, 3]:
            support_picker.add_item(Rules.support_label(kind, level))
    support_button = _button("套用測試軍師技")
    support_button.pressed.connect(apply_support)
    add_child(support_button)
    add_child(_label("道具測試值：屬性+5、上限／靈藥+30、忠誠+10。\n增加上限不補當前值；陣亡者不復活。", 18))
    for key in Rules.catalog():
        var button := _button("")
        button.pressed.connect(use_item.bind(key))
        item_buttons[key] = button
        add_child(button)
    message = _label("", 18)
    add_child(message)
    back_button = _button("返回首頁")
    back_button.pressed.connect(func(): return_requested.emit())
    add_child(back_button)

func _label(text: String, font_size: int) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", font_size)
    return label

func _picker() -> OptionButton:
    var picker := OptionButton.new()
    picker.custom_minimum_size.y = 64
    picker.fit_to_longest_item = false
    picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    picker.get_popup().theme = theme
    add_child(picker)
    return picker

func _button(text: String) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size.y = 64
    return button

func bind(model, stock: Dictionary) -> void:
    campaign = model
    inventory = stock
    _side_changed(maxi(0, side_picker.selected))

func _side_changed(side: int) -> void:
    if campaign == null:
        return
    var preferred := maxi(0, squad_picker.selected)
    squad_picker.clear()
    for squad in campaign.armies[side]:
        squad_picker.add_item("%s · %d兵" % [squad["name"], campaign.troops(squad)])
    squad_picker.select(mini(preferred, squad_picker.item_count - 1))
    _squad_changed(squad_picker.selected)

func _squad_changed(index: int) -> void:
    var preferred := maxi(0, general_picker.selected)
    general_picker.clear()
    if index >= 0:
        for g in campaign.armies[side_picker.selected][index]["generals"]:
            general_picker.add_item(g["name"] + ("（陣亡）" if float(g["hp"]) <= 0.0 else ""))
    general_picker.select(mini(preferred, general_picker.item_count - 1))
    _general_changed(general_picker.selected)

func _general_changed(_index: int) -> void:
    message.text = ""
    refresh()

func target() -> Dictionary:
    if campaign == null or side_picker.selected < 0 or squad_picker.selected < 0 or general_picker.selected < 0:
        return {}
    var army: Array = campaign.armies[side_picker.selected]
    if squad_picker.selected >= army.size():
        return {}
    var gs: Array = army[squad_picker.selected]["generals"]
    return gs[general_picker.selected] if general_picker.selected < gs.size() else {}

func refresh() -> void:
    var g := target()
    var fighting: bool = campaign != null and campaign.phase == "fighting"
    if g.is_empty():
        info.text = "請選擇武將。"
    else:
        info.text = "%s · 等級%d／經驗%d（成長公式待核定）\n武力 %d／255　智力 %d／255　忠誠 %d／100\n生命 %.1f／%.0f　技力 %.0f／%.0f" % [g["name"], g.get("level", 1), g.get("experience", 0), g["might"], g["intellect"], g["loyalty"], g["hp"], g["max_hp"], g["mp"], g["max_mp"]]
        var choice: Dictionary = campaign.support_choices.get(g["id"], {})
        var index := int(choice.get("level", 0))
        if choice.get("kind") == "entry_heal":
            index += 3
        support_picker.select(index)
    support_picker.disabled = fighting or g.is_empty()
    support_button.disabled = fighting or g.is_empty()
    var catalog: Dictionary = Rules.catalog()
    for key in item_buttons:
        item_buttons[key].text = "%s ×%d" % [catalog[key]["name"], inventory.get(key, 0)]
        item_buttons[key].disabled = fighting or side_picker.selected != 0 or g.is_empty() or float(g.get("hp", 0)) <= 0.0 or int(inventory.get(key, 0)) <= 0
    if fighting:
        message.text = "當場交戰含暫停期間，道具與軍師技配置均鎖定。"

func use_item(key: String) -> bool:
    if campaign == null or campaign.phase == "fighting" or side_picker.selected != 0:
        return false
    if not Rules.use_item(target(), inventory, key):
        message.text = "目前無法生效，未消耗道具。"
        return false
    refresh()
    message.text = "道具已生效，扣除1件。"
    state_changed.emit()
    return true

func apply_support() -> bool:
    var g := target()
    if campaign == null or campaign.phase == "fighting" or g.is_empty():
        return false
    var index := support_picker.selected
    var kind := "none" if index == 0 else ("regeneration" if index <= 3 else "entry_heal")
    var level := index if index <= 3 else index - 3
    if not campaign.set_support(g["id"], kind, level):
        return false
    refresh()
    message.text = "測試配置已更新，下次進場才生效。"
    state_changed.emit()
    return true
