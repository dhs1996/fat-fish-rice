class_name FallItem
extends RefCounted

## 一个掉落物的纯数据（会被 RiceSim 持有、被 RiceView 读取来画）。
## 刻意是 RefCounted 而不是 Node：仿真层不认识节点，表现层按这份数据画。

## 一局内唯一且递增的 id，表现层用它把 Node 和仿真数据对上
var id: int = 0
var kind: RiceRules.Kind = RiceRules.Kind.WHITE
var x: float = 0.0
var y: float = 0.0
## 竖向速度（像素/秒，向下为正）
var vy: float = 0.0
## 横向漂移（像素/秒）
var vx: float = 0.0
var radius: float = RiceRules.ITEM_R
## 当前旋转角度 / 旋转角速度（弧度、弧度每秒）
var rot: float = 0.0
var spin: float = 0.0
## false = 本帧已被接住或已漏掉，等待回收
var alive: bool = true
