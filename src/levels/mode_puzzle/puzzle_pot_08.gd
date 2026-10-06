extends LevelScriptBase
## puzzle_pot_08 —— 由同目录的 puzzle_pot_08.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	# 存档键写死：解谜模式 20 关合并成一页后按钮序号会变，写死后玩家存档不丢
	save_key = "103_0_0008"
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
	pot_col_range = Vector2i(2, 9)
	## 棕色神秘罐（植物）: 反向双发(49) x4 / 小喷菇(9) x7 / 窝瓜(18) x5 / 高坚果(24) x3
	pot_hint_num = 2
	## 棕色神秘罐（僵尸）: 玩偶匣(16) x8 / 跳跳(19) x4 / 普僵(1) x4
	random_pot_plant.assign({
	9: 7,
	18: 5,
	24: 3,
	49: 4
	})
	random_pot_zombie.assign({
	1: 4,
	16: 8,
	19: 4
	})


func run_flow(_mg: MainGameManager) -> void:
	## 开战
	await start_battle(-1, [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z016Jackbox,
		CharacterRegistry.ZombieType.Z019Pogo,
	])
