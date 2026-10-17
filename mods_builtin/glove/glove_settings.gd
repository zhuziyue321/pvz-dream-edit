extends RefCounted
## 手套模组的**共享设置**：解锁口径 + 冷却（开关 / 方式 / 时长 / 波数）的键名、默认值与静态读值口
##
## ★ 为什么单独一个文件，而不是都放在 `glove_mod.gd` 里：
##   `glove_mod.gd` 要 `HandComponentGlove.new()`，而 `HandComponentGlove` 又要读
##   `is_unlocked()` / `is_cooldown_enabled()` / `get_cooldown_time()` ——
##   两边互相 `preload` 就是一个环（GDScript 循环 preload 直接报 Cyclic，编译不过）。
##   把「谁都要读、自己谁也不依赖」的这一块抽出来，环就断了。
##
## 值存在**模组存档文件**的 `[glove]` 段（与开关同一份，见 `ModManager`），
## 读写一律走 `ModManager.get/set_mod_value()`，不走 `ConfigService`。

## 解锁口径：**和商店里的园艺手套同一时刻拿到** —— 在商店买下「园艺手套」（$1000，需先通关 5-5
## 解锁禅境花园才上架）的那一刻，关卡内手套同时到手，之后每一局的卡槽里都有它。
##
## 为什么改成这个口径：原版里它们本来就是**同一只手套**（原版手套只用于禅境花园搬花盆），
## 关卡内搬植物是这只手套的同人扩展用法；跟着商店的买断记录走，玩家只买一次、只记一份存档，
## 不用再单独维护一个「解锁关卡序号」（旧口径是通关 4-5，见工作记录 2026-10-13）。
## 判定直接读本体的买断记录：`GlobalGameState.is_garden_tool_bought()`
## （存档键 `garden_data.bought_garden_tools`，见 `global_garden_state.gd`）。
## 工具枚举：GardenManager.E_GardenTool.GardeningGlove（园艺手套 = 4）。
const GLOVE_GARDEN_TOOL: GardenManager.E_GardenTool = GardenManager.E_GardenTool.GardeningGlove

## 冷却设置在**模组存档文件**里的键名（`[glove]` 段；与开关同一份文件，不用改 `ConfigService`）
const SETTING_KEY_COOLDOWN_ENABLED := "cooldown_enabled"
const SETTING_KEY_COOLDOWN_TIME := "cooldown_time"
const SETTING_KEY_COOLDOWN_BY_WAVE := "cooldown_by_wave"
const SETTING_KEY_COOLDOWN_WAVE := "cooldown_wave"
## 冷却时长的可调范围与默认值（秒）
const COOLDOWN_TIME_MIN := 0.5
const COOLDOWN_TIME_MAX := 60.0
const COOLDOWN_TIME_STEP := 0.5
const COOLDOWN_TIME_DEFAULT := 5.0
## 冷却波数的可调范围与默认值（波）：每开一波扣 1，扣到 0 就冷却好
const COOLDOWN_WAVE_MIN := 1
const COOLDOWN_WAVE_MAX := 20
const COOLDOWN_WAVE_STEP := 1
const COOLDOWN_WAVE_DEFAULT := 2
## 冷却开关的默认值：**关** —— 原版没有这个玩法，旧行为就是"搬完一株接着搬"
const COOLDOWN_ENABLED_DEFAULT := false
## 冷却方式的默认值：**按秒数** —— 按波数是新加的一种口径，默认沿用原来的秒数
const COOLDOWN_BY_WAVE_DEFAULT := false


## 玩家是否已在商店买下园艺手套 —— 买了 = 关卡内手套也到手（两者同一时刻获取）
## 静态：解锁口径属于模组，本体不需要知道「关卡内手套」这回事
## ⚠️ 读的是**当前存档**的买断记录（`Global.global_game_state`），还没进游戏时读不到，返回 false
static func is_unlocked() -> bool:
	if Global == null or Global.global_game_state == null:
		return false
	return Global.global_game_state.is_garden_tool_bought(GLOVE_GARDEN_TOOL)


## 手套搬完之后是否要冷却（模组页面里的开关；值落在模组存档文件里本模组那一段）
## 静态：冷却口径属于模组，`HandComponentGlove` 每局都要读它，本体完全不认识这回事
static func is_cooldown_enabled() -> bool:
	return bool(ModManager.get_mod_value(
			ModIds.GLOVE, SETTING_KEY_COOLDOWN_ENABLED, COOLDOWN_ENABLED_DEFAULT))


## 冷却时长（秒）：搬完一株之后要等多少秒才能再用手套
static func get_cooldown_time() -> float:
	return clampf(float(ModManager.get_mod_value(
			ModIds.GLOVE, SETTING_KEY_COOLDOWN_TIME, COOLDOWN_TIME_DEFAULT)),
			COOLDOWN_TIME_MIN, COOLDOWN_TIME_MAX)


## 冷却是否按**波数**算（模组页面里的开关）：开 = 用 `get_cooldown_wave()`（每开一波扣 1），
## 关 = 用 `get_cooldown_time()`（按秒数倒数）
static func is_cooldown_by_wave() -> bool:
	return bool(ModManager.get_mod_value(
			ModIds.GLOVE, SETTING_KEY_COOLDOWN_BY_WAVE, COOLDOWN_BY_WAVE_DEFAULT))


## 冷却波数（波）：搬完一株之后要等开过几波僵尸才能再用手套（每开一波扣 1，扣到 0 冷却好）
static func get_cooldown_wave() -> int:
	return clampi(int(ModManager.get_mod_value(
			ModIds.GLOVE, SETTING_KEY_COOLDOWN_WAVE, COOLDOWN_WAVE_DEFAULT)),
			COOLDOWN_WAVE_MIN, COOLDOWN_WAVE_MAX)
