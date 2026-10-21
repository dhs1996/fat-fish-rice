extends Node

## 存档读写。本类**不认识任何业务概念**：只知道「一个键 + 可选的键空间分段」。
## 分段的意义（哪一档装什么、什么时候清）属于业务层，见 services/save_scope_const.gd。
## 键格式：player_<cur_player>_<scope>_<key>；不分段时 player_<cur_player>_<key>

var cur_player: String = "default"


func _path(key: String, scope: String = "") -> String:
	var head := "player_%s_" % cur_player
	var name := (head + scope + "_" + key) if scope != "" else (head + key)
	return "user://saves/" + name + ".json"


func save(key: String, value: Variant, scope: String = "") -> bool:
	var path := _path(key, scope)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveSys 写入失败: " + path)
		return false
	# 缩进保存：开发期手改存档是常态，能 diff 才能排查
	f.store_string(JSON.stringify(value, "\t"))
	f.close()
	return true


func load_state(key: String, scope: String = "") -> Variant:
	var path := _path(key, scope)
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	return JSON.parse_string(text)


func erase(key: String, scope: String = "") -> bool:
	var path := _path(key, scope)
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
