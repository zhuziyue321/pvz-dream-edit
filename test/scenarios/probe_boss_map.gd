extends RefCounted
## 探针：僵王关（冒险 5-10）地图 —— 夜屋顶（Night Roof）
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_boss_map
## 覆盖：
##   1. 静态：5-10 关卡资源**自己**指定僵王关地图（map_boss.tres）+ 夜屋顶底图（GameBg.Boss）
##      + Brainiac Maniac（GameBGM.Boss）+ 夜晚（蘑菇不睡）
##   2. 静态：MainSceneRegistry 只剩前院 / 泳池 / 屋顶三个通用槽位（不再为僵王关单开枚举），
##      map_boss 自报的配套场景 = MainGameRoof
##   3. 静态：map_boss 与 map_roof 车道几何逐格一致（夜屋顶只是换了夜色底图，车道一格没挪）
##   4. 静态：夜屋顶背景子场景契约（根 Sprite2D / Home is MainGameHome / RoofSlope is MainGameSlope / 带 6 号房门遮罩）
##   5. 实机：进 5-10 核对底图、房门遮罩、5 行 × 9 列全屋顶格子、5 台屋顶小推车、5 行僵尸行、斜面，
##      并逐格核对「生成的格子」与「地图数据」一致（等价 validate_map_consistency 的要点）
## 机器可读汇总：最后一行 [BOSSMAP] result=PASS|FAIL failed=<n>

## 僵王关（5-10）在选关界面上的位置：第 5 页（0 起 = 4）的第 10 关
const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const PAGE_05 := 4
const ID_05_10 := "0050"

const LEVEL_5_10 := "res://src/levels/mode_adventure/adventure_05_10.gd"
const MAP_BOSS := "res://data/map/map_boss.tres"
const MAP_ROOF := "res://data/map/map_roof.tres"
const BG_BOSS := "res://src/world/background/main_game_bg_boss.tscn"

## 夜屋顶与白天屋顶共用同一套几何：5 行 × 9 列、逐行阶梯 col_dy、全屋顶小推车
const EXPECT_ROW_NUM := 5
const EXPECT_COL_NUM := 9
const EXPECT_ROOF_CLEANER := 2

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 僵王关（5-10）夜屋顶地图 ==========")
	_check_level_05_10(a)
	_check_registry(a)
	_check_map_same_as_roof(a)
	_check_bg_scene_contract(a)
	await _check_level_runtime(a)
	_finish(a)


#region 静态：关卡资源

## 5-10 是原版夜屋顶（Night Roof）的僵王关：地图、底图、BGM、昼夜都要与其它屋顶关区分开。
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Level_5-10 、/wiki/Night_Roof)
func _check_level_05_10(a) -> void:
	a.log("")
	a.log("STEP1 5-10 关卡资源")
	var para: ResourceLevelData = (load(LEVEL_5_10) as GDScript).new()
	if para == null:
		_check(a, "5-10 关卡资源可加载", false, LEVEL_5_10)
		return
	_check(a, "5-10 关卡资源可加载", true)
	_check(a, "5-10 主场景槽位 = MainGameRoof（不再有 MainGameBoss 这种专属枚举）",
		para.game_sences == MainSceneRegistry.MainScenes.MainGameRoof, str(para.game_sences))
	_check(a, "5-10 底图 = GameBg.Boss（夜屋顶）", para.game_BG == ConstLevelData.GameBg.Boss,
		str(para.game_BG))
	_check(a, "5-10 BGM = GameBGM.Boss（Brainiac Maniac）", para.game_BGM == ConstLevelData.GameBGM.Boss,
		str(para.game_BGM))
	_check(a, "5-10 是夜晚（寒冰菇等蘑菇不睡觉）", not para.is_day, str(para.is_day))
	_check(a, "5-10 没有天降阳光", not para.is_day_sun, str(para.is_day_sun))
	## 花盆不在关卡数据里了：由 run_flow() 开头的 plant_flower_pot_columns(4) 铺（见 STEP5 实机）
	## 关卡自己指定地图：僵王关的夜屋顶图不再靠场景槽位反查（见 docs/参考存档/地图实现.md §三）
	var map_res: ResourceMapData = para.map_data
	_check(a, "5-10 显式指定 map_data", map_res != null, str(map_res))
	if map_res != null:
		_check(a, "5-10 指定的地图 = map_boss", map_res.resource_path == MAP_BOSS,
			map_res.resource_path)
#endregion


#region 静态：注册表

