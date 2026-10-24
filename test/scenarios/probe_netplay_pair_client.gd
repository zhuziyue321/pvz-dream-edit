extends RefCounted

## 妯＄粍鎼埌 `user://mods/` 鍚?class_name 涓嶅啀娉ㄥ唽涓哄叏灞€绫伙紝鎺㈤拡杩欓噷 preload 鎴愬父閲忓啀寮曠敤
const NetplayMod := preload("res://mods_builtin/netplay/netplay_mod.gd")
const NetplaySession := preload("res://mods_builtin/netplay/netplay_session.gd")
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
## 与主机端同一关（预热用，见 `_warm_up`）
const LEVEL_SCRIPT := "res://src/levels/mode_adventure/adventure_01_10.gd"
## ★ 关卡跟主机端用同一个（命令行 `--pair-level=...` 换；见 `probe_netplay_pair_host.gd`）
static func level_script() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pair-level="):
			return arg.split("=")[-1]
	return LEVEL_SCRIPT
const PORT := 8912
const OBSERVE_SECONDS := 60.0
const REPORT_EVERY := 2.0

var _snapshots := 0
var _reports := 0
var _render_only_bad := 0
var _saw_zombie := false
## "眼前只摆自己那块"验过了没有（只验一次）
var _range_checked := false
var _a = null
var _session: NetplaySession = null


func run(a) -> void:
	_a = a
	a.log("")
	a.log("========== 双进程联机实测（客户端端） ==========")
	if not ModManager.is_mod_enabled(ModIds.NETPLAY):
		ModManager.set_mod_enabled(ModIds.NETPLAY, true)
	await a.frames(5)
	## ★ 会话是**懒加载**的（没开房间就没有它）：这里走的就是「加入房间」那一侧的那一步
	var mod := ModManager.get_mod(ModIds.NETPLAY) as NetplayMod
	_session = mod._ensure_session() if mod != null else null
	if _session == null:
		a.log("!! 拿不到会话节点")
		a.quit_game()
		return

	_warm_up(a)

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
	while (GameContext.curr_main_game == null or not is_instance_valid(GameContext.curr_main_game)) and t < 60.0:
		await a.wait(0.5)
		t += 0.5
	if GameContext.curr_main_game == null:
		a.log("!! 没被带进关卡")
		a.quit_game()
		return
	a.log("  已被带进 [%s]，阶段=%d" % [
		str(_session.room_level_id), GameContext.curr_main_game.main_game_progress])
	## ★ 玩家会按的那颗「准备」：报上去主机才按得动开始
	_session.declare_ready(true)
	a.log("  已报准备 peer=%d" % _session.local_peer_id)
	## ★ 客户端也挑一张卡（不挑的话客户端那块是空的，"只显示自己那块"无从验）
	_pick_cards(a, 1)

	var elapsed := 0.0
	while elapsed < OBSERVE_SECONDS:
		await a.wait(REPORT_EVERY)
		elapsed += REPORT_EVERY
		## ★ 开战之后验一次"眼前只摆自己那块"
		if not _range_checked and _progress() == MainGameManager.E_MainGameProgress.MAIN_GAME:
			_range_checked = true
			_check_visible_range(a)
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


func _progress() -> int:
	if GameContext.curr_main_game == null or not is_instance_valid(GameContext.curr_main_game):
		return -1
	return GameContext.curr_main_game.main_game_progress


## 在选卡界面挑 [param count] 张卡（走本体那枚入口 `_on_card_click`）
func _pick_cards(a, count: int) -> void:
	var mg := GameContext.curr_main_game
	if mg == null or mg.card_manager == null or mg.card_manager.card_slot_norm == null:
		a.log("  （本关没有常规卡槽，跳过挑卡）")
		return
	var norm: CardSlotNorm = mg.card_manager.card_slot_norm
	var candidates: CardSlotCandidate = norm.card_slot_candidate
	if candidates == null or not is_instance_valid(candidates):
		a.log("  （没有待选区，跳过挑卡）")
		return
	var picked := 0
	for card_id in candidates.all_card_candidate_containers_plant:
		if picked >= count:
			break
		var container = candidates.all_card_candidate_containers_plant[card_id]
		if container == null or not is_instance_valid(container) or container.card == null:
			continue
		norm._on_card_click(container.card)
		picked += 1
	a.log("  客户端挑了 %d 张卡" % picked)


