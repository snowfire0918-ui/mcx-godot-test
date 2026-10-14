extends RefCounted

# Original procedural art; all coordinates below are presentation only.
# No actor dictionaries, HP, troop weights, timers or RNG are modified here.
const INK := Color("#17252b")
const GOLD := Color("#dec183")
const STEEL := Color("#b9c7c6")
const SKIN := Color("#e5b990")
const COATS := [Color("#437fa2"), Color("#ae554b")]
const DARKS := [Color("#233f59"), Color("#642f34")]

static func background(canvas: Control, font: Font) -> void:
    var w := canvas.size.x
    var h := canvas.size.y
    canvas.draw_rect(Rect2(0, 0, w, h), Color("#768775"))
    _poly(canvas, [Vector2(0, 52), Vector2(w * 0.14, 15), Vector2(w * 0.29, 45), Vector2(w * 0.47, 9), Vector2(w * 0.64, 47), Vector2(w * 0.84, 17), Vector2(w, 42), Vector2(w, 100), Vector2(0, 100)], Color("#536c62"))
    _poly(canvas, [Vector2(0, 66), Vector2(w * 0.23, 41), Vector2(w * 0.48, 70), Vector2(w * 0.75, 40), Vector2(w, 62), Vector2(w, 110), Vector2(0, 110)], Color("#3c574c"))
    canvas.draw_rect(Rect2(0, 80, w, h - 80), Color("#647051"))
    _poly(canvas, [Vector2(0, 120), Vector2(w, 88), Vector2(w, h - 28), Vector2(0, h)], Color("#727452"))
    _poly(canvas, [Vector2(w * 0.37, 85), Vector2(w * 0.53, 85), Vector2(w * 0.72, h), Vector2(w * 0.25, h)], Color("#827956"))
    # Deterministic grass / stones: rendering never consumes simulation randomness.
    for i in range(56):
        var x := float((i * 137 + 31) % 997) / 997.0 * w
        var y := 98.0 + float((i * 79 + 13) % 251) / 251.0 * (h - 109.0)
        var tone := Color("#575f44") if i % 3 else Color("#9c9069")
        canvas.draw_line(Vector2(x, y), Vector2(x + 5, y - 2), tone, 1.0)
        if i % 4 == 0:
            canvas.draw_line(Vector2(x + 2, y), Vector2(x + 1, y - 4), tone, 1.0)
    for side in range(2):
        var x := 28.0 if side == 0 else w - 28.0
        var direction := 1.0 if side == 0 else -1.0
        canvas.draw_line(Vector2(x, 19), Vector2(x, 81), GOLD, 2.0)
        _poly(canvas, [Vector2(x, 20), Vector2(x + direction * 37, 24), Vector2(x + direction * 31, 35), Vector2(x + direction * 37, 48), Vector2(x, 44)], DARKS[side])
        canvas.draw_string(font, Vector2(x + 7 if side == 0 else x - 25, 39), "我" if side == 0 else "敵", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)
    canvas.draw_rect(Rect2(1, 1, w - 2, h - 2), Color("#b59e66"), false, 2.0)
    canvas.draw_string(font, Vector2(w * 0.5 - 40, 28), "兩軍交鋒", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#f2e3bd"))

static func actors(canvas: Control, font: Font, soldiers: Array, generals: Array, time: float, active: bool) -> void:
    # Paint feet from back to front, including mounted officers in the same pass.
    var ordered: Array = []
    for soldier in soldiers:
        if float(soldier["hp"]) > 0.0:
            ordered.append(soldier)
    for general in generals:
        if float(general["hp"]) > 0.0:
            ordered.append(general)
    ordered.sort_custom(func(a: Dictionary, b: Dictionary): return float(a["y"]) < float(b["y"]))
    var zoom := clampf(canvas.size.x / 720.0, 0.62, 1.1)
    for actor in ordered:
        var team := int(actor["team"])
        var facing := 1.0 if team == 0 else -1.0
        var pos := Vector2(float(actor["x"]) * canvas.size.x / 920.0, 48.0 + float(actor["y"]) * (canvas.size.y - 58.0) / 350.0)
        var moving: bool = active and float(actor["cooldown"]) <= 0.01
        var step := sin(time * 13.0 + float(actor["x"]) * 0.08 + float(actor["y"]) * 0.1) if moving else 0.0
        canvas.draw_set_transform(pos, 0.0, Vector2(zoom * facing, zoom))
        if actor.has("slot"):
            _officer(canvas, team, int(actor["slot"]), step, active and float(actor["cooldown"]) > 0.49)
        else:
            _soldier(canvas, team, int(actor["kind"]), step, active and float(actor.get("attack_flash", 0)) > 0.0)
        canvas.draw_set_transform(Vector2.ZERO)
    # Keep officer numbers / HP above the whole army, readable through the ranks.
    for general in generals:
        if float(general["hp"]) <= 0.0:
            continue
        var pos := Vector2(float(general["x"]) * canvas.size.x / 920.0, 48.0 + float(general["y"]) * (canvas.size.y - 58.0) / 350.0)
        var bar := Rect2(pos + Vector2(-21, -56) * zoom, Vector2(42, 5) * zoom)
        canvas.draw_rect(bar.grow(1), INK)
        bar.size.x *= clampf(float(general["hp"]) / float(general["max_hp"]), 0.0, 1.0)
        canvas.draw_rect(bar, Color("#b0d79b"))
        var title: String = ["主", "副1", "副2"][int(general["slot"])]
        var label_pos := pos + Vector2(-12, 16) * zoom
        canvas.draw_string_outline(font, label_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, INK)
        canvas.draw_string(font, label_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)

static func _poly(canvas: Control, points: Array, color: Color) -> void:
    canvas.draw_colored_polygon(PackedVector2Array(points), color)

static func _soldier(canvas: Control, team: int, kind: int, step: float, striking: bool) -> void:
    var body: Color = COATS[team]
    var dark: Color = DARKS[team]
    canvas.draw_line(Vector2(-6, 2), Vector2(7, 2), Color(0.09, 0.12, 0.09, 0.38), 5.0)
    canvas.draw_line(Vector2(-3, -5), Vector2(-4 + step * 2, 1), INK, 3)
    canvas.draw_line(Vector2(3, -5), Vector2(4 - step * 2, 1), INK, 3)
    _poly(canvas, [Vector2(-5, -15), Vector2(4, -15), Vector2(6, -5), Vector2(-6, -5)], dark)
    canvas.draw_rect(Rect2(-4, -15, 8, 8), body)
    for y in [-13, -10]:
        canvas.draw_line(Vector2(-3, y), Vector2(3, y), STEEL.darkened(0.35), 1)
    canvas.draw_line(Vector2(-5, -6), Vector2(5, -6), GOLD, 2)
    canvas.draw_rect(Rect2(-3, -22, 6, 6), SKIN)
    _poly(canvas, [Vector2(-5, -21), Vector2(-4, -25), Vector2(2, -26), Vector2(5, -22), Vector2(5, -20), Vector2(-5, -20)], INK)
    canvas.draw_line(Vector2(-3, -23), Vector2(3, -23), STEEL, 2)
    canvas.draw_line(Vector2(-3, -26), Vector2(-7, -28), body, 2)
    canvas.draw_line(Vector2(2, -19), Vector2(4, -19), INK, 1)
    if kind == 0:
        var blade := Vector2(17, -14) if striking else Vector2(9, -27)
        canvas.draw_line(Vector2(5, -13), blade, STEEL, 2)
        canvas.draw_line(Vector2(4, -12), Vector2(8, -12), GOLD, 2)
        _poly(canvas, [Vector2(-8, -16), Vector2(-2, -17), Vector2(-1, -8), Vector2(-5, -5), Vector2(-9, -9)], INK)
        _poly(canvas, [Vector2(-7, -15), Vector2(-3, -15), Vector2(-3, -9), Vector2(-5, -7), Vector2(-7, -10)], body)
        canvas.draw_circle(Vector2(-5, -12), 1.6, GOLD)
    elif kind == 1:
        var tip := Vector2(23, -16) if striking else Vector2(10, -34)
        canvas.draw_line(Vector2(2, -4), tip, Color("#c4a16d"), 2)
        var shaft := (tip - Vector2(2, -4)).normalized()
        var cross := Vector2(-shaft.y, shaft.x) * 2.0
        _poly(canvas, [tip + shaft * 6, tip + cross, tip - cross], STEEL)
        canvas.draw_line(tip - shaft * 2, tip - shaft * 7 + Vector2(-3, 2), body, 2)
    else:
        canvas.draw_rect(Rect2(-7, -18, 3, 10), Color("#6a4a37"))
        for n in range(3):
            canvas.draw_line(Vector2(-7 + n, -16), Vector2(-7 + n, -25), STEEL, 1)
        canvas.draw_arc(Vector2(5, -14), 8, -PI / 2, PI / 2, 8, GOLD, 2)
        canvas.draw_line(Vector2(5, -22), Vector2(5, -6), STEEL, 1)
        if striking:
            canvas.draw_line(Vector2(13, -14), Vector2(39, -14), Color("#f4dfa4"), 1.5)
            _poly(canvas, [Vector2(41, -14), Vector2(35, -17), Vector2(35, -11)], STEEL)
    if striking and kind != 2:
        canvas.draw_arc(Vector2(6, -14), 16, -0.8, 0.6, 7, Color(1, 0.87, 0.6, 0.8), 2)

static func _officer(canvas: Control, team: int, slot: int, step: float, striking: bool) -> void:
    var coat: Color = COATS[team]
    var dark: Color = DARKS[team]
    var horse := Color("#9c795b") if slot == 0 else (Color("#c3b79d") if slot == 1 else Color("#736056"))
    canvas.draw_line(Vector2(-18, 4), Vector2(22, 4), Color(0.09, 0.12, 0.09, 0.4), 7)
    for leg in [-11, -6, 10, 15]:
        var stride := step * (3.0 if leg % 2 else -3.0)
        canvas.draw_line(Vector2(leg, -8), Vector2(leg + stride, 3), horse.darkened(0.25), 3)
        canvas.draw_line(Vector2(leg + stride, 3), Vector2(leg + stride + 3, 3), INK, 2)
    _poly(canvas, [Vector2(-17, -18), Vector2(11, -19), Vector2(15, -11), Vector2(8, -6), Vector2(-13, -7), Vector2(-19, -12)], horse)
    _poly(canvas, [Vector2(8, -18), Vector2(14, -31), Vector2(18, -34), Vector2(25, -29), Vector2(29, -21), Vector2(24, -18), Vector2(18, -22), Vector2(17, -11)], horse)
    _poly(canvas, [Vector2(11, -19), Vector2(15, -31), Vector2(18, -33), Vector2(14, -17)], INK)
    canvas.draw_line(Vector2(21, -29), Vector2(21, -35), horse, 3)
    canvas.draw_circle(Vector2(24, -26), 1.2, INK)
    canvas.draw_line(Vector2(25, -23), Vector2(3, -24), GOLD, 1)
    canvas.draw_line(Vector2(-17, -15), Vector2(-24, -6 + step), INK, 4)
    canvas.draw_rect(Rect2(-8, -19, 17, 10), dark)
    canvas.draw_line(Vector2(-8, -9), Vector2(9, -9), GOLD, 2)
    # Rider's cape, lamellar cuirass, helmet and command plume.
    _poly(canvas, [Vector2(-7, -35), Vector2(0, -31), Vector2(-4, -17), Vector2(-18, -19 + step)], dark)
    canvas.draw_rect(Rect2(-6, -35, 13, 14), coat)
    for y in [-32, -28, -24]:
        canvas.draw_line(Vector2(-4, y), Vector2(6, y), GOLD.darkened(0.18), 2)
    canvas.draw_circle(Vector2(-5, -33), 3, GOLD)
    canvas.draw_circle(Vector2(7, -33), 3, GOLD)
    canvas.draw_line(Vector2(0, -22), Vector2(5, -13), INK, 4)
    canvas.draw_rect(Rect2(-3, -43, 8, 7), SKIN)
    _poly(canvas, [Vector2(-5, -42), Vector2(-4, -47), Vector2(3, -49), Vector2(7, -44), Vector2(6, -41)], GOLD)
    canvas.draw_line(Vector2(0, -48), Vector2(-7, -54), coat.lightened(0.2), 3)
    canvas.draw_line(Vector2(3, -40), Vector2(5, -40), INK, 1)
    var tip := Vector2(38, -28) if striking else Vector2(17, -54)
    canvas.draw_line(Vector2(8, -19), tip, Color("#cbaa71"), 3)
    _poly(canvas, [tip + Vector2(2, -8), tip + Vector2(6, -2), tip + Vector2(1, 5), tip - Vector2(2, 0)], STEEL)
    if striking:
        canvas.draw_arc(Vector2(12, -25), 29, -0.8, 0.55, 10, Color("#f7db8d"), 3)
