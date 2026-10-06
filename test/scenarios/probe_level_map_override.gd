extends RefCounted
## 探针：关卡自带地图（map_data）—— 不再靠场景枚举为某一关单开槽位
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_level_map_override
## 覆盖：
##   1. 静态：1-1 / 1-2 / 1-3 / 5-10 四关各自 preload 了自己的地图，game_sences 回落到通用槽位
##   2. 静态：MainSceneRegistry 只剩前院 / 泳池 / 屋顶三个通用槽位，DEFAULT_MAP_PATHS 不含专用图
##   3. 静态：其它关卡不自带地图，继续按 game_sences 取场景默认图
##
## 为什么要有这条探针：三张专用图（map_front_1row / map_front_5row / map_boss）曾经是
## MainScenes 里的 MainGameFront1Row / MainGameFront5Row / MainGameBoss 三个枚举值 ——
## 它们指向的是同一份主游戏场景，只为「选一张不同的地图」而存在，属于把关卡差异顶到全局枚举上。
## 已下沉为关卡自己的 map_data，这里锁住这条契约，防止有人改回去。
## 机器可读汇总：最后一行 [LEVELMAP] result=PASS|FAIL failed=<n>

const MAP_1ROW := "res://data/map/map_front_1row.tres"
const MAP_5ROW := "res://data/map/map_front_5row.tres"
const MAP_BOSS := "res://data/map/map_boss.tres"

## 四关各自应该自带哪张图、场景槽位回落到哪个通用值
const EXPECTED := [
	{"id": "adventure_01_01", "map": MAP_1ROW, "sences": MainSceneRegistry.MainScenes.MainGameFront},
	{"id": "adventure_01_02", "map": MAP_5ROW, "sences": MainSceneRegistry.MainScenes.MainGameFront},
	{"id": "adventure_01_03", "map": MAP_5ROW, "sences": MainSceneRegistry.MainScenes.MainGameFront},
	{"id": "adventure_05_10", "map": MAP_BOSS, "sences": MainSceneRegistry.MainScenes.MainGameRoof},
]
## 抽样：这些关卡不该自带地图，继续走场景默认图
const DEFAULT_LEVELS := ["adventure_01_04", "adventure_02_01", "adventure_03_01",
	"survival_flag_01_day", "survival_flag_05_roof"]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 关卡自带地图（map_data） ==========")
	_check_override_levels(a)
	_check_registry(a)
	_check_default_levels(a)
	_finish(a)


#region 静态：自带地图的四关

func _check_override_levels(a) -> void:
	a.log("")
	a.log("STEP1 自带地图的四关")
	for e: Dictionary in EXPECTED:
		var level_id := str(e["id"])
		var path := LevelRegistry.get_level_path(level_id)
		if path == "":
			_check(a, "%s 已在注册表里" % level_id, false, level_id)
			continue
		var para: ResourceLevelData = (load(path) as GDScript).new()
		if para == null:
			_check(a, "%s 可实例化" % level_id, false, path)
			continue
		var map_res: ResourceMapData = para.map_data
		_check(a, "%s 自带 map_data" % level_id, map_res != null, str(map_res))
		if map_res != null:
			_check(a, "%s 指定的地图 = %s" % [level_id, str(e["map"])],
				map_res.resource_path == e["map"], map_res.resource_path)
		_check(a, "%s 的场景槽位是通用值（%d）" % [level_id, int(e["sences"])],
			int(para.game_sences) == int(e["sences"]), str(para.game_sences))
#endregion


#region 静态：注册表只剩通用槽位

func _check_registry(a) -> void:
	a.log("")
	a.log("STEP2 MainSceneRegistry 只剩通用槽位")
	var paths := MainSceneRegistry.DEFAULT_MAP_PATHS
	_check(a, "DEFAULT_MAP_PATHS 只有前院 / 泳池 / 屋顶 3 项", paths.size() == 3, str(paths.size()))
	for p: Variant in paths.values():
		var path := str(p)
		_check(a, "不含专用图：%s" % path,
			path != MAP_1ROW and path != MAP_5ROW and path != MAP_BOSS, path)
#endregion


#region 静态：其它关卡仍走默认图

func _check_default_levels(a) -> void:
	a.log("")
	a.log("STEP3 其它关卡仍走场景默认图")
	for level_id: String in DEFAULT_LEVELS:
		var path := LevelRegistry.get_level_path(level_id)
		if path == "":
			_check(a, "%s 已在注册表里" % level_id, false, level_id)
			continue
		var para: ResourceLevelData = (load(path) as GDScript).new()
		if para == null:
			_check(a, "%s 可实例化" % level_id, false, path)
			continue
		_check(a, "%s 不自带地图（按 game_sences 回落）" % level_id,
			para.map_data == null, str(para.map_data))
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
	a.log("[LEVELMAP] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
