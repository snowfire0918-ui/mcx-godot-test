extends Control

# V0.0.12 exposes prebattle setup and improves original battlefield presentation.
# Damage / rosters / skill assignment remain explicitly marked prototype fixtures.
const Campaign = preload("res://scripts/battle_campaign.gd")
const PrototypeRoster = preload("res://scripts/prototype_roster.gd")
const Rules = preload("res://scripts/rpg_rules.gd")
const Store = preload("res://scripts/campaign_store.gd")
const RpgPanel = preload("res://scripts/rpg_panel.gd")
const BattleArt = preload("res://scripts/battle_art.gd")
const ROUND_SECONDS := 99.0
const GENERAL_ATTACK_INTERVAL := 0.65
const FIELD_W := 920.0
const MAX_VISIBLE_PER_ARMY := 100
const SOLDIER_REACH := 15.0
const SOLDIER_SPEED := 58.0
const SOLDIER_ATTACK_INTERVAL := 0.75
const GENERAL_SPEED := 44.0
const GENERAL_REACH := 22.0
const GENERAL_DAMAGE := 2.0
const FIELD_DISPLAY_H := 350.0
const COLORS := [Color("#5ba6e6"), Color("#e46d67")]

var campaign = Campaign.new()
var campaign_started := false
var home: VBoxContainer
var selection: VBoxContainer
var battle: VBoxContainer
var layout: VBoxContainer
var scroll: ScrollContainer
var field: Control
var status: Label
var score: Label
var details: Label
var general_info: Label
var selection_info: Label
var squad_pickers: Array[OptionButton] = []
var squad_details: Array[Label] = []
var deploy_button: Button
var next_round_button: Button
var resume_button: Button
var manage_button: Button
var prebattle_button: Button
var prepare_after_create := false
var rpg_return_squads: Array = []
var rpg_panel: VBoxContainer
var save_notice: Label
var save_path := "user://campaign-v1.json"
var store
var saved_file_present := false
var next_checkpoint := 5.0
var reset_dialog: ConfirmationDialog
var exit_dialog: ConfirmationDialog
var attacker_count: SpinBox
var defender_count: SpinBox
var general_count: SpinBox
var ui_font: Font
var units: Array[Dictionary] = []
var active := false
var starting_troops := [0, 0]
var soldiers_visual: Array[Dictionary] = []
var battle_elapsed := 0.0
var generals: Array[Dictionary] = []
var inventory := Rules.inventory()

func _ready() -> void:
    get_tree().quit_on_go_back = false
    store = Store.new(save_path)
    _make_ui()
    _restore_campaign()
    _show_home(false)

func _notification(what: int) -> void:
    if not is_node_ready():
        return
    if what == NOTIFICATION_APPLICATION_PAUSED and campaign_started:
        _show_home()
    elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if reset_dialog.visible:
            reset_dialog.hide()
        elif exit_dialog.visible:
            exit_dialog.hide()
        elif rpg_panel.visible:
            _return_from_rpg()
        elif not home.visible:
            _show_home()
        else:
            exit_dialog.dialog_text = "將保存本機戰役，下次可繼續。確定退出？" if campaign_started else "確定退出遊戲？"
            exit_dialog.popup_centered(Vector2i(mini(560, int(size.x) - 24), 220))

