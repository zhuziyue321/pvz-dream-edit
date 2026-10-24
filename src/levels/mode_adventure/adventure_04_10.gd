extends LevelScriptBase
## adventure_04_10 —— 由同目录的 adventure_04_10.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	save_key = "101_3_0040"
	## 场景：泳池·浓雾 —— 槽位 / 底图 / 雾 / 昼夜 / 天降阳光全由场景脚本给出
	scene_name = SceneSettingRegistry.SCENE_FOG
	## 覆盖场景默认：原版 4-10 是雷雨夜（屏幕压暗，打雷时亮一下），且不放 BGM
	game_BGM = ConstLevelData.GameBGM.NoBGM
	is_rain = true
	is_lightning = true
	## 出怪倍率 = 3：原版暴雨夜（冒险 4-10 = mLevel 40，LawnApp::IsStormyNightLevel）的倍率
	## （Board.cpp:679-682）。此前漏配 = 默认 1
	zombie_multy = 3
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	## 传送带卡池(原版 4-10): 莲叶17 / 海蘑菇25 / 仙人掌27 / 裂荚29 / 杨桃30 / 南瓜头31 / 磁力菇32
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	&"lily_pad": 2,
	&"sea_shroom": 2,
	&"cactus": 2,
	&"split_pea": 2,
	&"star_fruit": 2,
	&"pumpkin": 2,
	&"magnet_shroom": 2
	})
	## 本关通关掉落：卷心菜投手（种子包）
	level_complete_loot = "cabbage_pult_seed_packet"


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[StringName] = [
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.BUCKET,
		ZombieIds.JACKBOX,
		ZombieIds.BALLOON,
		ZombieIds.DIGGER,
		ZombieIds.POGO,
	]

	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	## 首波 2 秒：原版暴雨夜 `mZombieCountDown = 200` tick
	await start_battle(20, zombie_list, 0.0, 2.0)
	## 通关掉落：首次通关掉本关奖励（见 _init 里的 level_complete_loot），已通关过只出奖杯
	if is_curr_level_success():
		win_with_trophy_only()
	else:
		await gain(level_complete_loot)
