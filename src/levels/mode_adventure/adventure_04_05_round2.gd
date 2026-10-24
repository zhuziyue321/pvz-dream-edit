extends LevelScriptBase
## ★ 二周目版（adventure_04_05_round2）—— 二周目及以后进这一关时加载的就是本文件：
##   进关方按周目取脚本（LevelRegistry.get_adventure_level_id(关卡序号, 周目)），
##   正本 adventure_04_05.gd 与它是**同一关的两套脚本**，存档键仍是同一份（二周目的进度靠记录里的 Round 区分）。
##   本文件与正本的差异（见 docs/参考存档/二周目.md）：
##     · 波数：10 波，与一周目相同（本关按要求不加波）
##     · 开局锁定前 3 个随机卡槽：从本关能用的植物里随机挑 3 株占住前 3 槽，玩家只能改后面的槽
## adventure_04_05 —— 由同目录的 adventure_04_05.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


## 本关三段戴夫对话：台词都在数据层，见 res://data/dave/dialog/adventure_04_05_*.tres
const DAVE_OPENING := preload("res://data/dave/dialog/adventure_04_05_opening.tres")
const DAVE_MORE_VASES := preload("res://data/dave/dialog/adventure_04_05_more_vases.tres")
const DAVE_LAST_VASES := preload("res://data/dave/dialog/adventure_04_05_last_vases.tres")


func _init() -> void:
	save_key = "101_3_0035"
	## 二周目差异：开局锁定前 3 个随机卡槽 —— 从本关能用的植物里随机挑 3 株占住前 3 槽，
	## 玩家只能编辑第 4 个槽起的部分（机制与边界见 docs/参考存档/二周目.md）
	locked_random_card_num = 3
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
	&"pea_shooter_single": 9,
	&"squash": 2
	})
	random_pot_zombie.assign({
	&"norm": 3,
	&"jackbox": 1
	})
	pot_config_on_round.assign([{
	"pot_col_range": Vector2i(6, 9),
	"pot_hint_num": 0,
	"random_pot_plant": {
	&"pea_shooter_single": 9,
	&"squash": 2
	},
	"random_pot_zombie": {
	&"norm": 3,
	&"jackbox": 1
	}
	}, {
	"pot_col_range": Vector2i(5, 9),
	"pot_hint_num": 2,
	"random_pot_plant": {
	&"pea_shooter_single": 7,
	&"snow_pea": 5,
	&"squash": 1
	},
	"random_pot_zombie": {
	&"norm": 4,
	&"bucket": 2,
	&"football": 1
	}
	}, {
	"pot_col_range": Vector2i(4, 9),
	"pot_hint_num": 3,
	"random_pot_plant": {
	&"pea_shooter_single": 6,
	&"snow_pea": 6,
	&"hypno_shroom": 4
	},
	"random_pot_zombie": {
	&"norm": 4,
	&"bucket": 2,
	&"jackson": 1,
	&"jackbox": 2
	}
	}])
	## 本关通关掉落：裂荚射手（种子包）
	level_complete_loot = "split_pea_seed_packet"


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[StringName] = [
		ZombieIds.NORM,
		ZombieIds.BUCKET,
		ZombieIds.FOOTBALL,
		ZombieIds.JACKSON,
		ZombieIds.JACKBOX,
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
