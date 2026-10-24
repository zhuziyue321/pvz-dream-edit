extends RefCounted
## 探针：郊外营地（DLC 版第 7 章 Woods 移植的地图）
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_woods_map
## 覆盖：
##   1. 静态：map_woods 可加载，且车道几何与 map_front（白天前院）逐格一致
##      （background7 的草坪按原版网格绘制，与前院 background1 对齐，车道一格没挪）
##   2. 静态：郊外背景子场景契约（根 Sprite2D / Home / 不带屋顶斜面 / 带 Woods 房门遮罩）
##   3. 静态：GameBg.Woods 底图、GameBGM.Woods 曲目文件存在、SCENE_WOODS 场景设置值
##   4. 实机：合成关卡（map_data = map_woods + scene_name = woods）进主游戏，
##      核对底图、房门遮罩数组随 GameBg 扩到 8、不装屋顶斜面、5×9 陆地格子、5 行僵尸行
## 机器可读汇总：最后一行 [WOODSMAP] result=PASS|FAIL failed=<n>

const MAP_WOODS := "res://data/map/map_woods.tres"
const MAP_FRONT := "res://data/map/map_front.tres"
const BG_WOODS := "res://src/world/background/main_game_bg_woods.tscn"
const BG_WOODS_TEXTURE := "res://pak/images/background7woods.png"
const BGM_WOODS := "res://assets_custom/audio/BGM/woody_tombstones.ogg"

## 郊外与前院共用同一套几何：5 行 × 9 列、无 col_dy 阶梯、全陆地小推车
const EXPECT_ROW_NUM := 5
const EXPECT_COL_NUM := 9

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 郊外营地地图 ==========")
	_check_map_same_as_front(a)
	_check_bg_scene_contract(a)
	_check_constants(a)
	await _check_runtime(a)
	_finish(a)


#region 静态：几何与 map_front 一致

## 郊外营地（background7woods）与白天前院（background1）是同一套原版网格：
## 5×9 陆地草坪、格子一个没挪，所以地图除了「背景场景 / 备注名」必须与 map_front 逐项相同。
func _check_map_same_as_front(a) -> void:
	a.log("")
	a.log("STEP1 map_woods 与 map_front 几何一致")
	var woods: ResourceMapData = load(MAP_WOODS)
	var front: ResourceMapData = load(MAP_FRONT)
	if woods == null or front == null:
		_check(a, "两张地图资源可加载", false, "%s / %s" % [str(woods), str(front)])
		return
	_check(a, "两张地图资源可加载", true)
	_check(a, "行数一致", woods.get_row_num() == front.get_row_num(),
		"%d / %d" % [woods.get_row_num(), front.get_row_num()])
	_check(a, "列数一致", woods.get_col_num() == front.get_col_num(),
		"%d / %d" % [woods.get_col_num(), front.get_col_num()])
	_check(a, "列 x 一致", woods.col_x == front.col_x, str(woods.col_x))
	_check(a, "列宽一致", woods.col_width == front.col_width, str(woods.col_width))
	_check(a, "没有屋顶斜面", not woods.have_slope, str(woods.have_slope))
	_check(a, "僵尸进家面板一致", woods.zombie_go_home_panel == front.zombie_go_home_panel,
		str(woods.zombie_go_home_panel))
	_check(a, "僵尸进家落点一致", woods.zombie_go_home_marker == front.zombie_go_home_marker,
		str(woods.zombie_go_home_marker))
	_check(a, "没有用 bg_base_texture 顶替底图", woods.bg_base_texture == null, str(woods.bg_base_texture))
	_check(a, "地图自报的槽位 = MainGameFront",
		woods.game_sences == MainSceneRegistry.MainScenes.MainGameFront, str(woods.game_sences))
	var mismatch := 0
	for row in range(mini(woods.get_row_num(), front.get_row_num())):
		var w: ResourceMapRowData = woods.rows[row]
		var f: ResourceMapRowData = front.rows[row]
		if w == null or f == null:
			mismatch += 1
			continue
		if w.plant_cell_type != f.plant_cell_type or w.zombie_row_type != f.zombie_row_type \
			or w.row_y != f.row_y or w.row_height != f.row_height \
			or w.zombie_create_global_pos != f.zombie_create_global_pos \
			or w.col_dy != f.col_dy or w.col_dx != f.col_dx \
			or w.have_lawn_mover != f.have_lawn_mover or w.lawn_mover_type != f.lawn_mover_type \
			or w.have_rake != f.have_rake:
			mismatch += 1
			a.log("     第 %d 行不一致: woods=%s front=%s" % [row, str(w), str(f)])
	_check(a, "逐行定义一致（地形 / 生成点 / 阶梯 / 小推车）", mismatch == 0, "不一致行数=%d" % mismatch)
