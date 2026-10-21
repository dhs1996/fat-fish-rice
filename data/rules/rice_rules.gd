class_name RiceRules
extends RefCounted

## 玩法数值表。**灰盒期形态**：本文件自己持有数据与默认值，不依赖配表管线
## （配表管线的形态见技能 godot-config-tables，数值定稿后再迁移）。
##
## 铁律：所有可调数值住在这里，业务代码里不许出现魔法数字。
## 调平衡只改本文件，改完跑 tools/verify.ps1。

## 掉落物种类。
##   WHITE / GOLD —— 饭团，接住加分（GOLD 稀有且高分）
##   CHILI         —— 辣椒，接住辣到：操作反转若干秒
##   STONE         —— 石头，接住砸锅：扣一颗心
enum Kind { WHITE, GOLD, CHILI, STONE }

# ── 场地（设计分辨率，与 project.godot 的 viewport 一致）────────────────
const FIELD_W := 1280.0
const FIELD_H := 720.0
## 米饭落到这条线算漏接（桌面高度）
const GROUND_Y := 664.0

# ── 肥鱼与锅 ────────────────────────────────────────────────────────
## 鱼身中心线的 y
const FISH_Y := 600.0
## 立绘在设计分辨率下的高度 / 脚底相对锚点的 y（脚底 = GROUND_Y，站在桌面上）
## 232 → 275 是为了让"手"落到锅底：立绘里她的手在顶部下方约 13%，
## 即 local = FEET_Y - 0.87 * CHAR_HEIGHT；275 时正好是 -175，等于锅底（POT_RIM_DY + 锅高）。
const CHAR_HEIGHT := 230.0
const CHAR_FEET_Y := 64.0
## 立绘水平补偿：鲸尾在立绘左边占了一大块，图心不等于身体中心（身体在图宽 66% 处），
## 所以要往左推一点，才能让"她本人"正好站在锅下面。
const CHAR_OFFSET_X := 12.0
## 横向移动速度（像素/秒）。实测取值依据：横穿全屏 1280 / 1150 ≈ 1.1 秒，
## 而米饭从出生落到锅口要 ~1.8 秒 —— 玩家总来得及赶到，但赶到后没时间犹豫。
const FISH_SPEED := 1150.0
## 锅口离角色锚点（FISH_Y）的 y 偏移（负数 = 上方）——它同时就是接饭判定线。
## 取值是算出来的：锅口 + 锅的绘制高度 必须停在立绘头顶之上（见 fish_view.gd 的
## CHAR_HEIGHT / POT_WIDTH / POT_ASPECT），否则锅会盖住角色的脸。
const POT_RIM_DY := -282.0
## 锅口半宽 = 接饭判定的横向半径（绘制宽度略大于它：AI 图的锅沿有壁厚，
## 玩家不会把那圈壁厚算成"应该接得住"的范围）
const POT_HALF_W := 78.0
## 锅能动到的左右边界（允许略微出屏，边角米饭也要接得到）
const POT_MIN_X := 34.0
## 接住这么多粒，锅里的米堆画到最满
const POT_PILE_FULL := 12

# ── 掉落 ────────────────────────────────────────────────────────────
## 出生位置（屏幕上方外）
const SPAWN_Y := -40.0
## 掉落物判定/绘制半径
const ITEM_R := 17.0
## 一个"波次"的时长（秒），难度全按波次算
const WAVE_SECONDS := 20.0
const FALL_SPEED_BASE := 200.0
const FALL_SPEED_PER_WAVE := 20.0
const FALL_SPEED_MAX := 560.0
const SPAWN_INTERVAL_BASE := 0.90
const SPAWN_INTERVAL_PER_WAVE := 0.075
const SPAWN_INTERVAL_MIN := 0.30
## 从第几波开始掉落物带横向漂移
const DRIFT_START_WAVE := 2
const DRIFT_MAX := 70.0

# ── 概率（石头随波次变多，辣椒与金米固定）──────────────────────────────
const GOLD_CHANCE := 0.07
const CHILI_CHANCE := 0.08
const STONE_CHANCE_BASE := 0.05
const STONE_CHANCE_PER_WAVE := 0.012
const STONE_CHANCE_MAX := 0.18

# ── 计分 ────────────────────────────────────────────────────────────
const SCORE_WHITE := 1
const SCORE_GOLD := 5
## 每这么多连击 +1 倍率
const COMBO_PER_MULT := 5
const MULT_MAX := 8

# ── 生命与"辣到" ────────────────────────────────────────────────────
const HEARTS_MAX := 3
const SPICY_SECONDS := 3.5


## 连击 → 倍率（1 起，封顶 MULT_MAX）
static func mult_for_combo(combo: int) -> int:
	return clampi(1 + combo / COMBO_PER_MULT, 1, MULT_MAX)


## 当前波次的掉落速度
static func fall_speed(wave: int) -> float:
	var w := maxi(1, wave)
	return minf(FALL_SPEED_BASE + FALL_SPEED_PER_WAVE * float(w - 1), FALL_SPEED_MAX)


## 当前波次的出生间隔（秒）
static func spawn_interval(wave: int) -> float:
	var w := maxi(1, wave)
	return maxf(SPAWN_INTERVAL_BASE - SPAWN_INTERVAL_PER_WAVE * float(w - 1), SPAWN_INTERVAL_MIN)


## 当前波次的石头概率
static func stone_chance(wave: int) -> float:
	var w := maxi(1, wave)
	return minf(STONE_CHANCE_BASE + STONE_CHANCE_PER_WAVE * float(w - 1), STONE_CHANCE_MAX)


## 接饭判定线（锅口所在的高度）
static func catch_y() -> float:
	return FISH_Y + POT_RIM_DY
