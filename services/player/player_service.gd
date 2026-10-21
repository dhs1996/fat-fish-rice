extends ServiceBase

## 玩家档案服务：持有**跨局**的永久数据（最高分 / 累计接住的米饭 / 局数）。
##
## 边界：一局之内的分数、连击、心属于 RiceSim —— 它才是那一局状态的唯一持有者。
## 本服务只在一局结束时收一次结果，所以不存在"同一份数据两处各存一半"。
## 谁有状态谁 emit：刷新纪录由本服务自己广播，界面只订阅。

signal best_score_changed(best: int)
signal run_recorded(score: int, is_new_best: bool)

const KEY_BEST := "best_score"
const KEY_TOTAL_RICE := "total_rice"
const KEY_RUNS := "runs"


func _ready() -> void:
	_save_key = "profile"
	_save_scope = SaveScope.META
	_ensure_state()


## 读档；没有或坏了就补默认值（抗脏数据）
func _ensure_state() -> void:
	load_state()
	if not state.has(KEY_BEST):
		state[KEY_BEST] = 0
	if not state.has(KEY_TOTAL_RICE):
		state[KEY_TOTAL_RICE] = 0
	if not state.has(KEY_RUNS):
		state[KEY_RUNS] = 0
	save()


func best_score() -> int:
	return int(state.get(KEY_BEST, 0))


func total_rice() -> int:
	return int(state.get(KEY_TOTAL_RICE, 0))


func runs() -> int:
	return int(state.get(KEY_RUNS, 0))


## 记一局结果并落档。
## @return 本局是否刷新了最高分
func record_run(score: int, rice: int) -> bool:
	state[KEY_RUNS] = runs() + 1
	state[KEY_TOTAL_RICE] = total_rice() + maxi(0, rice)
	var is_new_best := score > best_score()
	if is_new_best:
		state[KEY_BEST] = score
	save()
	if is_new_best:
		best_score_changed.emit(best_score())
	run_recorded.emit(score, is_new_best)
	return is_new_best