#endregion


#region 静态：背景子场景契约

func _check_bg_scene_contract(a) -> void:
	a.log("")
	a.log("STEP2 郊外背景子场景契约")
	var packed: PackedScene = load(BG_WOODS)
	if packed == null:
		_check(a, "背景场景可加载", false, BG_WOODS)
		return
	var inst: Node = packed.instantiate()
	_check(a, "根节点是 Sprite2D（代码里 as Sprite2D）", inst is Sprite2D, inst.get_class())
	var home: Node = inst.get_node_or_null("Home")
	var slope: Node = inst.get_node_or_null("RoofSlope")
	var mask: Node = inst.get_node_or_null("Home/Door/DoorMask/Background7WoodsGameoverMask")
	var panel: Node = inst.get_node_or_null("Home/Door/DoorDown/PanelZombieGoHome/Marker2DZombieGoHome")
	_check(a, "有 Home(MainGameHome)", home is MainGameHome, str(home))
	_check(a, "没有屋顶斜面（郊外是平地草坪）", slope == null, str(slope))
	_check(a, "有 Woods 房门遮罩", mask is Sprite2D, str(mask))
	if mask is Sprite2D:
		## (0, 189) 是模板匹配算出来的（遮罩图与底图在该位置逐像素重合，MSE=0），
		## 不是沿用 roof 系的估值 —— 防止将来有人手滑改回去
		_check(a, "遮罩对准露营车（模板匹配位 (0,189)）", mask.position == Vector2(0, 189),
			str(mask.position))
	_check(a, "有僵尸进家落点", panel is Marker2D, str(panel))
	inst.free()
#endregion


#region 静态：常量与场景设置

func _check_constants(a) -> void:
	a.log("")
	a.log("STEP3 底图 / BGM / 场景设置")
	var tex: Texture2D = ConstLevelData.get_game_bg_texture(ConstLevelData.GameBg.Woods)
	_check(a, "GameBg.Woods 已登记底图", tex != null, str(tex))
	if tex != null:
		_check(a, "底图 = background7woods", tex.resource_path == BG_WOODS_TEXTURE, tex.resource_path)
	var bgm_path: String = ConstLevelData.GameBGMMap.get(ConstLevelData.GameBGM.Woods, "")
	_check(a, "GameBGM.Woods 已登记曲目", not bgm_path.is_empty(), bgm_path)
	_check(a, "郊外曲文件存在", ResourceLoader.exists(bgm_path), bgm_path)
	var setting := SceneSettingRegistry.get_scene(SceneSettingRegistry.SCENE_WOODS)
	_check(a, "SCENE_WOODS 已登记场景设置", setting != null, str(setting))
	if setting != null:
		_check(a, "场景底图 = Woods", setting.game_BG == ConstLevelData.GameBg.Woods,
			str(setting.game_BG))
		_check(a, "场景 BGM = Woods（Woody Tombstones）", setting.game_BGM == ConstLevelData.GameBGM.Woods,
			str(setting.game_BGM))
		_check(a, "场景是白天", setting.is_day, str(setting.is_day))
		_check(a, "场景天降阳光", setting.is_day_sun, str(setting.is_day_sun))
		_check(a, "场景不开血月（血月是月夜屋顶专属）", not setting.is_blood_moon, str(setting.is_blood_moon))
		_check(a, "场景槽位 = MainGameFront",
			setting.game_sences == MainSceneRegistry.MainScenes.MainGameFront, str(setting.game_sences))
#endregion


