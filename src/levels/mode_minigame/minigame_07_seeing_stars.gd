extends LevelScriptBase
## minigame_07_seeing_stars —— 原版迷你游戏**第 7 关**「观星」(Seeing Stars)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## **本关的特殊逻辑全部在本文件**：星星轮廓点的坐标与图案、轮廓点限种、通关 / 超时判负。
## 关卡数据（ResourceLevelData）上没有任何观星开关，GIM_Other 里也没有观星分支。
## 用到的通用设施（都不含观星规则，改本关玩法不用去动它们）：
##   · `PlantCell.only_allow_plant_types` / `forbidden_plant_types` + `is_plant_type_allowed()`
##     —— 格子级的「只允许 / 禁止」限种能力，种植条件第一道闸
##     （`ResourcePlantCondition.judge_is_can_plant()`，所有植物先过这一关）
##   · `CellStarOverlay` —— 给一批格子各摆一棵半透明不动的植物虚影的绘制层
##     （用哪种植物的哪一帧、什么算达标由本文件传进去）
##   · `LevelScriptBase.init_level_items()` —— 进关打限制的时机：格子已建好、玩家还动手不了
##   · `LevelScriptBase.create_progress_provider()` —— 右下角进度条换成观星口径
##     （进度 = 已种上杨桃的轮廓点数 / 轮廓点总数、不画旗帜，见 `SeeingStarsProgressProvider`）
##
## 原版规则（来源：PVZ Wiki https://plantsvszombies.wiki.gg/wiki/Seeing_Stars）：
##   1. 草坪上有一片星星形状的轮廓点，**轮廓点上只能种杨桃和南瓜头**（及它们的模仿者）；
##   2. 通关条件是**每个轮廓点都有一颗杨桃**，不是打完最后一波（PC 版无限波次，
##      没种满就一直打下去）；
##   3. iOS / Android 版要求 4 面旗帜内种满，超时算输 —— 本关按这条实现，
##      不然「没种满」时波次打完关卡永远不会结束。
##
## 规则原文口径（wiki）：「预留（星星）的格子不能种植除了杨桃和南瓜头以外的其他植物」

## 绘制层：给轮廓点各摆一棵半透明不动的杨桃虚影（通用组件，不含任何玩法规则）
## 只被本关用，所以跟本关脚本放在同一个目录（关卡侧），不进 src/items/
const CELL_STAR_OVERLAY = preload("res://src/levels/mode_minigame/minigame_07_seeing_stars_cell_star_overlay.tscn")
## 虚影定格在杨桃 idle 动画的第 0 帧（动画名见 plant_star_fruit.tscn 的 AnimationLibrary）
const STAR_FRUIT_IDLE_ANIM := &"StarFruit_idle"

## 星星轮廓点：每一项是 Vector2i(row, col)，**行与列都从 0 开始**（与 PlantCell.row_col 一致）
## 想换图案就改这张表（自制关卡复制本脚本改这里即可）；越界的坐标会被丢掉并打日志
## 默认的大星星（白天草坪 5 行 × 9 列），共 13 个点：
##  ```
##  ...#.....
##  ...#.....
##  .######..
##  ...###...
##  ...#..#..
##  ```
const STAR_CELLS: Array[Vector2i] = [
	Vector2i(0, 3),
	Vector2i(1, 3),
	Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5), Vector2i(2, 6),
	Vector2i(3, 3), Vector2i(3, 4), Vector2i(3, 5),
	Vector2i(4, 3), Vector2i(4, 6),
]
## 轮廓点上允许种的植物（原版：杨桃 + 南瓜头；模仿者是「同一张卡换个壳」，card_plant_type 不变）
const STAR_CELL_ALLOW_PLANT_TYPES: Array[CharacterRegistry.PlantType] = [
	CharacterRegistry.PlantType.P030StarFruit,
	CharacterRegistry.PlantType.P031Pumpkin,
]
## 轮廓点之外禁止种的植物：杨桃只能种在轮廓点上（避免在别处白扔 125 阳光）
## 南瓜头不受此限 —— 它是正常防守植物，别处该用还得用
const OUTSIDE_FORBIDDEN_PLANT_TYPES: Array[CharacterRegistry.PlantType] = [
	CharacterRegistry.PlantType.P030StarFruit,
]

