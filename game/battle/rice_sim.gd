class_name RiceSim
extends RefCounted

## 接饭仿真内核。**纯逻辑**：不认识 Node2D / Control / 任何显示对象，
## 只按 dt 推进数值、按规则发 signal；表现层（battle.gd）订阅它自己画。
##
## 状态唯一：一局之内的分数 / 连击 / 心 / 波次 / 掉落物**全在这里**，
## 表现层只读不写，改数值一律走本类的方法。跨局的永久数据在 PlayerService。

signal item_spawned(item: FallItem)
signal item_caught(item: FallItem, gained: int, combo: int)
signal item_missed(item: FallItem)
signal stone_hit(item: FallItem, hearts: int)
signal chili_caught(item: FallItem, seconds: float)
signal spicy_ended()
signal wave_changed(wave: int)
signal score_changed(score: int, combo: int, mult: int)
signal game_over(final_score: int, caught: int, best_combo: int)

## 场上还活着的掉落物（表现层只读遍历）
var items: Array[FallItem] = []

var pot_x: float = 0.0
var score: int = 0
var combo: int = 0
var best_combo: int = 0
var hearts: int = RiceRules.HEARTS_MAX
var caught: int = 0
var missed: int = 0
var elapsed: float = 0.0
var wave: int = 1

var _rng := RandomNumberGenerator.new()
var _spawn_timer: float = 0.0
var _spicy_left: float = 0.0
var _running: bool = false
var _next_id: int = 1
var _doomed: Array[FallItem] = []


## seed_value >= 0 时用固定种子（冒烟/回放要确定性），否则随机
func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	reset()


## 开新一局：清空所有局内状态。已 connect 的 signal 不用重连。
func reset() -> void:
	items.clear()
	_doomed.clear()
	pot_x = RiceRules.FIELD_W * 0.5
	score = 0
	combo = 0
	best_combo = 0
	hearts = RiceRules.HEARTS_MAX
	caught = 0
	missed = 0
	elapsed = 0.0
	wave = 1
	_spawn_timer = 0.7
	_spicy_left = 0.0
	_next_id = 1
	_running = true
	score_changed.emit(score, combo, mult())


func is_running() -> bool:
	return _running


func is_spicy() -> bool:
	return _spicy_left > 0.0


func mult() -> int:
	return RiceRules.mult_for_combo(combo)


func catch_y() -> float:
	return RiceRules.catch_y()


## 键盘移动：dir ∈ [-1, 1]（辣到时方向反转）
func move_pot(dir: float, dt: float) -> void:
	if not _running or is_zero_approx(dir) or dt <= 0.0:
		return
	var d: float = (-dir) if _spicy_left > 0.0 else dir
	pot_x = clampf(pot_x + d * RiceRules.FISH_SPEED * dt,
			RiceRules.POT_MIN_X, RiceRules.FIELD_W - RiceRules.POT_MIN_X)


## 指针移动：把锅搬到 x（辣到时镜像 —— 这就是"操作反转"对指针的语义）
func steer_pot(x: float) -> void:
	if not _running:
		return
	var target: float = (RiceRules.FIELD_W - x) if _spicy_left > 0.0 else x
	pot_x = clampf(target, RiceRules.POT_MIN_X, RiceRules.FIELD_W - RiceRules.POT_MIN_X)


## 推进一帧。dt 由表现层给（物理帧固定步长，仿真本身不读时钟）。
func step(dt: float) -> void:
	if not _running or dt <= 0.0:
		return
	elapsed += dt
	_tick_wave()
	_tick_spicy(dt)
	_tick_spawn(dt)
	_tick_items(dt)


## 调试钩子（tools/shotter.gd 与 --demo 用）：直接把心扣掉，0 就结算。
## 业务代码不要调用。
func debug_set_hearts(value: int) -> void:
	hearts = maxi(0, value)
	score_changed.emit(score, combo, mult())
	if hearts <= 0 and _running:
		_end()


func _tick_wave() -> void:
	var w := int(elapsed / RiceRules.WAVE_SECONDS) + 1
	if w == wave:
		return
	wave = w
	wave_changed.emit(wave)


func _tick_spicy(dt: float) -> void:
	if _spicy_left <= 0.0:
		return
	_spicy_left -= dt
	if _spicy_left <= 0.0:
		_spicy_left = 0.0
		spicy_ended.emit()


