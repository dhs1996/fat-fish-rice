extends Node

## 跨场景广播。**只收不属于任何单一状态持有者的全局事件。**
##
## 允许清单（新增事件必须先加进这里，否则不要广播）：
##   game_paused(paused)      全局暂停
##   scene_changing(target)   场景切换开始
##   run_ended(reason)        一局结束（死亡 / 通关 / 放弃）
##
## 不在这里的：
##   - 状态变化 → 由持有状态的服务自己 emit（见 services/player/player_service.gd）
##   - 父子 / 界面内部 → 直接 connect 对方的 signal，不绕路

signal game_paused(paused: bool)
signal scene_changing(target: String)
signal run_ended(reason: String)
