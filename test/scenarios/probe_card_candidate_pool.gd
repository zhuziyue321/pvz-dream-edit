extends RefCounted
## 探针：选卡候选卡池（数据层快照 + UI 容器池，跨关卡复用）
##
## 无头可跑。校验：
##   1. 数据层快照跨关卡复用：连续两次 `AllCards.get_seed_chooser_catalog()` 是同一个对象
##   2. 卡池变化（`AllCards.rebuild()`）会让快照失效重建，版本号变大
##   3. UI 容器跨关卡复用：第二份 `card_slot_norm` 取到的是**同一批容器与同一批卡节点**
##   4. 关卡销毁（`free()`）时容器被收回池，卡已从出战卡槽搬回容器、选卡状态与冷却都复位
##
## 机器可读汇总：最后一行 [POOL] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

const CARD_SLOT_SCENE := "res://src/ui/card/card_slot/card_slot_norm.tscn"
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE


func run(a) -> void:
	a.log("")
	a.log("========== 探针：选卡候选卡池（快照 + 容器池跨关卡复用）==========")

	# ------------------------------------------------ STEP1 数据层快照
	a.log("STEP1 数据层：快照跨关卡复用同一对象")
	var catalog1: CardSeedChooserCatalog = AllCards.get_seed_chooser_catalog()
	var catalog2: CardSeedChooserCatalog = AllCards.get_seed_chooser_catalog()
	_check(a, "连续两次取快照是同一个对象", catalog1 == catalog2)
	_check(a, "快照里有植物候选", not catalog1.plants.is_empty(), str(catalog1.plants.size()))
	_check(a, "快照里的源卡身份可读", catalog1.plants[0].card_reference != null,
		str(catalog1.plants[0].card_reference.to_dict()))

	# ------------------------------------------------ STEP2 卡池变化 → 快照失效
	a.log("STEP2 数据层：卡池重建后快照失效重建")
	var version_before: int = catalog1.version
	AllCards.rebuild()
	var catalog3: CardSeedChooserCatalog = AllCards.get_seed_chooser_catalog()
	_check(a, "重建后拿到的是新快照对象", catalog3 != catalog1)
	_check(a, "新快照版本号更大", catalog3.version > version_before,
		"%d -> %d" % [version_before, catalog3.version])
	_check(a, "新快照的候选数量没变", catalog3.plants.size() == catalog1.plants.size(),
		"%d -> %d" % [catalog1.plants.size(), catalog3.plants.size()])

	# ------------------------------------------------ STEP3 第一次进关
	a.log("STEP3 UI：第一次进关，候选列表从池里新建")
	var slot1: Control = await _open_slot(a)
	if slot1 == null:
		_finish(a)
		return
	var candidate1: CardSlotCandidate = slot1.get_node("CardSlotCandidate")
	var container1: CardCandidateContainer = _pea_container(candidate1)
	if container1 == null:
		_check(a, "第一次进关有豌豆射手的候选容器", false)
		slot1.free()
		_finish(a)
		return
	_check(a, "第一次进关有豌豆射手的候选容器", true)
	var container_id: int = container1.get_instance_id()
	var card_node_id: int = container1.card.get_instance_id()
	var card_cool_time: float = container1.card.cool_time
	var page_count1: int = candidate1.all_card_page_array.size()

	## 模拟选卡：卡被搬进出战卡槽（真实流程同样把卡 reparent 走），并沾上选卡 / 冷却状态
	container1.card.reparent(slot1, false)
	container1.card.is_choosed_pre_card = true
	container1.card.set_card_cool_time_start_cool(card_cool_time * 0.5)
	slot1.free()

	_check(a, "关卡销毁后容器仍存活（已收回池）", is_instance_valid(container1))
	_check(a, "收回后容器的父节点是卡池存储节点",
		is_instance_valid(container1) and container1.get_parent() != null \
			and container1.get_parent().name == "CardCandidatePoolStorage",
		"已失效" if not is_instance_valid(container1) else str(container1.get_parent().name))
	_check(a, "收回后卡已搬回容器",
		is_instance_valid(container1) and container1.card.get_parent() == container1)
	_check(a, "收回后清掉了「已选中」标记",
		is_instance_valid(container1) and not container1.card.is_choosed_pre_card)
	_check(a, "收回后冷却复位（可再次选卡）",
		is_instance_valid(container1) and not container1.card._is_cooling \
			and is_equal_approx(container1.card.cool_time, card_cool_time))

	# ------------------------------------------------ STEP4 第二次进关：复用
	a.log("STEP4 UI：第二次进关，同一批容器与卡节点直接复用")
	var slot2: Control = await _open_slot(a)
	if slot2 == null:
		_finish(a)
		return
	var candidate2: CardSlotCandidate = slot2.get_node("CardSlotCandidate")
	var container2: CardCandidateContainer = _pea_container(candidate2)
	_check(a, "第二次进关仍有豌豆射手的候选容器", container2 != null)
	if container2 != null:
		_check(a, "复用同一个容器节点", container2.get_instance_id() == container_id,
			"%d vs %d" % [container2.get_instance_id(), container_id])
		_check(a, "复用同一张卡节点", container2.card.get_instance_id() == card_node_id)
		_check(a, "卡已挂回容器", container2.card.get_parent() == container2)
	_check(a, "第二份候选列表页数与第一份相同",
		candidate2.all_card_page_array.size() == page_count1,
		"%d vs %d" % [candidate2.all_card_page_array.size(), page_count1])
	slot2.free()

	_finish(a)


## 从探针里开一份卡槽场景（与主游戏同一场景文件），返回实例；豌豆容器不存在时返回 null
func _open_slot(a) -> Control:
	var slot_root: Control = load(CARD_SLOT_SCENE).instantiate()
	a.get_tree().root.add_child(slot_root)
	await a.frames(1)
	var candidate: CardSlotCandidate = slot_root.get_node_or_null("CardSlotCandidate")
	if candidate == null or _pea_container(candidate) == null:
		slot_root.free()
		return null
	return slot_root


## 取豌豆射手（普通植物页）的候选容器
func _pea_container(candidate: CardSlotCandidate) -> CardCandidateContainer:
	if candidate == null or not AllCards.plant_card_ids.has(PEA_SHOOTER):
		return null
	return candidate.all_card_candidate_containers_plant.get(AllCards.plant_card_ids[PEA_SHOOTER], null)


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[POOL] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