func _make_ui() -> void:
    ui_font = _chinese_font()
    theme = Theme.new()
    theme.default_font = ui_font
    theme.default_font_size = 22
    var bg := ColorRect.new()
    bg.color = Color("#102b25")
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for edge in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + edge, 20)
    add_child(margin)
    scroll = ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_child(scroll)
    layout = VBoxContainer.new()
    layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    layout.add_theme_constant_override("separation", 16)
    scroll.add_child(layout)
    var brand := _label("MCX GAMES", 34)
    brand.add_theme_color_override("font_color", Color("#e8c36d"))
    layout.add_child(brand)
    layout.add_child(_label("三國：我的三國我做主\n第一代豪華重製版 · 測試 V0.0.12", 22))
    save_notice = _label("", 16)
    layout.add_child(save_notice)
    home = _column(layout)
    home.add_child(_label("戰役設定（原型參數）", 26))
    attacker_count = _count_input(home, "我軍進攻隊伍", 1, 5, 3)
    defender_count = _count_input(home, "敵軍防守隊伍", 1, 10, 3)
    general_count = _count_input(home, "每隊武將人數", 1, 3, 3)
    home.add_child(_label("每隊1主將、0～2副將；每場各選1隊。\n99秒撤回保留生命與兵力。休整一場+10生命，陣亡者不復活。", 19))
    var start := _button("建立新測試戰役")
    start.pressed.connect(_request_new_campaign)
    home.add_child(start)
    resume_button = _button("繼續戰役")
    resume_button.pressed.connect(_resume_campaign)
    home.add_child(resume_button)
    manage_button = _button("武將／道具／軍師技測試")
    manage_button.pressed.connect(_open_home_setup)
    home.add_child(manage_button)
    home.add_child(_label("戰役自動保存在本機；重新開啟可繼續。\n交戰每5秒保存，返回首頁時也會保存。", 18))
    reset_dialog = ConfirmationDialog.new()
    reset_dialog.theme = theme
    reset_dialog.dialog_autowrap = true
    reset_dialog.title = "建立新測試戰役"
    reset_dialog.dialog_text = "將重建並覆寫本機戰役、傷勢、兵力與測試道具。確定重新建立？"
    reset_dialog.ok_button_text = "確定重建"
    reset_dialog.cancel_button_text = "保留戰役"
    reset_dialog.confirmed.connect(_new_campaign)
    add_child(reset_dialog)
    exit_dialog = ConfirmationDialog.new()
    exit_dialog.theme = theme
    exit_dialog.dialog_autowrap = true
    exit_dialog.title = "退出遊戲"
    exit_dialog.ok_button_text = "確定退出"
    exit_dialog.cancel_button_text = "繼續遊戲"
    exit_dialog.confirmed.connect(_confirm_quit)
    add_child(exit_dialog)
    selection = _column(layout)
    selection_info = _label("選隊出戰", 24)
    selection.add_child(selection_info)
    for side in range(2):
        selection.add_child(_label("我軍進攻隊伍" if side == 0 else "敵軍防守隊伍（測試選隊）", 22))
        var picker := OptionButton.new()
        picker.custom_minimum_size.y = 64
        picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        picker.fit_to_longest_item = false
        picker.get_popup().theme = theme
        picker.item_selected.connect(_selection_changed.bind(side))
        squad_pickers.append(picker)
        selection.add_child(picker)
        var info := _label("", 20)
        squad_details.append(info)
        selection.add_child(info)
    selection.add_child(_label("未出場的隊伍在本場結束後休整。\n勝隊可以再戰，也可換隊。", 18))
    prebattle_button = _button("戰前整備 · 軍師技／道具")
    prebattle_button.pressed.connect(_show_rpg.bind(true))
    selection.add_child(prebattle_button)
    deploy_button = _button("選定隊伍 · 出戰")
    deploy_button.pressed.connect(_start_selected_round)
    selection.add_child(deploy_button)
    var select_back := _button("返回首頁")
    select_back.pressed.connect(_show_home)
    selection.add_child(select_back)
    battle = _column(layout)
    status = _label("戰鬥測試", 26)
    status.add_theme_color_override("font_color", Color("#e8c36d"))
    battle.add_child(status)
    score = _label("", 22)
    battle.add_child(score)
    field = Control.new()
    field.custom_minimum_size = Vector2(0, FIELD_DISPLAY_H)
    field.draw.connect(_draw_field)
    battle.add_child(field)
    general_info = _label("", 18)
    battle.add_child(general_info)
    details = _label("", 20)
    battle.add_child(details)
    next_round_button = _button("重新選隊")
    next_round_button.pressed.connect(_show_selection)
    battle.add_child(next_round_button)
    var pause := _button("暫停／返回首頁")
    pause.pressed.connect(_show_home)
    battle.add_child(pause)
    rpg_panel = RpgPanel.new()
    rpg_panel.theme = theme
    rpg_panel.state_changed.connect(_save_campaign)
    rpg_panel.return_requested.connect(_return_from_rpg)
    layout.add_child(rpg_panel)

