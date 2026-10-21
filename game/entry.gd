class_name GameEntry
extends Node

## 入口。职责只有三件：打印启动信息、挂主菜单、跑命令行自检钩子。
## 业务逻辑不要往这里堆 —— 一局的流程在 game/battle/battle.gd，
## 菜单与"回到菜单"的宿主在 game/menu/main_menu.gd。
##
## 自检钩子（都由 tools/verify.ps1 驱动）：
##   --demo          不开窗口跑一遍「开局 → 推进 → 结算」，断言状态确实在动
##   --shot <dir>    非 headless 跑一遍并截图（菜单 / 对局 / 结算），见 tools/shotter.gd

const MAIN_MENU := preload("res://game/menu/main_menu.tscn")

var _menu: MainMenu = null


func _ready() -> void:
	print("[rice] boot: Godot %s | 最高分 %d | 累计接住 %d 个 | 已玩 %d 局" % [
		Engine.get_version_info()["string"],
		PlayerService.best_score(),
		PlayerService.total_rice(),
		PlayerService.runs(),
	])
	_menu = MAIN_MENU.instantiate() as MainMenu
	if _menu == null:
		push_error("main_menu.tscn 根节点必须 extends PanelBase")
		get_tree().quit(1)
		return
	_menu.show_panel(Ui.Layer.PANEL)
	_run_cli_hooks()


## 给自检工具用：走和「点开始接饭」完全相同的开局路径
func debug_start_battle() -> BattleScene:
	if _menu == null:
		return null
	return _menu.debug_start_battle()


func _run_cli_hooks() -> void:
	var args := OS.get_cmdline_user_args()
	if "--demo" in args:
		_demo()
	elif "--shot" in args:
		var script := load("res://tools/shotter.gd") as GDScript
		if script == null:
			push_error("--shot: 载入 tools/shotter.gd 失败")
			get_tree().quit(1)
			return
		add_child(script.new())


## 交互链路自检：开局 → 推进 8 秒 → 结算，断言分数/接住数真的在动、存档真的落了。
## 真实画面另见 tools/shotter.gd；这个只保证链路没断。
func _demo() -> void:
	var battle := debug_start_battle()
	if battle == null:
		push_error("--demo: 开局失败")
		get_tree().quit(1)
		return
	battle.debug_advance(8.0)
	var stats := battle.debug_stats()
	var score := int(stats.get("score", 0))
	var caught := int(stats.get("caught", 0))
	print("[rice] demo: 推进 8 秒 → 分数=%d 接住=%d 漏接=%d 最高连击=%d 心=%d 波次=%d 场上=%d" % [
		score,
		caught,
		int(stats.get("missed", 0)),
		int(stats.get("best_combo", 0)),
		int(stats.get("hearts", 0)),
		int(stats.get("wave", 0)),
		int(stats.get("alive", 0)),
	])
	var ok := score > 0 and caught > 0
	battle.debug_game_over()
	var best := PlayerService.best_score()
	print("[rice] demo: 结算 → 最高分=%d 累计=%d 个 局数=%d" % [
		best, PlayerService.total_rice(), PlayerService.runs(),
	])
	if best < score:
		ok = false
		print("[rice] demo: 存档没记住本局最高分")
	print("[rice] demo: %s" % ("OK" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