## ★ 客户端侧的分块落点检查：**眼前只摆自己那一块**（别人的卡看不见、点不到）
func _check_visible_range(a) -> void:
	var mg := GameContext.curr_main_game
	if mg == null or mg.card_manager == null or mg.card_manager.card_slot_battle == null:
		return
	var battle: CardSlotBattle = mg.card_manager.card_slot_battle
	var card_sync := mg.get_node_or_null("NetplayCardSync")
	if card_sync == null:
		a.log("  [NG] 没有卡槽同步节点")
		return
	var block: Dictionary = card_sync.range_of(_session.local_peer_id)
	var ok := int(block.get("start", -1)) == battle.visible_start \
		and int(block.get("count", -1)) == battle.visible_count
	a.log("  [%s] 客户端眼前只摆自己那块：可见=[%d,%d) 应为=[%d,%d)（卡槽里共 %d 张）" % [
		("OK" if ok else "NG"), battle.visible_start, battle.visible_start + battle.visible_count,
		int(block.get("start", -1)), int(block.get("start", -1)) + int(block.get("count", 0)),
		battle.curr_cards.size()])


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
		"bids": mine["bids"],
		"pids": mine["pids"],
		"sids": mine["sids"],
		"snapshots": _snapshots,
	})
	_a.log("  ... 已回报 #%d z=%d plants=%d bullets=%d 快照=%d 只渲染异常=%d 阶段=%d 连线=%d" % [
		_reports, ids.size(), int(mine["plants"]), int(mine["bullets"]), _snapshots,
		_render_only_bad, _progress(), _session.state])


func _view() -> Dictionary:
	var mg := GameContext.curr_main_game
	var ids: Array = []
	var hp: Array = []
	var xs: Array = []
	var bids: Array = []
	var pids: Array = []
	var sids: Array = []
	var plants := 0
	var bullets := 0
	if mg == null or not is_instance_valid(mg):
		return {"ids": ids, "hp": hp, "xs": xs, "plants": plants, "bullets": bullets,
			"bids": bids, "pids": pids, "sids": sids}
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
						pids.append(plant.entity_id)
	pids.sort()
	if mg.suns != null:
		for child in mg.suns.get_children():
			var sun := child as Sun
			if sun != null and is_instance_valid(sun) and sun.entity_id != 0:
				sids.append(sun.entity_id)
		sids.sort()
	if mg.bullets != null:
		bullets = mg.bullets.get_child_count()
		for child in mg.bullets.get_children():
			var bullet := child as Bullet000Base
			if bullet != null and is_instance_valid(bullet) and bullet.entity_id != 0:
				bids.append(bullet.entity_id)
		bids.sort()
	return {"ids": ids, "hp": hp, "xs": xs, "plants": plants, "bullets": bullets,
		"bids": bids, "pids": pids, "sids": sids}


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
## 预热：趁**还没连线**把关卡与主游戏场景 load 一遍
##
## ★ 为什么必须预热：`change_scene_to_file()`（`GlobalUtils.change_scene()` 内部走的就是它）会把主线程堵住（加载 + 实例化整关），
## 这一卡里没人去 `poll()` ENet；堵过 ENet 的对端超时（实测约 3~5 秒）主机就把本机踢掉了 ——
## 表现为"刚被带进关就掉线"，两端从此各打各的。先把资源 load 进缓存，这一卡就短了。
func _warm_up(a) -> void:
	var script := load(level_script()) as GDScript
	if script == null:
		return
	var para: ResourceLevelData = script.new()
	var scene_path := str(Global.main_scene_registry.get_scene_path(para.game_sences))
	var warmed := false
	if scene_path != "":
		warmed = load(scene_path) != null
	a.log("  已预热关卡与主游戏场景（换场景那一卡会堵过 ENet 超时被踢）：%s" % str(warmed))


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
