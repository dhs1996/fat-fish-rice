class_name BattleHud
extends Control

## 对局 HUD：分数 / 连击倍率 / 最高分 / 波次 / 心 / "辣到"提示 / 受击红闪。
## 里面只有这一个场景用的东西，所以整块在代码里搭，不额外维护一份 .tscn 皮肤。
## HUD 不吃点击（mouse_filter = IGNORE），否则会挡住拖动锅的操作。

const C_TEXT := Color(1.0, 0.98, 0.93)
const C_OUTLINE := Color(0.12, 0.09, 0.08, 0.88)
const C_GOLD := Color(1.0, 0.86, 0.36)
const C_SPICY := Color(1.0, 0.45, 0.25)

var _lbl_score: Label = null
var _lbl_mult: Label = null
var _lbl_best: Label = null
var _lbl_wave: Label = null
var _lbl_spicy: Label = null
var _hearts: HeartsBar = null
var _flash: ColorRect = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1.0, 0.3, 0.25)
	_flash.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_lbl_score = _make_label(Vector2(34.0, 14.0), Vector2(520.0, 70.0), 52, HORIZONTAL_ALIGNMENT_LEFT)
	_lbl_mult = _make_label(Vector2(36.0, 84.0), Vector2(420.0, 36.0), 26, HORIZONTAL_ALIGNMENT_LEFT)
	_lbl_wave = _make_label(Vector2(440.0, 20.0), Vector2(400.0, 40.0), 28, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl_best = _make_label(Vector2(880.0, 20.0), Vector2(366.0, 40.0), 28, HORIZONTAL_ALIGNMENT_RIGHT)
	_lbl_best.add_theme_color_override("font_color", C_GOLD)

	_hearts = HeartsBar.new()
	_hearts.position = Vector2(34.0, 662.0)
	_hearts.size = Vector2(180.0, 48.0)
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hearts)

	_lbl_spicy = _make_label(Vector2(340.0, 132.0), Vector2(600.0, 52.0), 36, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl_spicy.add_theme_color_override("font_color", C_SPICY)
	_lbl_spicy.text = "辣到啦！左右操作反转"
	_lbl_spicy.visible = false

	set_score(0, 0, 1)
	set_best(0)
	set_wave(1)
	reset_hearts(RiceRules.HEARTS_MAX)


func set_score(score: int, combo: int, mult: int) -> void:
	_lbl_score.text = "%d" % score
	if combo >= 2:
		_lbl_mult.text = "连击 %d   倍率 x%d" % [combo, mult]
		_lbl_mult.modulate = Color(1.0, 0.84, 0.36, 1.0) if mult > 1 else Color(1.0, 1.0, 1.0, 0.85)
	else:
		_lbl_mult.text = ""


func set_best(best: int) -> void:
	_lbl_best.text = "最高 %d" % best


func set_wave(wave: int) -> void:
	_lbl_wave.text = "第 %d 波" % wave


func set_hearts(hearts: int) -> void:
	_hearts.set_hearts(hearts)


func reset_hearts(max_hearts: int) -> void:
	_hearts.max_hearts = max_hearts
	_hearts.set_hearts(max_hearts)


func set_spicy(on: bool) -> void:
	if _lbl_spicy.visible != on:
		_lbl_spicy.visible = on


## 受击红闪（不会挡住操作：ColorRect 是 IGNORE 点击）
func flash(col: Color) -> void:
	_flash.color = col
	_flash.modulate = Color(1.0, 1.0, 1.0, 0.5)
	var tween := create_tween()
	tween.tween_property(_flash, "modulate:a", 0.0, 0.36)


func _make_label(at: Vector2, box: Vector2, font_size: int, align: int) -> Label:
	var lbl := Label.new()
	lbl.position = at
	lbl.size = box
	lbl.horizontal_alignment = align as HorizontalAlignment
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", C_TEXT)
	lbl.add_theme_color_override("font_outline_color", C_OUTLINE)
	lbl.add_theme_constant_override("outline_size", 10)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	return lbl


## 心：扣掉的那颗画成空的。这里自成一体，不引用外层 BattleHud 的常量，
## 免得内部类去找外部类的成员。
class HeartsBar:
	extends Control

	const C_FILL := Color(0.94, 0.26, 0.34)
	const C_FILL_DARK := Color(0.72, 0.13, 0.20)
	const C_EMPTY := Color(0.12, 0.09, 0.08, 0.32)

	var hearts: int = 3
	var max_hearts: int = 3

	func set_hearts(v: int) -> void:
		hearts = clampi(v, 0, max_hearts)
		queue_redraw()

	func _draw() -> void:
		for i in max_hearts:
			var at := Vector2(26.0 + float(i) * 48.0, 26.0)
			var filled := i < hearts
			_draw_heart(at, 18.0, C_FILL if filled else C_EMPTY)
			if filled:
				draw_circle(at + Vector2(-6.0, -7.0), 4.0, Color(1.0, 1.0, 1.0, 0.55))

	func _draw_heart(at: Vector2, r: float, col: Color) -> void:
		draw_circle(at + Vector2(-r * 0.42, -r * 0.26), r * 0.56, col)
		draw_circle(at + Vector2(r * 0.42, -r * 0.26), r * 0.56, col)
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-r * 0.93, -r * 0.06),
			at + Vector2(r * 0.93, -r * 0.06),
			at + Vector2(0.0, r * 1.02),
		]), col)
