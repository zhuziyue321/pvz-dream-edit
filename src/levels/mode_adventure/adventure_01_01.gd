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
## 所以下面「选择植物」那一步与 wait_plant 都敢指定豌豆射手 —— 别的卡这时候还没解锁。
## 玩家已经通关过 1-1 时那条分支（看 run_flow）不播教程，不受这条约束影响。
##
## 「选择植物」这一步**本关自己等两个信号**（见文末 _wait_select_plant），没用 wait_take_card：
## 只等「捡起种子包」会漏掉玩家手快连着点完「拿卡 → 种下」的情况，那时手上已经空了，
## 再等捡卡就永远等不到，教程卡死在「点击种子包」上、一局都开不了战。


func _init() -> void:
	save_key = "101_0_0001"
	## 本关专用地图：5 行草坪里按原版只有最中间 1 行铺了草皮（第一天只开一条道）
	## 地图由关卡自己指定，不再靠「为 1-1 单开一个场景枚举」来区分（见 docs/参考存档/地图实现.md）
	map_data = preload("res://data/map/map_front_1row.tres") as ResourceMapData
	## 二周目起直接给满 5 行草皮（原版口径，见 docs/参考存档/二周目.md）
	map_data_from_second_round = preload("res://data/map/map_front.tres") as ResourceMapData
	start_sun = 150
	## 本关通关掉落：向日葵（种子包）
	level_complete_loot = "sunflower_seed_packet"


func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[StringName] = [ZombieIds.NORM]

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
		await _tutorial_flow(mg)
	else:
		## 已经通关过：教程跳过，红字照常播（ PREPARE YOUR DEFENSES 那一段）
		await ready_set_plant()
	## 战斗：4 波，出怪表里只有普通僵尸（1-1 只放最基础的那一只）
	await start_battle(4, zombie_list)
	## 通关掉落：首次通关掉本关奖励（见 _init 里的 level_complete_loot），已通关过只出奖杯
	if is_curr_level_success():
		win_with_trophy_only()
	else:
		await gain(level_complete_loot)


## 新手教程：一句话一个 await，顺序照搬原版 1-1 的教学节奏
## （台词取自原版 ADVICE_* 条目，见 data/strings/lawn_strings.txt）
##
## [mg] 主游戏管理器：「选择植物」那一步要拿它接草坪格子的「植物种下」信号
func _tutorial_flow(mg: MainGameManager) -> void:
	## 箭头指到豌豆射手的种子包上
	await arrow_card(PlantIds.PEA_SHOOTER_SINGLE)
	## 教玩家把种子包捡起来
	await hint("点击种子包，把它捡起来！")
	## 等「选择植物」完成：捡起种子包 / 已经种下去了，谁先到都算过
	await _wait_select_plant(mg)
	## 手上拿着东西了，撤回箭头，别挡着草地
	await hide_arrow()
	## 教玩家把植物种下去
	await hint("点击草地种下你的种子！")
	await wait_plant(1, PlantIds.PEA_SHOOTER_SINGLE)
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
	if not await wait_plant_timeout(1, PlantIds.PEA_SHOOTER_SINGLE, 4.0):
		## 等了 4 秒还没动手，才补这一句教学（卡片要玩家自己捡，不给箭头）
		await hint("点击豌豆射手，再种一棵！")
		await wait_plant(1, PlantIds.PEA_SHOOTER_SINGLE)
	await hint("别让僵尸靠近你的房子！")
	await wait(4.0)
	## 收尾：关掉提示条与箭头（没有「教程收尾」会替你收，用完自己关）
	await hint("")
	await hide_arrow()


#region 教程第一步：「选择植物」（捡起种子包 / 已经种下，谁先到都算过）
## 「选择植物」这一步完成：**捡起豌豆射手的种子包** 或 **草坪上种下了豌豆射手**
##
## 只认「捡起种子包」会漏掉一种情况：玩家手快，把「拿卡 → 种下」连着点完了 ——
## 那一刻手上已经空了，再等捡卡就永远等不到，教程卡死在第一句提示上、僵尸一只都不出。
## 所以这里两个信号都接：**下一步的种植都完成了，选择植物当然也算完成**。
signal select_plant_done


## 等「选择植物」这一步：上面两个信号谁先到，就往下走
##
## [mg] 主游戏管理器：接草坪格子的「植物种下」信号要用它的 plant_cell_manager
func _wait_select_plant(mg: MainGameManager) -> void:
	## 先看看这一步是不是**已经完成**了 —— 是就不用等信号：
	##   1. 手上已经拿着豌豆射手的种子包（提示还没出完玩家就把卡点了）
	if LevelWaitCondition.is_holding_card(mg, PlantIds.PEA_SHOOTER_SINGLE):
		return
	##   2. 草坪上已经有豌豆射手（玩家手快，「拿卡 → 种下」连着点完了 ——
	##      下一步的种植都做完了，选择植物当然也算完成；本关开局草坪是空的，有就是玩家种的）
	if LevelWaitCondition.count_lawn_plants(mg, PlantIds.PEA_SHOOTER_SINGLE) > 0:
		return
	## 信号一：草坪上种下了豌豆射手（每个格子各有一个信号，逐个接上）
	for row_cells: Array in mg.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			if plant_cell != null:
				plant_cell.signal_plant_create.connect(_on_peashooter_planted)
	## 信号二：玩家把豌豆射手的种子包捡到了手上（拿卡是瞬间动作，只能靠这个事件）
	EventBus.subscribe(ConstEventName.HAND_CARD_TAKE, _on_peashooter_taken)
	## 两个信号谁先到都会把 select_plant_done 发出去，等到这一下就往下走
	await select_plant_done
	## 这一步已经过了，两个信号都断掉，别影响后面的教程
	EventBus.unsubscribe(ConstEventName.HAND_CARD_TAKE, _on_peashooter_taken)
	## 玩家中途退出关卡时主游戏已经没了，别再去访问它的格子
	if not is_instance_valid(mg):
		return
	for row_cells: Array in mg.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			if plant_cell != null \
					and plant_cell.signal_plant_create.is_connected(_on_peashooter_planted):
				plant_cell.signal_plant_create.disconnect(_on_peashooter_planted)


## 草坪上种下了豌豆射手 —— 「选择植物」这一步算过了
func _on_peashooter_planted(_cell: PlantCell, plant_type: StringName) -> void:
	if plant_type != PlantIds.PEA_SHOOTER_SINGLE:
		return
	select_plant_done.emit()


## 玩家把豌豆射手的种子包捡到了手上 —— 「选择植物」这一步算过了
func _on_peashooter_taken(card: Card) -> void:
	if card == null or card.card_plant_type != PlantIds.PEA_SHOOTER_SINGLE:
		return
	select_plant_done.emit()
#endregion
