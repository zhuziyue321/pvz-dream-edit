extends RefCounted
## 双进程联机实测 —— **主机这一端**（另一端见 `probe_netplay_pair_client.gd`）
##
## 为什么非得两个进程：单进程探针里 `rpc()` **没有对端时不本地回调**，
## 于是「主机推事件 ⇒ 发命令 ⇒ 客户端照着重建」整段链路**原理上验不到** ——
## 波次 / 阳光 / 掉落 / 快照那几刀此前都只有单进程证据。这是把它们放到真实双端上跑一遍。
##
## ★ 对拍方式（避免事后按时间戳对齐两个进程的输出）：
##   客户端每 2 秒把自己的"场上长什么样"**走真实的命令通道**发回主机，
##   主机**收到那一刻**当场采一份自己的做对比 —— 两份采样只差一个 RTT，
##   而且配对关系是网络自己带过来的，不靠墙钟。
##
## 判据：
##   · `ids` 完全一致 —— 客户端不能有"主机没有的僵尸"（幽灵），也不能漏
##   · `phantom` = 客户端报的编号里，主机从头到尾都没见过的那些
##   · `dhp` / `dx` 是血量 / 位置的最大偏差（只记录，不作为判据 —— 采样本身就差一个 RTT）
##
## 机器可读汇总：最后一行 `[PAIR] result=PASS|FAIL reports=.. mismatch=.. phantom=..`

const SESSION_PATH := "/root/NetplaySession"
## 传送带关：不用选卡（没有 `card_slot_norm`），于是「准备 / 开始」那一整套不挡路，
## 双进程实测能直接进战斗 —— 要测的是同步，不是选卡 UI。
const LEVEL_SCRIPT := "res://src/levels/mode_adventure/adventure_01_10.gd"
const PORT := 8912
## 观察时长：第一波默认 20 秒后才来（见 `boot_level.gd`），要盖到至少一波僵尸
const OBSERVE_SECONDS := 45.0
const REPORT_EVERY := 2.0
const MIN_REPORTS := 3

var _reports := 0
var _mismatch := 0
var _phantom := 0
## 主机在整个观察期里见过的所有僵尸编号（判定"客户端那边是不是幽灵"）
var _host_all_ids: Dictionary = {}
var _saw_zombie := false
var _a = null


func run(a) -> void:
	_a = a
	a.log("")
	a.log("========== 双进程联机实测（主机端） ==========")
	if not ModManager.is_mod_enabled(ModIds.NETPLAY):
		ModManager.set_mod_enabled(ModIds.NETPLAY, true)
	await a.frames(5)
	var session := a.get_node_or_null(SESSION_PATH) as NetplaySession
	if session == null:
		a.log("!! 拿不到会话节点")
		a.quit_game()
		return
	if not session.create_host(PORT):
		a.log("!! 建房间失败（端口被占？）")
		a.quit_game()
		return
	a.log("  已建房间，端口 %d" % PORT)
	## 客户端靠这个文件判断"主机已经起来了"再连过来
	_touch("host_ready")
	if not session.command_received.is_connected(_on_command_received):
		session.command_received.connect(_on_command_received)

	## 等客户端进来（先连上再进关，客户端才会被一起带进去）
	var waited := 0.0
	while session.other_peer_ids().is_empty() and waited < 60.0:
		await a.wait(0.5)
		waited += 0.5
	if session.other_peer_ids().is_empty():
		a.log("!! 等了 60 秒也没人进来")
		a.quit_game()
		return
	a.log("  客户端已加入：%s" % str(session.other_peer_ids()))

	await _enter_level(a)
	if Global.main_game == null:
		a.log("!! 没进成关卡")
		a.quit_game()
		return

	## 观察：对拍全在 `_on_command_received()` 里做，这里只负责把进程撑住
	var elapsed := 0.0
	while elapsed < OBSERVE_SECONDS:
		await a.wait(REPORT_EVERY)
		elapsed += REPORT_EVERY
		a.log("  ... 观察中 %.0fs（已收到 %d 份客户端回报）" % [elapsed, _reports])

	a.log("")
	a.log("[PAIR] result=%s reports=%d mismatch=%d phantom=%d saw_zombie=%s" % [
		("PASS" if _ok() else "FAIL"), _reports, _mismatch, _phantom, str(_saw_zombie)])
	a.quit_game()


func _ok() -> bool:
	return _reports >= MIN_REPORTS and _mismatch == 0 and _phantom == 0


#region 进关
func _enter_level(a) -> void:
	var script := load(LEVEL_SCRIPT) as GDScript
	if script == null:
		a.log("!! 关卡脚本加载失败")
		return
	var para: ResourceLevelData = script.new()
	Global.game_para = para
	## ⚠️ 客户端是照 `para.game_sences` 换场景的（见 `NetplayMod._on_level_enter_requested`），
	## 主机这里必须用同一个表达式 —— 走不同的话两端根本不在同一个场景里，测出来全是假的
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[para.game_sences])
	var t := 0.0
	while (Global.main_game == null or not is_instance_valid(Global.main_game)) and t < 25.0:
		await a.wait(0.5)
		t += 0.5
	if Global.main_game == null:
		return
	a.log("  已进关，阶段=%d" % Global.main_game.main_game_progress)
