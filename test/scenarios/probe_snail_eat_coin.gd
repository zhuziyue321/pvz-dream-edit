extends RefCounted
## 诊断探针：花园里真实植物掉的钱，蜗牛到底吃不吃得到
## 打印：植物落钱点高度 / 钱的实际落点 / 蜗牛有没有盯上 / 最后有没有吃到
## 机器可读汇总：最后一行 [EAT] result=PASS|FAIL failed=<n>

var _failed := 0

const GARDEN_SCENE := "res://src/garden/garden.tscn"


func run(a) -> void:
	a.log("")
	a.log("========== 探针 蜗牛到底吃不吃钱 ==========")
	await a.wait(2.0)

	var state = Global.global_game_state
	_mark_cleared(state, 50)
	_reset_garden(state)
	_check(a, "买断蜗牛成功", state.buy_garden_tool(GardenManager.E_GardenTool.Snail))
	## 往温室里放 3 株植物
	state.curr_num_new_garden_plant = 3

	a.get_tree().change_scene_to_file(GARDEN_SCENE)
	if not await a.wait_scene("garden", 15.0):
		_check(a, "进入花园", false, str(a.get_tree().current_scene))
		_finish(a)
		return
	await a.wait(2.0)

	var garden = a.get_tree().current_scene
	var stinky = garden.stinky
	_check(a, "蜗牛已出现在花园里", stinky != null, str(stinky))
	if stinky == null:
		_finish(a)
		return
	a.log("蜗牛 move_range = " + str(stinky.move_range) + " 位置 = " + str(stinky.global_position))
	a.log("拾取距离(够得着的判据) = " + str(stinky.PICK_COIN_DISTANCE))

	var comps := _find_plant_cells(garden)
	a.log("花园里的植物格子数量 = " + str(comps.size()))
	for c in comps:
		a.log("  格子位置 = " + str(c.global_position))
	if comps.is_empty():
		_check(a, "花园里有植物格子", false, "0")
		_finish(a)
		return
	## 只取温室这一页的格子(别的背景页没启用,位置在视口外)
	var cells: Array = []
	for c in comps:
		if c.global_position.y > 50.0 and c.global_position.y < 450.0:
			cells.append(c)
	a.log("温室格子数量 = " + str(cells.size()))
	## 上 / 中 / 下几排各挑一个
	var picks: Array = []
	for idx in [0, 8, 16, cells.size() - 1]:
		if idx >= 0 and idx < cells.size() and not picks.has(cells[idx]):
			picks.append(cells[idx])

	stinky.wake_up()
	var coin_before: int = Global.global_game_state.coin_value
	var eaten_count := 0
	for i in picks.size():
		var c = picks[i]
		## 真实植物的产钱点 = 植物位置往上 60(见 ComponentGarden._ready)
		var pos: Vector2 = c.global_position + Vector2(0.0, -60.0)
		a.log("---- 格子 %s 产钱点 %s" % [str(c.global_position), str(pos)])
		EventBus.push_event("create_coin", [[1.0, 0.0, 0.0], pos])
		await a.wait(1.5)
		var coin := _last_coin(garden)
		if coin == null:
			a.log("  [NG] 钱没生成")
			_failed += 1
			continue
		a.log("  钱实际落点 = " + str(coin.global_position)
			+ "  与蜗牛横向差 = " + str(snappedf(absf(coin.global_position.x - stinky.global_position.x), 0.1))
			+ "  够得着 = " + str(stinky._is_coin_reachable(coin)))
		await a.wait(1.0)
		a.log("  蜗牛盯上了吗 target_coin = " + str(stinky.target_coin))
		var eaten := false
		for _t in 14:
			await a.wait(1.0)
			if coin.is_get or not is_instance_valid(coin):
				eaten = true
				break
		if eaten:
			eaten_count += 1
		a.log("  结果 = " + ("吃到了" if eaten else "没吃到") + "  蜗牛位置 = " + str(stinky.global_position))

	a.log("吃到 " + str(eaten_count) + " / " + str(picks.size()) + " 枚")
	_check(a, "至少吃到一枚钱", Global.global_game_state.coin_value > coin_before,
		str(coin_before) + " -> " + str(Global.global_game_state.coin_value))
	_finish(a)


func _last_coin(garden) -> Coin:
	var last: Coin = null
	for child in garden.drop_coin_parent.get_children():
		var coin := child as Coin
		if coin != null:
			last = coin
	return last


func _find_plant_cells(root: Node) -> Array:
	var out: Array = []
	for child in root.get_children():
		if child is PlantCellGarden:
			out.append(child)
		out.append_array(_find_plant_cells(child))
	return out


#region 断言与工具
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[EAT] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 复位成「只拥有阳光房、没买过花园工具」的存档
func _reset_garden(state) -> void:
	state.garden_data = {
		"num_bg_page_0": 1,
		"num_bg_page_1": 0,
		"num_bg_page_2": 0,
		GlobalGameState.BOUGHT_GARDEN_TOOLS_KEY: [],
		GlobalGameState.GARDEN_TOOL_NUM_KEY: {},
	}
	state.curr_num_new_garden_plant = 0


func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}
#endregion