func _column(parent: Node) -> VBoxContainer:
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 12)
    parent.add_child(column)
    return column

func _count_input(parent: Node, caption: String, minimum: int, maximum: int, value: int) -> SpinBox:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    parent.add_child(row)
    var label := _label(caption + "（%d～%d）" % [minimum, maximum], 20)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    var count := SpinBox.new()
    count.min_value = minimum
    count.max_value = maximum
    count.step = 1
    count.value = value
    count.custom_minimum_size = Vector2(110, 56)
    row.add_child(count)
    return count

func _chinese_font() -> Font:
    var font := SystemFont.new()
    font.font_names = PackedStringArray(["Noto Sans CJK TC", "Noto Sans CJK SC", "Noto Sans", "sans-serif"])
    font.allow_system_fallback = true
    return font

func _label(value: String, font_size: int) -> Label:
    var label := Label.new()
    label.text = value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color.WHITE)
    return label

func _button(value: String) -> Button:
    var button := Button.new()
    button.text = value
    button.custom_minimum_size = Vector2(0, 64)
    return button

func _request_new_campaign(prepare: bool = false) -> void:
    prepare_after_create = prepare
    if campaign_started or saved_file_present:
        reset_dialog.popup_centered(Vector2i(mini(560, int(size.x) - 24), 220))
    else:
        _new_campaign()

func _new_campaign() -> void:
    var roster: Array = PrototypeRoster.build(int(attacker_count.value), int(defender_count.value), int(general_count.value))
    var error := campaign.configure(roster[0], roster[1])
    if not error.is_empty():
        save_notice.text = error
        return
    campaign_started = true
    active = false
    generals.clear()
    soldiers_visual.clear()
    units.clear()
    inventory = Rules.inventory()
    rpg_panel.side_picker.select(0)
    rpg_panel.squad_picker.select(-1)
    rpg_panel.general_picker.select(-1)
    rpg_panel.bind(campaign, inventory)
    _save_campaign(true)
    _show_selection()
    if prepare_after_create:
        prepare_after_create = false
        _show_rpg(true)

func _show_home(save: bool = true) -> void:
    active = false
    home.visible = true
    selection.visible = false
    battle.visible = false
    rpg_panel.visible = false
    rpg_return_squads.clear()
    resume_button.visible = campaign_started
    manage_button.visible = true
    manage_button.text = "武將／道具／軍師技測試" if campaign_started else "建立戰役並配置軍師技"
    if save:
        _save_campaign()
    scroll.scroll_vertical = 0

func _open_home_setup() -> void:
    if campaign_started:
        _show_rpg()
    else:
        _request_new_campaign(true)

func _show_rpg(from_selection: bool = false) -> void:
    if not campaign_started:
        return
    var pending: Array = [squad_pickers[0].selected, squad_pickers[1].selected] if from_selection else []
    _show_home()
    rpg_return_squads = pending
    home.visible = false
    if from_selection:
        rpg_panel.side_picker.select(0)
        rpg_panel.general_picker.select(0)
    rpg_panel.bind(campaign, inventory)
    if from_selection:
        # Rebuild the friendly roster before selecting: the previous view may
        # contain fewer enemy squads than the friendly index being requested.
        rpg_panel.squad_picker.select(maxi(0, int(pending[0])))
        rpg_panel.squad_picker.item_selected.emit(rpg_panel.squad_picker.selected)
    rpg_panel.back_button.text = "返回選隊" if from_selection else "返回首頁"
    rpg_panel.visible = true

