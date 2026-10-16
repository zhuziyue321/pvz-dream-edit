extends LevelScriptBase
## adventure_01_02 —— 由同目录的 adventure_01_02.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。
##
## 本关教学（向日葵）就写在 run_flow() 里：提示条 + 箭头 + 等玩家操作，三样工具拼起来。
##
## 「选择植物」那一步**本关自己等两个信号**（见文末 _wait_select_plant），没用 wait_take_card：
## 只等「捡起种子包」会漏掉玩家手快连着点完「拿卡 → 种下」的情况，那时手上已经空了，
## 再等捡卡就永远等不到，教程卡死在「向日葵是非常重要的植物！」上、僵尸一只都不出。


func _init() -> void:
	save_key = "101_0_0002"
	## 本关专用地图：5 行草坪里只有中间 3 行铺了草皮（1-2 / 1-3 共用这一张）
	## 地图由关卡自己指定，不再靠「为本关单开一个场景枚举」来区分（见 docs/参考存档/地图实现.md）
	map_data = preload("res://data/map/map_front_5row.tres") as ResourceMapData
	## 本关通关掉落：樱桃炸弹（种子包）
	level_complete_loot = "cherry_bomb_seed_packet"


func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[StringName] = [ZombieIds.NORM]

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
		await _tutorial_flow(mg)
	## 开战：10 波，出怪表里只有普通僵尸
	await start_battle(10, zombie_list)
	## 通关掉落：首次通关掉本关奖励（见 _init 里的 level_complete_loot），已通关过只出奖杯
	if is_curr_level_success():
		win_with_trophy_only()
	else:
		await gain(level_complete_loot)


## 本关教学：教玩家种向日葵（顺序照搬原版 1-2）
## （台词取自原版 ADVICE_* 条目，见 data/strings/lawn_strings.txt）
##
## [mg] 主游戏管理器：「选择植物」那一步要拿它接草坪格子的「植物种下」信号
func _tutorial_flow(mg: MainGameManager) -> void:
	## 允许操作：先让玩家能点卡片 / 种植，此时还不出怪、不天降阳光
	await allow_operation()
	## 箭头指到向日葵的种子包上
	await arrow_card(PlantIds.SUN_FLOWER)
	await hint("向日葵是非常重要的植物！")
	## 等「选择植物」完成：捡起种子包 / 已经种下去了，谁先到都算过
	await _wait_select_plant(mg)
	## 教玩家把向日葵种下去
	await hint("点击草地种下你的种子！")
	await wait_plant(1, PlantIds.SUN_FLOWER)
	## 再种两株，凑够三棵向日葵
	## 教学排在开战之前，天降阳光还没启动，靠教程掉两颗阳光把这一段补上
	## （原版这段教学与开战同时进行，玩家一边种一边收天上掉的阳光）
	await arrow_card(PlantIds.SUN_FLOWER)
	await hint("至少要种下三棵向日葵！")
	await spawn_sun()
	await spawn_sun()
	await wait_plant(2, PlantIds.SUN_FLOWER)
	await hide_arrow()
	## 夸一句，停一停让玩家看清发生了什么
	await hint("干得漂亮！")
	await wait(2.0)
	## 收尾：关掉提示条（箭头已经在上面收了）
	await hint("")


#region 教程第一步：「选择植物」（捡起种子包 / 已经种下，谁先到都算过）
## 「选择植物」这一步完成：**捡起向日葵的种子包** 或 **草坪上种下了向日葵**
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
	##   1. 手上已经拿着向日葵的种子包（提示还没出完玩家就把卡点了）
	if LevelWaitCondition.is_holding_card(mg, PlantIds.SUN_FLOWER):
		return
	##   2. 草坪上已经有向日葵（玩家手快，「拿卡 → 种下」连着点完了 ——
	##      下一步的种植都做完了，选择植物当然也算完成；本关开局草坪是空的，有就是玩家种的）
	if LevelWaitCondition.count_lawn_plants(mg, PlantIds.SUN_FLOWER) > 0:
		return
	## 信号一：草坪上种下了向日葵（每个格子各有一个信号，逐个接上）
	for row_cells: Array in mg.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			if plant_cell != null:
				plant_cell.signal_plant_create.connect(_on_sunflower_planted)
	## 信号二：玩家把向日葵的种子包捡到了手上（拿卡是瞬间动作，只能靠这个事件）
	EventBus.subscribe(ConstEventName.HAND_CARD_TAKE, _on_sunflower_taken)
	## 两个信号谁先到都会把 select_plant_done 发出去，等到这一下就往下走
	await select_plant_done
	## 这一步已经过了，两个信号都断掉，别影响后面的教程
	EventBus.unsubscribe(ConstEventName.HAND_CARD_TAKE, _on_sunflower_taken)
	## 玩家中途退出关卡时主游戏已经没了，别再去访问它的格子
	if not is_instance_valid(mg):
		return
	for row_cells: Array in mg.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			if plant_cell != null \
					and plant_cell.signal_plant_create.is_connected(_on_sunflower_planted):
				plant_cell.signal_plant_create.disconnect(_on_sunflower_planted)


## 草坪上种下了向日葵 —— 「选择植物」这一步算过了
func _on_sunflower_planted(_cell: PlantCell, plant_type: StringName) -> void:
	if plant_type != PlantIds.SUN_FLOWER:
		return
	select_plant_done.emit()


## 玩家把向日葵的种子包捡到了手上 —— 「选择植物」这一步算过了
func _on_sunflower_taken(card: Card) -> void:
	if card == null or card.card_plant_type != PlantIds.SUN_FLOWER:
		return
	select_plant_done.emit()
#endregion
