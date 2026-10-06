extends LevelScriptBase
## adventure_04_04 —— 由同目录的 adventure_04_04.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	## 场景：泳池·浓雾 —— 槽位 / 底图 / BGM / 雾 / 昼夜 / 天降阳光全由场景脚本给出
	scene_name = SceneSettingRegistry.SCENE_FOG
	drop_unlock_on_level_complete = true
	drop_unlock_tip = "你找到了戴夫的玉米卷，商店上架了新商品！"
	drop_unlock_icon = preload("res://assets/image/main_game_item/Taco.png")


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z015Dolphinrider,
		CharacterRegistry.ZombieType.Z017Balloon,
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