func _return_from_rpg() -> void:
    if not rpg_return_squads.is_empty() and campaign.phase != "fighting":
        var pending := rpg_return_squads.duplicate()
        rpg_return_squads.clear()
        _show_selection(pending)
    else:
        _show_home()

func _save_campaign(replace_invalid: bool = false) -> bool:
    if not campaign_started:
        return true
    # Bound automatic retries even while storage remains unavailable.
    # Explicit pause, mutation and exit saves still run immediately.
    next_checkpoint = campaign.elapsed + 5.0
    var error: String = store.save(campaign, inventory, replace_invalid)
    if not error.is_empty():
        save_notice.text = "儲存失敗：" + error
        return false
    saved_file_present = true
    save_notice.text = "已保存本機戰役 · 第%d場" % campaign.round_number
    return true

func _restore_campaign() -> bool:
    var result: Dictionary = store.load_into(campaign, inventory)
    saved_file_present = result.found
    if not result.error.is_empty():
        save_notice.text = "讀取失敗：" + result.error
        return false
    if not result.found:
        save_notice.text = "尚無本機戰役存檔。"
        return false
    campaign_started = true
    active = false
    attacker_count.value = campaign.armies[0].size()
    defender_count.value = campaign.armies[1].size()
    general_count.value = campaign.armies[0][0]["generals"].size()
    rpg_panel.bind(campaign, inventory)
    _bind_round_actors(false)
    next_checkpoint = campaign.elapsed + 5.0
    if not generals.is_empty():
        if campaign.phase == "fighting":
            status.text = "第%d場 · 自動交戰" % campaign.round_number
            next_round_button.visible = false
            _refresh()
        else:
            _finish_round(false)
    save_notice.text = "已由備份恢復，請核對進度。" if result.recovered else "已讀取本機戰役，按繼續恢復。"
    return true

func _confirm_quit() -> void:
    if not _save_campaign():
        exit_dialog.dialog_text = save_notice.text + "\n請取消退出後重試。"
        exit_dialog.call_deferred("popup_centered", Vector2i(mini(560, int(size.x) - 24), 220))
        return
    get_tree().quit()

func _resume_campaign() -> void:
    if not campaign_started:
        return
    if campaign.phase == "selection":
        _show_selection()
    else:
        home.visible = false
        selection.visible = false
        rpg_panel.visible = false
        battle.visible = true
        active = campaign.phase == "fighting"
        scroll.scroll_vertical = 0
        field.queue_redraw()

func _show_selection(pending: Array = []) -> void:
    if not campaign_started or campaign.phase == "fighting":
        return
    active = false
    home.visible = false
    battle.visible = false
    selection.visible = true
    rpg_panel.visible = false
    var result := campaign.campaign_result()
    selection_info.text = "第%d場 · 選隊出戰" % (campaign.round_number + 1)
    if not result.is_empty():
        selection_info.text = "戰役結束 · " + _result_text(result)
    elif not campaign.last_result.is_empty():
        selection_info.text += "\n上一場：" + _result_text(campaign.last_result)
    for side in range(2):
        var picker := squad_pickers[side]
        var preferred: int = pending[side] if pending.size() == 2 else campaign.selected[side]
        picker.clear()
        for index in range(campaign.armies[side].size()):
            var squad: Dictionary = campaign.armies[side][index]
            var alive := campaign.squad_alive(squad)
            picker.add_item("%s · %d兵 · %s" % [squad["name"], campaign.troops(squad), "可出戰" if alive else "全將陣亡"])
            picker.set_item_disabled(index, not alive)
        if preferred < 0 or preferred >= picker.item_count or picker.is_item_disabled(preferred):
            preferred = -1
            for index in range(picker.item_count):
                if not picker.is_item_disabled(index):
                    preferred = index
                    break
        picker.select(preferred)
        _selection_changed(preferred, side)
    deploy_button.disabled = not result.is_empty()
    scroll.scroll_vertical = 0

