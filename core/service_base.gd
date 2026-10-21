class_name ServiceBase
extends Node

## 服务基类：状态 + 存档 + 自己 emit 的 signal 都在子类里。
## 谁有状态谁 emit —— signal 只在持有状态的类里定义与 emit，别处只 connect。
##
## state 统一是 Dictionary（JSON 友好、手改存档无痛）。
## 需要更强的约束就把它包成 Resource 或专门的 RefCounted 行类，
## 但**不要**让两个服务各存同一份数据的一半。

## 这个服务的存档键。空串 = 不落档。
var _save_key: String = ""
## 存档分段，取值见 services/save_scope_const.gd。
## 刻意声明成 String：分段的意义是业务规则，框架层不认识它。
var _save_scope: String = ""
## 本服务的状态。不落档的服务只把它当进程内缓存。
var state: Dictionary = {}


func save() -> bool:
	if _save_key.is_empty():
		push_error("%s: 没有 save_key，无法落档" % name)
		return false
	return SaveSys.save(_save_key, state, _save_scope)


## 读档到 state（不存在或坏数据时 state 变空字典，由子类补默认值）
func load_state() -> Dictionary:
	if _save_key.is_empty():
		return {}
	var loaded: Variant = SaveSys.load_state(_save_key, _save_scope)
	state = loaded if loaded is Dictionary else {}
	return state


func remove_save() -> bool:
	if _save_key.is_empty():
		return false
	return SaveSys.erase(_save_key, _save_scope)
