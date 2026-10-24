extends RefCounted
## 探针 SUN_PRODUCER：产阳光植物（向日葵 / 双子向日葵）的继承链与组件挂载（对应 docs/TODO清单.md 的 U-45）
##
## 【为什么要有这一条】
##   `plant_sun_flower.gd` 与 `plant_twin_sun_flower.gd` 原本是**两个逐字相同的脚本**，
##   2026-10-22 抽成 `PlantSunProducerBase` 后两者只剩 `class_name`。
##   这次改写唯一真实的风险是：**`@onready var create_sun_component` 挪到基类后还能不能取到**
##   （节点路径 `$CreateSunComponent` 在基类里解析，子类场景必须仍有同名节点）。
##   取不到不会报错，只会「向日葵不产阳光」—— 所以必须有机器可读的断言。
##
## 【判定口径】
##   各株种下 → 本体有效 → `create_sun_component != null` → 组件处于启用状态 → 实例 `is PlantSunProducerBase`。
##   ⚠️ 不判定阳光的**产出节奏**（要等 24 秒以上，且节奏在场景参数里，与本次改写无关）。
##
## 【机器可读汇总】最后一行 `[SUNPRODUCER] result=PASS|FAIL failed=<n>`
##
## 【自证方法】把 `PlantSunProducerBase` 里的 `@onready var create_sun_component` 删掉 →
##   本探针第 2 组断言（组件已挂上）必须 FAIL。

const LEVEL := "res://src/levels/mode_adventure/adventure_01_01.gd"
const PLANTS: Array[StringName] = [
	PlantIds.SUN_FLOWER,
	PlantIds.TWIN_SUN_FLOWER,
]
## 每种植物各占一行，避免互相抢格子
const LANES: Array[int] = [0, 1]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE SUN_PRODUCER 产阳光植物 ==========")
	if not await _boot(a):
		_finish(a)
		return
	for i in range(PLANTS.size()):
		await _check_plant(a, PLANTS[i], LANES[i])
	_finish(a)


func _boot(a) -> bool:
	var para: Resource = (load(LEVEL) as GDScript).new()
	if para == null:
		_check(a, "关卡资源可加载", false, LEVEL)
		return false
	Global.game_para = para
	GlobalUtils.change_scene(
		Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.MainGameFront)
	)
	await a.wait(2.0)
	if GameContext.curr_main_game == null:
		_check(a, "主游戏已就绪", false, "curr_main_game 为空")
		return false
	if GameContext.curr_main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		GameContext.curr_main_game.main_game_start()
	var waited := 0.0
	while GameContext.curr_main_game.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME \
			and waited < 30.0:
		await a.wait(1.0)
		waited += 1.0
	var ok: bool = GameContext.curr_main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME
	_check(a, "进入主游戏阶段", ok, "progress=%d" % GameContext.curr_main_game.main_game_progress)
	return ok


func _check_plant(a, plant_id: StringName, lane: int) -> void:
	var label := str(plant_id)
	var cell := _pick_cell(GameContext.curr_main_game.plant_cell_manager, lane)
	if cell == null:
		_check(a, "%s 找到空格子" % label, false, "lane=%d" % lane)
		return
	var plant: Plant000Base = cell.create_plant(plant_id)
	if plant == null or not is_instance_valid(plant):
		_check(a, "%s 种下成功" % label, false, "create_plant 返回空（未解锁 / 注册表缺条目）")
		return
	await a.wait(0.5)
	_check(a, "%s 种下成功" % label, true, "lane=%d" % plant.lane)
	_check(a, "%s 继承 PlantSunProducerBase" % label, plant is PlantSunProducerBase,
		"实际类=%s" % plant.get_class())
	var comp: CreateSunComponent = (plant as PlantSunProducerBase).create_sun_component
	_check(a, "%s 挂上 CreateSunComponent" % label, comp != null,
		"null（基类的 @onready $CreateSunComponent 没取到）" if comp == null else str(comp))
	if comp == null:
		return
	_check(a, "%s 产阳光组件已启用" % label, comp.is_enabling, "is_enabling=%s" % str(comp.is_enabling))


## 该行最右的空格子（僵尸从右侧来，不影响本探针；只是统一取法）
func _pick_cell(mgr, lane: int) -> PlantCell:
	if mgr == null:
		return null
	var all: Array = mgr.all_plant_cells
	if all.size() <= lane:
		return null
	var best: PlantCell = null
	for cell in all[lane]:
		if not is_instance_valid(cell):
			continue
		if not _is_cell_free(cell):
			continue
		if best == null or (cell as PlantCell).row_col.y > best.row_col.y:
			best = cell
	return best


## 不能用 `plant_in_cell.is_empty()`：那个字典预置了全部槽位键（值恒 null），任何格子都不 empty。
## 按槽位走 `PlantCell.get_plant()`（见规范细则 S-06）。
func _is_cell_free(cell: PlantCell) -> bool:
	for place in [
		CharacterRegistry.PlacePlantInCell.Norm,
		CharacterRegistry.PlacePlantInCell.Shell,
		CharacterRegistry.PlacePlantInCell.Down,
		CharacterRegistry.PlacePlantInCell.Float,
		CharacterRegistry.PlacePlantInCell.Imitater,
	]:
		if is_instance_valid(cell.get_plant(place)):
			return false
	return true


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[SUNPRODUCER] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
