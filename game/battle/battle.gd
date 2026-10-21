class_name BattleScene
extends Node2D

## 一局的表现层 + 流程：持有 RiceSim，每物理帧推进它，并按它发的 signal 维护掉落物 Node。
## 边界：这里可以碰 Node；rice_sim.gd 里不行。
##
## 一局之内的规则判定全在 RiceSim；这里只做四件事：读输入、推进仿真、同步显示、走结算流程。

signal exit_to_menu()

const GAME_OVER_PANEL := preload("res://game/pop/game_over.tscn")
const POPUP_LIFE := 0.75
## 调试自动接饭的跟随系数（只在 debug_advance 里用）
const AUTOPILOT_LERP := 0.16

var _sim: RiceSim = null
var _world: Node2D = null
var _items_root: Node2D = null
var _fish: FishView = null
var _spark: CPUParticles2D = null
var _hud: BattleHud = null

## item.id → 正在显示的 RiceView。_active 只为了顺序遍历（Dictionary.values() 是无类型的）
var _views: Dictionary[int, RiceView] = {}
var _active: Array[RiceView] = []
var _view_pool: Array[RiceView] = []
var _popup_pool: Array[Label] = []

var _over_panel: GameOverPanel = null
var _shake: float = 0.0
var _shake_t: float = 0.0


func _ready() -> void:
	_sim = RiceSim.new()
	_build_scene()
	_bind(true)
	_sync_fish()
	_hud.set_best(PlayerService.best_score())
	_hud.set_wave(_sim.wave)
	_popup("开饭了！用锅接住饭团，躲开石头和辣椒", Vector2(RiceRules.FIELD_W * 0.5, 232.0), Color(1.0, 1.0, 1.0))


func _exit_tree() -> void:
	_bind(false)


func _physics_process(delta: float) -> void:
	if _sim == null:
		return
	if _sim.is_running():
		_read_input(delta)
		_sim.step(delta)
		_sync_items()
		_sync_fish()
	_update_shake(delta)


# ── 输入 ────────────────────────────────────────────────────────────

func _read_input(delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if Input.is_physical_key_pressed(KEY_A):
		dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir += 1.0
	if not is_zero_approx(dir):
		_sim.move_pot(clampf(dir, -1.0, 1.0), delta)
		_fish.set_moving(clampf(dir, -1.0, 1.0))
	else:
		_fish.set_moving(0.0)
		# 按住鼠标（手机上等于按住手指）时，锅直接跟到指针横向位置
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_sim.steer_pot(get_global_mouse_position().x)


# ── 场景搭建 ─────────────────────────────────────────────────────────

func _build_scene() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	var sky := TextureRect.new()
	sky.name = "Sky"
	sky.texture = _make_sky_texture()
	sky.position = Vector2.ZERO
	sky.size = Vector2(RiceRules.FIELD_W, RiceRules.FIELD_H)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.z_index = -20
	_world.add_child(sky)

	var scenery := Scenery.new()
	scenery.name = "Scenery"
	scenery.z_index = -10
	_world.add_child(scenery)

	_items_root = Node2D.new()
	_items_root.name = "Items"
	_world.add_child(_items_root)

	_fish = FishView.new()
	_fish.name = "Fish"
	_fish.z_index = 10
	_world.add_child(_fish)

	_spark = _make_spark()
	_spark.name = "Spark"
	_spark.z_index = 6
	_world.add_child(_spark)

	# HUD 单独挂一层 CanvasLayer：它不该跟着世界一起抖
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HudLayer"
	hud_layer.layer = 5
	add_child(hud_layer)
	_hud = BattleHud.new()
	_hud.name = "Hud"
	hud_layer.add_child(_hud)


func _make_sky_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.36, 0.66, 0.94))
	g.set_color(1, Color(0.99, 0.94, 0.86))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 16
	tex.height = 256
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	return tex


func _make_spark() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.55
	p.explosiveness = 1.0
	p.direction = Vector2(0.0, -1.0)
	p.spread = 75.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 240.0
	p.gravity = Vector2(0.0, 620.0)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.5
	p.color = Color(1.0, 0.98, 0.86, 0.95)
	return p


