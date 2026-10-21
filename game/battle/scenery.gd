class_name Scenery
extends Node2D

## 背景装饰：云（会飘）+ 太阳 + 桌面。纯 _draw，没有位图资源。
## 每帧重画的就是十几个圆和几条线，开销可以忽略；
## 真要省的话把云也搬进 TextureRect，但那是优化，不是现在该做的事。

const C_TABLE := Color(0.63, 0.42, 0.26)
const C_TABLE_EDGE := Color(0.79, 0.57, 0.34)
const C_TABLE_LINE := Color(0.52, 0.33, 0.19)
const C_CLOUD := Color(1.0, 1.0, 1.0, 0.86)
const C_CLOUD_SHADE := Color(0.94, 0.96, 1.0, 0.55)
const C_SUN := Color(1.0, 0.93, 0.66, 0.5)

## 云的种子：换一次世界就换一片天，但同一局内云是天生的
const CLOUD_SEED := 20240701
const CLOUD_COUNT := 7
const CLOUD_DRIFT := 11.0

## 每条云：x, y, 缩放（用一个 Vector3 打包，省一个类）
var _clouds: Array[Vector3] = []
var _t: float = 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = CLOUD_SEED
	for i in CLOUD_COUNT:
		_clouds.append(Vector3(
			rng.randf_range(0.0, RiceRules.FIELD_W),
			rng.randf_range(56.0, 430.0),
			rng.randf_range(0.7, 1.6)
		))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# 太阳
	draw_circle(Vector2(1080.0, 92.0), 48.0, C_SUN)
	draw_circle(Vector2(1080.0, 92.0), 34.0, Color(1.0, 0.96, 0.78, 0.65))
	# 云
	for c in _clouds:
		var span := RiceRules.FIELD_W + 320.0
		var x := fposmod(c.x + _t * CLOUD_DRIFT, span) - 160.0
		_draw_cloud(Vector2(x, c.y), c.z)
	# 桌面
	draw_rect(Rect2(0.0, RiceRules.GROUND_Y, RiceRules.FIELD_W, RiceRules.FIELD_H - RiceRules.GROUND_Y), C_TABLE)
	draw_rect(Rect2(0.0, RiceRules.GROUND_Y, RiceRules.FIELD_W, 12.0), C_TABLE_EDGE)
	for i in 9:
		var y := RiceRules.GROUND_Y + 26.0 + float(i) * 7.0
		draw_line(Vector2(0.0, y), Vector2(RiceRules.FIELD_W, y), Color(C_TABLE_LINE, 0.16), 2.0)


func _draw_cloud(at: Vector2, scale_factor: float) -> void:
	draw_circle(at + Vector2(-34.0, 6.0) * scale_factor, 30.0 * scale_factor, C_CLOUD_SHADE)
	draw_circle(at + Vector2(0.0, 0.0) * scale_factor, 40.0 * scale_factor, C_CLOUD)
	draw_circle(at + Vector2(38.0, 8.0) * scale_factor, 27.0 * scale_factor, C_CLOUD_SHADE)
	draw_circle(at + Vector2(14.0, -18.0) * scale_factor, 26.0 * scale_factor, C_CLOUD)
