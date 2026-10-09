extends RefCounted
## 双进程联机实测 —— **客户端这一端**（另一端见 `probe_netplay_pair_host.gd`）
##
## 这一端要证的三件事（都是单进程探针**原理上证不到**的）：
##   1. 主机一进关，本机被**真的带进同一关**（`level_enter_requested` → 换场景 → 同一份 `game_para`）
##   2. 主机的快照**真的到了**（`state_snapshot_received` 计数 > 0）
##   3. 场上的僵尸是被主机重建出来的 —— 编号是主机那一套，且本机它们**只渲染**
##      （`attack_component` 被 `E_IsEnableFactor.Netplay` 关掉）
##
## 每 2 秒把自己看到的"场上长什么样"**走真实的命令通道**发回主机，由主机当场对拍。
##
## ⚠️ 回报走 `receive_command.rpc()` 而不是 `send_command()`：后者要先过
## `NetplayCommand.is_valid()`，`pair_view` 不是业务命令会被丢掉。这只是**测试用的通道借用**，
## 不改动任何业务代码。
##
## 机器可读汇总：最后一行 `[PAIR-CLIENT] result=PASS|FAIL ...`

const SESSION_PATH := "/root/NetplaySession"
const PORT := 8912
const OBSERVE_SECONDS := 45.0
const REPORT_EVERY := 2.0

var _snapshots := 0
var _reports := 0
var _render_only_bad := 0
var _saw_zombie := false
var _a = null
var _session: NetplaySession = null


func run(a) -> void:
	_a = a
	a.log("")
	a.log("========== 双进程联机实测（客户端端） ==========")
	if not ModManager.is_mod_enabled(ModIds.NETPLAY):
		ModManager.set_mod_enabled(ModIds.NETPLAY, true)
	await a.frames(5)
	_session = a.get_node_or_null(SESSION_PATH) as NetplaySession
	if _session == null:
		a.log("!! 拿不到会话节点")
		a.quit_game()
		return

	## 等主机那边把房间开起来（会合点：主机写好 host_ready 这个文件）
	var waited := 0.0
	while not _flag_exists("host_ready") and waited < 90.0:
		await a.wait(0.5)
		waited += 0.5
	if not _flag_exists("host_ready"):
		a.log("!! 等了 90 秒也没等到主机")
		a.quit_game()
		return
	a.log("  主机已就绪，正在加入 127.0.0.1:%d" % PORT)
	if not _session.join("127.0.0.1", PORT):
		a.log("!! 加入失败")
		a.quit_game()
		return
	if not _session.state_snapshot_received.is_connected(_on_snapshot):
		_session.state_snapshot_received.connect(_on_snapshot)

	var t := 0.0
	while not _session.is_linked() and t < 30.0:
		await a.wait(0.5)
		t += 0.5
	if not _session.is_linked():
		a.log("!! 没连上主机")
		a.quit_game()
		return
	a.log("  已连上主机（本地 peer=%d）" % _session.local_peer_id)

	## 等被主机带进关卡（本机不自己进关：`GlobalUtils.enter_level_gate` 挡着）
	t = 0.0
	while (Global.main_game == null or not is_instance_valid(Global.main_game)) and t < 60.0:
		await a.wait(0.5)
		t += 0.5
	if Global.main_game == null:
		a.log("!! 没被带进关卡")
		a.quit_game()
		return
	a.log("  已被带进 [%s]，阶段=%d" % [
		str(_session.room_level_id), Global.main_game.main_game_progress])

	var elapsed := 0.0
	while elapsed < OBSERVE_SECONDS:
		await a.wait(REPORT_EVERY)
		elapsed += REPORT_EVERY
		_report()

	a.log("")
	a.log("[PAIR-CLIENT] result=%s snapshots=%d reports=%d render_only_bad=%d saw_zombie=%s" % [
		("PASS" if _ok() else "FAIL"), _snapshots, _reports, _render_only_bad, str(_saw_zombie)])
	a.quit_game()


func _ok() -> bool:
	## 快照真的到了 + 场上有僵尸 + 它们都处于"只渲染"
	return _snapshots > 0 and _saw_zombie and _render_only_bad == 0 and _reports > 0


func _on_snapshot(_snap: Dictionary) -> void:
	_snapshots += 1


#region 回报
## 把本机看到的"场上长什么样"发回主机，由主机当场对拍
func _report() -> void:
	if _session == null:
		return
	var mine := _view()
	var ids: Array = mine["ids"]
	if not ids.is_empty():
		_saw_zombie = true
	_reports += 1
	_session.receive_command.rpc({
		"op": "pair_view",
		"ids": ids,
		"hp": mine["hp"],
		"xs": mine["xs"],
		"plants": mine["plants"],
		"bullets": mine["bullets"],
		"snapshots": _snapshots,
	})
	_a.log("  ... 已回报 #%d z=%d plants=%d bullets=%d 快照=%d 只渲染异常=%d" % [
		_reports, ids.size(), int(mine["plants"]), int(mine["bullets"]), _snapshots, _render_only_bad])


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
			## ★ 本机这些僵尸必须是"只渲染"：攻击组件被 Netplay 这个因素关掉
			if is_instance_valid(z.attack_component) and z.attack_component.is_enabling:
				_render_only_bad += 1
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
func _flag_exists(flag: String) -> bool:
	return FileAccess.file_exists(_rdy(flag))


func _rdy(flag: String) -> String:
	var tmp := OS.get_environment("TEMP")
	if tmp.is_empty():
		tmp = OS.get_environment("TMP")
	if tmp.is_empty():
		tmp = "."
	return tmp.path_join("pvz_netplay_pair").path_join(flag)
#endregion