## 原版手机版：4 面旗帜内种满，第 4 面旗帜升起时还没种满算输
const MAX_FLAG := 4
## 旗帜波固定在第 9 / 19 / 29 … 波（curr_wave 从 0 开始），见 ZombieWaveManager.start_next_wave
const WAVE_EVERY_FLAG := 10
## 胜负判定的轮询间隔（秒）
const POLL_STEP := 0.25

## 运行期：STAR_CELLS 解析出来的轮廓格子
var star_cells: Array[PlantCell] = []
## 星星轮廓的绘制层（挂在背景物品层，由 init_level_items() 创建）
var star_overlay: CellStarOverlay


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0008"
	game_BG = ConstLevelData.GameBg.FrontDay
	## 场景曲：本关是白天前院 → 白天曲 Grasswalk
	game_BGM = ConstLevelData.GameBGM.FrontDay
	zombie_multy = 2
	## 4 面旗帜 = 40 波（进度条上的旗帜数 = max_wave / 10，见 ZombieWaveManager.get_flag_num）
	max_wave = MAX_FLAG * WAVE_EVERY_FLAG
	## 出怪表：预览僵尸和开战共用同一份（也在 _init 里给，开战不走 start_battle 预制体）
	zombie_refresh_types.assign([
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z004PoleVaulter,
		CharacterRegistry.ZombieType.Z005Bucket,
	])
	## 杨桃是通关必需品：预选进卡槽，玩家在选卡界面摘不掉
	## （原版：默认选中，硬摘掉会弹警告 —— 没杨桃这关永远打不完）
	prechosen_cards = ResourceCardReference.create_plant_list([CharacterRegistry.PlantType.P030StarFruit])


#region 进关打点：轮廓点 + 限种 + 绘制层
## 进关时（格子已建好、玩家还动手不了）把观星的三件事办了：
##   ① 解析轮廓点  ② 打种植限制  ③ 挂上星星绘制层
## **限制必须在这里打**：留到 run_flow() 就晚了 —— 那时玩家已经选完卡了
func init_level_items(mg: MainGameManager, item_root: Node2D) -> void:
	star_cells = _resolve_star_cells(mg)
	_apply_plant_limit(mg)
	## 重进关时可能已经挂过一层：先清掉再重建，不留两叠虚影（free_item 幂等）
	_free_star_overlay()
	star_overlay = CELL_STAR_OVERLAY.instantiate()
	item_root.add_child(star_overlay)
	star_overlay.init_item(star_cells, _get_star_fruit_scene(), STAR_FRUIT_IDLE_ANIM,
		Callable(self, "_is_cell_has_star_fruit"))
	Log.debug(str("观星：共 ") + str(star_cells.size()) + str(" 个星星轮廓点"))


## 清掉绘制层（引用自己留一份就是为了能自己收拾）—— **可重复调用**
## 关卡结束（种满通关 / 超时判负 / 僵尸进家）与重进关都会走这里
func _free_star_overlay() -> void:
	if star_overlay == null:
		return
	if is_instance_valid(star_overlay):
		star_overlay.free_item()
	star_overlay = null


## 虚影用的杨桃场景：从注册表取（类型映射一律走注册表，不在业务代码里散落 preload）
func _get_star_fruit_scene() -> PackedScene:
	return Global.character_registry.get_plant_info(CharacterRegistry.PlantType.P030StarFruit,
		CharacterRegistry.PlantInfoAttribute.PlantScenes)


## 把 STAR_CELLS 里的 (row, col) 翻译成格子；越界 / 重复的跳过
func _resolve_star_cells(mg: MainGameManager) -> Array[PlantCell]:
	var out: Array[PlantCell] = []
	var plant_cell_manager: PlantCellManager = mg.plant_cell_manager
	var all_cells: Array[Array] = plant_cell_manager.all_plant_cells
	var row_col: Vector2i = plant_cell_manager.row_col
	for pos: Vector2i in STAR_CELLS:
		if pos.x < 0 or pos.x >= row_col.x or pos.y < 0 or pos.y >= row_col.y:
			Log.warn(str("观星轮廓点越界，已跳过：") + str(pos) + str("（本关草坪 ") + str(row_col) + str("）"))
			continue
		var plant_cell: PlantCell = all_cells[pos.x][pos.y]
		if out.has(plant_cell):
			continue
		out.append(plant_cell)
	return out