func _selection_changed(index: int, side: int) -> void:
    if index < 0:
        squad_details[side].text = "沒有可出戰隊伍"
        return
    var squad: Dictionary = campaign.armies[side][index]
    var lines: Array[String] = []
    for slot in range(squad["generals"].size()):
        var g: Dictionary = squad["generals"][slot]
        lines.append("%s · 生命 %.1f／%.0f%s" % [g["name"], g["hp"], g["max_hp"], "（陣亡）" if float(g["hp"]) <= 0.0 else ""])
        var support: Dictionary = campaign.support_choices.get(g["id"], {})
        if not support.is_empty():
            lines.append("測試軍師技：" + Rules.support_label(support["kind"], int(support["level"])))
    squad_details[side].text = "\n".join(lines)

func _start_selected_round() -> void:
    if not campaign.begin_round(squad_pickers[0].selected, squad_pickers[1].selected):
        return
    _bind_round_actors(true)
    active = true
    battle_elapsed = 0.0
    home.visible = false
    selection.visible = false
    rpg_panel.visible = false
    battle.visible = true
    status.text = "第%d場 · 自動交戰" % campaign.round_number
    next_round_button.visible = false
    scroll.scroll_vertical = 0
    _recount_armies()
    _refresh()
    _save_campaign()

func _bind_round_actors(reset_positions: bool) -> void:
    units.clear()
    soldiers_visual.clear()
    generals.clear()
    if campaign.selected.has(-1):
        return
    for side in range(2):
        var squad: Dictionary = campaign.armies[side][campaign.selected[side]]
        starting_troops[side] = campaign.round_start_troops[side]
        var base_x: float = 240.0 if side == 0 else 680.0
        for slot in range(squad["generals"].size()):
            var g: Dictionary = squad["generals"][slot]
            g.merge({"team": side, "slot": slot}, true)
            if reset_positions or not (g.has("x") and g.has("y") and g.has("cooldown")):
                g.merge({"x": 74.0 if side == 0 else 846.0, "y": 88.0 + float(slot) * 99.0, "cooldown": 0.0}, true)
            generals.append(g)
        for kind in range(3):
            var group_id := units.size()
            units.append({"team": side, "kind": kind, "soldiers": 0, "hp": 0})
            var kind_count := 0
            for soldier in squad["soldiers"]:
                if int(soldier["kind"]) == kind:
                    kind_count += 1
            # Single-kind squads may use all100 proxies. Keep every initial
            # position valid for the battlefield and existing save schema.
            var rank_spacing := minf(22.0, 210.0 / maxf(1.0, ceilf(float(kind_count) / 6.0) - 1.0))
            var n := 0
            for s in squad["soldiers"]:
                if int(s["kind"]) != kind:
                    continue
                var column: int = n % 6
                var row: int = int(n / 6)
                var direction: float = 1.0 if side == 0 else -1.0
                s.merge({"team": side, "group": group_id}, true)
                if reset_positions or not (s.has("x") and s.has("y") and s.has("cooldown")):
                    s.merge({"x": base_x - direction * float(row) * rank_spacing,
                        "y": 54.0 + float(kind) * 94.0 + float(column) * 13.0,
                        "cooldown": float(n % 5) * 0.13, "attack_flash": 0.0}, true)
                s["attack_flash"] = s.get("attack_flash", 0.0)
                soldiers_visual.append(s)
                n += 1
    _recount_armies()

func _use_item(item_key: String) -> bool:
    return rpg_panel.use_item(item_key) if campaign_started else false


