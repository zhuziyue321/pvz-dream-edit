extends LevelScriptBase
## puzzle_pot_02 —— 由同目录的 puzzle_pot_02.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	# 存档键写死：解谜模式 20 关合并成一页后按钮序号会变，写死后玩家存档不丢
	save_key = "103_0_0002"
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.Puzzle
	is_day = false
	is_day_sun = false
	is_lawn_mover = false
	look_show_zombie = false
	can_choosed_card = false
	is_show_ready_set_plant = false
	monster_mode = ConstLevelData.E_MonsterMode.Null
	card_mode = ConstLevelData.E_CardMode.Null
	is_pot_mode = true
	pot_mode = ConstLevelData.E_PotMode.Fixd
	pot_col_range = Vector2i(4, 9)
	## 棕色神秘罐（植物）: 反向双发(49) x7 / 寒冰射手(6) x3 / 坚果墙(4) x3 / 土豆地雷(5) x2
	pot_hint_num = 0
	## 棕色神秘罐（僵尸）: 铁桶(5) x3 / 普僵(1) x6 / 玩偶匣(16) x1
	random_pot_plant.assign({
	4: 3,
	5: 2,
	6: 3,
	49: 7
	})
	random_pot_zombie.assign({
	1: 6,
	5: 3,
	16: 1
	})


func run_flow(_mg: MainGameManager) -> void:
	## 开战
	await start_battle(-1, [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z016Jackbox,
	])
