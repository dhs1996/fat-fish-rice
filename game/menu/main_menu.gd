class_name MainMenu
extends PanelBase

## 主菜单，同时也是「一局」的宿主：
## 开局时它把 BattleScene 挂到 Ui.Layer.BATTLE，然后把自己藏起来（不销毁），
## 等战斗发 exit_to_menu 再把自己显出来。它是一局的生命周期里唯一的知道"回来了该去哪"的人，
## 所以不需要 EventBus 或额外的流程服务。

const BATTLE_SCENE := preload("res://game/battle/battle.tscn")

@onready var LblBest: Label = %LblBest
@onready var BtnStart: Button = %BtnStart
@onready var BtnQuit: Button = %BtnQuit

var _battle: BattleScene = null
## 装饰用的鱼娘（同一个 FishView，纯摆着看）
var _deco: FishView = null


func on_init() -> void:
	close_on_tap_outside = false
	_deco = FishView.new()
	_deco.position = Vector2(RiceRules.FIELD_W - 220.0, 830.0)
	add_child(_deco)
	_refresh_best()


func _bind(on: bool) -> void:
	if on:
		PlayerService.best_score_changed.connect(_on_best_changed)
		BtnStart.pressed.connect(_on_start)
		BtnQuit.pressed.connect(_on_quit)
	else:
		if PlayerService.best_score_changed.is_connected(_on_best_changed):
			PlayerService.best_score_changed.disconnect(_on_best_changed)
		if BtnStart.pressed.is_connected(_on_start):
			BtnStart.pressed.disconnect(_on_start)
		if BtnQuit.pressed.is_connected(_on_quit):
			BtnQuit.pressed.disconnect(_on_quit)


func _refresh_best() -> void:
	LblBest.text = "最高分 %d" % PlayerService.best_score()


func _on_best_changed(best: int) -> void:
	LblBest.text = "最高分 %d" % best


func _on_start() -> void:
	start_battle()


func _on_quit() -> void:
	get_tree().quit()


## 开局：挂场景 → 订阅它的退出信号 → 藏起自己
func start_battle() -> void:
	if is_instance_valid(_battle):
		return
	var battle := BATTLE_SCENE.instantiate() as BattleScene
	if battle == null:
		push_error("battle.tscn 根节点应为 BattleScene(Node2D)")
		return
	_battle = battle
	Ui.view(Ui.Layer.BATTLE).add_child(battle)
	battle.exit_to_menu.connect(_on_battle_exit)
	_set_menu_shown(false)


func _on_battle_exit() -> void:
	if is_instance_valid(_battle):
		_battle.queue_free()
	_battle = null
	_refresh_best()
	_set_menu_shown(true)


func _set_menu_shown(shown: bool) -> void:
	visible = shown
	# 藏起来时别让装饰鱼继续每帧重画
	if _deco != null:
		_deco.set_process(shown)


## 自检钩子：headless 里点不了按钮，用这个走同一条开局路径。业务代码不要调。
func debug_start_battle() -> BattleScene:
	start_battle()
	return _battle
