extends RefCounted
## 探针：战斗植物「水盆」（模组 `water_bowl`，编号 P050WaterBowl）
##
## 无头可跑，只动内存（开关写进 autopilot 那份临时 user 目录）。校验：
##   1. 装上模组 → 注册表里有场景 / 阳光 / 种植条件（地形与花盆相同、占 Down 位），且已解锁
##   2. 卡片：追加在所有普通植物之后（页数由植物总数算），待选区里那张卡可见
##   3. 地形：草地上种下水盆 → 格子条件 = 1 无 + 64 水盆 → 海蘑菇种得进、豌豆射手种不进
##   4. 动画：水盆播的是 `Pot_waterplants`（花盆场景里水盆那一支）
##   5. 影子：上层植物（海蘑菇）的影子藏掉（盆里是水），水盆被铲掉后影子还回去
##   6. 关掉模组 → 卡位、解锁、种植判据一并撤掉
##
## 机器可读汇总：最后一行 [WATERBOWL] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

const WATER_BOWL := PlantIds.WATER_BOWL
const FLOWER_POT := PlantIds.FLOWER_POT
## 水生植物（静态表里种植条件「只认水」的那几株之一）
const SEA_SHROOM := PlantIds.SEA_SHROOM
## 陆生植物（普通卡，条件 22：草地 / 花盆 / 睡莲）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE

const PLANT_CELL_SCENE := "res://src/ui/plant_cell.tscn"
const CARD_SLOT_SCENE := "res://src/ui/card/card_slot/card_slot_norm.tscn"
## 与 `AnimComponentNorm.PLAYBACK_PARAM` 同一条路径（花盆的树是「混合树 + TimeScale + 状态机」）
const PLAYBACK_PARAM := "parameters/StateMachine/playback"