func _check_registry(a) -> void:
	a.log("")
	a.log("STEP2 MainSceneRegistry 登记")
	var registry: MainSceneRegistry = Global.main_scene_registry
	var roof := MainSceneRegistry.MainScenes.MainGameRoof
	## 主游戏只剩前院 / 泳池 / 屋顶三个通用槽位：为某一关单开的枚举值已下沉到关卡的 map_data
	_check(a, "僵王关仍共用唯一主游戏场景",
		str(registry.MainScenesMap.get(roof, "")) == "res://src/main/main_game_base.tscn",
		str(registry.MainScenesMap.get(roof, "")))
	var resolved = registry.get_default_map_data(roof)
	_check(a, "反查到的地图数据是 ResourceMapData", resolved is ResourceMapData, str(resolved))
	if resolved is ResourceMapData:
		## 屋顶槽位的默认图仍是 map_roof —— 僵王关的夜屋顶图只能由 5-10 自己指定
		_check(a, "MainGameRoof 的默认图 = map_roof（不是 map_boss）",
			resolved.resource_path == MAP_ROOF, resolved.resource_path)
#endregion


#region 静态：夜屋顶与白天屋顶几何一致

## 夜屋顶（background6boss）与白天屋顶（background5）是同一张屋顶、只是配色变夜，
## 所以僵王关地图除了「背景场景 / 地图枚举 / 备注名」之外必须与 map_roof 逐项相同 ——
## 车道 / 阶梯 / 生成点 / 小推车 / 斜面 / 进家位置全都不能差，否则僵尸与植物会错位。
func _check_map_same_as_roof(a) -> void:
	a.log("")
	a.log("STEP3 map_boss 与 map_roof 几何一致")
	var boss: ResourceMapData = load(MAP_BOSS)
	var roof: ResourceMapData = load(MAP_ROOF)
	if boss == null or roof == null:
		_check(a, "两张地图资源可加载", false, "%s / %s" % [str(boss), str(roof)])
		return
	_check(a, "两张地图资源可加载", true)
	_check(a, "行数一致", boss.get_row_num() == roof.get_row_num(),
		"%d / %d" % [boss.get_row_num(), roof.get_row_num()])
	_check(a, "列数一致", boss.get_col_num() == roof.get_col_num(),
		"%d / %d" % [boss.get_col_num(), roof.get_col_num()])
	_check(a, "列 x 一致", boss.col_x == roof.col_x, str(boss.col_x))
	_check(a, "列宽一致", boss.col_width == roof.col_width, str(boss.col_width))
	_check(a, "有屋顶斜面", boss.have_slope, str(boss.have_slope))
	_check(a, "僵尸进家面板一致", boss.zombie_go_home_panel == roof.zombie_go_home_panel,
		str(boss.zombie_go_home_panel))
	_check(a, "僵尸进家落点一致", boss.zombie_go_home_marker == roof.zombie_go_home_marker,
		str(boss.zombie_go_home_marker))
	## 底图走 game_BG（GameBg.Boss），不走「无草皮底图覆盖」那条路
	_check(a, "没有用 bg_base_texture 顶替底图", boss.bg_base_texture == null, str(boss.bg_base_texture))
	_check(a, "地图自报的槽位 = MainGameRoof",
		boss.game_sences == MainSceneRegistry.MainScenes.MainGameRoof, str(boss.game_sences))
	var mismatch := 0
	for row in range(mini(boss.get_row_num(), roof.get_row_num())):
		var b: ResourceMapRowData = boss.rows[row]
		var r: ResourceMapRowData = roof.rows[row]
		if b == null or r == null:
			mismatch += 1
			continue
		if b.plant_cell_type != r.plant_cell_type or b.zombie_row_type != r.zombie_row_type \
			or b.row_y != r.row_y or b.row_height != r.row_height \
			or b.zombie_create_global_pos != r.zombie_create_global_pos \
			or b.col_dy != r.col_dy or b.col_dx != r.col_dx \
			or b.have_lawn_mover != r.have_lawn_mover or b.lawn_mover_type != r.lawn_mover_type \
			or b.have_rake != r.have_rake:
			mismatch += 1
			a.log("     第 %d 行不一致: boss=%s roof=%s" % [row, str(b), str(r)])
	_check(a, "逐行定义一致（地形 / 生成点 / 阶梯 / 小推车）", mismatch == 0, "不一致行数=%d" % mismatch)
#endregion


#region 静态：背景子场景契约

