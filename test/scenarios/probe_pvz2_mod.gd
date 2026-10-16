extends RefCounted
## 探针：战斗植物「菜问」（模组 `pvz2`，PVZ2 角色）
##
## 无头可跑，只动内存（开关写进 autopilot 那份临时 user 目录）。校验：
##   1. 装上模组 → 注册表里有场景 / 阳光 / 冷却 / 种植条件（普通陆生、占 Norm 位），且已解锁
##   2. 卡片：追加在普通植物之后、待选区里有卡位
##   3. 图鉴：模组自己登记的那条「菜问」
##   4. 动画：种进草地后播的是 PVZ2 烘焙动画（idle 三段之一），播放器里 17 段动画都在
##   5. 出拳：检测框（左右相邻两格）在、出手间隔计时器在、三个数值（15 / 35 / 0.35）对上
##   6. **渲染**：烘焙动画的 57 个槽位不再各自带 z_index（曾把血条与卡片冷却遮罩盖住）；
##      PVZ2 那套装扮一件都不画（场上这株与卡片卡面上都查）

##   7. **收拳**：出拳段播完回待机，不停格在出拳最后一帧
##   8. **伤害**：满血僵尸挨一记直拳掉 15 点血
##   9. **朝向**：直拳 / 上勾拳 × 朝左 / 朝右 四段按目标方位挑（僵尸挪到左边就换朝左那段）
##  10. **斩杀判定**：押进斩杀窗口（总血 - 35 ≤ 死亡临界值）后判定为可斩杀，且挑出的是上勾拳段
##  11. 关掉模组 → 卡位、解锁、图鉴一并撤掉
##
## 机器可读汇总：最后一行 [PVZ2] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

## 菜问的植物 id（模组自己起的字符串 id，本体不认得它）
const BONK_CHOY := &"pvz2_bonkchoy"
## 普通陆生植物（拿来对照卡位顺序）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE
## PVZ2 那段烘焙动画里的 17 段（见 `mods_builtin/pvz2/bonkchoy/bonkchoy_anim.tscn`）
const ALL_ANIMS: Array[String] = [
	"idle", "idle2", "idle3",
	"attack", "attack2", "attack3", "attack4", "attack5", "attack6", "attack7",
	"plantfood_on", "plantfood", "plantfood_off",
	"plantfood_on2", "plantfood2", "plantfood_off2",
	"water",
]
const IDLE_ANIMS: Array[String] = ["idle", "idle2", "idle3"]
## 直拳 / 上勾拳 × 朝右 / 朝左 四段，与 `bonkchoy_plant.gd` 的同名常量对齐
## （判据：可见槽位 x 跨度 + 变换矩阵是否被镜像，见该脚本文件头）
const JAB_ANIM_RIGHT := &"attack"
const JAB_ANIM_LEFT := &"attack2"
const UPPERCUT_ANIM_RIGHT := &"attack4"
const UPPERCUT_ANIM_LEFT := &"attack5"
## PVZ2 那套装扮的贴图（生日帽 / 水手装 / 围巾 / 腰带 / 花环 / 绷带…）：
## 烘焙产物里它们和本体一起画，本作不要 —— 已在 `.tscn` 里逐帧压掉（见 `bonkchoy_plant.gd` 文件头）
const COSTUME_TEXTURES: Array[String] = [
	"bonkchoy_55x60.png", "bonkchoy_77x171.png", "bonkchoy_79x40.png",
	"bonkchoy_96x34.png", "bonkchoy_96x40.png", "bonkchoy_97x37.png",
	"bonkchoy_98x101.png", "bonkchoy_102x68.png", "bonkchoy_103x67.png",
	"bonkchoy_105x134.png", "bonkchoy_109x59.png", "bonkchoy_130x52.png",
]

const PLANT_CELL_SCENE := "res://src/ui/plant_cell.tscn"
## 普通僵尸（拿来验伤害：满血 270，一拳 15 打不死，探针里不会走死亡/掉落流程）
const ZOMBIE_NORM := "res://src/entities/character/zombie/zombie_norm.tscn"


