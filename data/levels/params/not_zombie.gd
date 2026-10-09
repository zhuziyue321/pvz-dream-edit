extends LevelScriptBase
## not_zombie —— 自制关卡样例：坚果保龄球（由同目录的 not_zombie.tres 迁移而来）
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 不覆写 run_flow()：跑 LevelScriptBase 的默认流程
## （保龄球红线 → 小推车 → 准备安放植物 → 开战），与原默认时间轴等价。


func _init() -> void:
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.MiniGame
	is_day = false
	is_day_sun = false
	look_show_zombie = false
	can_choosed_card = false
	max_wave = 20
	zombie_refresh_types.assign([
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z004PoleVaulter,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z006Paper,
		CharacterRegistry.ZombieType.Z007ScreenDoor,
		CharacterRegistry.ZombieType.Z008Football,
		CharacterRegistry.ZombieType.Z009Jackson,
	])
	## 只有传送带：出战卡由传送带发，玩家不选卡
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	## 传送带随机池 = 7 张植物 + 4 张僵尸（键 = 角色编号，值 = 相对权重）
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	4: 2, 5: 1, 8: 2, 13: 2, 15: 1, 23: 2, 41: 1
	})
	conveyor_weights.append_array(ResourceCardWeight.create_zombie_weights({
	1: 1, 3: 2, 8: 1, 9: 1
	}))
	## 传送带固定顺序：第 0 张发 8 号僵尸，第 1 张发 13 号植物
	conveyor_order.assign({
	0: ResourceCardReference.create(ResourceCardReference.CardType.Zombie, 8),
	1: ResourceCardReference.create(ResourceCardReference.CardType.Plant, 13),
	})
	## 保龄球红线：第 4 列之后只能进僵尸，左侧只能种植物
	is_bowling_stripe = true
	plant_cell_col_j = 4
	plant_cell_can_use.assign({
	"left_can_plant": true,
	"left_can_zombie": false,
	"right_can_plant": false,
	"right_can_zombie": true
	})
