extends LevelScriptBase
## adventure_04_10 —— 由同目录的 adventure_04_10.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	## 场景：泳池·浓雾 —— 槽位 / 底图 / 雾 / 昼夜 / 天降阳光全由场景脚本给出
	scene_name = SceneSettingRegistry.SCENE_FOG
	## 覆盖场景默认：原版 4-10 是雷雨夜（屏幕压暗，打雷时亮一下），且不放 BGM
	game_BGM = ConstLevelData.GameBGM.NoBGM
	is_rain = true
	is_lightning = true
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	## 传送带卡池(原版 4-10): 莲叶17 / 海蘑菇25 / 仙人掌27 / 裂荚29 / 杨桃30 / 南瓜头31 / 磁力菇32
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	17: 2,
	25: 2,
	27: 2,
	29: 2,
	30: 2,
	31: 2,
	32: 2
	})


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z016Jackbox,
		CharacterRegistry.ZombieType.Z017Balloon,
		CharacterRegistry.ZombieType.Z018Digger,
		CharacterRegistry.ZombieType.Z019Pogo,
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
	await start_battle(20, zombie_list)
