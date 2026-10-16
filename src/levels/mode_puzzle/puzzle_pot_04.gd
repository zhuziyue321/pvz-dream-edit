extends LevelScriptBase
## puzzle_pot_04 —— 由同目录的 puzzle_pot_04.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	# 存档键写死：解谜模式 20 关合并成一页后按钮序号会变，写死后玩家存档不丢
	save_key = "103_0_0004"
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
	## 棕色神秘罐（植物）: 魅惑菇(13) x4 / 反向双发(49) x4 / 小喷菇(9) x11
	pot_hint_num = 2
	## 棕色神秘罐（僵尸）: 玩偶匣(16) x8 / 橄榄球(8) x1 / 普僵(1) x7
	random_pot_plant.assign({
	&"puff_shroom": 11,
	&"hypno_shroom": 4,
	&"pea_shooter_double_reverse": 4
	})
	random_pot_zombie.assign({
	&"norm": 7,
	&"football": 1,
	&"jackbox": 8
	})


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 开战
	await start_battle(-1, [
		ZombieIds.NORM,
		ZombieIds.FOOTBALL,
		ZombieIds.JACKBOX,
	])
