class_name PanelBase
extends Control

## 界面基类。对标 Egret 工程的 core.Panel：界面一致性收口在这里，
## 各界面不用各写一遍遮罩 / 点空白关闭 / 销毁幂等 / 关闭回调。
##
## 子类要做的事：
##   1. extends PanelBase，实现 on_init()（@onready 已就绪）
##   2. 在 _bind() 里成对 connect / disconnect
##   3. 关闭统一走 close_me()，不要自己 queue_free()

## 皮肤里可选的模态遮罩（约定唯一名 %BgMask）。没有就是 null。
@onready var BgMask: ColorRect = (get_node_or_null("%BgMask") as ColorRect) if has_node("%BgMask") else null

## 点面板外空白处是否关掉自己。整屏界面（主菜单这种被点没就剩黑屏的）覆盖成 false。
var close_on_tap_outside: bool = true

var _tap_blocker: Control = null
var _destroyed: bool = false
var _close_cb: Callable = Callable()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# 全屏挡点击块：只负责拦住背后的点击，不负责好看。
	# 遮罩/底色一律由各界面自己的场景声明，否则会和 BgMask 叠成两层。
	_tap_blocker = Control.new()
	_tap_blocker.name = "TapBlocker"
	_tap_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tap_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_tap_blocker.gui_input.connect(_on_blocker_input)
	add_child(_tap_blocker)
	move_child(_tap_blocker, 0)   # 放到最底层：皮肤里的按钮盖在它上面，点击先到按钮
	_bind(true)
	on_init()


## 子类初始化。此时 @onready 字段已赋值。
func on_init() -> void:
	pass


## 统一注册 / 注销：注册和注销走同一段代码，漏注销在结构上就难发生。
## 子类覆写，示例：
##   if on: PlayerService.credit_changed.connect(_on_credit)
##   elif PlayerService.credit_changed.is_connected(_on_credit):
##       PlayerService.credit_changed.disconnect(_on_credit)
func _bind(on: bool) -> void:
	if on:
		pass


func _on_blocker_input(event: InputEvent) -> void:
	if not close_on_tap_outside:
		return
	if event is InputEventMouseButton and event.pressed:
		on_tap_outside()
		accept_event()


## 点空白处的处理，子类可覆盖。
## 默认关掉自己；"关闭要走回调交给调用方"的界面覆盖成调自己的关闭入口。
func on_tap_outside() -> void:
	close_me()


## 关闭的唯一入口：子类可覆盖成走调用方的关闭流程。
func close_me() -> void:
	destroy()


## 幂等：queue_free() 是延迟的，重复调用会重复触发 _close_cb。
func destroy() -> void:
	if _destroyed or is_queued_for_deletion():
		return
	_destroyed = true
	_bind(false)
	on_destroy()
	if _close_cb.is_valid():
		_close_cb.call()
	queue_free()


func on_destroy() -> void:
	pass


## 打开界面：挂到 Ui 层并记录关闭回调。
func show_panel(layer: int = Ui.Layer.PANEL, on_close: Callable = Callable()) -> PanelBase:
	_close_cb = on_close
	Ui.view(layer).add_child(self)
	return self
