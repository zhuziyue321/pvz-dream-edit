extends LevelScriptBase
## adventure_03_10 —— 由同目录的 adventure_03_10.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	save_key = "101_2_0030"
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	## 传送带关用 Ultimate Battle,来源: https://plantsvszombies.wiki.gg/wiki/Music_(PvZ)
	game_BG = ConstLevelData.GameBg.Pool
	game_BGM = ConstLevelData.GameBGM.UltimateBattle
	is_day_sun = false
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	## 传送带卡池(原版 3-10): 莲叶17 / 三线19 / 水草20 / 辣椒21 / 地刺22 / 火炬树桩23 / 高坚果24
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	&"lily_pad": 2,
	&"three_peater": 2,
	&"tangle_kelp": 2,
	&"jalapeno": 2,
	&"caltrop": 2,
	&"torch_wood": 2,
	&"tall_nut": 2
	})
	## 本关通关掉落：海蘑菇（种子包）
	level_complete_loot = "sea_shroom_seed_packet"


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[StringName] = [
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.BUCKET,
		ZombieIds.SNORKLE,
		ZombieIds.ZAMBONI,
		ZombieIds.BOBSLED,
		ZombieIds.DOLPHINRIDER,
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
	## 首波 1 秒：原版迷你 boss（冒险 1-10 / 2-10 / 3-10）`mZombieCountDown = 100` tick
	await start_battle(-1, zombie_list, 0.0, 1.0)
	## 通关掉落：首次通关掉本关奖励（见 _init 里的 level_complete_loot），已通关过只出奖杯
	if is_curr_level_success():
		win_with_trophy_only()
	else:
		await gain(level_complete_loot)
