extends LevelScriptBase
## puzzle_zombie_09 —— 由同目录的 puzzle_zombie_09.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	# 存档键写死：解谜模式 20 关合并成一页后按钮序号会变，写死后玩家存档不丢
	save_key = "103_1_0009"
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.Puzzle
	is_day = false
	is_day_sun = false
	is_lawn_mover = false
	look_show_zombie = false
	can_choosed_card = false
	monster_mode = ConstLevelData.E_MonsterMode.Null
	start_sun = 50
	max_choosed_card_num = 8
	prechosen_cards = ResourceCardReference.create_zombie_list([25, 3, 4, 5, 21, 18, 22, 8])
	is_zombie_mode = true
	## 原版本关的纸板植物: 豌豆射手(1) / 向日葵(2) / 坚果墙(4) / 土豆地雷(5) / 寒冰射手(6)
	##                    大嘴花(7) / 大喷菇(11) / 胆小菇(14) / 窝瓜(18) / 三线射手(19)
	##                    高坚果(24) / 裂荚射手(29) / 杨桃(30) / 磁力菇(32)
	plant_col_on_zombie_mode = 5
	all_plants_weight_on_zombie_mode.assign({
	1: 2,
	2: 6,
	4: 2,
	5: 2,
	6: 2,
	7: 2,
	11: 2,
	14: 1,
	18: 2,
	19: 2,
	24: 2,
	29: 2,
	30: 2,
	32: 2
	})
	all_must_plants_on_zombie_mode.assign({
	2: 6
	})
	is_bowling_stripe = true
	plant_cell_col_j = 4
	plant_cell_can_use.assign({
	"left_can_plant": false,
	"left_can_zombie": false,
	"right_can_plant": false,
	"right_can_zombie": true
	})


func run_flow(mg: MainGameManager) -> void:
	if mg.curr_game_round == 1:
		## 保龄球红线（仅第 1 轮）
		await bowling_stripe()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(-1, [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z004PoleVaulter,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z008Football,
		CharacterRegistry.ZombieType.Z018Digger,
		CharacterRegistry.ZombieType.Z021Bungi,
		CharacterRegistry.ZombieType.Z022Ladder,
		CharacterRegistry.ZombieType.Z025Imp,
	])
