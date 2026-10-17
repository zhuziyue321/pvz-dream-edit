extends RefCounted
## 锤子模组的**共享设置**：解锁关卡 + 秒杀 / 伤害 / 范围 / 冷却（开关 / 方式 / 时长 / 波数）的键名、默认值与静态读值口
##
## ★ 为什么单独一个文件，而不是都放在 `hammer_mod.gd` 里：
##   `hammer_mod.gd` 要 `HandComponentHammerMod.new()`，而 `HandComponentHammerMod` 又要读
##   `get_radius()` / `get_damage_value()` / `is_kill_mode()` / 冷却四件套 ——
##   两边互相 `preload` 就是一个环（GDScript 循环 preload 直接报 Cyclic，编译不过）。
##   把「谁都要读、自己谁也不依赖」的这一块抽出来，环就断了（与 `glove_settings.gd` 同款处理）。
##
## 值存在**模组存档文件**的 `[hammer]` 段（与开关同一份，见 `ModManager`），
## 读写一律走 `ModManager.get/set_mod_value()`，不走 `ConfigService`。

## 解锁：通关冒险 2-4（关卡序号 14）之后锤子才归玩家，从 2-5 起卡槽里有它
## （关卡序号口径见本体的 `ConstUnlockLevel.get_adventure_level_name()`：(区域-1)*10 + 小关号）
## 选点理由：2-4 是夜晚最后一关，通关时正好也是戴夫把图鉴交给玩家的节点，
## 往后（2-5 起）开始出现一大波密集僵尸，锤子在这里给才有用武之地；更早给会削弱布局与阳光规划的压力。
const UNLOCK_ADVENTURE_LEVEL := 14

## 设置在**模组存档文件**里的键名（`[hammer]` 段）
const SETTING_KEY_KILL_MODE := "kill_mode"
const SETTING_KEY_DAMAGE := "damage_value"
const SETTING_KEY_RADIUS := "radius"
const SETTING_KEY_COOLDOWN_ENABLED := "cooldown_enabled"
const SETTING_KEY_COOLDOWN_TIME := "cooldown_time"
const SETTING_KEY_COOLDOWN_BY_WAVE := "cooldown_by_wave"
const SETTING_KEY_COOLDOWN_WAVE := "cooldown_wave"

## 伤害数值的可调范围与默认值
const DAMAGE_VALUE_MIN := 100
const DAMAGE_VALUE_MAX := 5000
const DAMAGE_VALUE_STEP := 100
const DAMAGE_VALUE_DEFAULT := 1800
## 范围半径的可调范围与默认值（像素）
const RADIUS_MIN := 40.0
const RADIUS_MAX := 240.0
const RADIUS_STEP := 20.0
const RADIUS_DEFAULT := 80.0
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
## 各开关的默认值：数值伤害（不秒杀）、无冷却、冷却按秒数 —— 与手套模组同口径
const KILL_MODE_DEFAULT := false
const COOLDOWN_ENABLED_DEFAULT := false
const COOLDOWN_BY_WAVE_DEFAULT := false


## 通关进度是否已够拿到锤子（静态：解锁口径属于模组，本体不需要知道）
static func is_unlocked(max_success_adventure_level: int) -> bool:
	return max_success_adventure_level >= UNLOCK_ADVENTURE_LEVEL


## 是否一键秒杀（模组页面里的开关；开着就忽略伤害数值）
static func is_kill_mode() -> bool:
	return bool(ModManager.get_mod_value(
			ModIds.HAMMER, SETTING_KEY_KILL_MODE, KILL_MODE_DEFAULT))


## 伤害数值：一锤对范围内每只僵尸造成的伤害（秒杀开关打开时不看这个值）
static func get_damage_value() -> int:
	return clampi(int(ModManager.get_mod_value(
			ModIds.HAMMER, SETTING_KEY_DAMAGE, DAMAGE_VALUE_DEFAULT)),
			DAMAGE_VALUE_MIN, DAMAGE_VALUE_MAX)


## 范围半径（像素）：以点击点为圆心，圆内（按僵尸受击框）都挨这一锤
static func get_radius() -> float:
	return clampf(float(ModManager.get_mod_value(
			ModIds.HAMMER, SETTING_KEY_RADIUS, RADIUS_DEFAULT)),
			RADIUS_MIN, RADIUS_MAX)


## 挥完之后是否要冷却
static func is_cooldown_enabled() -> bool:
	return bool(ModManager.get_mod_value(
			ModIds.HAMMER, SETTING_KEY_COOLDOWN_ENABLED, COOLDOWN_ENABLED_DEFAULT))


## 冷却时长（秒）：挥完一锤之后要等多少秒才能再挥
static func get_cooldown_time() -> float:
	return clampf(float(ModManager.get_mod_value(
			ModIds.HAMMER, SETTING_KEY_COOLDOWN_TIME, COOLDOWN_TIME_DEFAULT)),
			COOLDOWN_TIME_MIN, COOLDOWN_TIME_MAX)


## 冷却是否按**波数**算（模组页面里的开关）：开 = 用 `get_cooldown_wave()`（每开一波扣 1），
## 关 = 用 `get_cooldown_time()`（按秒数倒数）
static func is_cooldown_by_wave() -> bool:
	return bool(ModManager.get_mod_value(
			ModIds.HAMMER, SETTING_KEY_COOLDOWN_BY_WAVE, COOLDOWN_BY_WAVE_DEFAULT))


## 冷却波数（波）：挥完一锤之后要等开过几波僵尸才能再挥（每开一波扣 1，扣到 0 冷却好）
static func get_cooldown_wave() -> int:
	return clampi(int(ModManager.get_mod_value(
			ModIds.HAMMER, SETTING_KEY_COOLDOWN_WAVE, COOLDOWN_WAVE_DEFAULT)),
			COOLDOWN_WAVE_MIN, COOLDOWN_WAVE_MAX)
