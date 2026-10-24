extends "res://src/mods/mod_base.gd"
## 僵尸卡：「我是僵尸」关卡发僵尸卡牌 + 换上 PVZ2 的僵尸卡槽 / 僵尸卡面 / 脑光
##
## ## 为什么是模组（而不是本体功能）
##
##   · 原版 PVZ1 没有「在关卡里直接放下僵尸」这件事，所以本体那条僵尸卡通道是**关着**的
##     （`ConstFeatureSwitch.ZOMBIE_CARD_ENABLED = false`；只有控制台「调试模式」会临时打开）。
##   · 「我是僵尸」关卡恰恰要靠僵尸卡开局 —— 没有它那关发不出牌、也判不了负
##     （没有僵尸卡时 `MgMLoseManager.get_min_zombie_sun_cost()` 返回 0 = 不判负）。
##   · 打开那个总开关是**全局**的：普通关卡的选卡界面也会冒出僵尸页，玩家能在正常关里放僵尸。
##     所以本模组不去动总开关，只在「我是僵尸」关卡里**直接把僵尸卡发进出战卡槽**。
##
## ## 生效范围
##
## **只在 `game_para.is_zombie_mode` 的关卡里**（别的关卡一行代码都不走）。
##
## ## 做了什么
##
##   1. 发僵尸卡 —— 关卡自己写的僵尸预选卡优先；没写就用默认四张（普通 / 路障 / 撑杆 / 铁桶）
##   2. 出战卡槽底图 → PVZ2 的 `ZombieSeedBank`（446×87）
##   3. 僵尸卡卡面 → PVZ2 的 `ZombieSeed`（50×70）
##   4. 选卡界面（待选区）背景 → PVZ2 的 `SeedChooser_Background_I_Zombie`（465×513）
##   5. 脑光 —— 被啃的脑子上冒粉色星芒：啃一口闪一下，脑子被吃掉时爆一下
##   6. 脑子阳光 —— 天上掉下来的阳光换成 PVZ2 的 `BrainSun`（只换外观，收集行为不变）
##
## 素材来自本机那份 PVZ2 DLC（`../PVZ_DLC/_unpacked/images/`），随模组一起分发。

const ZombieCardWiring := preload("zombie_card_wiring.gd")


## 模组 id（登记在 `ModIds`，与 `ModManager.MOD_SCRIPT_PATHS` 一一对应）
func get_mod_id() -> StringName:
	return ModIds.ZOMBIE_CARD


## 模组显示名
func get_mod_name() -> String:
	return "僵尸卡（我是僵尸）"


## 模组说明：一句话写清它改了什么、为什么不属于原版
func get_mod_description() -> String:
	return "「我是僵尸」关卡发僵尸卡牌（原来只有开调试模式才有），并换上 PVZ2 的僵尸卡槽 / 僵尸卡面 / 脑光。"


## 分类：改写规则（改的是「僵尸卡能不能用」这条既有规则，不新增单位）
func get_mod_categories() -> Array[StringName]:
	return [ModCategory.OVERRIDE_RULE]


## 每局接线：只有「我是僵尸」关卡才装
func install_to_main_game(main_game: MainGameManager) -> void:
	if main_game == null or main_game.game_para == null:
		return
	if not main_game.game_para.is_zombie_mode:
		return
	var wiring = ZombieCardWiring.new()
	wiring.name = "ZombieCardWiring"
	main_game.add_child(wiring)
	wiring.setup(main_game)
