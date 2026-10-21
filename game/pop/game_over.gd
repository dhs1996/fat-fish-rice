class_name GameOverPanel
extends PanelBase

## 结算面板。用法：instantiate → setup(...) → show_panel(Ui.Layer.POP)。
## setup 必须在 show_panel **之前**调用：文本是在 on_init() 里刷的（那时 @onready 才就位）。
##
## 它不持有任何持久数据：分数由 BattleScene 传进来，最高分由 PlayerService 提供。

signal restart_requested()
signal menu_requested()

@onready var LblTitle: Label = %LblTitle
@onready var LblScore: Label = %LblScore
@onready var LblDetail: Label = %LblDetail
@onready var LblBest: Label = %LblBest
@onready var LblMeme: Label = %LblMeme
@onready var BtnRestart: Button = %BtnRestart
@onready var BtnMenu: Button = %BtnMenu

## 蓝色大肥鱼（DeepSeek娘）的社区梗台词，每局随机挑一句
const MEME_LINES: Array[String] = [
	"「你这吃白饭的蓝色大肥鱼」",
	"「我能去你家吃饭吗，就一碗」",
	"「我去吃饭，测完告诉我就行」",
	"「原来是高等模型」",
]

var _score: int = 0
var _rice: int = 0
var _best_combo: int = 0
var _best: int = 0
var _new_best: bool = false


func setup(score: int, rice: int, best_combo: int, best: int, new_best: bool) -> void:
	_score = score
	_rice = rice
	_best_combo = best_combo
	_best = best
	_new_best = new_best


func on_init() -> void:
	close_on_tap_outside = false
	LblTitle.text = "这些饭全归我了！" if _new_best else "锅空了…"
	LblScore.text = "%d" % _score
	LblDetail.text = "接住 %d 个饭团 · 最高连击 %d" % [_rice, _best_combo]
	LblBest.text = "最高分 %d" % _best
	LblMeme.text = MEME_LINES[randi() % MEME_LINES.size()]
	BtnRestart.text = "再来一碗"
	BtnMenu.text = "回主菜单"


func _bind(on: bool) -> void:
	if on:
		BtnRestart.pressed.connect(_on_restart)
		BtnMenu.pressed.connect(_on_menu)
	else:
		if BtnRestart.pressed.is_connected(_on_restart):
			BtnRestart.pressed.disconnect(_on_restart)
		if BtnMenu.pressed.is_connected(_on_menu):
			BtnMenu.pressed.disconnect(_on_menu)


func _on_restart() -> void:
	restart_requested.emit()
	close_me()


func _on_menu() -> void:
	menu_requested.emit()
	close_me()
