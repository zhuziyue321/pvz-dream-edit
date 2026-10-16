extends LevelScriptBase
## vase_zombie —— 自制关卡样例：砸罐子 + 我是僵尸（由同目录的 vase_zombie.tres 迁移而来）
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 不覆写 run_flow()：跑 LevelScriptBase 的默认流程
## （保龄球红线 → 小推车 → 准备安放植物 → 开战），与原默认时间轴等价。


func _init() -> void:
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.Puzzle
	is_day = false
	is_day_sun = false
	is_lawn_mover = false
	look_show_zombie = false
	can_choosed_card = false
	monster_mode = ConstLevelData.E_MonsterMode.Null
	zombie_refresh_types.assign([
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.POLE_VAULTER,
		ZombieIds.BUCKET,
		ZombieIds.PAPER,
		ZombieIds.SCREEN_DOOR,
		ZombieIds.FOOTBALL,
		ZombieIds.JACKSON,
	])
	start_sun = 300
	## 「我是僵尸」模式的出战卡：1 / 3 / 5 号僵尸
	prechosen_cards = ResourceCardReference.create_zombie_list([1, 3, 5])
	pot_mode = ConstLevelData.E_PotMode.Fixd
	pot_col_range = Vector2i(5, 6)
	## 罐子打开前也能一直看到罐内是什么（目前只有自制关卡在用）
	is_can_look_random_res_pot = true
	random_pot_num_on_fixed_mode = Vector3i(0, 0, 5)
	is_zombie_mode = true
	plant_col_on_zombie_mode = 5
	all_plants_weight_on_zombie_mode.assign({
	&"pea_shooter_single": 1,
	&"sun_flower": 1
	})
	## 保龄球红线：第 4 列之后只能进僵尸
	is_bowling_stripe = true
	plant_cell_col_j = 4
	plant_cell_can_use.assign({
	"left_can_plant": false,
	"left_can_zombie": false,
	"right_can_plant": false,
	"right_can_zombie": true
	})
