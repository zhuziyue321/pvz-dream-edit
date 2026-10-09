extends LevelScriptBase
## adventure_04_05 —— 由同目录的 adventure_04_05.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


## 本关三段戴夫对话：台词都在数据层，见 res://data/dave/dialog/adventure_04_05_*.tres
const DAVE_OPENING := preload("res://data/dave/dialog/adventure_04_05_opening.tres")
const DAVE_MORE_VASES := preload("res://data/dave/dialog/adventure_04_05_more_vases.tres")
const DAVE_LAST_VASES := preload("res://data/dave/dialog/adventure_04_05_last_vases.tres")


func _init() -> void:
	is_one_shot_flow = true
	## 砸罐子关不按批次存档：罐子不进存档，续玩恢复不出任何进度，只会导致一进关就跳到第 3 批
	game_round = 3
	is_save_multi_round_data = false
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.Puzzle
	is_day = false
	is_day_sun = false
	look_show_zombie = false
	can_choosed_card = false
	is_show_ready_set_plant = false
	## 进关就停在相机归位位（砸罐子没有预览僵尸 / 选卡，不该先拍房子）
	camera_init_x = MainGameCamera.CAM_POS_ORI.x
	monster_mode = ConstLevelData.E_MonsterMode.Null
	card_mode = ConstLevelData.E_CardMode.Null
	is_pot_mode = true
	pot_mode = ConstLevelData.E_PotMode.Fixd
	pot_col_range = Vector2i(6, 9)
	random_pot_plant.assign({
	1: 9,
	18: 2
	})
	random_pot_zombie.assign({
	1: 3,
	16: 1
	})
	pot_config_on_round.assign([{
	"pot_col_range": Vector2i(6, 9),
	"pot_hint_num": 0,
	"random_pot_plant": {
	1: 9,
	18: 2
	},
	"random_pot_zombie": {
	1: 3,
	16: 1
	}
	}, {
	"pot_col_range": Vector2i(5, 9),
	"pot_hint_num": 2,
	"random_pot_plant": {
	1: 7,
	6: 5,
	18: 1
	},
	"random_pot_zombie": {
	1: 4,
	5: 2,
	8: 1
	}
	}, {
	"pot_col_range": Vector2i(4, 9),
	"pot_hint_num": 3,
	"random_pot_plant": {
	1: 6,
	6: 6,
	13: 4
	},
	"random_pot_zombie": {
	1: 4,
	5: 2,
	9: 1,
	16: 2
	}
	}])
	## 本关通关掉落：裂荚射手（种子包）
	level_complete_loot = "split_pea_seed_packet"


func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z008Football,
		CharacterRegistry.ZombieType.Z009Jackson,
		CharacterRegistry.ZombieType.Z016Jackbox,
	]

	## 第 1 批：戴夫介绍玩法
	await dave_dialog(DAVE_OPENING)
	## 初始化小推车：砸罐子关不播「准备安放植物」，这里是本关唯一能上推车的地方
	await init_lawn_mover()
	## 第 1 批开战：罐子在进关时就摆好了。等到本批罐子全砸开 + 场上僵尸清空
	await start_battle(10, zombie_list)
	## 第 2 批：戴夫说话（戴夫再摆一批罐子）
	await dave_dialog(DAVE_MORE_VASES)
	## 第 2 批清场：清掉上批残留的植物 / 没砸开的罐子，再按第 2 轮配置摆出新一批（4 列）
	await clear_field()
	## 第 2 批开战：等到本批罐子全砸开 + 场上僵尸清空
	await start_battle(10, zombie_list)
	## 第 3 批：戴夫说话（戴夫摆最后一批罐子）
	await dave_dialog(DAVE_LAST_VASES)
	## 第 3 批清场：清掉上批残留，再按第 3 轮配置摆出新一批（5 列）
	await clear_field()
	## 第 3 批开战：最后一轮，打完由砸罐子玩法自己推 battle_finished 收尾（不判胜，见下一行）
	await start_battle(10, zombie_list)
	## 通关掉落：首次通关掉本关奖励（见 _init 里的 level_complete_loot），已通关过只出奖杯
	if is_curr_level_success():
		win_with_trophy_only()
	else:
		await gain(level_complete_loot)
