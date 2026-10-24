extends LevelScriptBase
## adventure_02_10 —— 由同目录的 adventure_02_10.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	save_key = "101_1_0020"
	## 传送带关用 Ultimate Battle,来源: https://plantsvszombies.wiki.gg/wiki/Music_(PvZ)
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.UltimateBattle
	is_day = false
	is_day_sun = false
	is_have_tombston = true
	init_tombstone_num = 13
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	&"puff_shroom": 2,
	&"fume_shroom": 2,
	&"grave_buster": 2,
	&"hypno_shroom": 2,
	&"scaredy_shroom": 2,
	&"ice_shroom": 2,
	&"doom_shroom": 2
	})
	## 本关通关掉落：睡莲（种子包）
	level_complete_loot = "lily_pad_seed_packet"


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[StringName] = [
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.SCREEN_DOOR,
		ZombieIds.FOOTBALL,
		ZombieIds.JACKSON,
	]

	## 戴夫推销卡槽扩充（2-2 ~ 3-4 这几关都有；传送带关不能选卡，本句空转）
	await dave_sell_card_slot()
	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	## 首波 1 秒：原版迷你 boss（冒险 1-10 / 2-10 / 3-10）`mZombieCountDown = 100` tick
	await start_battle(20, zombie_list, 0.0, 1.0)
	## 通关掉落：首次通关掉本关奖励（见 _init 里的 level_complete_loot），已通关过只出奖杯
	if is_curr_level_success():
		win_with_trophy_only()
	else:
		await gain(level_complete_loot)
