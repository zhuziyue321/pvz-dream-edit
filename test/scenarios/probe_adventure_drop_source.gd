extends RefCounted
## 探针：冒险关卡的通关掉落「写在关卡自己身上」，全项目没有「关卡序号 -> 战利品」的常量表
##
## 覆盖（都是静态检查，不用进关）：
##   1. 50 关逐关对照：LevelRegistry 按关卡序号查到的掉落植物 == 期望值
##      （真正的声明在各关 `_init()` 的 level_complete_loot 上 —— 那是**战利品名字**，
##       这里按关卡序号反查，顺带验这个名字在 LootRegistry 里登记过）
##   2. 掉道具的 5 关（1-4 铁铲 / 2-4 大图鉴 / 3-4 车钥匙 / 4-4 玉米卷 / 5-4 洒水壶）
##      战利品贴图对得上、且没有植物
##   3. 掉植物的关有植物、没有贴图（两类互斥）
##   4. 没有掉落的 6 关（x-9 / 5-10）确实查不到东西
## 机器可读汇总：最后一行 [ADVDROP] result=PASS|FAIL failed=<n>

## 期望的掉落植物：键 = 冒险关卡序号(1-1 = 1 …… 5-10 = 50)，值为该关给的植物
## 数据来源：PVZ 原版冒险模式（与原先写在 ConstPlantUnlock 上的那份一致）
const EXPECT_PLANT: Dictionary = {
	1: CharacterRegistry.PlantType.P002SunFlower,		## 1-1 向日葵
	2: CharacterRegistry.PlantType.P003CherryBomb,		## 1-2 樱桃炸弹
	3: CharacterRegistry.PlantType.P004WallNut,			## 1-3 坚果
	5: CharacterRegistry.PlantType.P005PotatoMine,		## 1-5 土豆地雷
	6: CharacterRegistry.PlantType.P006SnowPea,			## 1-6 寒冰射手
	7: CharacterRegistry.PlantType.P007Chomper,			## 1-7 大嘴花
	8: CharacterRegistry.PlantType.P008PeaShooterDouble, ## 1-8 双发射手
	10: CharacterRegistry.PlantType.P009PuffShroom,		## 1-10 小喷菇
	11: CharacterRegistry.PlantType.P010SunShroom,		## 2-1 阳光菇
	12: CharacterRegistry.PlantType.P011FumeShroom,		## 2-2 大喷菇
	13: CharacterRegistry.PlantType.P012GraveBuster,		## 2-3 墓碑吞噬者
	15: CharacterRegistry.PlantType.P013HypnoShroom,		## 2-5 魅惑菇
	16: CharacterRegistry.PlantType.P014ScaredyShroom,	## 2-6 胆小菇
	17: CharacterRegistry.PlantType.P015IceShroom,		## 2-7 寒冰菇
	18: CharacterRegistry.PlantType.P016DoomShroom,		## 2-8 毁灭菇
	20: CharacterRegistry.PlantType.P017LilyPad,			## 2-10 睡莲
	21: CharacterRegistry.PlantType.P018Squash,			## 3-1 窝瓜
	22: CharacterRegistry.PlantType.P019ThreePeater,		## 3-2 三线射手
	23: CharacterRegistry.PlantType.P020TangleKelp,		## 3-3 缠绕海草
	25: CharacterRegistry.PlantType.P021Jalapeno,		## 3-5 火爆辣椒
	26: CharacterRegistry.PlantType.P022Caltrop,			## 3-6 地刺
	27: CharacterRegistry.PlantType.P023TorchWood,		## 3-7 火炬树桩
	28: CharacterRegistry.PlantType.P024TallNut,			## 3-8 高坚果
	30: CharacterRegistry.PlantType.P025SeaShroom,		## 3-10 海蘑菇
	31: CharacterRegistry.PlantType.P026Plantern,		## 4-1 路灯花
	32: CharacterRegistry.PlantType.P027Cactus,			## 4-2 仙人掌
	33: CharacterRegistry.PlantType.P028Blover,			## 4-3 三叶草
	35: CharacterRegistry.PlantType.P029SplitPea,		## 4-5 裂荚射手
	36: CharacterRegistry.PlantType.P030StarFruit,		## 4-6 杨桃
	37: CharacterRegistry.PlantType.P031Pumpkin,			## 4-7 南瓜
	38: CharacterRegistry.PlantType.P032MagnetShroom,	## 4-8 磁力菇
	40: CharacterRegistry.PlantType.P033CabbagePult,		## 4-10 卷心菜投手
	41: CharacterRegistry.PlantType.P034FlowerPot,		## 5-1 花盆
	42: CharacterRegistry.PlantType.P035CornPult,		## 5-2 玉米投手
	43: CharacterRegistry.PlantType.P036CoffeeBean,		## 5-3 咖啡豆
	45: CharacterRegistry.PlantType.P037Garlic,			## 5-5 大蒜
	46: CharacterRegistry.PlantType.P038UmbrellaLeaf,	## 5-6 叶子保护伞
	47: CharacterRegistry.PlantType.P039MariGold,		## 5-7 金盏花
	48: CharacterRegistry.PlantType.P040MelonPult,		## 5-8 西瓜投手
}