## 种植限制：轮廓点上只收杨桃 / 南瓜头，轮廓点之外不能种杨桃
func _apply_plant_limit(mg: MainGameManager) -> void:
	for plant_cell: PlantCell in star_cells:
		plant_cell.set_only_allow_plant_types(STAR_CELL_ALLOW_PLANT_TYPES)
	for plant_cells_row in mg.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in plant_cells_row:
			if star_cells.has(plant_cell):
				continue
			plant_cell.set_forbidden_plant_types(OUTSIDE_FORBIDDEN_PLANT_TYPES)
#endregion


#region 通关判定
## 本关的星星轮廓点是否全都种上了杨桃（模仿者杨桃变身完成后就是一颗真杨桃）
## 轮廓点一个都没有时返回 false：不能让「空集」被判成「全都种满了」直接通关
func is_all_star_cells_planted() -> bool:
	if star_cells.is_empty():
		return false
	for plant_cell: PlantCell in star_cells:
		if not _is_cell_has_star_fruit(plant_cell):
			return false
	return true


## 还差几个轮廓点没种上
func get_unplanted_num() -> int:
	var unplanted := 0
	for plant_cell: PlantCell in star_cells:
		if not _is_cell_has_star_fruit(plant_cell):
			unplanted += 1
	return unplanted


## 某个格子的普通位置（Norm）上是不是一颗杨桃
func _is_cell_has_star_fruit(plant_cell: PlantCell) -> bool:
	if not is_instance_valid(plant_cell):
		return false
	var plant := plant_cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm)
	if not is_instance_valid(plant):
		return false
	return plant.plant_type == CharacterRegistry.PlantType.P030StarFruit


## 奖杯掉在哪：星星的几何中心
func get_star_center_global_position() -> Vector2:
	if star_overlay == null:
		return Vector2.ZERO
	return star_overlay.get_center_global_position()
#endregion


#region 进度条口径
## 本关进度条代表**种植进度**：已种上杨桃的轮廓点数 / 轮廓点总数（种满 = 100% = 掉奖杯）
## 波次只是「4 面旗帜」的倒计时，不占进度条（进度条上不画旗帜，见 SeeingStarsProgressProvider）
func create_progress_provider() -> LevelProgressProvider:
	return SeeingStarsProgressProvider.new()
#endregion


func run_flow(mg: MainGameManager) -> void:
	## 展示僵尸
	await show_zombie(zombie_refresh_types)
	## 选卡
	await choose_card()
	## 初始化小推车
	await init_lawn_mover()
	## 准备安放植物
	await ready_set_plant()
	## 开战：出怪参数已经在 _init 里写进关卡数据，这里只管把主游戏开起来
	await mg.main_game_start()
	## 观星的胜负判定：种满就赢，第 4 面旗帜升起还没种满就输
	await _wait_seeing_stars_result(mg)
	## 关卡结束（赢 / 输 / 僵尸进家都从这里往下走）：奖杯位置已经取过，绘制层可以收了
	_free_star_overlay()


## 观星的胜负判定：轮询到「星星轮廓点全种满」或者「第 N 面旗帜升起」
## 僵尸进家判负走原有的失败流程（MgmLoseManager），与这段互不干扰
func _wait_seeing_stars_result(mg: MainGameManager) -> void:
	if star_cells.is_empty():
		Log.error("观星：本关没有星星轮廓点，无法判定通关条件")
		return

	while is_instance_valid(mg) and mg.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
		if is_all_star_cells_planted():
			Log.debug(str("观星：") + str(star_cells.size()) + str(" 个轮廓点全部种上杨桃，通关"))
			EventBus.push_event("create_trophy", [get_star_center_global_position()])
			return
		if _get_passed_flag_num(mg) >= MAX_FLAG:
			Log.debug(str("观星：第 ") + str(MAX_FLAG) + str(" 面旗帜已升起，还剩 ")
				+ str(get_unplanted_num()) + str(" 个轮廓点没种满，判负"))
			## 与「僵尸进家」同一套失败流程（重开存档 + 失败音乐 + 红字），本身与僵尸模式无关
			mg.lose_manager.on_zombie_mode_lose()
			return
		await mg.get_tree().create_timer(POLL_STEP).timeout


## 当前已经升起几面旗帜（旗帜波在 curr_wave = 9 / 19 / 29 … 时升旗）
func _get_passed_flag_num(mg: MainGameManager) -> int:
	var wave_manager := mg.zombie_manager.zombie_wave_manager
	if not is_instance_valid(wave_manager):
		return 0
	return floori(float(wave_manager.curr_wave + 1) / float(WAVE_EVERY_FLAG))
