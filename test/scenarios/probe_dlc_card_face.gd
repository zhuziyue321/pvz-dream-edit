extends RefCounted
## 探针：卡面（种子包）里那株植物的**落点与缩放** —— 本体手摆卡面基准 + DLC 模组全部植物
##
## 无头可跑，只动内存（开关写进 autopilot 那份临时 user 目录）。校验：
##   1. 本体手摆卡面基准样本：内容中心落在卡面挂点 ±6 px（手摆值允许几像素微调，
##      这是全仓卡面的**口径基准**；实测最大偏离 = 大嘴花 4.04 px）
##   2. DLC 每株的卡面都画出来了（`CharacterStatic` 下有那株植物）
##   3. DLC 每株的卡面内容中心同样落在挂点 ±4 px（`card_face_position` 是算出来的，可以严格些）
##   4. DLC 每株的卡面内容不超出卡底图（50×70，留 2 px 余量）
##
## ⚠️ 卡面内容含「运行期才由动画 texture 轨道塞进来的部件」：只按场景文件估算会偏，
##   所以这里一律用 `AnimationFrameUtil.get_content_rect()` 量运行期结果
##   （见 docs/参考存档/DLC植物导入.md §6.2）。
##
## 卡面口径：`get_content_rect(face)` 的坐标系就是 `CharacterStatic` 的局部坐标，
## 「内容中心 = 挂点」即「内容中心 ≈ (0,0)」——
## 本体那 48 张手摆卡面都在这个位置（如豌豆射手 `position=(1,14)`，内容中心 (-0.46, 2.92)）。
## DLC 的卡面是算出来的：`card_face_position = -内容中心(植物本地) × card_face_scale`。
## **别拿动画画布坐标算** —— 画布原点在左上、动画节点自己带 position，漏了它整株就偏到卡外
## （2026-10-18 实测：投掷蘑菇偏 (-14.7, -20.5)、臼炮蘑菇偏 (-19.7, -29.4)）。
##
## 机器可读汇总：最后一行 [DLCFACE] result=PASS|FAIL failed=<n>

var _failed := 0

## 卡底图尺寸（`data/ui/card_bg/norm.tres`，50×70）
const CARD_SIZE := Vector2(50.0, 70.0)
## 本体手摆卡面允许的中心偏离（手摆值是肉眼调的）
const NATIVE_CENTER_TOLERANCE := 6.0
## DLC 卡面允许的中心偏离（按公式算的，可以严格）
const DLC_CENTER_TOLERANCE := 4.0
## 内容允许超出卡底图的像素（贴边植物允许叶子略出一点）
const OVERFLOW_TOLERANCE := 2.0

## 本体手摆卡面基准样本（体型跨度：小花 / 标准射手 / 爆炸 / 高瘦 / 大嘴）
const NATIVE_REFERENCE: Array[StringName] = [
	PlantIds.SUN_FLOWER, PlantIds.PEA_SHOOTER_SINGLE, PlantIds.CHERRY_BOMB,
	PlantIds.TALL_NUT, PlantIds.CHOMPER,
]

## 本模组装上来的全部植物（id 与 `dlc_mod.gd` 的常量一致）
const PLANT_TYPES: Array[StringName] = [
	&"dlc_kingcactus", &"dlc_pultshroom", &"dlc_bonkchoy", &"dlc_aloe",
	&"dlc_mortarshroom", &"dlc_reed", &"dlc_bloodorange", &"dlc_voltshroom",
	&"dlc_glowshroom", &"dlc_oakarcher", &"dlc_beeshooter", &"dlc_hurrikale",
	&"dlc_chardguard", &"dlc_shrinkingviolet", &"dlc_ampliflower", &"dlc_lemonade",
	&"water_bowl",
]


func run(a) -> void:
	a.log("")
	a.log("========== 探针：卡面（种子包）落点 ==========")

	a.log("---- 本体手摆卡面基准 ----")
	for plant_type in NATIVE_REFERENCE:
		_check_card_face(a, plant_type, NATIVE_CENTER_TOLERANCE, false)

	ModManager.set_mod_enabled(ModIds.DLC, true)
	## 卡面是 `PlantRuntimeKit` 帧末才画的（`_build_card_face.call_deferred()`）
	await a.frames(4)

	a.log("---- DLC 模组植物 ----")
	for plant_type in PLANT_TYPES:
		_check_card_face(a, plant_type, DLC_CENTER_TOLERANCE, true)

	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_finish(a)


## 量一株的卡面：内容中心相对卡面挂点偏了多少、内容有没有出卡
## [param tolerance] 中心允许偏离的像素
## [param check_fit] 是否断言内容不超出卡底图（本体样本只量基准，不断言）
func _check_card_face(a, plant_type: StringName, tolerance: float, check_fit: bool) -> void:
	a.log("· %s" % str(plant_type))
	var card: Card = AllCards.all_plant_card_prefabs.get(plant_type, null)
	if card == null:
		_check(a, "卡位在", false, "AllCards 里没有这张卡")
		return
	var anchor_node := card.character_static
	if anchor_node == null or anchor_node.get_child_count() == 0:
		_check(a, "卡面画出来了", false, "CharacterStatic 下没有植物")
		return
	var face := anchor_node.get_child(0) as Node2D
	## `get_content_rect` 已经把 face 自己的 position / scale 算进去 → 结果就是挂点局部坐标
	var rect := AnimationFrameUtil.get_content_rect(face)
	a.log("   [DIAG] 节点=%s 子节点=%d 可见精灵=%d/%d" % [
		face.name, face.get_child_count(), _count_sprites(face, true), _count_sprites(face, false)])
	var center := rect.get_center()
	a.log("   [INFO] scale=%s position=%s 内容 rect=%s 中心=%s" % [
		str(face.scale), str(face.position), str(rect), str(center)])
	_check(a, "卡面内容中心落在挂点（±%.0f px）" % tolerance,
		absf(center.x) <= tolerance and absf(center.y) <= tolerance,
		str(center))
	if not check_fit:
		return
	## 出卡检查：内容在卡底图坐标里不能溢出（挂点在卡底图的 (24,30)，卡底图左上角是 (0,0)）
	var card_rect := Rect2(anchor_node.position + rect.position, rect.size)
	_check(a, "卡面内容在卡底图内（50×70，容差 %.0f px）" % OVERFLOW_TOLERANCE,
		card_rect.position.x >= -OVERFLOW_TOLERANCE
			and card_rect.position.y >= -OVERFLOW_TOLERANCE
			and card_rect.end.x <= CARD_SIZE.x + OVERFLOW_TOLERANCE
			and card_rect.end.y <= CARD_SIZE.y + OVERFLOW_TOLERANCE,
		str(card_rect))


## 数精灵（[param only_visible] 为 true 时只数可见的；含自身）
func _count_sprites(node: Node, only_visible: bool) -> int:
	var count := 0
	if node is Sprite2D:
		if not only_visible or (node as Sprite2D).is_visible_in_tree():
			count += 1
	for child in node.get_children():
		count += _count_sprites(child, only_visible)
	return count


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLCFACE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