## 掉道具（不是植物）的关卡：序号 -> 贴图文件名里的关键字
const EXPECT_ITEM: Dictionary = {
	4: "Shovel",		## 1-4 铁铲
	14: "Almanac",	## 2-4 大图鉴
	24: "CarKeys",	## 3-4 戴夫的车钥匙
	34: "Taco",		## 4-4 玉米卷
	44: "WateringCan",	## 5-4 禅境花园洒水壶
}

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 冒险模式通关掉落:声明写在关卡脚本自己身上 ==========")
	await a.wait(1.0)
	_check_all_levels(a)
	_check_unlock(a)
	_finish(a)


#region 断言
## 逐个关卡序号查过去：查不到关卡 = 这一关没写掉落；查到了就逐项对照期望值
func _check_all_levels(a) -> void:
	a.log("")
	a.log("STEP1 1-1 ~ 5-10 逐关对照")
	for level in range(1, 51):
		var data := LevelRegistry.get_adventure_level_data(level)
		var level_name: String = ConstUnlockLevel.get_adventure_level_name(level)
		if data == null:
			_check(a, "%s 有对应的关卡脚本" % level_name, false, "LevelRegistry 查不到这一关")
			continue
		var plant := LevelRegistry.get_adventure_level_reward_plant(level)
		## 本关声明的战利品名字（"" = 本关没有奖励，掉奖杯兜底）
		var loot: String = data.level_complete_loot
		var expect_plant: Variant = EXPECT_PLANT.get(level, null)
		var expect_item: Variant = EXPECT_ITEM.get(level, null)
		if expect_plant == null and expect_item == null:
			_check(a, "%s 没有通关掉落（只有奖杯）" % level_name,
				plant == CharacterRegistry.PlantType.Null
					and (loot.is_empty() or loot == LootRegistry.TROPHY),
				str(plant) + " / " + loot)
			continue
		_check(a, "%s 的战利品名登记过（%s）" % [level_name, loot], LootRegistry.has(loot), loot)
		if expect_item != null:
			var icon := LootRegistry.get_texture(loot)
			_check(a, "%s 掉的是道具 %s" % [level_name, expect_item],
				icon != null and expect_item in icon.resource_path,
				loot + " / " + str(icon))
			_check(a, "%s 掉道具就不再给植物" % level_name,
				plant == CharacterRegistry.PlantType.Null, str(plant))
			continue
		_check(a, "%s 掉的是植物 %s" % [level_name, _plant_name(expect_plant)],
			plant == expect_plant, str(plant))
		_check(a, "%s 掉植物就不再用贴图战利品" % level_name,
			LootRegistry.get_texture(loot) == null, loot)


## 解锁侧走的是同一份声明：通关 1-2 解锁樱桃炸弹，重复解锁不再返回，1-4（掉道具）不解锁植物
func _check_unlock(a) -> void:
	a.log("")
	a.log("STEP2 通关解锁查的是同一份声明")
	var state = Global.global_game_state
	var kept: Array[CharacterRegistry.PlantType] = state.curr_plant.duplicate()
	state.curr_plant.assign([CharacterRegistry.PlantType.P001PeaShooterSingle])

	var new_unlock := state.unlock_plant_on_adventure_level(2)
	_check(a, "通关 1-2 解锁樱桃炸弹",
		new_unlock.size() == 1 and new_unlock[0] == CharacterRegistry.PlantType.P003CherryBomb,
		str(new_unlock))
	_check(a, "解锁写进了 curr_plant",
		state.curr_plant.has(CharacterRegistry.PlantType.P003CherryBomb), str(state.curr_plant))
	_check(a, "再解锁一次不再返回新植物",
		state.unlock_plant_on_adventure_level(2).is_empty(), str(state.curr_plant))
	_check(a, "1-4 掉的是道具，不解锁植物",
		state.unlock_plant_on_adventure_level(4).is_empty())
	_check(a, "1-9 没有奖励，不解锁植物",
		state.unlock_plant_on_adventure_level(9).is_empty())

	state.curr_plant.assign(kept)


func _plant_name(plant_type) -> String:
	return str(Global.character_registry.get_plant_info(
		int(plant_type) as CharacterRegistry.PlantType,
		CharacterRegistry.PlantInfoAttribute.PlantName))


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[ADVDROP] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
