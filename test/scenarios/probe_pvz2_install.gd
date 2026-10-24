extends RefCounted
## 探针：装 / 卸模组「PVZ2」（五株植物：注册表 / 数值 / 卡面 / 卸载）
##
## 无头可跑，只动内存（开关写进 autopilot 那份临时 user 目录）。
##
## 校验：
##   1. 打开 PVZ2 会把依赖的「PAM 动画播放器」一并打开（`get_mod_dependencies()`）
##   2. 五株都登记进注册表，且阳光 / 冷却与 `pvz2_mod.gd` 的常量一致（数值来自 RTON）
##   3. 五张配方的卡面都能造出来，且卡面里挂着**已加载**的 PAM 定格渲染器
##      （PAM 路线没有 `AnimationPlayer`，通用取帧会造出一棵空树 —— 正是这条要防的）
##   4. 关掉模组 → 注册表里的五株全部消失
##
## 机器可读汇总：最后一行 `[PVZ2-INSTALL] result=PASS|FAIL failed=<n>`

const Pvz2Mod := preload("res://mods_builtin/pvz2/pvz2_mod.gd")
const Recipes: Array = [
	preload("res://mods_builtin/pvz2/bonkchoy/bonkchoy_recipe.gd"),
	preload("res://mods_builtin/pvz2/celerystalker/celerystalker_recipe.gd"),
	preload("res://mods_builtin/pvz2/firepeashooter/firepeashooter_recipe.gd"),
	preload("res://mods_builtin/pvz2/peapod/peapod_recipe.gd"),
	preload("res://mods_builtin/pvz2/goopeashooter/goopeashooter_recipe.gd"),
]
## 期望的「植物 id / 阳光 / 冷却」（与 `pvz2_mod.gd` 的常量对齐；数值来自 RTON）
const EXPECTED := {
	&"pvz2_bonkchoy": [150, 5.0],
	&"pvz2_celerystalker": [50, 15.0],
	&"pvz2_firepeashooter": [175, 5.0],
	&"pvz2_peapod": [125, 5.0],
	&"pvz2_goopeashooter": [100, 5.0],
}

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：模组 PVZ2 装 / 卸（五株）==========")

	# ------------------------------------------------ STEP1 装模组 + 依赖
	a.log("STEP1 打开 PVZ2 → 依赖的 PAM 播放器一并打开")
	ModManager.set_mod_enabled(ModIds.PVZ2, true)
	await a.frames(3)
	_check(a, "PVZ2 已启用", ModManager.is_mod_enabled(ModIds.PVZ2))
	_check(a, "依赖的 PAM 动画播放器也被打开", ModManager.is_mod_enabled(ModIds.PAM),
		"没打开：检查 get_mod_dependencies()")

	# ------------------------------------------------ STEP2 注册表与数值
	a.log("STEP2 五株登记进注册表 + 数值")
	var registry := Global.character_registry
	var missing: Array[String] = []
	var wrong_value: Array[String] = []
	for plant_type: StringName in EXPECTED:
		var scene = registry.get_plant_info(plant_type,
			CharacterRegistry.PlantInfoAttribute.PlantScenes)
		if scene == null:
			missing.append(str(plant_type))
			continue
		var sun_cost = registry.get_plant_info(plant_type,
			CharacterRegistry.PlantInfoAttribute.SunCost)
		var cool_time = registry.get_plant_info(plant_type,
			CharacterRegistry.PlantInfoAttribute.CoolTime)
		var expect: Array = EXPECTED[plant_type]
		if int(sun_cost) != int(expect[0]) or not is_equal_approx(float(cool_time), float(expect[1])):
			wrong_value.append("%s(阳光 %s/%s, 冷却 %s/%s)" % [
				str(plant_type), str(sun_cost), str(expect[0]), str(cool_time), str(expect[1])])
	_check(a, "五株都登记了场景", missing.is_empty(), ", ".join(missing))
	_check(a, "五株的阳光 / 冷却与常量一致", wrong_value.is_empty(), ", ".join(wrong_value))

	# ------------------------------------------------ STEP3 卡面
	a.log("STEP3 五张卡面都挂上了能画的定格节点")
	var broken_faces: Array[String] = []
	for recipe_script: Script in Recipes:
		var recipe = recipe_script.new()
		recipe.card_face_scale = Vector2(0.4, 0.4)
		recipe.card_face_position = Vector2(1, 14)
		var face: Node2D = recipe.build_card_face()
		if face == null or face.get_child_count() == 0:
			broken_faces.append("%s(空)" % recipe_script.resource_path.get_file())
			continue
		var frame: Node = face.get_child(0)
		if not frame.call("is_loaded"):
			broken_faces.append("%s(定格节点没加载)" % recipe_script.resource_path.get_file())
		face.queue_free()
	_check(a, "五张卡面都造得出来且定格节点已加载", broken_faces.is_empty(), ", ".join(broken_faces))

	# ------------------------------------------------ STEP3.5 挂载路径（场景里那个空 Node2D 是怎么变成播放器的）
	a.log("STEP3.5 `pam_bridge.attach()`：空 Node2D → 播放器")
	var bridge := preload("res://mods_builtin/pvz2/pam_bridge.gd")
	var plant_script := preload("res://mods_builtin/pvz2/bonkchoy/bonkchoy_plant.gd")
	var host := Node2D.new()
	## 先入树再挂脚本 —— 与实机一致（场景里的挂点是先加载好、`character_ready()` 里才挂播放器）
	a.add_child(host)
	await a.frames(2)
	var attached: bool = bridge.attach(host, plant_script.BIN_REL_PATH, plant_script.ATLAS_REL_PATH,
		plant_script.HIDDEN_PARTS, plant_script.ONESHOT_STATES,
		plant_script.ANIM_PIVOT, plant_script.ANIM_SCALE)
	await a.frames(3)
	_check(a, "attach() 返回成功", attached)
	_check(a, "挂上后数据已加载", host.call("is_loaded"))
	_check(a, "挂上后 _process 开着（少了它会「画出第一帧然后一动不动」）", host.is_processing())
	var host_rect: Rect2 = host.call("get_render_rect")
	_check(a, "挂上后能算出包围盒", host_rect.size.x > 1.0 and host_rect.size.y > 1.0, str(host_rect))
	host.queue_free()
	await a.frames(2)

	# ------------------------------------------------ STEP4 卸载
	a.log("STEP4 关掉模组 → 注册表撤干净")
	ModManager.set_mod_enabled(ModIds.PVZ2, false)
	await a.frames(3)
	var leftover: Array[String] = []
	for plant_type: StringName in EXPECTED:
		if registry.get_plant_info(plant_type,
				CharacterRegistry.PlantInfoAttribute.PlantScenes) != null:
			leftover.append(str(plant_type))
	_check(a, "五株都从注册表撤掉了", leftover.is_empty(), ", ".join(leftover))

	await a.frames(2)
	_finish(a)


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[PVZ2-INSTALL] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
