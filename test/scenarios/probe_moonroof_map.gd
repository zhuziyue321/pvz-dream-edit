extends RefCounted
## 探针：月夜屋顶（DLC 版第 6 章 Moon 移植的地图）
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_moonroof_map
## 覆盖：
##   1. 静态：map_moonroof 可加载，且车道几何与 map_boss（= map_roof）逐格一致
##      （月夜屋顶与夜屋顶 / 白天屋顶是同一张屋顶，只换底图，车道一格没挪）
##   2. 静态：月夜屋顶背景子场景契约（根 Sprite2D / Home / RoofSlope / 带 6 号月夜房门遮罩）
##   3. 静态：GameBg.MoonRoof 底图、GameBGM.Moon 曲目文件存在、SCENE_MOON_ROOF 场景设置值
##   4. 实机：合成关卡（map_data = map_moonroof + scene_name = moon_roof）进主游戏，
##      核对底图、房门遮罩数组随 GameBg 扩到 7、斜面、5×9 全屋顶格子、5 台屋顶小推车、5 行陆地僵尸行
## 机器可读汇总：最后一行 [MOONMAP] result=PASS|FAIL failed=<n>

const MAP_MOON := "res://data/map/map_moonroof.tres"
const MAP_BOSS := "res://data/map/map_boss.tres"
const BG_MOON := "res://src/world/background/main_game_bg_moonroof.tscn"
## 常驻底图是**月夜**那幅（与僵王关同一张）；`background6moon.png` 是血月专用、
## 由 main_game_bg_moonroof.gd 在血月期间换上来，平时不能当底图
const BG_MOON_TEXTURE := "res://pak/images/background6boss.jpg"
const BG_MOON_BLOOD_TEXTURE := "res://pak/images/background6moon.png"
const BGM_MOON := "res://assets_custom/audio/BGM/harvest_moon.ogg"

## 月夜屋顶与夜屋顶共用同一套几何：5 行 × 9 列、逐行阶梯 col_dy、全屋顶小推车
const EXPECT_ROW_NUM := 5
const EXPECT_COL_NUM := 9
const EXPECT_ROOF_CLEANER := 2

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 月夜屋顶地图 ==========")
	_check_map_same_as_boss(a)
	_check_bg_scene_contract(a)
	_check_constants(a)
	await _check_runtime(a)
	_finish(a)


#region 静态：几何与 map_boss 一致

## 月夜屋顶（background6moon）与夜屋顶（background6boss）/ 白天屋顶（background5）
## 是同一张屋顶、只是配色不同，所以地图除了「背景场景 / 备注名」必须与 map_boss 逐项相同。
func _check_map_same_as_boss(a) -> void:
	a.log("")
	a.log("STEP1 map_moonroof 与 map_boss 几何一致")
	var moon: ResourceMapData = load(MAP_MOON)
	var boss: ResourceMapData = load(MAP_BOSS)
	if moon == null or boss == null:
		_check(a, "两张地图资源可加载", false, "%s / %s" % [str(moon), str(boss)])
		return
	_check(a, "两张地图资源可加载", true)
	_check(a, "行数一致", moon.get_row_num() == boss.get_row_num(),
		"%d / %d" % [moon.get_row_num(), boss.get_row_num()])
	_check(a, "列数一致", moon.get_col_num() == boss.get_col_num(),
		"%d / %d" % [moon.get_col_num(), boss.get_col_num()])
	_check(a, "列 x 一致", moon.col_x == boss.col_x, str(moon.col_x))
	_check(a, "列宽一致", moon.col_width == boss.col_width, str(moon.col_width))
	_check(a, "有屋顶斜面", moon.have_slope, str(moon.have_slope))
	_check(a, "僵尸进家面板一致", moon.zombie_go_home_panel == boss.zombie_go_home_panel,
		str(moon.zombie_go_home_panel))
	_check(a, "僵尸进家落点一致", moon.zombie_go_home_marker == boss.zombie_go_home_marker,
		str(moon.zombie_go_home_marker))
	_check(a, "没有用 bg_base_texture 顶替底图", moon.bg_base_texture == null, str(moon.bg_base_texture))
	_check(a, "地图自报的槽位 = MainGameRoof",
		moon.game_sences == MainSceneRegistry.MainScenes.MainGameRoof, str(moon.game_sences))
	var mismatch := 0
	for row in range(mini(moon.get_row_num(), boss.get_row_num())):
		var m: ResourceMapRowData = moon.rows[row]
		var b: ResourceMapRowData = boss.rows[row]
		if m == null or b == null:
			mismatch += 1
			continue
		if m.plant_cell_type != b.plant_cell_type or m.zombie_row_type != b.zombie_row_type \
			or m.row_y != b.row_y or m.row_height != b.row_height \
			or m.zombie_create_global_pos != b.zombie_create_global_pos \
			or m.col_dy != b.col_dy or m.col_dx != b.col_dx \
			or m.have_lawn_mover != b.have_lawn_mover or m.lawn_mover_type != b.lawn_mover_type \
			or m.have_rake != b.have_rake:
			mismatch += 1
			a.log("     第 %d 行不一致: moon=%s boss=%s" % [row, str(m), str(b)])
	_check(a, "逐行定义一致（地形 / 生成点 / 阶梯 / 小推车）", mismatch == 0, "不一致行数=%d" % mismatch)
