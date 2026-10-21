extends SceneTree

## 全量脚本自检。在**真实运行上下文**里加载每个 .gd（= 强制编译），autoload 单例可见。
##
## 用法：
##   godot --headless --path <proj> --import                       # 必须先跑，否则跨文件 class_name 解析不到
##   godot --headless --path <proj> --script res://tools/check_all.gd
##
## ⚠ 本脚本的退出码**不能单独作为判定依据**，原因有两条，都是实测出来的：
##   1. `load()` 对**解析失败**的脚本仍返回非 null（拿到编译失败的 GDScriptResource），
##      所以「load 非 null」不等于「编译通过」。
##   2. 不能用 `reload()` 来补：对 autoload 脚本它必返回 ERR_ALREADY_IN_USE(22)，
##      对未 --import 的工程又会返回 ERR_PARSE_ERROR(43)，两种都是假失败。
##
## 所以：**权威判定 = 外层扫这次运行的日志**，出现
##   SCRIPT ERROR / Parse Error / Could not find base class / Failed to load script
## 即视为失败。verify.ps1 已按这个规则实现。
##
## 本脚本的价值：把**每一个**脚本都强制编译一遍（含没人 load 的死代码），
## 并把编译错误打进日志——这才是全量检查的意义。

const SCAN_ROOTS: Array[String] = [
	"res://core",
	"res://data",
	"res://game",
	"res://services",
]

var _null_loads: Array[String] = []
var _checked: int = 0


func _init() -> void:
	# 延到第一帧：autoload 单例已就位，解析上下文与真实运行一致
	call_deferred("_run")


func _run() -> void:
	var files: Array[String] = []
	for root in SCAN_ROOTS:
		_collect(root, files)

	for path in files:
		_checked += 1
		if load(path) == null:
			_null_loads.append(path)

	print("[check_all] scanned %d scripts, %d returned null" % [_checked, _null_loads.size()])
	for p in _null_loads:
		print("  X " + p)
	# 只把「load 返回 null」当硬失败；其余交给外层扫日志
	quit(1 if not _null_loads.is_empty() else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = d.get_next()
			continue
		var full := dir_path.path_join(entry)
		if d.current_is_dir():
			_collect(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()
