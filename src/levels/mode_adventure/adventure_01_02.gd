extends LevelScriptBase
## adventure_01_02 —— 由同目录的 adventure_01_02.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。
##
## 本关教学（向日葵）就写在 run_flow() 里：提示条 + 箭头 + 等玩家操作，三样工具拼起来。


func _init() -> void:
	save_key = "101_0_0002"
	## 本关专用地图：5 行草坪里只有中间 3 行铺了草皮（1-2 / 1-3 共用这一张）
	## 地图由关卡自己指定，不再靠「为本关单开一个场景枚举」来区分（见 docs/参考存档/地图实现.md）
	map_data = preload("res://data/map/map_front_5row.tres") as ResourceMapData


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [CharacterRegistry.ZombieType.Z001Norm]

	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 初始化小推车
	await init_lawn_mover()
	## 准备安放植物（原版红字）
	await ready_set_plant()
	if not is_curr_level_success():
		## 本关教学只在还没通关过 1-2 时播（原版教程只在冒险模式第一轮出现）
		await _tutorial_flow()
	## 开战：10 波，出怪表里只有普通僵尸
	await start_battle(10, zombie_list)


## 本关教学：教玩家种向日葵（顺序照搬原版 1-2）
## （台词取自原版 ADVICE_* 条目，见 data/strings/lawn_strings.txt）
func _tutorial_flow() -> void:
	## 允许操作：先让玩家能点卡片 / 种植，此时还不出怪、不天降阳光
	await allow_operation()
	## 箭头指到向日葵的种子包上
	await arrow_card(CharacterRegistry.PlantType.P002SunFlower)
	await hint("向日葵是非常重要的植物！")
	await wait_take_card(CharacterRegistry.PlantType.P002SunFlower)
	## 教玩家把向日葵种下去
	await hint("点击草地种下你的种子！")
	await wait_plant(1, CharacterRegistry.PlantType.P002SunFlower)
	## 再种两株，凑够三棵向日葵
	## 教学排在开战之前，天降阳光还没启动，靠教程掉两颗阳光把这一段补上
	## （原版这段教学与开战同时进行，玩家一边种一边收天上掉的阳光）
	await arrow_card(CharacterRegistry.PlantType.P002SunFlower)
	await hint("至少要种下三棵向日葵！")
	await spawn_sun()
	await spawn_sun()
	await wait_plant(2, CharacterRegistry.PlantType.P002SunFlower)
	await hide_arrow()
	## 夸一句，停一停让玩家看清发生了什么
	await hint("干得漂亮！")
	await wait(2.0)
	## 收尾：关掉提示条（箭头已经在上面收了）
	await hint("")
