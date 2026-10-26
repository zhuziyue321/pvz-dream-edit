extends RefCounted

## 探针：玩家对战「植物卡对战口径」（阳光 / 冷却）
##
## 覆盖（`mods_builtin/player_battle/player_battle_plant_wiring.gd` +
## `player_battle_settings.gd` 的两张表，口径 = 白天前院 / DLC 的 `Versus: Day`）：
##   1. 每局接线节点挂上了（`PlayerBattlePlantWiring`）
##   2. 待选区里**表里登记过**的植物：容器 `sun_cost` 与内层卡 `sun_cost` / `cool_time`
##      都换成了对战值（面板显示的那份与选中后搬进卡槽的那份是两处，都要查）
##   3. 待选区里**表外**的对照株（豌豆射手 / 向日葵 / 樱桃炸弹）仍是注册表原值 ——
##      防「整片都改了」这种过度覆盖
##   4. 点一张被覆盖的卡 ⇒ 卡槽里那张也是对战价（选卡搬的是同一个节点，不该被换回去）
##
## 机器可读汇总（最后一行）：[PLANTVERSUS] result=PASS|FAIL failed=<n>

## 模组的共享常量表（探针别另抄一份数值）
const Settings := preload("res://mods_builtin/player_battle/player_battle_settings.gd")
## 关卡脚本的两个加载根（内置源 / 玩家那份，`user://mods/` 优先）
const LEVEL_PATHS := [
	"res://mods_builtin/player_battle/levels/player_battle_day.gd",
	"user://mods/player_battle/levels/player_battle_day.gd",
]
## 接线节点名（与入口脚本的 `PLANT_WIRING_NAME` 同一个）
const WIRING_NAME := "PlayerBattlePlantWiring"
## 表外对照株：wiki 没标对战差异的三株，卡上的值应该还是注册表原值
const UNTOUCHED_PLANTS: Array[StringName] = [
	PlantIds.PEA_SHOOTER_SINGLE,
	PlantIds.SUN_FLOWER,
	PlantIds.CHERRY_BOMB,
]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：玩家对战植物卡对战口径 ==========")
	await a.wait_stable("/root/StartMenu", 8.0)
	## 这局的接线只在模组启用时才装（见 `ModManager.install_mods_to_main_game`）
	ModManager.set_mod_enabled(ModIds.PLAYER_BATTLE, true)
	await a.wait(0.5)

	var level_gd: GDScript = null
	for path in LEVEL_PATHS:
		if ResourceLoader.exists(path):
			level_gd = load(path) as GDScript
			break
	if level_gd == null:
		a.log("!! 关卡脚本加载失败（两个加载根都没有）")
		_finish(a)
		return

	var para = level_gd.new()
	para.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelPlayerBattle, 0, "0001")
	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	var mg: MainGameManager = await _wait_choose_ready(a, 40.0)
	if mg == null:
		a.log("!! 进不了关卡 / 待选区没建出来")
		_finish(a)
		return
	await a.wait(0.5)

	## ---- STEP1 接线节点 ----
	a.log("STEP1 接线节点")
	var wiring: Node = mg.get_node_or_null(WIRING_NAME)
	_check(a, "每局接线节点已挂上（%s）" % WIRING_NAME, wiring != null)

	var slot = mg.card_manager.card_slot_battle
	var candidates: CardSlotCandidate = mg.card_manager.card_slot_norm.card_slot_candidate
	if candidates == null or slot == null:
		a.log("!! 拿不到待选区 / 出战卡槽")
		_finish(a)
		return

	## ---- STEP2 表里登记的株：待选区里已换 ----
	a.log("STEP2 待选区：表里登记的株 = 对战口径")
	var checked := 0
	var bad_cost := ""
	var bad_cool := ""
	for plant_type: StringName in Settings.PLAYER_BATTLE_PLANT_COSTS.keys():
		var container: CardCandidateContainer = _container_of(candidates, plant_type)
		if container == null:
			continue	## 本仓库没有这株（DLC 模组没开 / 没解锁到卡位）
		checked += 1
		var expect_cost: int = int(Settings.PLAYER_BATTLE_PLANT_COSTS[plant_type])
		if container.sun_cost != expect_cost:
			bad_cost += "%s 容器=%d(应 %d) " % [plant_type, container.sun_cost, expect_cost]
		if container.card.sun_cost != expect_cost:
			bad_cost += "%s 卡=%d(应 %d) " % [plant_type, container.card.sun_cost, expect_cost]
		var expect_cool: float = float(Settings.PLAYER_BATTLE_PLANT_COOLDOWNS.get(plant_type, -1.0))
		if expect_cool >= 0.0 and not is_equal_approx(container.card.cool_time, expect_cool):
			bad_cool += "%s=%.1f(应 %.1f) " % [plant_type, container.card.cool_time, expect_cool]
	_check(a, "表里登记的株在待选区至少命中一株（%d 株）" % checked, checked > 0)
	_check(a, "待选区容器与内层卡的阳光都是对战价", bad_cost == "", bad_cost)
	_check(a, "待选区卡的冷却是对战价（墓碑吞噬者 / 芦荟 15 s）", bad_cool == "", bad_cool)

	## ---- STEP3 表外的对照株：不该被动 ----
	a.log("STEP3 待选区：表外对照株仍是注册表原值")
	var untouch_bad := ""
	var untouch_checked := 0
	for plant_type: StringName in UNTOUCHED_PLANTS:
		var container: CardCandidateContainer = _container_of(candidates, plant_type)
		if container == null:
			continue
		untouch_checked += 1
		var raw_cost: int = Global.character_registry.get_plant_info(
			plant_type, CharacterRegistry.PlantInfoAttribute.SunCost)
		var raw_cool: float = Global.character_registry.get_plant_info(
			plant_type, CharacterRegistry.PlantInfoAttribute.CoolTime)
		if container.sun_cost != raw_cost or container.card.sun_cost != raw_cost:
			untouch_bad += "%s 阳光=%d/%d(应 %d) " % [
				plant_type, container.sun_cost, container.card.sun_cost, raw_cost]
		if not is_equal_approx(container.card.cool_time, raw_cool):
			untouch_bad += "%s 冷却=%.1f(应 %.1f) " % [plant_type, container.card.cool_time, raw_cool]
	_check(a, "表外对照株至少命中一株（%d 株）" % untouch_checked, untouch_checked > 0)
	_check(a, "表外对照株没被改成对战价", untouch_bad == "", untouch_bad)

	## ---- STEP4 点进卡槽：还是对战价 ----
	a.log("STEP4 点一张被覆盖的卡 ⇒ 卡槽里也是对战价")
	var covered_type := _first_covered_type(candidates)
	_check(a, "找得到一张表里登记过的植物卡", covered_type != PlantIds.NULL, String(covered_type))
	if covered_type != PlantIds.NULL:
		var probe_container: CardCandidateContainer = _container_of(candidates, covered_type)
		var expect: int = int(Settings.PLAYER_BATTLE_PLANT_COSTS[covered_type])
		probe_container.card.signal_card_click.emit()
		await a.wait(0.5)
		_check(a, "点选后卡进了植物块", slot.count_cards_in_block(0) == 1,
			"%d 张" % slot.count_cards_in_block(0))
		var in_slot: Card = null
		for card in slot.curr_cards:
			if card != null and card.card_plant_type == covered_type:
				in_slot = card
				break
		_check(a, "卡槽里那张就是待选区那一个节点（不是新造的副本）", in_slot == probe_container.card)
		_check(a, "槽里那张的阳光仍是对战价（%d）" % expect,
			in_slot != null and in_slot.sun_cost == expect,
			"拿不到卡" if in_slot == null else str(in_slot.sun_cost))
		var expect_cool: float = float(
			Settings.PLAYER_BATTLE_PLANT_COOLDOWNS.get(covered_type, -1.0))
		if expect_cool >= 0.0:
			_check(a, "槽里那张的冷却是对战价（%.1f）" % expect_cool,
				in_slot != null and is_equal_approx(in_slot.cool_time, expect_cool),
				"拿不到卡" if in_slot == null else "%.1f" % in_slot.cool_time)

	_finish(a)