#endregion


#region 对拍
## 客户端回报到了：当场采一份主机的，两边对着看
func _on_command_received(_from_peer_id: int, command: Dictionary) -> void:
	if str(command.get("op", "")) != "pair_view":
		return
	var mine := _view()
	var client_ids := _sorted_ints(command.get("ids", []))
	var client_hp := _to_ints(command.get("hp", []))
	var client_xs := _to_ints(command.get("xs", []))
	var host_ids: Array = mine["ids"]
	_reports += 1
	for id in host_ids:
		_host_all_ids[id] = true
	if not host_ids.is_empty():
		_saw_zombie = true

	var ids_match := host_ids == client_ids
	if not ids_match:
		_mismatch += 1
	var phantom_ids: Array = []
	for id in client_ids:
		if not _host_all_ids.has(id):
			phantom_ids.append(id)
	_phantom += phantom_ids.size()

	var dhp := 0
	var dx := 0
	var host_hp: Array = mine["hp"]
	var host_xs: Array = mine["xs"]
	for i in range(mini(host_ids.size(), client_ids.size())):
		if host_ids[i] != client_ids[i]:
			continue
		dhp = maxi(dhp, absi(int(host_hp[i]) - client_hp[i]))
		dx = maxi(dx, absi(int(host_xs[i]) - client_xs[i]))

	_a.log("  PAIR #%d | z=%d | ids=%s | dhp=%d dx=%d | plants h=%d c=%d | bullets h=%d c=%d%s" % [
		_reports, host_ids.size(),
		("OK" if ids_match else "DIFF host=%s client=%s" % [str(host_ids), str(client_ids)]),
		dhp, dx,
		int(mine["plants"]), int(command.get("plants", -1)),
		int(mine["bullets"]), int(command.get("bullets", -1)),
		("" if phantom_ids.is_empty() else " | PHANTOM=%s" % str(phantom_ids))])


## 主机这一刻眼里的"场上长什么样"
func _view() -> Dictionary:
	var mg := Global.main_game
	var ids: Array = []
	var hp: Array = []
	var xs: Array = []
	var plants := 0
	var bullets := 0
	if mg == null or not is_instance_valid(mg):
		return {"ids": ids, "hp": hp, "xs": xs, "plants": plants, "bullets": bullets}
	if mg.zombie_manager != null:
		for z in mg.zombie_manager.all_zombies_1d:
			if not is_instance_valid(z) or z.entity_id == 0:
				continue
			ids.append(z.entity_id)
			hp.append(0 if z.hp_component == null else int(z.hp_component.curr_hp))
			xs.append(int(z.global_position.x))
		var sorted: Array = _sort_by_id(ids, hp, xs)
		ids = sorted[0]
		hp = sorted[1]
		xs = sorted[2]
	if mg.plant_cell_manager != null:
		for row in mg.plant_cell_manager.all_plant_cells:
			for cell in row:
				if not is_instance_valid(cell):
					continue
				for place in cell.plant_in_cell:
					var plant: Plant000Base = cell.get_plant(place)
					if is_instance_valid(plant) and plant.entity_id != 0:
						plants += 1
	if mg.bullets != null:
		bullets = mg.bullets.get_child_count()
	return {"ids": ids, "hp": hp, "xs": xs, "plants": plants, "bullets": bullets}


## 按编号排序，同时把 hp / xs 一起带着排（否则两边对不上号）
func _sort_by_id(ids: Array, hp: Array, xs: Array) -> Array:
	var order := range(ids.size())
	order.sort_custom(func(i, j): return ids[i] < ids[j])
	var s_ids: Array = []
	var s_hp: Array = []
	var s_xs: Array = []
	for i in order:
		s_ids.append(ids[i])
		s_hp.append(hp[i])
		s_xs.append(xs[i])
	return [s_ids, s_hp, s_xs]
#endregion


#region 小工具
func _sorted_ints(raw: Variant) -> Array:
	var out := _to_ints(raw)
	out.sort()
	return out


func _to_ints(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for v in raw:
			out.append(int(v))
	return out


## 两个进程之间的"会合点"：一个空文件，存在即代表那一步到了
func _touch(flag: String) -> void:
	var f := FileAccess.open(_rdy(flag), FileAccess.WRITE)
	if f != null:
		f.close()


func _rdy(flag: String) -> String:
	var tmp := OS.get_environment("TEMP")
	if tmp.is_empty():
		tmp = OS.get_environment("TMP")
	if tmp.is_empty():
		tmp = "."
	return tmp.path_join("pvz_netplay_pair").path_join(flag)
#endregion
