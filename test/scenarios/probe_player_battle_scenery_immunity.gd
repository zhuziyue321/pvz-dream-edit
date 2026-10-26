extends RefCounted

## 探针：对战里两只「建筑型僵尸」的免疫（靶子僵尸 / 产脑光墓碑）
##
## 覆盖（2026-10-25 用户要求「靶子僵尸像墓碑那样：免疫小推车等、被魅惑僵尸无视」）：
##   1. 两只都 `is_targetable_by_hypno_zombie() == false`（魅惑僵尸索敌会跳过）；
##   2. 两只场景里都挂着 `ImmuneMowerComponent`：小推车是 `E_DamageCause.Mower` 的秒杀伤害，
##      由该修饰器在伤害管线里整包取消（2026-10-26 由「脚本空覆盖」改成「免疫一类伤害」）；
##   3. 靶子 `be_mowered_run()` 真的碾一次 ⇒ 血量不掉、不进入死亡、节点还在；
##   4. 反向对照：普通僵尸 `is_targetable_by_hypno_zombie() == true` —— 别把整类都禁掉；
##   5. 靶子仍然**能被打**（走植物那条通道）：受击框还在。
##
## 机器可读汇总（最后一行）：[SCENERYIMM] result=PASS|FAIL failed=<n>

## 靶子僵尸 id（见 `player_battle_settings.gd`）
const TARGET_ID := &"pb_target_zombie"
## 产脑光墓碑的场景（两只都从模组加载根取，`user://` 优先）
const GRAVE_PATHS := [
	"res://mods_builtin/player_battle/vsgravestone/zombie_vsgravestone.tscn",
	"user://mods/player_battle/vsgravestone/zombie_vsgravestone.tscn",
]
const LEVEL_PATHS := [
	"res://mods_builtin/player_battle/levels/player_battle_day.gd",
	"user://mods/player_battle/levels/player_battle_day.gd",
]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：对战建筑型僵尸免疫（靶子 / 墓碑）==========")
	await a.wait_stable("/root/StartMenu", 8.0)
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
	var mg: MainGameManager = await _wait_ready(a, 40.0)
	if mg == null:
		a.log("!! 进不了关卡 / 靶子僵尸没摆出来")
		_finish(a)
		return
	await a.wait(0.5)

	## ---- STEP1 靶子僵尸：两个免疫 + 反证 ----
	a.log("STEP1 靶子僵尸")
	var target: Zombie000Base = _find_zombie(mg, TARGET_ID)
	_check(a, "场上找到靶子僵尸", target != null)
	if target != null:
		_check(a, "靶子僵尸：魅惑僵尸索敌会无视它", not target.is_targetable_by_hypno_zombie())
		## 免疫小推车靠场景里的修饰器组件（`ComponentImmuneMower`），不是脚本里的空覆盖
		_check(a, "靶子场景挂着免疫小推车的修饰器组件",
			target.get_node_or_null("ImmuneMowerComponent") != null)
		_check(a, "靶子僵尸：能被植物打（受击框还在）",
			target.hurt_box_component != null)
		var hp_before: int = target.hp_component.get_all_hp()
		target.be_mowered_run(null)
		await a.wait(0.3)
		var hp_after: int = target.hp_component.get_all_hp() if is_instance_valid(target) else -1
		_check(a, "靶子僵尸：被小推车碾过不扣血（%d → %d）" % [hp_before, hp_after],
			hp_after == hp_before)
		_check(a, "靶子僵尸：被碾过之后没有进入死亡流程",
			is_instance_valid(target) and not target.is_death)

	## ---- STEP2 墓碑：同样两条 ----
	a.log("STEP2 产脑光墓碑")
	var grave: Zombie000Base = _new_grave()
	_check(a, "墓碑场景能实例化（模组已装）", grave != null)
	if grave != null:
		_check(a, "墓碑：魅惑僵尸索敌会无视它", not grave.is_targetable_by_hypno_zombie())
		## 免疫靠场景里的修饰器组件。⚠️ 这里**只查挂载、不入树**：组件是在 `_ready()`
		## （`component_ready()`）里注册进 `DamageSystem` 的，未入树时调 `be_mowered_run()`
		## 会走真正的碾压流程把它压死 —— 那不是这个探针要验的事。
		_check(a, "墓碑场景挂着免疫小推车的修饰器组件",
			grave.get_node_or_null("ImmuneMowerComponent") != null)
		grave.free()

	## ---- STEP3 反向对照：普通僵尸不该被一起禁掉 ----
	a.log("STEP3 反向对照")
	## 只调方法、不入树：默认值就在基类里，不需要 ready / 管理器
	var norm_zombie := Global.character_registry.instantiate_zombie(ZombieIds.NORM)
	_check(a, "普通僵尸能实例化", norm_zombie != null)
	if norm_zombie != null:
		_check(a, "普通僵尸：魅惑僵尸照常能打它", norm_zombie.is_targetable_by_hypno_zombie())
		norm_zombie.free()

	_finish(a)


#region 工具
func _find_zombie(mg: MainGameManager, zombie_type: StringName) -> Zombie000Base:
	for z in mg.zombie_manager.all_zombies_1d:
		if z != null and is_instance_valid(z) and z.zombie_type == zombie_type:
			return z
	return null


func _new_grave() -> Zombie000Base:
	for path in GRAVE_PATHS:
		if ResourceLoader.exists(path):
			var scene := load(path) as PackedScene
			if scene != null:
				return scene.instantiate() as Zombie000Base
	return null


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[SCENERYIMM] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)


func _wait_ready(a, timeout: float) -> MainGameManager:
	var waited := 0.0
	while waited < timeout:
		var mg: MainGameManager = GameContext.curr_main_game
		if mg != null and is_instance_valid(mg) and mg.zombie_manager != null:
			if _find_zombie(mg, TARGET_ID) != null:
				return mg
		await a.wait(0.5)
		waited += 0.5
	return null
#endregion