func run(a) -> void:
	a.log("")
	a.log("========== 探针：战斗植物「水盆」（模组 water_bowl）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组
	a.log("STEP1 装上模组 → 水盆登记进注册表")
	ModManager.set_mod_enabled(ModIds.WATER_BOWL, true)
	var plant_scene = registry.get_plant_info(WATER_BOWL, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	_check(a, "水盆登记了场景", plant_scene != null, "null" if plant_scene == null else plant_scene.resource_path)
	_check(a, "水盆阳光 = 25（与花盆一致）",
		registry.get_plant_info(WATER_BOWL, CharacterRegistry.PlantInfoAttribute.SunCost) == 25)
	_check(a, "水盆已解锁", Global.global_game_state.is_plant_unlocked(WATER_BOWL))
	var condition = registry.get_plant_info(WATER_BOWL, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "水盆登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "水盆与花盆同一套地形（2 草地 + 32 屋顶 = 34）", condition.plant_condition == 34,
		str(condition.plant_condition))
	_check(a, "水盆占下层（Down）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Down,
		str(condition.place_plant_in_cell))
	## 图鉴：模组自己登记的那条（见 water_bowl_mod.gd 的 _register_almanac_entry）
	_check(a, "装上模组后水盆有图鉴条目（图鉴扩展页能显示）",
		str(Global.global_read_data.get_extra_almanac_entry(WATER_BOWL).get("名字", "")) == "水盆",
		str(Global.global_read_data.get_extra_almanac_entry(WATER_BOWL)))

	# ------------------------------------------------ STEP2 卡位与页码
	a.log("STEP2 卡片：追加在普通植物之后、页码由总数算出来")
	if not AllCards.plant_card_ids.has(WATER_BOWL):
		_check(a, "水盆有卡位", false, "没有任何卡位")
		_finish(a)
		return
	var bowl_id: int = AllCards.plant_card_ids[WATER_BOWL]
	var pot_id: int = AllCards.plant_card_ids.get(FLOWER_POT, -1)
	_check(a, "水盆卡排在花盆卡之后（模组新增一律追加）", bowl_id > pot_id,
		"花盆=%d 水盆=%d" % [pot_id, bowl_id])

	var slot_root: Control = load(CARD_SLOT_SCENE).instantiate()
	a.get_tree().root.add_child(slot_root)
	await a.frames(2)
	var candidate: CardSlotCandidate = slot_root.get_node_or_null("CardSlotCandidate") as CardSlotCandidate
	if candidate == null or candidate.all_card_page_array.is_empty():
		_check(a, "待选卡槽能造出来", false, "取不到 CardSlotCandidate")
		if slot_root != null:
			slot_root.free()
		_finish(a)
		return
	var per_page: int = candidate.all_card_page_array[0].get_child_count()
	a.log("   每页 %d 张卡，共 %d 页" % [per_page, candidate.all_card_page_array.size()])
	## 排列顺序由待选卡槽自己算：普通植物在前，调试模式 / 模组新增追加在后
	var ordered := candidate._build_ordered_plant_types()
	var bowl_order: int = ordered.find(WATER_BOWL)
	_check(a, "水盆排在普通植物之后（属于追加的那批）",
		bowl_order >= ordered.size() - ConstPlantUnlock.DEBUG_MODE_PLANT_TYPES.size() - 1,
		"顺序下标=%d / 共 %d 株" % [bowl_order, ordered.size()])
	var container = candidate.all_card_candidate_containers_plant.get(bowl_id, null)
	_check(a, "待选区里有水盆的卡位", container != null)
	_check(a, "水盆那张卡是可见的（已解锁）", container != null and container.visible)
	## 页码 = 顺序下标 / 每页格数（页数按植物总数算，见 _create_card_pages）
	var bowl_page: int = candidate.all_card_page_array.find(
		container.get_parent().get_parent() if container != null else null)
	_check(a, "水盆的页码 = 顺序下标 / 每页格数", bowl_page == bowl_order / per_page,
		"第 %d 页 / 共 %d 页" % [bowl_page + 1, candidate.all_card_page_array.size()])
	slot_root.free()

	# ------------------------------------------------ STEP3 地形
	a.log("STEP3 地形：草地上种下水盆 → 上面只接水生植物")
	var cell: PlantCell = load(PLANT_CELL_SCENE).instantiate()
	a.get_tree().root.add_child(cell)
	await a.frames(1)
	_check(a, "草地格子初始地形 = 3（1 无 + 2 草地）", cell.curr_condition == 3, str(cell.curr_condition))
	var bowl = cell.create_plant(WATER_BOWL, false, false)
	if bowl == null:
		_check(a, "水盆能种进草地", false, "create_plant 返回 null")
		cell.free()
		_finish(a)
		return
	_check(a, "种下水盆后地形 = 65（1 无 + 64 水盆）", cell.curr_condition == 65, str(cell.curr_condition))
	_check(a, "水盆自己声明的地形位 = 64", bowl.get("own_condition_bit") == 64,
		str(bowl.get("own_condition_bit")))
	_check(a, "水盆打开了 is_water", bowl.get("is_water") == true, str(bowl.get("is_water")))

	## 判据与手持物 / 虚影同源（都是条件资源的 judge_is_can_plant）
	var sea_cond = registry.get_plant_info(SEA_SHROOM, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	var pea_cond = registry.get_plant_info(PEA_SHOOTER, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	_check(a, "海蘑菇可以种进水盆", sea_cond != null and sea_cond.judge_is_can_plant(cell, SEA_SHROOM))
	_check(a, "豌豆射手种不进水盆（陆生只认草地 / 花盆 / 睡莲）",
		pea_cond != null and not pea_cond.judge_is_can_plant(cell, PEA_SHOOTER))
	var sea = cell.create_plant(SEA_SHROOM, false, false)
	_check(a, "海蘑菇真的种进去了", sea != null)
	## 海蘑菇挂的是 Norm 容器，而 Norm 容器已经被收进水盆的上下移动容器（水盆一晃它跟着晃）
	_check(a, "海蘑菇挂在水盆的上下移动容器下",
		sea != null and bowl.get("down_plant_container").is_ancestor_of(sea),
		"null" if sea == null else str(sea.get_parent().name))
	## 水盆里装的是水：上层植物的影子落在水面上看着别扭，藏掉
	_check(a, "海蘑菇种进水盆后影子被藏掉",
		sea != null and is_instance_valid(sea.shadow) and not sea.shadow.visible)

	# ------------------------------------------------ STEP4 动画
	a.log("STEP4 水盆播的是 Pot_waterplants（花盆场景里水盆那一支）")
	await a.frames(2)
	var tree: AnimationTree = bowl.get_node_or_null("AnimationTree")
	var playback = tree.get(PLAYBACK_PARAM) if tree != null else null
	var anim_name: String = playback.get_current_node() if playback != null else ""
	_check(a, "状态机当前在 Pot_waterplants", anim_name == "Pot_waterplants", str(anim_name))

	# ------------------------------------------------ STEP4.5 水盆没了 → 影子还回去
	a.log("STEP4.5 水盆被铲掉 → 上层容器搬回格子，影子还回去")
	bowl.character_death_disappear()
	await a.frames(2)
	_check(a, "水盆没了以后海蘑菇还在", is_instance_valid(sea))
	_check(a, "水盆没了以后海蘑菇的影子又出来了",
		is_instance_valid(sea) and is_instance_valid(sea.shadow) and sea.shadow.visible)
	cell.free()

	# ------------------------------------------------ STEP5 关掉模组
	a.log("STEP5 关掉模组 → 撤干净")
	ModManager.set_mod_enabled(ModIds.WATER_BOWL, false)
	_check(a, "水盆不再是已解锁", not Global.global_game_state.is_plant_unlocked(WATER_BOWL))
	_check(a, "注册表里没有水盆了",
		registry.get_plant_info(WATER_BOWL, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "水盆的卡位撤掉了", not AllCards.plant_card_ids.has(WATER_BOWL))
	var sea_cond_back = registry.get_plant_info(SEA_SHROOM, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	_check(a, "海蘑菇的条件回到「只认水(8)」",
		sea_cond_back != null and sea_cond_back.plant_condition == 8, str(sea_cond_back.plant_condition))
	## 图鉴条目必须跟着一起撤：关掉模组后不该在图鉴里看见一个谁都种不出来的盆
	_check(a, "关掉模组后水盆的图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(WATER_BOWL).get("名字", "")) != "水盆",
		str(Global.global_read_data.get_extra_almanac_entry(WATER_BOWL)))

	_finish(a)


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[WATERBOWL] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
