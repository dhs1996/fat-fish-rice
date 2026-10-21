class_name FishView
extends Node2D

## 主角：AI 立绘（举手的 chibi 鱼娘）+ 锅 + 锅里的米堆 + 辣到时的火苗。
## origin = 角色锚点（RiceRules.FISH_Y）。脚底对齐到桌面，锅口圆心固定在 POT_RIM_DY。
##
## 为什么锅的绘制和判定都拴在 POT_RIM_DY 上：那既是接饭判定线，也是玩家眼睛盯的位置。
## 两者错开一点，玩家就会觉得"明明接住了却没接住"。
##
## 立绘是静态图，只有轻微点头 + 火苗闪烁，没有骨骼动画（见 README 已知限制）。

const TEX_CHAR := preload("res://assets/art/char.png")
## 锅是**独立素材**（一张 icon），不画在立绘里：这样换锅、调锅口位置都不必重出立绘。
const TEX_POT := preload("res://assets/art/pot_icon.png")

## 立绘在设计分辨率下的高度 / 脚底相对锚点的 y（站在桌面上，见 RiceRules）
const CHAR_HEIGHT := RiceRules.CHAR_HEIGHT
const FEET_Y := RiceRules.CHAR_FEET_Y
## 锅的绘制宽度（判定宽度是 POT_HALF_W * 2 = 156，这里画 172：AI 图的锅沿有壁厚，
## 玩家不会把壁厚算成"应该接得住"的范围）
const POT_WIDTH := 172.0
## 锅贴图是俯视角，纵向压扁成 3/4 视角 —— 米饭才像落进锅里，而不是贴在锅面上
const POT_ASPECT := 0.80
## 锅贴图顶边相对判定线的偏移（贴图顶部还有一点点锅壁厚度，所以往下压几像素）
const POT_TOP_OFFSET := 0.0
## 锅 icon 左边带把手，图心不等于锅心：往左补偿才能让锅口对准 pot_x
const POT_OFFSET_X := 0.0

const C_PILE := Color(0.99, 0.98, 0.93)
const C_PILE_LIGHT := Color(1.0, 1.0, 1.0, 0.8)
const C_FLAME := Color(1.0, 0.48, 0.14)
const C_FLAME_IN := Color(1.0, 0.84, 0.30)

var _t: float = 0.0
## 锅里米堆的高度（0..1）
var _pile: float = 0.0
var _spicy: bool = false
## -1..1：移动方向，只用来带一点点头/晃动
var _moving: float = 0.0


func set_pile(v: float) -> void:
	_pile = clampf(v, 0.0, 1.0)


func set_spicy(on: bool) -> void:
	_spicy = on


func set_moving(dir: float) -> void:
	_moving = clampf(dir, -1.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var rim_y := RiceRules.POT_RIM_DY
	_draw_character()
	_draw_pot(rim_y)
	if _spicy:
		_draw_flames(rim_y)


func _draw_character() -> void:
	var h := CHAR_HEIGHT
	var w := h * float(TEX_CHAR.get_width()) / float(TEX_CHAR.get_height())
	# 走动时轻微上下点头：静态立绘加一点位移就不像贴纸了
	var bob := sin(_t * 9.0) * minf(2.2, absf(_moving) * 2.8)
	var left := -w * 0.5 + RiceRules.CHAR_OFFSET_X
	draw_texture_rect(TEX_CHAR, Rect2(Vector2(left, FEET_Y - h + bob), Vector2(w, h)), false)


func _draw_pot(rim_y: float) -> void:
	var w := POT_WIDTH
	var h := w * POT_ASPECT
	draw_texture_rect(TEX_POT, Rect2(Vector2(-w * 0.5 + POT_OFFSET_X, rim_y + POT_TOP_OFFSET), Vector2(w, h)), false)
	# 锅里的米堆：坐在盆底（视觉内壁最低处 ≈ 盆高的 60%），接得越多堆得越高、越宽。
	# 之前贴在 rim_y + 0.34*h，看着像挂在盆后壁上的一小块白斑。
	if _pile > 0.02:
		var base_y := rim_y + h * 0.60
		var pile_h := 5.0 + 15.0 * _pile
		var pile_w := (RiceRules.POT_HALF_W - 18.0) * (0.55 + 0.45 * _pile)
		var center := Vector2(0.0, base_y - pile_h)
		_ellipse(center, pile_w, pile_h, C_PILE)
		_ellipse(center + Vector2(-pile_w * 0.24, -pile_h * 0.42), pile_w * 0.42, pile_h * 0.42, C_PILE_LIGHT)


func _draw_flames(rim_y: float) -> void:
	for i in 3:
		var x := (float(i) - 1.0) * 40.0
		var flick := 0.72 + 0.28 * sin(_t * 13.0 + float(i) * 1.7)
		var h := 30.0 * flick
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 11.0, rim_y - 2.0),
			Vector2(x, rim_y - 2.0 - h),
			Vector2(x + 11.0, rim_y - 2.0),
		]), C_FLAME)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 5.0, rim_y - 2.0),
			Vector2(x, rim_y - 2.0 - h * 0.6),
			Vector2(x + 5.0, rim_y - 2.0),
		]), C_FLAME_IN)


func _ellipse(at: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	draw_set_transform(at, 0.0, Vector2(rx / ry, 1.0))
	draw_circle(Vector2.ZERO, ry, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