func run(a) -> void:
	a.log("")
	a.log("========== 探针：战斗植物「菜问」（模组 pvz2，PVZ2 角色）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组
	a.log("STEP1 装上模组 → 菜问登记进注册表")
	ModManager.set_mod_enabled(ModIds.PVZ2, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(BONK_CHOY, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	_check(a, "菜问登记了场景", plant_scene != null, "null" if plant_scene == null else plant_scene.resource_path)
	_check(a, "菜问阳光 = 150",
		registry.get_plant_info(BONK_CHOY, CharacterRegistry.PlantInfoAttribute.SunCost) == 150)
	_check(a, "菜问冷却 = 7.5 秒",
		registry.get_plant_info(BONK_CHOY, CharacterRegistry.PlantInfoAttribute.CoolTime) == 7.5)
	_check(a, "菜问已解锁", Global.global_game_state.is_plant_unlocked(BONK_CHOY))
	var condition = registry.get_plant_info(BONK_CHOY, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "菜问登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "菜问是普通陆生植物（2 草地 + 4 花盆 + 16 睡莲 = 22）",
		condition.plant_condition == 22, str(condition.plant_condition))
	_check(a, "菜问占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "菜问有卡位", AllCards.plant_card_ids.has(BONK_CHOY))
	var choy_id: int = AllCards.plant_card_ids.get(BONK_CHOY, -1)
	var pea_id: int = AllCards.plant_card_ids.get(PEA_SHOOTER, -1)
	_check(a, "菜问卡排在豌豆射手卡之后（模组新增一律追加）", choy_id > pea_id,
		"豌豆=%d 菜问=%d" % [pea_id, choy_id])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	_check(a, "装上模组后菜问有图鉴条目",
		str(Global.global_read_data.get_extra_almanac_entry(BONK_CHOY).get("名字", "")) == "菜问",
		str(Global.global_read_data.get_extra_almanac_entry(BONK_CHOY)))

	# ------------------------------------------------ STEP4 种下去 + 动画
	a.log("STEP4 种进草地 → 播 PVZ2 那段烘焙动画")
	var cell: PlantCell = load(PLANT_CELL_SCENE).instantiate()
	a.get_tree().root.add_child(cell)
	await a.frames(1)
	var choy = cell.create_plant(BONK_CHOY, false, false)
	if choy == null:
		_check(a, "菜问能种进草地", false, "create_plant 返回 null")
		cell.free()
		_finish(a)
		return
	await a.frames(2)
	var player: AnimationPlayer = choy.get_node_or_null("Body/BonkChoyAnim/AnimationPlayer")
	if player == null:
		_check(a, "菜问身上有 PVZ2 动画播放器", false, "取不到 Body/BonkChoyAnim/AnimationPlayer")
		cell.free()
		_finish(a)
		return
	var missing: Array[String] = []
	for anim_name in ALL_ANIMS:
		if not player.has_animation(anim_name):
			missing.append(anim_name)
	_check(a, "17 段 PVZ2 动画都在播放器里", missing.is_empty(), str(missing))
	var curr: String = String(player.current_animation)
	_check(a, "当前在播待机三段之一", curr in IDLE_ANIMS, str(curr))
	_check(a, "播放器真的在跑（不是停在第 0 帧）", player.is_playing())

	# ------------------------------------------------ STEP5 出拳的那套零件与数值
	a.log("STEP5 出拳：检测框 + 冷却计时器 + 数值（直拳 15 / 上勾拳 35 / 间隔 0.35）")
	var detect := choy.get_node_or_null("DetectComponent") as DetectComponent
	_check(a, "菜问挂了检测组件", detect != null)
	_check(a, "检测范围铺开了（本行左右相邻两格）",
		detect != null and detect.get_child_count() > 0,
		"null" if detect == null else "子节点 %d 个" % detect.get_child_count())
	_check(a, "出拳间隔计时器在", choy.get_node_or_null("AttackCdTimer") != null)
	_check(a, "出手间隔 = 0.35 秒", is_equal_approx(float(choy.get("attack_cd")), 0.35),
		str(choy.get("attack_cd")))
	_check(a, "直拳伤害 = 15", int(choy.get("jab_damage")) == 15, str(choy.get("jab_damage")))
	_check(a, "上勾拳伤害 = 35", int(choy.get("uppercut_damage")) == 35,
		str(choy.get("uppercut_damage")))

	# ------------------------------------------------ STEP6 渲染：不越层 + 不画装扮
	a.log("STEP6 渲染：动画槽停在 0 层（血条 / 卡片冷却遮罩才压得住它），且一件装扮都不画")
	var anim_root := choy.get_node_or_null("Body/BonkChoyAnim")
	var bad_z: Array[String] = []
	if anim_root == null:
		_check(a, "动画根节点在", false, "取不到 Body/BonkChoyAnim")
	else:
		for slot in anim_root.get_children():
			if slot is CanvasItem and (slot as CanvasItem).z_index != 0:
				bad_z.append("%s=%d" % [slot.name, (slot as CanvasItem).z_index])
		_check(a, "动画槽全部停在 0 层（曾经是 0~56，会盖住血条与卡片冷却遮罩）",
			bad_z.is_empty(), str(bad_z))
		var on_plant: Array[Sprite2D] = []
		_collect_sprites(anim_root, on_plant)
		_check(a, "场上这株没画装扮", _shown_costumes(on_plant).is_empty(),
			str(_shown_costumes(on_plant)))
	## 卡面是从植物场景取帧来的（同一份动画数据），也该干干净净
	var card: Card = AllCards.all_plant_card_prefabs.get(BONK_CHOY, null)
	if card == null or not is_instance_valid(card.character_static):
		_check(a, "菜问的卡面在（拿来查装扮）", false, "拿不到卡片或 character_static")
	else:
		var on_card: Array[Sprite2D] = []
		_collect_sprites(card.character_static, on_card)
		_check(a, "卡面上也没画装扮", _shown_costumes(on_card).is_empty(),
			str(_shown_costumes(on_card)))
	## 同层里靠树序压住植物：血条（HpComponent）必须排在 Body 之后 —— 本体植物的规矩，
	## 菜问不能破（破了就算 z 都是 0，血条也会被身体盖住）
	var body_index: int = choy.get_node("Body").get_index() if choy.has_node("Body") else -1
	var hp_index: int = choy.get_node("HpComponent").get_index() if choy.has_node("HpComponent") else -1
	_check(a, "血条排在 Body 之后（同层里血条画在植物之上）", hp_index > body_index,
		"Body=%d HpComponent=%d" % [body_index, hp_index])

	# ------------------------------------------------ STEP7 收拳：出拳播完回待机
	a.log("STEP7 出拳动画播完 → 收拳回待机（不能定格在出拳最后一帧）")
	## 走真入口：这条信号就是「检测框里进了敌人」
	detect.signal_can_attack.emit()
	## 掐掉冷却计时器：本步只看出拳段的收尾，不让下一拳插进来
	choy.attack_cd_timer.stop()
	await player.animation_finished
	await a.frames(1)
	var curr_after: String = String(player.current_animation)
	_check(a, "出拳播完回到待机（不是停在出拳最后一帧）",
		player.is_playing() and curr_after in IDLE_ANIMS,
		"is_playing=%s curr=%s" % [str(player.is_playing()), curr_after])
	detect.signal_not_can_attack.emit()

	# ------------------------------------------------ STEP8 伤害
	a.log("STEP8 伤害：满血僵尸挨一记直拳掉 15 点血")
	var zombie: Zombie000Base = (load(ZOMBIE_NORM) as PackedScene).instantiate() as Zombie000Base
	## lane 必须在入树之前写：`DetectComponent.component_ready()` 见到 lane == -1 会 Log.error
	zombie.lane = choy.lane
	a.get_tree().root.add_child(zombie)
	await a.frames(1)
	## 先摆到**右边**那一格：受击框（僵尸局部 (0,-40)，40x80）落进检测框（240x80，中心在 (0,-25)）
	zombie.global_position = choy.global_position + Vector2(60, 40)
	await a.wait(0.2)
	choy.attack_cd_timer.stop()
	var targets: Array[Character000Base] = detect.get_all_enemy_can_be_attacked()
	_check(a, "检测框里认出了这只僵尸", targets.has(zombie), "认出 %d 个" % targets.size())
	var hp_c := zombie.hp_component
	_check(a, "满血 %d 时不算能斩杀" % hp_c.get_all_hp(),
		not choy._punches_can_kill(targets),
		"总血=%d 临界值=%d" % [hp_c.get_all_hp(), hp_c.death_hp])
	var hp_before: int = hp_c.curr_hp
	choy._attack_once(targets, int(choy.get("jab_damage")))
	_check(a, "直拳打掉 15 点血", hp_before - hp_c.curr_hp == 15,
		"%d → %d" % [hp_before, hp_c.curr_hp])

	# ------------------------------------------------ STEP9 朝向
	a.log("STEP9 朝向：直拳 / 上勾拳 × 朝左 / 朝右 四段按目标方位挑")
	_check(a, "直拳朝右 = attack", choy._pick_punch_anim(false, false) == JAB_ANIM_RIGHT,
		str(choy._pick_punch_anim(false, false)))
	_check(a, "直拳朝左 = attack2", choy._pick_punch_anim(false, true) == JAB_ANIM_LEFT,
		str(choy._pick_punch_anim(false, true)))
	_check(a, "上勾拳朝右 = attack4", choy._pick_punch_anim(true, false) == UPPERCUT_ANIM_RIGHT,
		str(choy._pick_punch_anim(true, false)))
	_check(a, "上勾拳朝左 = attack5", choy._pick_punch_anim(true, true) == UPPERCUT_ANIM_LEFT,
		str(choy._pick_punch_anim(true, true)))
	## 端到端（真出一拳，目标还在右格且没进斩杀窗口 ⇒ 该出朝右的直拳）
	choy.attack_cd_timer.stop()
	choy._punch()
	_check(a, "目标在右边：出的是朝右的直拳", player.current_animation == JAB_ANIM_RIGHT,
		String(player.current_animation))
	## 挪到左边那一格再出一拳 ⇒ 换成朝左那段
	zombie.global_position = choy.global_position + Vector2(-60, 40)
	await a.wait(0.2)
	choy.attack_cd_timer.stop()
	choy._punch()
	_check(a, "目标在左边：出的是朝左的直拳", player.current_animation == JAB_ANIM_LEFT,
		String(player.current_animation))

	# ------------------------------------------------ STEP10 斩杀判定
	a.log("STEP10 斩杀判定：目标（在左边）押进斩杀窗口 → 挑出的是朝左的上勾拳")
	## 押进斩杀窗口：总血比死亡临界值高 5 → 僵尸还活着（`character_death` 不触发），
	## 但这一拳的 35 打下去会落到临界值以下 ⇒ 判定为可斩杀
	hp_c.curr_hp = hp_c.death_hp + 5
	targets = detect.get_all_enemy_can_be_attacked()
	_check(a, "总血进入斩杀窗口时判定为可斩杀", choy._punches_can_kill(targets),
		"总血=%d 临界值=%d 上勾拳=%d" % [hp_c.get_all_hp(), hp_c.death_hp,
			int(choy.get("uppercut_damage"))])
	## 把「能不能斩杀」与「朝哪边」合成一次挑段：在左边 + 能斩杀 ⇒ 朝左的上勾拳
	var decided: StringName = choy._pick_punch_anim(
		choy._punches_can_kill(targets), choy._is_target_on_left(targets))
	_check(a, "目标在左边且能斩杀：挑出朝左的上勾拳", decided == UPPERCUT_ANIM_LEFT, str(decided))
	## 上勾拳那 35 点伤害不在这里打 —— 进斩杀窗口意味着挨完就死，会走僵尸的死亡 / 掉落流程
	## （关卡之外没有 zombie_manager 可挂，见 `probe_armor_component.gd` 文件头的同类说明）
	zombie.queue_free()
	await a.frames(2)

	cell.free()

	# ------------------------------------------------ STEP11 关掉模组
	a.log("STEP11 关掉模组 → 撤干净")
	ModManager.set_mod_enabled(ModIds.PVZ2, false)
	await a.frames(1)
	_check(a, "菜问不再是已解锁", not Global.global_game_state.is_plant_unlocked(BONK_CHOY))
	_check(a, "注册表里没有菜问了",
		registry.get_plant_info(BONK_CHOY, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "菜问的卡位撤掉了", not AllCards.plant_card_ids.has(BONK_CHOY))
	_check(a, "菜问的图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(BONK_CHOY).get("名字", "")) != "菜问")

	_finish(a)


#region 工具
## 递归收集一棵子树里的 Sprite2D（查装扮用）
func _collect_sprites(root: Node, out: Array[Sprite2D]) -> void:
	for child in root.get_children():
		if child is Sprite2D:
			out.append(child as Sprite2D)
		_collect_sprites(child, out)


## 当前「亮着、且贴图属于 PVZ2 那套装扮」的贴图名（去重）
func _shown_costumes(sprites: Array[Sprite2D]) -> Array[String]:
	var found: Array[String] = []
	for sprite in sprites:
		if not sprite.visible or sprite.texture == null:
			continue
		var file_name := sprite.texture.resource_path.get_file()
		if file_name in COSTUME_TEXTURES and not found.has(file_name):
			found.append(file_name)
	return found
#endregion


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[PVZ2] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
