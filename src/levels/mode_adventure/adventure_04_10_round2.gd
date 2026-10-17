extends LevelScriptBase
## ★ 二周目版（adventure_04_10_round2）—— 二周目及以后进这一关时加载的就是本文件：
##   进关方按周目取脚本（LevelRegistry.get_adventure_level_id(关卡序号, 周目)），
##   正本 adventure_04_10.gd 与它是**同一关的两套脚本**，存档键仍是同一份（二周目的进度靠记录里的 Round 区分）。
##   本文件与正本的差异（见 docs/参考存档/二周目.md）：
##     · 波数：20 → 30 波（普通关二周目多 10 波）
##     · 开局锁定前 3 个随机卡槽：从本关能用的植物里随机挑 3 株占住前 3 槽，玩家只能改后面的槽
## adventure_04_10 —— 由同目录的 adventure_04_10.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	## 二周目差异：开局锁定前 3 个随机卡槽 —— 从本关能用的植物里随机挑 3 株占住前 3 槽，
	## 玩家只能编辑第 4 个槽起的部分（机制与边界见 docs/参考存档/二周目.md）
	locked_random_card_num = 3
	## 场景：泳池·浓雾 —— 槽位 / 底图 / 雾 / 昼夜 / 天降阳光全由场景脚本给出
	scene_name = SceneSettingRegistry.SCENE_FOG
	## 覆盖场景默认：原版 4-10 是雷雨夜（屏幕压暗，打雷时亮一下），且不放 BGM
	game_BGM = ConstLevelData.GameBGM.NoBGM
	is_rain = true
	is_lightning = true
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
	await start_battle(30, zombie_list)
	## 通关掉落：首次通关掉本关奖励（见 _init 里的 level_complete_loot），已通关过只出奖杯
	if is_curr_level_success():
		win_with_trophy_only()
	else:
		await gain(level_complete_loot)
