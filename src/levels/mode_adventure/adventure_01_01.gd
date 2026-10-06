extends LevelScriptBase
## adventure_01_01 —— 教程关（原版冒险模式 1-1）
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
##
## 本关的教程就是**关卡流程里的一段**：一句话一个 await，
## 「箭头指哪 → 说什么台词 → 等玩家做什么」全在 run_flow() 里排着，翻这一个文件就知道本关教了什么。
## 三个工具拼起来就是教程：提示条（hint）、箭头（arrow_*）、等玩家操作（wait_*），
## 全都是关卡自己的快捷工具，本体不认识「教程」这回事。
##
## 教程能不能跑到底，依赖一条前提：**首次打 1-1 的玩家手里只有豌豆射手一张卡**
## （植物按关解锁，选卡阶段「卡槽数 >= 拥有植物卡数」时系统锁卡、按序固定把豌豆射手选满）。
## 所以下面 wait_take_card / wait_plant 都敢指定豌豆射手 —— 别的卡这时候还没解锁。
## 玩家已经通关过 1-1 时那条分支（看 run_flow）不播教程，不受这条约束影响。


func _init() -> void:
	save_key = "101_0_0001"
	## 本关专用地图：5 行草坪里按原版只有最中间 1 行铺了草皮（第一天只开一条道）
	## 地图由关卡自己指定，不再靠「为 1-1 单开一个场景枚举」来区分（见 docs/参考存档/地图实现.md）
	map_data = preload("res://data/map/map_front_1row.tres") as ResourceMapData
	start_sun = 150


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [CharacterRegistry.ZombieType.Z001Norm]

	## 预览：镜头拉到草坪右侧，让玩家先看一眼马上要面对的是什么
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 移回视角
	await camera_back()
	## 初始化小推车：本关新手教程不走「准备安放植物aaaa」，在这里让推车从屏幕外左侧开到位
	await init_lawn_mover()
	## 允许操作：从这一刻起玩家能点卡片 / 种植 / 收阳光了，但还没出怪
	await allow_operation()
	if not is_curr_level_success():
		## 新手教程只在还没通关过 1-1 时播
		await _tutorial_flow()
	else:
		## 已经通关过：教程跳过，红字照常播（ PREPARE YOUR DEFENSES 那一段）
		await ready_set_plant()
	## 战斗：10 波，出怪表里只有普通僵尸（1-1 只放最基础的那一只）
	await start_battle(10, zombie_list)


## 新手教程：一句话一个 await，顺序照搬原版 1-1 的教学节奏
## （台词取自原版 ADVICE_* 条目，见 data/strings/lawn_strings.txt）
func _tutorial_flow() -> void:
	## 箭头指到豌豆射手的种子包上
	await arrow_card(CharacterRegistry.PlantType.P001PeaShooterSingle)
	## 教玩家把种子包捡起来
	await hint("点击种子包，把它捡起来！")
	await wait_take_card(CharacterRegistry.PlantType.P001PeaShooterSingle)
	## 手上拿着东西了，撤回箭头，别挡着草地
	await hide_arrow()
	## 教玩家把植物种下去
	await hint("点击草地种下你的种子！")
	await wait_plant(1, CharacterRegistry.PlantType.P001PeaShooterSingle)
	## 夸一句，停一停让玩家看清发生了什么
	await hint("干得漂亮！")
	await wait(4.0)
	## 掉一颗阳光下来，教玩家收阳光
	await spawn_sun()
	await arrow_sun()
	await hint("点击收集掉落的阳光！")
	await wait_collect_sun()
	## 再掉一颗，让玩家攒够种第二株豌豆射手的阳光
	await spawn_sun()
	await hint("继续收集阳光！\n你需要他们来种下更多植物！")
	await wait_sun_enough(100)
	## 阳光够了，先让玩家自己动手：4 秒内种下了就往下走
	await hint("太好了！你已经收集到了足够\n进行下一次种植的阳光！")
	if not await wait_plant_timeout(1, CharacterRegistry.PlantType.P001PeaShooterSingle, 4.0):
		## 等了 4 秒还没动手，才补这一句教学（卡片要玩家自己捡，不给箭头）
		await hint("点击豌豆射手，再种一棵！")
		await wait_plant(1, CharacterRegistry.PlantType.P001PeaShooterSingle)
	await hint("别让僵尸靠近你的房子！")
	await wait(4.0)
	## 收尾：关掉提示条与箭头（没有「教程收尾」会替你收，用完自己关）
	await hint("")
	await hide_arrow()
