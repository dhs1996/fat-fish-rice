extends Node

## 画面自检（只在 --shot 时由 game/entry.gd 挂上）：
## 依次截「主菜单 / 对局 / 结算」三张 PNG 到 --shot 指定的目录，然后退出。
##
##   godot --path <proj> -- --shot D:/dev/godot/tmp/shots
##
## 为什么不能加 --headless：headless 不渲染，viewport 截图是空的。
## 判定看三件事：日志里的 err=0、目标目录里三张 PNG 存在、人眼看得过去。

const SAFETY_SECONDS := 40.0

var _out_dir: String = "user://shots"
var _failed: bool = false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var idx := args.find("--shot")
	if idx >= 0 and idx + 1 < args.size():
		_out_dir = args[idx + 1]
	if DirAccess.make_dir_recursive_absolute(_out_dir) != OK:
		push_error("[shot] 建不了目录: " + _out_dir)
		_failed = true
	# 兜底：任何一步卡住都不该让进程挂着
	get_tree().create_timer(SAFETY_SECONDS, true, false, true).timeout.connect(_on_safety_timeout)
	_run()


func _on_safety_timeout() -> void:
	push_error("[shot] %.0f 秒没跑完，强制退出" % SAFETY_SECONDS)
	get_tree().quit(1)


func _run() -> void:
	await _wait_frames(8)
	_capture("1_menu.png")

	var entry := get_parent() as GameEntry
	if entry == null:
		push_error("[shot] 父节点不是 GameEntry")
		get_tree().quit(1)
		return
	var battle := entry.debug_start_battle()
	if battle == null:
		push_error("[shot] 开局失败")
		get_tree().quit(1)
		return

	await _wait_frames(4)
	battle.debug_advance(7.0)
	await _wait_frames(4)
	_capture("2_battle.png")

	battle.debug_game_over()
	await _wait_frames(10)
	_capture("3_game_over.png")

	print("[shot] %s -> %s" % ["OK" if not _failed else "FAIL", _out_dir])
	get_tree().quit(1 if _failed else 0)


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _capture(file_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_error("[shot] 取不到 viewport 图像")
		_failed = true
		return
	var path := _out_dir.path_join(file_name)
	var err := img.save_png(path)
	print("[shot] %s err=%d size=%s" % [path, err, str(img.get_size())])
	if err != OK:
		_failed = true