func _tick_spawn(dt: float) -> void:
	_spawn_timer -= dt
	if _spawn_timer > 0.0:
		return
	var interval := RiceRules.spawn_interval(wave) * _rng.randf_range(0.85, 1.15)
	_spawn_timer = maxf(interval, RiceRules.SPAWN_INTERVAL_MIN)
	_spawn_item()


func _tick_items(dt: float) -> void:
	for item in items:
		if not item.alive:
			continue
		item.y += item.vy * dt
		item.x += item.vx * dt
		item.rot += item.spin * dt
		# 横向漂移撞到边界就弹回来，别让米饭飞出场地
		if item.x < item.radius:
			item.x = item.radius
			item.vx = absf(item.vx)
		elif item.x > RiceRules.FIELD_W - item.radius:
			item.x = RiceRules.FIELD_W - item.radius
			item.vx = -absf(item.vx)

		if item.y >= catch_y() and absf(item.x - pot_x) <= RiceRules.POT_HALF_W + item.radius * 0.35:
			_catch(item)
		elif item.y >= RiceRules.GROUND_Y:
			_doom(item)
			missed += 1
			combo = 0
			item_missed.emit(item)
			score_changed.emit(score, combo, mult())
		if not _running:
			break
	_flush_doomed()


func _spawn_item() -> void:
	var item := FallItem.new()
	item.id = _next_id
	_next_id += 1
	item.kind = _roll_kind()
	item.radius = RiceRules.ITEM_R
	item.y = RiceRules.SPAWN_Y
	item.x = _rng.randf_range(item.radius + 8.0, RiceRules.FIELD_W - item.radius - 8.0)
	item.vy = RiceRules.fall_speed(wave) * _rng.randf_range(0.92, 1.12)
	if wave >= RiceRules.DRIFT_START_WAVE:
		item.vx = _rng.randf_range(-RiceRules.DRIFT_MAX, RiceRules.DRIFT_MAX)
	item.rot = _rng.randf_range(-PI, PI)
	# 米饭团只轻微摇摆（翻滚看起来像纸片），石头辣椒可以滚
	var spin_max := 0.8 if item.kind == RiceRules.Kind.WHITE or item.kind == RiceRules.Kind.GOLD else 2.2
	item.spin = _rng.randf_range(-spin_max, spin_max)
	items.append(item)
	item_spawned.emit(item)


func _roll_kind() -> RiceRules.Kind:
	var r := _rng.randf()
	var stone := RiceRules.stone_chance(wave)
	if r < stone:
		return RiceRules.Kind.STONE
	r -= stone
	if r < RiceRules.CHILI_CHANCE:
		return RiceRules.Kind.CHILI
	r -= RiceRules.CHILI_CHANCE
	if r < RiceRules.GOLD_CHANCE:
		return RiceRules.Kind.GOLD
	return RiceRules.Kind.WHITE


func _catch(item: FallItem) -> void:
	_doom(item)
	match item.kind:
		RiceRules.Kind.WHITE, RiceRules.Kind.GOLD:
			combo += 1
			best_combo = maxi(best_combo, combo)
			var base := RiceRules.SCORE_WHITE if item.kind == RiceRules.Kind.WHITE else RiceRules.SCORE_GOLD
			var gained := base * mult()
			score += gained
			caught += 1
			item_caught.emit(item, gained, combo)
			score_changed.emit(score, combo, mult())
		RiceRules.Kind.CHILI:
			combo = 0
			_spicy_left = RiceRules.SPICY_SECONDS
			chili_caught.emit(item, _spicy_left)
			score_changed.emit(score, combo, mult())
		RiceRules.Kind.STONE:
			combo = 0
			hearts = maxi(0, hearts - 1)
			stone_hit.emit(item, hearts)
			score_changed.emit(score, combo, mult())
			if hearts <= 0:
				_end()


func _doom(item: FallItem) -> void:
	if not item.alive:
		return
	item.alive = false
	_doomed.append(item)


func _flush_doomed() -> void:
	if _doomed.is_empty():
		return
	for d in _doomed:
		items.erase(d)
	_doomed.clear()


func _end() -> void:
	_running = false
	game_over.emit(score, caught, best_combo)
