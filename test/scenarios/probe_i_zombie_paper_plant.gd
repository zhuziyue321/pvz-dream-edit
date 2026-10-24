extends RefCounted
## 探针：「我是僵尸」模式的**纸板植物**（原版 `Challenge::IZombieSetupPlant` / `IZombieDrawPlant`）。
##
## 断言的是**运行期状态**（不是观感）：
##   1. idle 静止：动画树的 TimeScale = 0（原版 reanim 的 animRate = 0），
##      且**动画播放位置不再前进**（真静止，不是「看起来慢」）
##      —— 攻击动画播的瞬间除外：原版**只有 idle 冻结**，开火时 `Plant::Fire()`
##      的 `PlayBodyReanim` 会把速率设回去（见 PvZ-Portable-main/src/Lawn/Plant.cpp:787）
##   2. 不眨眼（原版 mBlinkCountdown = 0）
##   3. 纸板外观：本体层挂「淡色本体」材质 + 三层错位的纯色剪影描边（偏移与颜色照原版）
##   4. **攻击动画照播 + 照样发射**：纸板豌豆射手 idle 不动，开火时攻击动画照播、
##      method track 照常吐豌豆（放行通道见 `ComponentAnimNorm.request_one_shot`）
##
## 需要真的进关跑一遍，所以 headless 也得等场景与战斗流程起来。

const LEVEL_PATH := "res://src/levels/mode_puzzle/puzzle_zombie_01.gd"

## 原版的三层描边（偏移 + 颜色），见 `Challenge::IZombieDrawPlant`
## ⚠️ 颜色按 **0~255** 写（跟原版源码对得上）；传给 shader 前要除 255
const EXPECT_OUTLINES := [
	{"offset": Vector2(4, 4), "color": Color(122, 86, 58)},
	{"offset": Vector2(2, 2), "color": Color(171, 135, 107)},
	{"offset": Vector2(-2, -2), "color": Color(171, 135, 107)},
]
## 原版本体层的淡肤色
const EXPECT_BODY_TINT := Color(255, 201, 160)
## 描边层节点名前缀（见 `PaperPlantLook.OUTLINE_NAME_PREFIX`）
const OUTLINE_PREFIX := "PaperPlantOutline"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 纸板植物（静止 + 纸板质感） ==========")
	var para: ResourceLevelData = (load(LEVEL_PATH) as GDScript).new()
	if para == null:
		_check(a, "关卡脚本可实例化", false)
		_finish(a)
		return
	Global.game_para = para
	await a.frames(3)
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	await a.wait(3.0)
	var mg: MainGameManager = GameContext.curr_main_game
	_check(a, "已进入主游戏", mg != null, "GameContext.curr_main_game 为空")
	if mg == null:
		_finish(a)
		return
	## 等纸板植物摆好 + 描边层复制完（描边层是延后一帧复制的）
	await a.wait(2.0)

	var plants := _collect_plants(mg)
	_check(a, "场上有纸板植物", not plants.is_empty(), "一株都没找到")
	if plants.is_empty():
		_finish(a)
		return
	for plant: Plant000Base in plants:
		await _check_plant(a, plant)
	## 截一张图（能取到就存一份，方便人眼确认纸板观感；headless 下可能取到空图）
	_screenshot(a)
	await _check_still_shoots(a, mg, plants)
	_finish(a)


## 截当前画面（存到 user://，跑批的临时 userdir 里）
func _screenshot(a) -> void:
	var tex: ViewportTexture = a.get_tree().root.get_texture()
	if tex == null:
		a.log("  [截图] 取不到视口纹理")
		return
	var img: Image = tex.get_image()
	if img == null:
		a.log("  [截图] 取不到图像")
		return
	var path := "user://paper_plant_shot.png"
	var err := img.save_png(path)
	a.log("  [截图] %s err=%s 尺寸=%s" % [path, str(err), str(img.get_size())])


## 收集场上所有纸板植物
func _collect_plants(mg: MainGameManager) -> Array[Plant000Base]:
	var result: Array[Plant000Base] = []
	for row: Array in mg.plant_cell_manager.all_plant_cells:
		for cell: PlantCell in row:
			var plant := cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm) as Plant000Base
			if plant != null and is_instance_valid(plant):
				result.append(plant)
	return result