# ── signal 绑定（成对）───────────────────────────────────────────────

func _bind(on: bool) -> void:
	if _sim == null:
		return
	var pairs: Array[Array] = [
		[_sim.item_spawned, _on_item_spawned],
		[_sim.item_caught, _on_item_caught],
		[_sim.item_missed, _on_item_missed],
		[_sim.stone_hit, _on_stone_hit],
		[_sim.chili_caught, _on_chili_caught],
		[_sim.wave_changed, _on_wave_changed],
		[_sim.score_changed, _on_score_changed],
		[_sim.game_over, _on_game_over],
	]
	for pair in pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if on:
			if not sig.is_connected(cb):
				sig.connect(cb)
		elif sig.is_connected(cb):
			sig.disconnect(cb)


# ── 同步显示 ─────────────────────────────────────────────────────────

func _sync_items() -> void:
	for view in _active:
		if view.data == null:
			continue
		view.position = Vector2(view.data.x, view.data.y)
		view.rotation = view.data.rot


func _sync_fish() -> void:
	_fish.position = Vector2(_sim.pot_x, RiceRules.FISH_Y)
	_fish.set_pile(float(_sim.caught % RiceRules.POT_PILE_FULL) / float(RiceRules.POT_PILE_FULL))
	_fish.set_spicy(_sim.is_spicy())
	_hud.set_hearts(_sim.hearts)
	_hud.set_spicy(_sim.is_spicy())


func _update_shake(delta: float) -> void:
	if _shake <= 0.05:
		if _world.position != Vector2.ZERO:
			_world.position = Vector2.ZERO
		return
	_shake = maxf(0.0, _shake - delta * 70.0)
	_shake_t += delta * 42.0
	_world.position = Vector2(sin(_shake_t) * _shake, cos(_shake_t * 1.7) * _shake * 0.6)


# ── 仿真事件 ─────────────────────────────────────────────────────────

func _on_item_spawned(item: FallItem) -> void:
	var view := _acquire_view()
	view.bind_item(item)
	view.position = Vector2(item.x, item.y)
	view.rotation = item.rot
	_views[item.id] = view
	_active.append(view)


func _on_item_caught(item: FallItem, gained: int, combo: int) -> void:
	var at := Vector2(item.x, _sim.catch_y())
	var col := Color(1.0, 0.88, 0.40) if combo >= RiceRules.COMBO_PER_MULT else Color(1.0, 1.0, 0.94)
	_popup("+%d" % gained, at + Vector2(0.0, -34.0), col)
	_spark.position = at
	_spark.restart()
	_release_view(item)


func _on_item_missed(item: FallItem) -> void:
	_release_view(item)


func _on_stone_hit(item: FallItem, hearts: int) -> void:
	_release_view(item)
	_shake = 18.0
	_hud.flash(Color(1.0, 0.26, 0.24))
	_popup("砸到啦！" if hearts > 0 else "锅被砸漏了…", Vector2(item.x, _sim.catch_y() - 20.0), Color(1.0, 0.42, 0.42))


func _on_chili_caught(item: FallItem, seconds: float) -> void:
	_release_view(item)
	_shake = 9.0
	_hud.flash(Color(1.0, 0.55, 0.20))
	_popup("辣到啦！%.1f 秒" % seconds, Vector2(item.x, _sim.catch_y() - 20.0), Color(1.0, 0.62, 0.32))


func _on_wave_changed(wave: int) -> void:
	_hud.set_wave(wave)
	_popup("第 %d 波！饭团更快了" % wave, Vector2(RiceRules.FIELD_W * 0.5, 156.0), Color(1.0, 0.96, 0.82))


func _on_score_changed(score: int, combo: int, mult: int) -> void:
	_hud.set_score(score, combo, mult)


