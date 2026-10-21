class_name RiceView
extends Node2D

## 一个掉落物的画法。数据全在绑定的 FallItem（仿真层）里，本类不存任何玩法状态。
##
## 掉落物是**饭团**（不是散米粒）：三角 + 海苔的轮廓在三四十像素下依然一眼认得出，
## 而散米粒在这个尺寸只会糊成一团白点。
## 这里坚持程序化绘制（试过 AI 贴图，见 README）：40px 幅面下 AI 的细节全糊，
## 接物游戏要的是"一眼分清是什么"；纯色块 + 统一描边反而更清楚，也和石头/辣椒同风格。

const C_RICE := Color(0.99, 0.98, 0.95)
const C_RICE_SHADE := Color(0.86, 0.86, 0.84)
const C_RICE_LINE := Color(0.34, 0.27, 0.22)
const C_NORI := Color(0.13, 0.20, 0.17)
const C_NORI_LIGHT := Color(0.20, 0.30, 0.25)
const C_GOLD := Color(1.0, 0.83, 0.26)
const C_GOLD_SHADE := Color(0.86, 0.58, 0.08)
const C_GOLD_LIGHT := Color(1.0, 0.95, 0.62)
const C_CHILI := Color(0.87, 0.17, 0.16)
const C_CHILI_DARK := Color(0.60, 0.09, 0.10)
const C_STEM := Color(0.32, 0.60, 0.26)
const C_STONE := Color(0.56, 0.58, 0.63)
const C_STONE_DARK := Color(0.38, 0.40, 0.45)
const C_STONE_LIGHT := Color(0.74, 0.76, 0.80)

## 饭团半径（外接）、底边位置、倒角半径
const ONIGIRI_R := 24.0
const ONIGIRI_BOTTOM := 17.0
const ONIGIRI_CORNER := 9.5

var data: FallItem = null


## 绑定仿真数据（每次从对象池取出时调用）
func bind_item(item: FallItem) -> void:
	data = item
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	match data.kind:
		RiceRules.Kind.WHITE:
			_draw_onigiri(C_RICE, C_RICE_SHADE, C_RICE_LINE)
		RiceRules.Kind.GOLD:
			_draw_onigiri(C_GOLD, C_GOLD_SHADE, C_CHILI_DARK)
			_draw_sparkle()
		RiceRules.Kind.CHILI:
			_draw_chili()
		RiceRules.Kind.STONE:
			_draw_stone()


## 饭团：圆角三角本体 + 海苔条 + 几粒米的高光
func _draw_onigiri(body: Color, shade: Color, line: Color) -> void:
	var tri := _rounded_triangle(ONIGIRI_R, ONIGIRI_CORNER)
	# 右下暗面（偏移 2px 画一遍，露出来的边就是体积）
	var shadow := PackedVector2Array()
	for p in tri:
		shadow.append(p + Vector2(2.0, 1.2))
	draw_colored_polygon(shadow, shade)
	draw_colored_polygon(tri, body)
	# 米粒质感
	for i in 4:
		var y := -8.0 + float(i) * 5.5
		draw_circle(Vector2(-8.0 + float(i) * 4.0, y), 1.7, Color(1.0, 1.0, 1.0, 0.9))
	# 海苔：只包住底边一小条，别喧宾夺主
	var nori := PackedVector2Array([
		Vector2(-10.0, 7.0), Vector2(10.0, 7.0),
		Vector2(9.0, ONIGIRI_BOTTOM + 2.5), Vector2(-9.0, ONIGIRI_BOTTOM + 2.5),
	])
	draw_colored_polygon(nori, C_NORI)
	draw_line(Vector2(-9.0, 10.0), Vector2(9.0, 10.0), C_NORI_LIGHT, 1.5, true)
	# 描边（cel 风格那条线）
	var outline := tri.duplicate()
	outline.append(tri[0])
	draw_polyline(outline, line, 1.8, true)


func _draw_sparkle() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -32.0), Vector2(4.0, -6.0), Vector2(28.0, 0.0), Vector2(4.0, 4.0),
		Vector2(0.0, 28.0), Vector2(-4.0, 4.0), Vector2(-28.0, 0.0), Vector2(-4.0, -6.0),
	]), Color(C_GOLD_LIGHT, 0.85))


func _draw_chili() -> void:
	# 弯月形辣椒：外弧 + 内弧拼成一个粗弯条
	var pts := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var a: float = lerpf(-0.35, 2.45, float(i) / float(steps))
		pts.append(Vector2(cos(a), sin(a)) * 17.0)
	for i in steps + 1:
		var a: float = lerpf(2.45, -0.35, float(i) / float(steps))
		pts.append(Vector2(cos(a), sin(a)) * 8.0)
	draw_colored_polygon(pts, C_CHILI)
	draw_arc(Vector2.ZERO, 12.5, 0.2, 2.2, 12, C_CHILI_DARK, 3.0, true)
	draw_line(Vector2(-15.0, -6.0), Vector2(-22.0, -16.0), C_STEM, 5.0, true)


func _draw_stone() -> void:
	var pts := PackedVector2Array([
		Vector2(-15.0, -3.0), Vector2(-8.0, -15.0), Vector2(5.0, -16.0),
		Vector2(15.0, -5.0), Vector2(13.0, 9.0), Vector2(1.0, 16.0), Vector2(-11.0, 11.0),
	])
	draw_colored_polygon(pts, C_STONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8.0, -15.0), Vector2(5.0, -16.0), Vector2(2.0, -2.0), Vector2(-6.0, -1.0),
	]), C_STONE_LIGHT)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, C_STONE_DARK, 2.0, true)


## 圆角三角形（尖朝上）：三个角用二次贝塞尔倒角
func _rounded_triangle(radius: float, corner: float) -> PackedVector2Array:
	var verts: Array[Vector2] = [
		Vector2(0.0, -radius),
		Vector2(radius * 0.92, ONIGIRI_BOTTOM),
		Vector2(-radius * 0.92, ONIGIRI_BOTTOM),
	]
	var out := PackedVector2Array()
	for i in 3:
		var corner_pt := verts[i]
		var prev := verts[(i + 2) % 3]
		var next := verts[(i + 1) % 3]
		var start := corner_pt + (prev - corner_pt).normalized() * corner
		var end := corner_pt + (next - corner_pt).normalized() * corner
		out.append(start)
		for s in 4:
			var t := float(s + 1) / 5.0
			var u := 1.0 - t
			out.append(start * u * u + corner_pt * 2.0 * u * t + end * t * t)
		out.append(end)
	return out