## 逐株检查：静止 / 不眨眼 / 纸板外观
func _check_plant(a, plant: Plant000Base) -> void:
	var title := "植物[%s]" % plant.plant_type
	_check(a, title + ": 是僵尸模式的纸板植物", plant.is_zombie_mode)

	## ① 动画静止：动画树的 TimeScale = 0
	## 攻击动画播的瞬间会临时抬回 1（原版只有 idle 冻结）——那一下跳过静止断言
	var anim_tree := plant.get_node_or_null(^"AnimationTree") as AnimationTree
	var attacking: bool = anim_tree != null and anim_tree.get("parameters/OneShot/active") == true
	if attacking:
		a.log("  [诊断] %s 正在攻击动画中，跳过静止断言" % title)
	else:
		var scale_value := -1.0
		if anim_tree != null:
			scale_value = anim_tree.get("parameters/TimeScale/scale")
		_check(a, title + ": 动画静止（TimeScale = 0）", is_equal_approx(scale_value, 0.0),
			"TimeScale=%s" % str(scale_value))

		## ①b 播放位置不再前进（真静止；光看 TimeScale 不足以证明动画没在动）
		## 前后各看一眼是否在攻击 —— 等待期间开火的话位置前进是正常的，不算 NG
		var pos_before := _anim_position(plant)
		await a.wait(1.0)
		var pos_after := _anim_position(plant)
		var attacked_during: bool = anim_tree != null and anim_tree.get("parameters/OneShot/active") == true
		if not attacked_during:
			_check(a, title + ": 动画播放位置不再前进", is_equal_approx(pos_before, pos_after),
				"位置 %s → %s" % [str(pos_before), str(pos_after)])
		else:
			a.log("  [诊断] %s 等待期间在播攻击动画，跳过位置断言" % title)
		## 诊断：动画树有没有真的切到待机动画（切不到 = 纸上还是「Start」姿势）
		a.log("  [诊断] %s 动画名=%s 位置=%s" % [title, str(plant.anim_component.anim_name_now), str(pos_after)])

	## ② 不眨眼
	_check(a, title + ": 不眨眼", not plant.blink_component.is_enabling)

	## ③ 纸板外观：本体层材质
	var body_material := plant.body.material as ShaderMaterial
	_check(a, title + ": 本体挂纸板材质", body_material != null)
	if body_material != null:
		var tint: Color = body_material.get_shader_parameter("paper_tint")
		var is_silhouette: bool = body_material.get_shader_parameter("silhouette")
		_check(a, title + ": 本体是「淡色本体」层", not is_silhouette)
		_check(a, title + ": 本体淡肤色 = 原版 (255,201,160)",
			tint.is_equal_approx(EXPECT_BODY_TINT / 255.0), str(tint))

	## ③b 贴图节点**真的**挂上了纸板材质
	##
	## ⚠️ 这条是踩过坑才加的：Godot 的「用父节点材质」只往上找**一层**，
	##   只给 Body 挂材质的话，贴图还是原色（画面上完全看不出纸板效果）。
	var sprite_mats := _sprite_materials(plant.body)
	var bad_count := 0
	for mat: Material in sprite_mats:
		if mat != body_material:
			bad_count += 1
	_check(a, title + ": 贴图节点都挂上了纸板材质",
		not sprite_mats.is_empty() and bad_count == 0,
		"贴图 %d 个，没挂上 %d 个" % [sprite_mats.size(), bad_count])

	## ③ 纸板外观：三层错位的纯色剪影描边
	var outlines: Array[Node] = []
	for child in plant.get_children():
		if String(child.name).begins_with(OUTLINE_PREFIX):
			outlines.append(child)
	_check(a, title + ": 有 3 层描边", outlines.size() == 3, "实际 %d 层" % outlines.size())
	for i in range(mini(outlines.size(), EXPECT_OUTLINES.size())):
		var expect: Dictionary = EXPECT_OUTLINES[i]
		var outline := outlines[i] as Node2D
		var material := outline.material as ShaderMaterial
		var ok: bool = material != null \
				and material.get_shader_parameter("silhouette") == true \
				and (material.get_shader_parameter("paper_tint") as Color).is_equal_approx(expect["color"] / 255.0) \
				and outline.position.is_equal_approx(plant.body.position + expect["offset"])
		_check(a, title + ": 描边 %d 与原版一致（偏移 %s / 颜色 %s）"
			% [i, expect["offset"], expect["color"]], ok, "pos=%s" % str(outline.position))
		## 描边层必须画在本体下面
		_check(a, title + ": 描边 %d 画在本体下面" % i, outline.z_index < plant.body.z_index,
			"描边 z=%d 本体 z=%d" % [outline.z_index, plant.body.z_index])
		## 描边层的贴图也得挂上剪影材质（同上：父材质只往上一层）
		var outline_mats := _sprite_materials(outline)
		var outline_bad := 0
		for mat: Material in outline_mats:
			if mat != material:
				outline_bad += 1
		_check(a, title + ": 描边 %d 的贴图都挂上了剪影材质" % i,
			not outline_mats.is_empty() and outline_bad == 0,
			"贴图 %d 个，没挂上 %d 个" % [outline_mats.size(), outline_bad])


