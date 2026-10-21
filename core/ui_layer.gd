extends Node

## 界面分层。对应 Egret 工程的 StageType{Panel,Battle,Pop,Tips,Top}：
## z 序是枚举，不是默契 —— 谁都不用再讨论 add_child 顺序。
## 枚举值刻意留间隔，方便以后插层。

enum Layer {
	BATTLE = 0,
	PANEL = 10,
	POP = 20,
	TIPS = 30,
	TOP = 40,
}

var _layers: Dictionary = {}


func _ready() -> void:
	for key in Layer:
		var value: int = Layer[key]
		var cl := CanvasLayer.new()
		cl.name = "Layer%d" % value
		cl.layer = value
		add_child(cl)
		_layers[value] = cl


## 取某一层的容器。界面一律挂这里，不要 add_child 到当前场景根。
func view(layer: int = Layer.PANEL) -> CanvasLayer:
	if not _layers.has(layer):
		push_error("Ui: 未定义的层 %d" % layer)
		return null
	return _layers[layer] as CanvasLayer