## BackgroundManager.init_background() 的运行期约定（同 probe_instantiate_bg）：
## 根必须是 Sprite2D、必须有 Home(MainGameHome)、夜屋顶还要 RoofSlope(MainGameSlope)，
## 并且带 6 号房门遮罩（GameBg.Boss 的 door_masks 下标要取到它）。
func _check_bg_scene_contract(a) -> void:
	a.log("")
	a.log("STEP4 夜屋顶背景子场景契约")
	var packed: PackedScene = load(BG_BOSS)
	if packed == null:
		_check(a, "背景场景可加载", false, BG_BOSS)
		return
	var inst: Node = packed.instantiate()
	_check(a, "根节点是 Sprite2D（代码里 as Sprite2D）", inst is Sprite2D, inst.get_class())
	var home: Node = inst.get_node_or_null("Home")
	var slope: Node = inst.get_node_or_null("RoofSlope")
	var mask: Node = inst.get_node_or_null("Home/Door/DoorMask/Background6GameoverMask")
	var panel: Node = inst.get_node_or_null("Home/Door/DoorDown/PanelZombieGoHome/Marker2DZombieGoHome")
	_check(a, "有 Home(MainGameHome)", home is MainGameHome, str(home))
	_check(a, "有 RoofSlope(MainGameSlope)", slope is MainGameSlope, str(slope))
	_check(a, "有 6 号房门遮罩", mask is Sprite2D, str(mask))
	_check(a, "有僵尸进家落点", panel is Marker2D, str(panel))
	inst.free()
#endregion


#region 实机：进 5-10

func _check_level_runtime(a) -> bool:
	a.log("")
	a.log("STEP5 5-10 实机")
	var para: ResourceLevelData = (load(LEVEL_5_10) as GDScript).new()
	if para == null:
		_check(a, "5-10 关卡资源可加载", false, LEVEL_5_10)
		return false
	para.set_choose_level(ADV, PAGE_05, ID_05_10)
	Global.game_para = para
	await a.wait(2.0)
	a.log("[场景] 进入 5-10（%s）" % para.save_game_name)
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[para.game_sences]
	)
	if not await _wait_main_game(a, 90.0):
		_check(a, "5-10 进入 MAIN_GAME", false, "超时")
		return false
	_check(a, "5-10 进入 MAIN_GAME", true)
	await a.wait(1.0)

	var mg = Global.main_game
	_check(a, "关卡参数已切到夜屋顶", mg.game_para.game_BG == ConstLevelData.GameBg.Boss,
		str(mg.game_para.game_BG))
	## 夜屋顶是裸屋顶：没有花盆就种不下任何植物 —— 花盆由 run_flow() 开头「系统种植」铺出来
	var pot_num := 0
	for i in range(20):
		pot_num = _count_pots(mg, 4)
		if pot_num > 0:
			break
		await a.wait(0.5)
	_check(a, "左侧 4 列铺上了花盆（裸屋顶的种植位）", pot_num == EXPECT_ROW_NUM * 4, str(pot_num))
	_check(a, "底图 = background6boss",
		mg.background_manager.background.texture == ConstLevelData.GameBgTextureMap[ConstLevelData.GameBg.Boss],
		str(mg.background_manager.background.texture))
	## 房门遮罩按 game_BG 打开：Boss 取的是第 6 张（只有夜屋顶背景子场景带它）
	var masks: Array = mg.background_manager.home.door_masks
	_check(a, "房门遮罩数组已同步扩到 6 个", masks.size() == ConstLevelData.GameBg.size(),
		"%d / %d" % [masks.size(), ConstLevelData.GameBg.size()])
	_check(a, "夜屋顶房门遮罩已打开",
		is_instance_valid(masks[ConstLevelData.GameBg.Boss])
			and masks[ConstLevelData.GameBg.Boss].visible,
		str(masks[ConstLevelData.GameBg.Boss]))

	## 斜面：夜屋顶与屋顶一样是斜的，缺了僵尸 / 子弹落位会错
	var slope = mg.main_game_slope
	_check(a, "斜面已装配", slope != null, str(slope))
	if slope != null:
		## RoofSlope 下挂一份 slope.tscn 实例，5 行各有一条 Area2DReal 行碰撞区
		var slope_inst: Node = slope.get_node_or_null("Slope")
		_check(a, "斜面挂上了 slope 实例", slope_inst is Slope, str(slope_inst))
		if slope_inst != null:
			var row_areas: Node = slope_inst.get_node_or_null("SlopeReal")
			_check(a, "斜面有 %d 条行碰撞区" % EXPECT_ROW_NUM,
				row_areas != null and row_areas.get_child_count() == EXPECT_ROW_NUM,
				str(row_areas.get_child_count() if row_areas != null else -1))
		## 按 x 取斜面相对 y（僵尸入场落位 / 抛物线影子都查它）：取场地中间列能取到有限值
		var mid_x: float = para.map_data.col_x[EXPECT_COL_NUM / 2] + 30.0
		var slope_y: float = slope.get_all_slope_y(mid_x)
		_check(a, "按 x 能取到斜面 y", is_finite(slope_y), "x=%.1f y=%s" % [mid_x, str(slope_y)])

	_check_map_generated(a, mg, para.map_data)
	_check_mowers(a, mg)
	_check_zombie_rows(a, mg)
	return true


