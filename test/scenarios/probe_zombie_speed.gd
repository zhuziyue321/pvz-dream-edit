extends RefCounted
## 探针：僵尸 Ground 模式行走速度（px/s）
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_zombie_speed
##
## 为什么要有它：`MoveComponent.E_MoveMode.Ground` 的位移来自动画里的 `_ground` 轨道，
## 直接读 .tres「位移 / 时长」会漏掉**动画循环回绕**那一帧的位移（回绕时 `_ground` 复位，
## 组件把复位量反向推给本体，等效于又前进了一个步幅）。所以速度只能按真实运行量测。
##
## 覆盖：
##   1. 普通僵尸：原版 `PickRandomSpeed()` 0.23~0.37 px/tick ⇒ 23~37 px/s（打印用，不做硬断言：
##      本作僵尸整体移速约为原版一半，属另一件事，见 docs/参考存档/植物僵尸逻辑对照.md §4.3）
##   2. 读报僵尸暴走：原版 `PHASE_NEWSPAPER_MAD` 0.89~0.91 px/tick，是普僵均值 0.30 的 **3 倍**
##      （本作靠 `paper_gasp` 子状态机放大动画 + `ground_speed_scale` 补差，断言按**倍率**来）
##
## 个体随机速度（±23%）会淹没倍率差异，所以测前把 `InitRandomSpeed` 压成 1.0。
## 机器可读汇总：最后一行 [ZSPEED] result=PASS|FAIL failed=<n>

const MAP_FRONT := "res://data/map/map_front.tres"
const MEASURE_SECONDS := 4.0
const SPAWN_X := 700.0
## 原版口径（`Zombie.cpp` 的 `PickRandomSpeed()`），tick ÷ 100 = 秒
const ORI_NORM_MIN := 23.0
const ORI_NORM_MAX := 37.0
## 破报暴走 / 普僵的移速倍率（原版 0.90 / 0.30 = 3.0）
const ORI_MAD_RATIO := 3.0
## 允许误差：动画轨道不是按精确数值烤的，给 ±15%
const TOLERANCE := 0.15

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 僵尸行走速度（Ground 模式） ==========")
	var mg = await _enter_level(a)
	if mg == null:
		_finish(a)
		return

	var norm_speed := await _measure_speed(a, mg, &"norm", 0, false)
	var paper_speed := await _measure_speed(a, mg, &"paper", 2, true)

	a.log("")
	a.log("[NORM] px/s=%.1f" % norm_speed)
	a.log("[PAPER_MAD] px/s=%.1f" % paper_speed)

	## 只报告不判负：整体移速约原版一半是独立问题，别让它盖掉下面真正的倍率断言
	a.log("  [INFO] 普僵 %.1f px/s，原版 %.0f~%.0f（本作整体移速偏慢，另见对照文档 §4.4）"
			% [norm_speed, ORI_NORM_MIN, ORI_NORM_MAX])
	var ratio := paper_speed / norm_speed if norm_speed > 0.0 else 0.0
	_check(a, "破报暴走 / 普僵 ≈ 3 倍（原版 0.90 : 0.30）",
		absf(ratio - ORI_MAD_RATIO) <= ORI_MAD_RATIO * TOLERANCE,
		"实测 %.2f 倍（暴走 %.1f / 普僵 %.1f）" % [ratio, paper_speed, norm_speed])
	_finish(a)


## 进前院白天合成关卡（与 probe_bush 同一套入口）
func _enter_level(a):
	var para: ResourceLevelData = ResourceLevelData.new()
	para.map_data = load(MAP_FRONT)
	para.scene_name = SceneSettingRegistry.SCENE_FRONT_DAY
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
		return null
	_check(a, "进入主游戏场景", true)
	await a.wait(1.5)
	return GameContext.curr_main_game


## 造一只僵尸，压掉个体随机速度，测一段时间的平均 px/s
func _measure_speed(a, mg, zombie_type: StringName, row: int, is_paper_mad: bool) -> float:
	var zm = mg.zombie_manager
	var row_node = zm.all_zombie_rows[row]
	var zombie: Zombie000Base = zm.create_norm_zombie(
		zombie_type,
		row_node,
		{
			Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane: row,
		},
		Vector2(SPAWN_X, row_node.zombie_create_position.global_position.y)
	)
	if zombie == null:
		_check(a, "生成僵尸 %s" % zombie_type, false)
		return -1.0
	## 等 _ready 里的 `init_random_speed()` 落完，再把个体随机速度压成 1.0
	await a.wait(0.4)
	zombie.update_speed_factor(1.0, Character000Base.E_Influence_Speed_Factor.InitRandomSpeed)
	if is_paper_mad:
		## 走真实破防路径：血量清零 → 防具 setter 触发 `on_armor_break()`
		## （is_gasp 与 ground_speed_scale 都在那里设，探针不复制那段逻辑）
		var paper_broken := false
		for armor in zombie.hp_component.armor_list:
			if armor is ArmorComponentNewspaper:
				armor.curr_hp = 0
				paper_broken = true
				break
		if not paper_broken:
			_check(a, "读报僵尸身上找到报纸防具", false)
			return -1.0
		await a.wait(0.8)
	else:
		await a.wait(0.4)
	var x0: float = zombie.global_position.x
	await a.wait(MEASURE_SECONDS)
	var x1: float = zombie.global_position.x
	if is_instance_valid(zombie):
		zombie.queue_free()
	return (x0 - x1) / MEASURE_SECONDS


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[ZSPEED] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