## 收集一棵植物（或一层描边）下面所有贴图节点的材质
func _sprite_materials(node: Node) -> Array[Material]:
	var result: Array[Material] = []
	for sprite: Node in _collect_sprites(node):
		var ci := sprite as CanvasItem
		if ci != null:
			result.append(ci.material)
	return result


## 收集下面所有贴图节点
func _collect_sprites(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			result.append(child)
		result.append_array(_collect_sprites(child))
	return result


## 读动画播放位置（动画树那条路）
func _anim_position(plant: Plant000Base) -> float:
	if not is_instance_valid(plant.anim_component):
		return -1.0
	plant.anim_component.update_current_anim()
	return plant.anim_component.anim_position_now


## 静止的纸板豌豆射手：攻击动画照播 + 照样吐豌豆
##
## 原版口径：只有 idle 冻结，开火时 `Plant::Fire()` 把 animRate 设回攻击速率
## （PvZ-Portable-main/src/Lawn/Plant.cpp:787），攻击动画照播、method track 照常发射。
## 这里放一只僵尸到豌豆射手右边，等它进入攻击状态，看攻击动画有没有播、有没有真的开火。
##
## ⚠️ 判定**数开火次数**（`signal_shoot_bullet`），不看场上的子弹数：
##   僵尸放得近时豌豆很快命中并消失，「子弹数」会回到 0，判不出有没有开过火。
func _check_still_shoots(a, mg: MainGameManager, plants: Array[Plant000Base]) -> void:
	var shooter: Plant000Base = null
	for plant: Plant000Base in plants:
		if plant.plant_type == PlantIds.PEA_SHOOTER_SINGLE:
			shooter = plant
			break
	if shooter == null:
		_check(a, "场上有一株纸板豌豆射手", false, "这一关没随机到豌豆射手")
		return
	_check(a, "场上有一株纸板豌豆射手", true)

	var attack := shooter.get_node_or_null(^"AttackComponent")
	_check(a, "攻击组件存在", attack != null)
	if attack == null:
		return

	## 数开火次数（发射前就挂上，别漏掉第一发）
	var shots := {"n": 0}
	attack.signal_shoot_bullet.connect(func() -> void: shots["n"] += 1)

	## 放一只僵尸到它右边，等攻击状态建立 + 冷却到点
	var zm: ZombieManager = mg.zombie_manager
	if zm.all_zombie_rows.is_empty():
		_check(a, "僵尸行已初始化", false)
		return
	var lane: int = shooter.row_col.x
	var row: ZombieRow = zm.all_zombie_rows[lane]
	var init_para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType: row.zombie_row_type,
	}
	var zombie_x: float = shooter.global_position.x + 120.0
	## ★ y 用**出怪点**的 y（`zombie_create_position`），不是行节点自己的 y ——
	##   行节点的原点跟地面差一截，差这点像素僵尸就落在植物那条 5 像素高的
	##   索敌带外面，植物永远发现不了它（仓库里放僵尸也一律用这个 y）。
	var spawn_y: float = row.zombie_create_position.global_position.y
	a.log("  [诊断] 植物=%s 出怪点y=%s 植物y=%s" % [
		str(shooter.global_position), str(spawn_y), str(shooter.global_position.y)])
	var zombie := zm.create_norm_zombie(ZombieIds.NORM, row, init_para,
			Vector2(zombie_x, spawn_y))
	_check(a, "测试僵尸创建成功", zombie != null)
	if zombie == null:
		return
	## 等它进入攻击状态并触发一次攻击（冷却 1.5 秒 + 随机首等）；
	## 期间每 0.2s 看一眼 OneShot 是否激活 —— 激活过 = 攻击动画真的播了
	var anim_played := false
	for i in range(20):
		await a.wait(0.2)
		var at := shooter.get_node_or_null(^"AnimationTree") as AnimationTree
		if at != null and at.get("parameters/OneShot/active") == true:
			anim_played = true
	_check(a, "攻击动画照常播放（原版只有 idle 冻结）", anim_played)
	a.log("  [诊断] 开火次数=%d 僵尸血量=%s 植物可攻击=%s" % [
		shots["n"],
		str(zombie.hp_component.curr_hp) if is_instance_valid(zombie) else "僵尸已失效",
		str(attack.is_attack_res)])
	_check(a, "纸板豌豆射手照样发射", shots["n"] > 0,
		"开火次数=%d" % shots["n"])


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if not detail.is_empty() else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[PAPERPLANT] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