## 生成的格子 / 僵尸行与地图数据逐项对齐（等价 validate_map_consistency 的要点）
func _check_map_generated(a, mg, map_data: ResourceMapData) -> void:
	var pcm = mg.plant_cell_manager
	_check(a, "格子行数 = %d" % EXPECT_ROW_NUM, pcm.all_plant_cells.size() == EXPECT_ROW_NUM,
		str(pcm.all_plant_cells.size()))
	_check(a, "row_col = (行, 列)", pcm.row_col == Vector2i(EXPECT_ROW_NUM, EXPECT_COL_NUM),
		str(pcm.row_col))
	var type_mismatch := 0
	var rect_mismatch := 0
	var index_mismatch := 0
	for r in range(pcm.all_plant_cells.size()):
		var row_cells: Array = pcm.all_plant_cells[r]
		if row_cells.size() != EXPECT_COL_NUM:
			type_mismatch += 1
			continue
		for c in range(row_cells.size()):
			var cell: PlantCell = row_cells[c]
			if cell.row_col != Vector2i(r, c):
				index_mismatch += 1
			if cell.plant_cell_type != map_data.rows[r].plant_cell_type:
				type_mismatch += 1
			var want: Rect2 = map_data.get_cell_rect(r, c)
			if abs(cell.get_rect().position.x - want.position.x) > 0.5 \
				or abs(cell.get_rect().position.y - want.position.y) > 0.5 \
				or abs(cell.get_rect().size.x - want.size.x) > 0.5 \
				or abs(cell.get_rect().size.y - want.size.y) > 0.5:
				rect_mismatch += 1
	_check(a, "每行 %d 个格子且地形与数据一致" % EXPECT_COL_NUM, type_mismatch == 0,
		"不符行数=%d" % type_mismatch)
	_check(a, "格子矩形与地图数据一致", rect_mismatch == 0, "不符格数=%d" % rect_mismatch)
	_check(a, "row_col 与 all_plant_cells 下标一致", index_mismatch == 0, "不符格数=%d" % index_mismatch)
	## 5-10 是白天屋顶的夜色版：格子地形一律 Roof（裸屋顶，投手类专用）
	var not_roof := 0
	for row_data: ResourceMapRowData in map_data.rows:
		if row_data.plant_cell_type != PlantCell.PlantCellType.Roof:
			not_roof += 1
	_check(a, "全行都是屋顶裸地（Roof）", not_roof == 0, "非屋顶行数=%d" % not_roof)


## 小推车：夜屋顶与屋顶一样是 5 台屋顶清洁车（roof cleaner），一行一台都不许缺
func _check_mowers(a, mg) -> void:
	var lm = mg.game_item_manager.gim_lawn_mover
	_check(a, "小推车 %d 台" % EXPECT_ROW_NUM, lm.all_lawn_movers.size() == EXPECT_ROW_NUM,
		str(lm.all_lawn_movers.size()))
	var wrong_type := 0
	for lane in range(lm.all_lawn_movers_type.size()):
		if int(lm.all_lawn_movers_type[lane]) != EXPECT_ROOF_CLEANER:
			wrong_type += 1
	_check(a, "小推车全是屋顶清洁车（类型 %d）" % EXPECT_ROOF_CLEANER, wrong_type == 0,
		str(lm.all_lawn_movers_type))


## 僵尸行：5 行陆地（原版 5-10 僵尸由僵王投放到任意一行）
func _check_zombie_rows(a, mg) -> void:
	var zm = mg.zombie_manager
	var rows: Array = zm.all_zombie_rows
	_check(a, "僵尸行 %d 行" % EXPECT_ROW_NUM, rows.size() == EXPECT_ROW_NUM, str(rows.size()))
	var wrong := 0
	for i in range(rows.size()):
		if rows[i].zombie_row_type != CharacterRegistry.ZombieRowType.Land:
			wrong += 1
	_check(a, "僵尸行全是陆地行（Land）", wrong == 0, "非陆地行数=%d" % wrong)


## 数场上已铺的花盆：只数左侧 col_count 列的 Down 槽位里的花盆
func _count_pots(mg, col_count: int) -> int:
	var num := 0
	for row_cells in mg.plant_cell_manager.all_plant_cells:
		for col in range(mini(col_count, row_cells.size())):
			var pot = (row_cells[col] as PlantCell).get_plant(CharacterRegistry.PlacePlantInCell.Down)
			if is_instance_valid(pot) and pot.plant_type == CharacterRegistry.PlantType.P034FlowerPot:
				num += 1
	return num


## 等主游戏进入 MAIN_GAME 阶段（5-10 没有戴夫对话，不需要点屏幕，只等时间轴自己走完）
func _wait_main_game(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if Global.main_game != null \
			and Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false
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
	a.log("[BOSSMAP] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