#region 工具
## 待选区里某株植物的候选容器（没有卡位返回 null）
func _container_of(candidates: CardSlotCandidate, plant_type: StringName) -> CardCandidateContainer:
	var card_id: int = AllCards.plant_card_ids.get(plant_type, -1)
	if card_id < 0:
		return null
	return candidates.all_card_candidate_containers_plant.get(card_id, null)


## 待选区里第一个「表里登记过」的株（找不到返回 `PlantIds.NULL`）
func _first_covered_type(candidates: CardSlotCandidate) -> StringName:
	for plant_type: StringName in Settings.PLAYER_BATTLE_PLANT_COSTS.keys():
		if _container_of(candidates, plant_type) != null:
			return plant_type
	return PlantIds.NULL


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[PLANTVERSUS] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)


## 等进关 + 待选区容器建出来（模组的接线排在 `card_manager.init_manager()` 之后）
func _wait_choose_ready(a, timeout: float) -> MainGameManager:
	var waited := 0.0
	while waited < timeout:
		var mg: MainGameManager = GameContext.curr_main_game
		if mg != null and is_instance_valid(mg) and mg.card_manager != null:
			var norm = mg.card_manager.card_slot_norm
			if norm != null and norm.card_slot_candidate != null \
					and not norm.card_slot_candidate.all_card_candidate_containers_plant.is_empty():
				return mg
		await a.wait(0.5)
		waited += 0.5
	return null
#endregion