func _on_game_over(score: int, caught: int, best_combo: int) -> void:
	var is_new_best := PlayerService.record_run(score, caught)
	_hud.set_best(PlayerService.best_score())
	var panel := GAME_OVER_PANEL.instantiate() as GameOverPanel
	if panel == null:
		push_error("game_over.tscn 根节点必须 extends PanelBase")
		return
	panel.setup(score, caught, best_combo, PlayerService.best_score(), is_new_best)
	panel.restart_requested.connect(_on_restart_requested)
	panel.menu_requested.connect(_on_menu_requested)
	_over_panel = panel
	panel.show_panel(Ui.Layer.POP)


func _on_restart_requested() -> void:
	_over_panel = null
	_reset_round()


func _on_menu_requested() -> void:
	_over_panel = null
	exit_to_menu.emit()


# ── 一局的重开 ───────────────────────────────────────────────────────

func _reset_round() -> void:
	for view in _active:
		view.data = null
		view.visible = false
		_view_pool.append(view)
	_active.clear()
	_views.clear()
	_shake = 0.0
	_shake_t = 0.0
	_world.position = Vector2.ZERO
	_sim.reset()
	_sync_fish()
	_hud.set_wave(_sim.wave)


# ── 掉落物 Node 的对象池 ─────────────────────────────────────────────
# 掉落物峰值得有十几二十个，每次 new Node 会让 GC 抖动；节点一旦建好就循环用。

func _acquire_view() -> RiceView:
	var view: RiceView = null
	if not _view_pool.is_empty():
		view = _view_pool.pop_back() as RiceView
	else:
		view = RiceView.new()
		_items_root.add_child(view)
	view.visible = true
	return view


func _release_view(item: FallItem) -> void:
	var view: RiceView = _views.get(item.id)
	if view == null:
		return
	_views.erase(item.id)
	_active.erase(view)
	view.data = null
	view.visible = false
	_view_pool.append(view)


# ── 飘字 ────────────────────────────────────────────────────────────

func _popup(text: String, at: Vector2, col: Color) -> void:
	var lbl := _acquire_popup()
	lbl.text = text
	lbl.position = at + Vector2(-160.0, 0.0)
	lbl.modulate = col
	lbl.visible = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", at.y - 72.0, POPUP_LIFE)
	tween.tween_property(lbl, "modulate:a", 0.0, POPUP_LIFE)
	tween.chain().tween_callback(lbl.hide)


func _acquire_popup() -> Label:
	for lbl in _popup_pool:
		if not lbl.visible:
			return lbl
	var lbl := Label.new()
	lbl.size = Vector2(320.0, 46.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.07, 0.85))
	lbl.add_theme_constant_override("outline_size", 9)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items_root.add_child(lbl)
	_popup_pool.append(lbl)
	return lbl


# ── 调试钩子（tools/shotter.gd 与 --demo 用，业务代码不要调）────────────

## 不依赖真实时间推进仿真，并顺手用"自动接饭"操作锅。
## 用来在 headless / 截图环境里一步造出"打了一会儿"的局面。
func debug_advance(seconds: float) -> void:
	const STEP := 1.0 / 60.0
	var frames := int(seconds / STEP)
	for i in frames:
		var target := _debug_target_x()
		if target >= 0.0:
			_sim.steer_pot(lerpf(_sim.pot_x, target, AUTOPILOT_LERP))
		_sim.step(STEP)
	_sync_items()
	_sync_fish()


## 直接把心扣光，走一遍结算流程（面板会被挂到 Ui.Layer.POP）。
func debug_game_over() -> void:
	if _sim != null:
		_sim.debug_set_hearts(0)


## 一局状态的快照，供 --demo 断言用（只读）。
func debug_stats() -> Dictionary:
	if _sim == null:
		return {}
	return {
		"score": _sim.score,
		"caught": _sim.caught,
		"missed": _sim.missed,
		"best_combo": _sim.best_combo,
		"hearts": _sim.hearts,
		"wave": _sim.wave,
		"alive": _sim.items.size(),
		"running": _sim.is_running(),
	}


func _debug_target_x() -> float:
	var best_x := -1.0
	var best_y := -INF
	for item in _sim.items:
		if not item.alive or item.y > _sim.catch_y():
			continue
		if item.y > best_y:
			best_y = item.y
			best_x = item.x
	return best_x
