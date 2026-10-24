extends RefCounted
class_name probe_netplay_slot_layout
## 探针：联机**卡槽分块**的纯逻辑回归（不开房间、不连机器，秒级跑完）
##
## 覆盖：
##   1. 卡槽按人数切块是不是"尽量均分"（6 格 2 人 = 3+3；7 格 2 人 = 3+4；5 格 3 人 = 1+2+2）
##   2. 合并卡表按块顺序拼好之后，每块的范围对不对（每个人的卡**连成一段**，不能交叉）
##   3. "卡槽第几格是不是这个人的块"判得对不对（房主验种植就靠这一句）
##   4. 越界 / 没有这个人 ⇒ 不认（宁可这一笔不发生，也不能种了别人的卡）
##
## 机器可读汇总：最后一行 [SLOTLAYOUT] result=PASS|FAIL failed=<n>

## 跨文件引用：`user://` 下脚本的 class_name 不会注册成全局类，所以走 preload 常量
const NetplaySlotLayout := preload("res://mods_builtin/netplay/netplay_slot_layout.gd")

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 联机卡槽分块 ==========")

	# ---------------------------------------------- STEP1 切块宽度
	a.log("STEP1 卡槽按人数切块（尽量均分）")
	_check(a, "6 格 2 人 = 3+3", _widths(6, 2) == [3, 3], str(_widths(6, 2)))
	_check(a, "7 格 2 人 = 3+4（零头给靠后的块）", _widths(7, 2) == [3, 4], str(_widths(7, 2)))
	_check(a, "5 格 3 人 = 1+2+2", _widths(5, 3) == [1, 2, 2], str(_widths(5, 3)))
	_check(a, "6 格 1 人 = 6", _widths(6, 1) == [6], str(_widths(6, 1)))
	_check(a, "0 格 ⇒ 没有块", _widths(0, 2) == [], str(_widths(0, 2)))
	_check(a, "0 人 ⇒ 没有块", _widths(6, 0) == [], str(_widths(6, 0)))
	## 宽度之和不得超过卡槽格数（不然合起来摆不下）
	var total := 0
	for w in _widths(7, 3):
		total += int(w)
	_check(a, "宽度之和 = 卡槽格数（7 格 3 人 = 2+2+3）", total == 7 and _widths(7, 3) == [2, 2, 3],
		str(_widths(7, 3)))

	# ---------------------------------------------- STEP2 分块方案
	a.log("STEP2 分块方案（房主算，按 peer id 排）")
	var plan: Dictionary = NetplaySlotLayout.plan_of([1, 2], 6)
	_check(a, "方案 = {1:3, 2:3}", plan.get(1) == 3 and plan.get(2) == 3, str(plan))
	var plan3: Dictionary = NetplaySlotLayout.plan_of([1, 2, 3], 6)
	_check(a, "3 人 6 格 = {1:2, 2:2, 3:2}", plan3.get(1) == 2 and plan3.get(2) == 2 and plan3.get(3) == 2,
		str(plan3))

	# ---------------------------------------------- STEP3 合并卡表
	a.log("STEP3 合并卡表（各人选的卡按块顺序拼成一份）")
	var blocks: Array = [
		{"peer_id": 1, "refs": [_ref(PlantIds.PEA_SHOOTER_SINGLE), _ref(PlantIds.SUN_FLOWER),
			_ref(PlantIds.WALL_NUT)]},
		{"peer_id": 2, "refs": [_ref(PlantIds.CHERRY_BOMB), _ref(PlantIds.POTATO_MINE)]},
	]
	var composed: Dictionary = NetplaySlotLayout.compose(blocks)
	var refs: Array = composed.get("refs", [])
	var ranges: Dictionary = composed.get("ranges", {})
	_check(a, "合并后 5 张", refs.size() == 5, str(refs.size()))
	_check(a, "房主那块 = 第 0~2 格", _range_of(ranges, 1) == {"start": 0, "count": 3},
		str(_range_of(ranges, 1)))
	_check(a, "对端那块 = 第 3~4 格", _range_of(ranges, 2) == {"start": 3, "count": 2},
		str(_range_of(ranges, 2)))
	## 顺序：房主的卡在前（房主是第 0 块）
	_check(a, "合并卡表第 0 张是房主那张", refs.size() > 0 and refs[0].content_id == PlantIds.PEA_SHOOTER_SINGLE,
		str(refs[0].content_id) if refs.size() > 0 else "empty")

	# ---------------------------------------------- STEP4 归属判定
	a.log("STEP4 卡槽第几格是不是这个人的块（房主验种植就靠这一句）")
	_check(a, "第 0 格属于房主", NetplaySlotLayout.owns_index(ranges, 1, 0))
	_check(a, "第 2 格属于房主", NetplaySlotLayout.owns_index(ranges, 1, 2))
	_check(a, "第 3 格**不属于**房主", not NetplaySlotLayout.owns_index(ranges, 1, 3))
	_check(a, "第 3 格属于对端", NetplaySlotLayout.owns_index(ranges, 2, 3))
	_check(a, "第 4 格属于对端", NetplaySlotLayout.owns_index(ranges, 2, 4))
	_check(a, "第 5 格谁都不是（越界）", not NetplaySlotLayout.owns_index(ranges, 1, 5)
		and not NetplaySlotLayout.owns_index(ranges, 2, 5))
	_check(a, "负数下标不认", not NetplaySlotLayout.owns_index(ranges, 1, -1))
	_check(a, "屋里有第三个人但他没块 ⇒ 不认", not NetplaySlotLayout.owns_index(ranges, 3, 0))
	_check(a, "空卡表时谁都不认", not NetplaySlotLayout.owns_index({}, 1, 0))

	# ---------------------------------------------- STEP5 有人少选几张
	a.log("STEP5 有人少选几张（块与块不交叉）")
	var blocks2: Array = [
		{"peer_id": 1, "refs": [_ref(PlantIds.PEA_SHOOTER_SINGLE)]},
		{"peer_id": 2, "refs": [_ref(PlantIds.CHERRY_BOMB), _ref(PlantIds.POTATO_MINE)]},
	]
	var composed2: Dictionary = NetplaySlotLayout.compose(blocks2)
	var ranges2: Dictionary = composed2.get("ranges", {})
	_check(a, "房主只选 1 张 ⇒ 他那块只有 1 格", _range_of(ranges2, 1) == {"start": 0, "count": 1},
		str(_range_of(ranges2, 1)))
	_check(a, "对端那块紧接在后面", _range_of(ranges2, 2) == {"start": 1, "count": 2},
		str(_range_of(ranges2, 2)))
	_check(a, "房主不能用对端那张", not NetplaySlotLayout.owns_index(ranges2, 1, 1))
	_check(a, "对端能用自己那两张", NetplaySlotLayout.owns_index(ranges2, 2, 1)
		and NetplaySlotLayout.owns_index(ranges2, 2, 2))

	_finish(a)


#region 断言与工具
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[SLOTLAYOUT] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _widths(capacity: int, players: int) -> Array:
	var out: Array = []
	for w in NetplaySlotLayout.block_widths(capacity, players):
		out.append(int(w))
	return out


func _range_of(ranges: Dictionary, peer_id: int) -> Dictionary:
	var block: Dictionary = ranges.get(peer_id, {})
	if block.is_empty():
		return {}
	return {"start": int(block.get("start", -1)), "count": int(block.get("count", 0))}


func _ref(plant_type: StringName) -> ResourceCardReference:
	return ResourceCardReference.create(ResourceCardReference.CardType.Plant, plant_type)
#endregion