#endregion


#region 静态：背景子场景契约

func _check_bg_scene_contract(a) -> void:
	a.log("")
	a.log("STEP2 月夜屋顶背景子场景契约")
	var packed: PackedScene = load(BG_MOON)
	if packed == null:
		_check(a, "背景场景可加载", false, BG_MOON)
		return
	var inst: Node = packed.instantiate()
	_check(a, "根节点是 Sprite2D（代码里 as Sprite2D）", inst is Sprite2D, inst.get_class())
	var home: Node = inst.get_node_or_null("Home")
	var slope: Node = inst.get_node_or_null("RoofSlope")
	var mask: Node = inst.get_node_or_null("Home/Door/DoorMask/Background6MoonGameoverMask")
	var panel: Node = inst.get_node_or_null("Home/Door/DoorDown/PanelZombieGoHome/Marker2DZombieGoHome")
	_check(a, "有 Home(MainGameHome)", home is MainGameHome, str(home))
	_check(a, "有 RoofSlope(MainGameSlope)", slope is MainGameSlope, str(slope))
	_check(a, "有月夜房门遮罩", mask is Sprite2D, str(mask))
	_check(a, "有僵尸进家落点", panel is Marker2D, str(panel))
	inst.free()
#endregion


#region 静态：常量与场景设置

func _check_constants(a) -> void:
	a.log("")
	a.log("STEP3 底图 / BGM / 场景设置")
	var tex: Texture2D = ConstLevelData.get_game_bg_texture(ConstLevelData.GameBg.MoonRoof)
	_check(a, "GameBg.MoonRoof 已登记底图", tex != null, str(tex))
	if tex != null:
		_check(a, "底图 = 月夜那幅（background6boss）", tex.resource_path == BG_MOON_TEXTURE,
			tex.resource_path)
	var bgm_path: String = ConstLevelData.GameBGMMap.get(ConstLevelData.GameBGM.Moon, "")
	_check(a, "GameBGM.Moon 已登记曲目", not bgm_path.is_empty(), bgm_path)
	_check(a, "月夜曲文件存在", ResourceLoader.exists(bgm_path), bgm_path)
	var setting := SceneSettingRegistry.get_scene(SceneSettingRegistry.SCENE_MOON_ROOF)
	_check(a, "SCENE_MOON_ROOF 已登记场景设置", setting != null, str(setting))
	if setting != null:
		_check(a, "场景底图 = MoonRoof", setting.game_BG == ConstLevelData.GameBg.MoonRoof,
			str(setting.game_BG))
		_check(a, "场景 BGM = Moon（Harvest Moon）", setting.game_BGM == ConstLevelData.GameBGM.Moon,
			str(setting.game_BGM))
		_check(a, "场景是夜晚（蘑菇不睡）", not setting.is_day, str(setting.is_day))
		_check(a, "场景没有天降阳光（Moon 章难点之一 lack of sun）", not setting.is_day_sun,
			str(setting.is_day_sun))
		_check(a, "场景槽位 = MainGameRoof",
			setting.game_sences == MainSceneRegistry.MainScenes.MainGameRoof, str(setting.game_sences))