#region 实机：合成关卡装配

## 没有为郊外营地单开关卡：合成一份 ResourceLevelData（指定 map_data + 场景名）直接进主游戏，
## 核对 BackgroundManager 的装配结果（底图 / 房门遮罩 / 格子 / 僵尸行）。
func _check_runtime(a) -> void:
	a.log("")
	a.log("STEP4 合成关卡实机装配")
	var para: ResourceLevelData = ResourceLevelData.new()
	if para == null:
		_check(a, "ResourceLevelData 可实例化", false)
		return
	para.map_data = load(MAP_WOODS)
	para.scene_name = SceneSettingRegistry.SCENE_WOODS
	_check(a, "场景套用后底图 = Woods", para.game_BG == ConstLevelData.GameBg.Woods,
		str(para.game_BG))
	_check(a, "场景套用后是白天", para.is_day, str(para.is_day))
	Global.game_para = para
	await a.wait(1.0)
	GlobalUtils.change_scene(
		Global.main_scene_registry.get_scene_path(para.game_sences)
	)
	var waited := 0.0
	while waited < 30.0 and GameContext.curr_main_game == null:
		await a.wait(0.5)
		waited += 0.5
	if GameContext.curr_main_game == null:
		_check(a, "进入主游戏场景", false, "超时")
		return
	_check(a, "进入主游戏场景", true)
	await a.wait(1.0)

	var mg = GameContext.curr_main_game
	_check(a, "底图 = background7woods",
		mg.background_manager.background.texture == ConstLevelData.get_game_bg_texture(ConstLevelData.GameBg.Woods),
		str(mg.background_manager.background.texture))
	## 房门遮罩数组必须随 GameBg 一起扩到 8（新增背景不同步扩数组会在 init_home 越界）
	var masks: Array = mg.background_manager.home.door_masks
	_check(a, "房门遮罩数组已同步扩到 %d 个" % ConstLevelData.GameBg.size(),
		masks.size() == ConstLevelData.GameBg.size(),
		"%d / %d" % [masks.size(), ConstLevelData.GameBg.size()])
	if masks.size() == ConstLevelData.GameBg.size():
		_check(a, "Woods 房门遮罩已打开",
			is_instance_valid(masks[ConstLevelData.GameBg.Woods])
				and masks[ConstLevelData.GameBg.Woods].visible,
			str(masks[ConstLevelData.GameBg.Woods]))

	## 郊外是平地草坪：不该装屋顶斜面（装了僵尸 / 子弹落位会错）
	_check(a, "没有屋顶斜面", mg.main_game_slope == null, str(mg.main_game_slope))

	## 格子 / 僵尸行
	var pcm = mg.plant_cell_manager
	_check(a, "格子行数 = %d" % EXPECT_ROW_NUM, pcm.all_plant_cells.size() == EXPECT_ROW_NUM,
		str(pcm.all_plant_cells.size()))
	var type_mismatch := 0
	for r in range(pcm.all_plant_cells.size()):
		var row_cells: Array = pcm.all_plant_cells[r]
		if row_cells.size() != EXPECT_COL_NUM:
			type_mismatch += 1
			continue
		for c in range(row_cells.size()):
			var cell: PlantCell = row_cells[c]
			if cell.plant_cell_type != para.map_data.rows[r].plant_cell_type:
				type_mismatch += 1
	_check(a, "每行 %d 个格子且地形与数据一致" % EXPECT_COL_NUM, type_mismatch == 0,
		"不符行数=%d" % type_mismatch)
	var not_land := 0
	for row_data: ResourceMapRowData in para.map_data.rows:
		if row_data.plant_cell_type == PlantCell.PlantCellType.Roof:
			not_land += 1
	_check(a, "没有屋顶裸地行（全陆地草地）", not_land == 0, "屋顶行数=%d" % not_land)

	var zm = mg.zombie_manager
	var rows: Array = zm.all_zombie_rows
	_check(a, "僵尸行 %d 行" % EXPECT_ROW_NUM, rows.size() == EXPECT_ROW_NUM, str(rows.size()))
#endregion


#region 断言

func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[WOODSMAP] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