func _process(delta: float) -> void:
    if not active:
        return
    # Settle existing defeat/timeout before moving, so a boundary cannot add extra damage.
    if _settle_round_if_over():
        return
    var dt := minf(minf(maxf(delta, 0.0), 0.08), ROUND_SECONDS - campaign.elapsed)
    var living: Array = [[], []]
    for i in range(soldiers_visual.size()):
        if float(soldiers_visual[i]["hp"]) > 0.0:
            living[int(soldiers_visual[i]["team"])].append(i)
    # Each actor selects a nearby enemy, approaches or attacks independently.
    for team in range(2):
        var enemies: Array = living[1 - team]
        for index in living[team]:
            var s: Dictionary = soldiers_visual[index]
            if float(s["hp"]) <= 0.0:
                continue
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
                if general_target >= 0 and float(target["hp"]) <= 0.0 and _settle_round_if_over():
                    return
            soldiers_visual[index] = s
    _move_generals(dt)
    if not active:
        return
    _recount_armies()
    # The timer measures elapsed play time even when rendering is slow.
    var result := campaign.advance(maxf(delta, 0.0))
    battle_elapsed = campaign.elapsed
    if not result.is_empty():
        _finish_round()
    else:
        _refresh()
        if campaign.elapsed >= next_checkpoint:
            _save_campaign()

func _settle_round_if_over() -> bool:
    # Damage resolves sequentially: the final general's death ends all actor turns.
    if campaign.advance(0.0).is_empty():
        return false
    _finish_round()
    return true

func _team_defeated(side: int) -> bool:
    for g in generals:
        if int(g["team"]) == side and float(g["hp"]) > 0.0:
            return false
    return true

func _result_text(result: String) -> String:
    match result:
        "timeout": return "99秒到，雙方撤回"
        "attacker_victory": return "我軍勝利"
        "defender_victory": return "敵軍勝利"
        "draw": return "雙方武將全滅"
    return ""

func _finish_round(save: bool = true) -> void:
    active = false
    _recount_armies()
    _refresh()
    var final_result := campaign.campaign_result()
    status.text = ("戰役結束 · " + _result_text(final_result)) if not final_result.is_empty() else ("本場結束 · " + _result_text(campaign.last_result))
    details.text = "生命與剩餘兵力已保留。\n未出場隊伍已休整：存活武將+10生命。"
    if campaign.last_result == "timeout":
        details.text = "99秒撤回，不按生命或兵力判勝負。\n生命與兵力已保留，可重新選隊。"
    next_round_button.visible = true
    next_round_button.text = "查看戰役結果" if not final_result.is_empty() else "重新選隊"
    field.queue_redraw()
    if save:
        _save_campaign()

func _recount_armies() -> void:
    for i in range(units.size()):
        var total := 0.0
        for s in soldiers_visual:
            if int(s["group"]) == i:
                total += float(s["hp"]) * float(s["troop_weight"])
        units[i]["soldiers"] = maxi(0, int(ceil(total - 0.000001)))
        units[i]["hp"] = units[i]["soldiers"]

func _total_soldiers(side: int) -> int:
    if not campaign_started or campaign.selected[side] < 0:
        return 0
    return campaign.troops(campaign.armies[side][campaign.selected[side]])

func _refresh() -> void:
    score.text = "我軍 %d兵　VS　敵軍 %d兵\n時間 %.1f／99秒" % [_total_soldiers(0), _total_soldiers(1), campaign.elapsed]
    var lines: Array[String] = []
    for side in range(2):
        var general_lines: Array[String] = []
        for g in generals:
            if int(g["team"]) == side:
                general_lines.append("%d.%s %.1f／%.0f%s" % [int(g["slot"]) + 1, ["主將", "副將", "副將"][int(g["slot"])], g["hp"], g["max_hp"], " †" if float(g["hp"]) <= 0.0 else ""])
        lines.append(("我軍：" if side == 0 else "敵軍：") + "　".join(general_lines))
    general_info.text = "\n".join(lines)
    if active:
        details.text = "武將全部陣亡才算本隊戰敗。\n本場損失：我軍%d兵／敵軍%d兵" % [starting_troops[0] - _total_soldiers(0), starting_troops[1] - _total_soldiers(1)]
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
            if enemy_general >= 0 and float(target["hp"]) <= 0.0 and _settle_round_if_over():
                return
        generals[gi] = general

func _draw_field() -> void:
    if not battle.visible:
        return
    BattleArt.background(field, ui_font)
    BattleArt.actors(field, ui_font, soldiers_visual, generals, campaign.elapsed, active)