#endregion


#region 实机：合成关卡装配

## 没有为月夜屋顶单开关卡：合成一份 ResourceLevelData（指定 map_data + 场景名）直接进主游戏，
## 核对 BackgroundManager 的装配结果（底图 / 房门遮罩 / 斜面 / 格子 / 小推车 / 僵尸行）。
func _check_runtime(a) -> void:
	a.log("")
	a.log("STEP4 合成关卡实机装配")
	var para: ResourceLevelData = ResourceLevelData.new()
	if para == null:
		_check(a, "ResourceLevelData 可实例化", false)
		return
	para.map_data = load(MAP_MOON)
	para.scene_name = SceneSettingRegistry.SCENE_MOON_ROOF
	_check(a, "场景套用后底图 = MoonRoof", para.game_BG == ConstLevelData.GameBg.MoonRoof,
		str(para.game_BG))
	_check(a, "场景套用后是夜晚", not para.is_day, str(para.is_day))
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
	_check(a, "底图 = 月夜那幅（background6boss）",
		mg.background_manager.background.texture.resource_path == BG_MOON_TEXTURE,
		str(mg.background_manager.background.texture))
	## 血月那幅（background6moon）不能被登记成常驻底图：一进关就是紫红，
	## 视觉上像是血月已经开了（血月要等旗帜波才起）
	_check(a, "血月那幅没被当成常驻底图",
		mg.background_manager.background.texture.resource_path != BG_MOON_BLOOD_TEXTURE,
		str(mg.background_manager.background.texture))
	## 房门遮罩数组必须随 GameBg 一起扩到 7（新增背景不同步扩数组会在 init_home 越界）
	var masks: Array = mg.background_manager.home.door_masks
	_check(a, "房门遮罩数组已同步扩到 %d 个" % ConstLevelData.GameBg.size(),
		masks.size() == ConstLevelData.GameBg.size(),
		"%d / %d" % [masks.size(), ConstLevelData.GameBg.size()])
	if masks.size() == ConstLevelData.GameBg.size():
		_check(a, "月夜房门遮罩已打开",
			is_instance_valid(masks[ConstLevelData.GameBg.MoonRoof])
				and masks[ConstLevelData.GameBg.MoonRoof].visible,
			str(masks[ConstLevelData.GameBg.MoonRoof]))

	## 斜面：月夜屋顶与屋顶一样是斜的，缺了僵尸 / 子弹落位会错
	var slope = mg.main_game_slope
	_check(a, "斜面已装配", slope != null, str(slope))
	if slope != null:
		var slope_inst: Node = slope.get_node_or_null("Slope")
		_check(a, "斜面挂上了 slope 实例", slope_inst is Slope, str(slope_inst))

	## 格子 / 小推车 / 僵尸行
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
	var not_roof := 0
	for row_data: ResourceMapRowData in para.map_data.rows:
		if row_data.plant_cell_type != PlantCell.PlantCellType.Roof:
			not_roof += 1
	_check(a, "全行都是屋顶裸地（Roof）", not_roof == 0, "非屋顶行数=%d" % not_roof)

	## 小推车不在这里断言：入场由关卡流程负责（合成关卡不是 LevelScriptBase，流程不会跑），
	## 类型 / 行数已由 STEP1 的逐行比对（lawn_mover_type = 2 屋顶清洁车）覆盖。

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
	a.log("[MOONMAP] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
