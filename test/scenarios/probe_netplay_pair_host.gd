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
## 观察时长：客户端被拉进关要 ~10 秒，第一波默认 20 秒后才来（见 `boot_level.gd`），
## 所以必须留到 60 秒才盖得到"两端都在打同一波"
const OBSERVE_SECONDS := 60.0
const REPORT_EVERY := 2.0
const MIN_REPORTS := 3

var _reports := 0
## 编号对不上分两类，**只有持续的才算错**（见 `_ok()`）：
##   · 瞬时 `transient` —— 单拍差一只、下一拍自己就好了
##   · 持续 `persistent` —— 连续两拍以上都对不上
## ★ 为什么不能要求"一次都不许对不上"：报告每 2 秒一次，而僵尸的**生成与消亡是瞬时的**。
## 采样撞上"主机刚生成 / 刚移除"那一瞬，客户端必然差一拍 —— 这是采样分辨率的问题，
## 不是同步错了。实测 30 拍里 3 拍瞬时差、0 拍持续差（`phantom=0` 且 `dhp` 全程为 0），
## 硬判"零差异"会把一个健康的同步判成 FAIL。
var _transient := 0
var _persistent := 0
## 每一类上一次是不是对的（按类记，见 `_classify`）
var _prev_ok: Dictionary = {}
## 至少有一次"两端都有植物且编号完全一致" —— 植物**是新进快照**的这一类
var _plant_match_seen := false
## 至少有一次"两端都有阳光且编号完全一致"
var _sun_match_seen := false
## 两端植物数量差的最大值（信息用：能看出"客户端一株都没有"这种整片缺失）
var _plant_gap := 0
## 血量偏差的最大值（只记录）：血量是主机逐帧下发、客户端直接覆盖的，
## 所以这个值全程为 0 本身就是"血量同步精确"的强证据
var _max_dhp := 0
var _phantom := 0
## 主机在整个观察期里见过的所有僵尸编号（判定"客户端那边是不是幽灵"）
var _host_all_ids: Dictionary = {}
var _saw_zombie := false
## 至少有一次"两端都有子弹且编号完全一致" —— 证明客户端渲染的就是主机那几颗
var _bullet_match_seen := false
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

	## ★ 确定性地把这一局开起来（不靠"主机自动跳过选卡"那条路）：
	## 传送带 / 卡槽锁死的关没有选卡界面，主机一进关就自动跳过 —— 那一刻客户端往往还没进关，
	## 于是"等准备"闸门把主机挡住，之后再没人按第二次开始 ⇒ 两端一起卡在 CHOOSE_CARD。
	## 这里把玩家会做的两步补上：等客户端报准备 → 主机按开始。
	await _wait_ready_then_start(a)
	_tick_log(a, "开战后")

	## 观察：对拍全在 `_on_command_received()` 里做，这里只负责把进程撑住
	var elapsed := 0.0
	var seeded := false
	while elapsed < OBSERVE_SECONDS:
		await a.wait(REPORT_EVERY)
		elapsed += REPORT_EVERY
		## 开战了就摆一排豌豆射手 —— 没有植物就没有子弹，子弹同步那一层就白测了
		if not seeded and _progress() == MainGameManager.E_MainGameProgress.MAIN_GAME:
			seeded = true
			_seed_plants(a)
		## ★ 不主动造几颗的话整局可能一颗阳光都没有 —— 那样 `S OK(0)` 看着是"一致"，
		## 其实是**阳光这条路根本没被测到**（实测第一版就是两端都 0）
		if int(elapsed) == 8 or int(elapsed) == 20 or int(elapsed) == 34:
			_maybe_make_sun()
		_tick_log(a, "观察中 %.0fs" % elapsed)

	a.log("")
	a.log("[PAIR] result=%s reports=%d transient=%d persistent=%d phantom=%d max_dhp=%d max_plant_gap=%d saw_zombie=%s bullet_match=%s plant_match=%s sun_match=%s" % [
		("PASS" if _ok() else "FAIL"), _reports, _transient, _persistent, _phantom,
		_max_dhp, _plant_gap, str(_saw_zombie), str(_bullet_match_seen),
		str(_plant_match_seen), str(_sun_match_seen)])
	a.quit_game()


func _ok() -> bool:
	## `plant_match` / `sun_match` 要求"两端都真的有这一类且编号一致" ——
	## 光是"两边都是 0"也算相等，但那等于这一类没被测到
	return _reports >= MIN_REPORTS and _persistent == 0 and _phantom == 0 \
		and _saw_zombie and _bullet_match_seen \
		and _plant_match_seen and _sun_match_seen


func _progress() -> int:
	if Global.main_game == null or not is_instance_valid(Global.main_game):
		return -1
	return Global.main_game.main_game_progress


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


## 直接在主机上摆一排豌豆射手（每行第一列一株）
##
## ⚠️ 为什么绕开"正常种卡"那条路：种卡是**命令同步**的事（`NetplayBattleSync` + 手牌 UI），
## 那是另一条链路；这里要验的是**子弹同步**，只要场上有植物在开火就够了。
## 代价：这些植物不会出现在客户端（快照只同步植物血量，不负责凭空种一棵），
## 所以 `plants` 那两列两端**本来就不该相等**，别拿它当判据。
func _seed_plants(a) -> void:
	var mg := Global.main_game
	if mg == null or mg.plant_cell_manager == null:
		return
	var cells := mg.plant_cell_manager.all_plant_cells
	if cells.is_empty():
		return
	var made := 0
	for row in cells:
		if row.is_empty():
			continue
		var cell = row[0]
		if not is_instance_valid(cell):
			continue
		## ⚠️ `cell` 是 Variant，`var plant := ...` 会**推断不出类型**而整份脚本解析失败
		var plant: Plant000Base = cell.create_plant(CharacterRegistry.PlantType.P001PeaShooterSingle)
		if plant != null:
			made += 1
	a.log("  已在主机上摆了 %d 株豌豆射手（只为造出子弹）" % made)


## 等屋里的人都报了准备，再由主机按「开始」（玩家会做的那两步）
##
## 为什么要显式做：自动跳过选卡那条路（没有选卡界面的关）会在客户端还没进关时就跳，
## 闸门一挡就没有第二次"开始"了 —— 两端一起卡死在选卡阶段。
func _wait_ready_then_start(a) -> void:
	var session := _session()
	if session == null:
		return
	var waited := 0.0
	while waited < 60.0:
		var others := session.other_peer_ids()
		if not others.is_empty() and NetplayReadyFlow.all_ready(session.ready_peers, others):
			break
		await a.wait(1.0)
		waited += 1.0
	a.log("  等准备 %.0fs：房间准备状态=%s 其他 peer=%s" % [
		waited, str(session.ready_peers), str(session.other_peer_ids())])
	if _progress() == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		a.log("  主机按「开始」（推 CARD_SLOT_NORM_START_GAME）")
		EventBus.push_event(ConstEventName.CARD_SLOT_NORM_START_GAME)
	## 等真的开战
	waited = 0.0
	while _progress() != MainGameManager.E_MainGameProgress.MAIN_GAME and waited < 40.0:
		await a.wait(1.0)
		waited += 1.0
	a.log("  等开战 %.0fs：阶段=%d" % [waited, _progress()])


func _session() -> NetplaySession:
	if _a == null:
		return null
	return _a.get_node_or_null(SESSION_PATH) as NetplaySession


## 主机主动造一颗阳光
##
## ⚠️ 只在**主机**造：客户端的 `sun_spawn_gate` 是占住的，让它造只会白造。
## 客户端那一颗应当来自主机的下发（`sun_spawn` 命令）或快照补种 ——
## 两边都对得上才算阳光这条路真的通。
func _maybe_make_sun() -> void:
	var mg := Global.main_game
	if mg == null or not is_instance_valid(mg):
		return
	if not is_instance_valid(mg.day_suns_manager):
		return
	mg.day_suns_manager.spawn_sun()


## 每一拍把连线的实际情况也打出来：一旦"两端对不上"，第一眼就能分清是连线断了还是同步错了
func _tick_log(a, label: String) -> void:
	var session := _session()
	var state := -1
	var ready: Dictionary = {}
	var peers: Array = []
	if session != null:
		state = session.state
		ready = session.ready_peers
		peers = session.other_peer_ids()
	a.log("  ... %s 阶段=%d 连线=%d 其他peer=%s 准备=%s 回报=%d" % [
		label, _progress(), state, str(peers), str(ready), _reports])


#region 对拍
## 客户端回报到了：当场采一份主机的，两边对着看
func _on_command_received(_from_peer_id: int, command: Dictionary) -> void:
	if str(command.get("op", "")) != "pair_view":
		return
	var mine := _view()
	var client_ids := _sorted_ints(command.get("ids", []))
	var client_hp := _to_ints(command.get("hp", []))
	var client_xs := _to_ints(command.get("xs", []))
	var client_bids := _sorted_ints(command.get("bids", []))
	var host_ids: Array = mine["ids"]
	var host_bids: Array = mine["bids"]
	_reports += 1
	for id in host_ids:
		_host_all_ids[id] = true
	if not host_ids.is_empty():
		_saw_zombie = true

	var hp_pids: Array = mine.get("pids", [])
	var cl_pids: Array = command.get("pids", [])
	var hp_sids: Array = mine.get("sids", [])
	var cl_sids: Array = command.get("sids", [])
	var ids_match := host_ids == client_ids
	var pids_match := hp_pids == cl_pids
	var sids_match := hp_sids == cl_sids
	## 三类同一把尺子：植物与阳光是新进快照的，跟僵尸一样允许"单拍差一只"
	_classify(&"ids", ids_match)
	_classify(&"pids", pids_match)
	_classify(&"sids", sids_match)
	if pids_match and not hp_pids.is_empty():
		_plant_match_seen = true
	if sids_match and not hp_sids.is_empty():
		_sun_match_seen = true
	_plant_gap = maxi(_plant_gap, absi(hp_pids.size() - cl_pids.size()))
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
	_max_dhp = maxi(_max_dhp, dhp)

	var bids_match := host_bids == client_bids
	## 子弹编号对上一次 ⇒ 客户端渲染的就是主机那几颗（不是自己另造的一份）
	if bids_match and not host_bids.is_empty():
		_bullet_match_seen = true
	_a.log("  PAIR #%d | z=%d ids=%s | dhp=%d dx=%d | B %s | P %s | S %s%s" % [
		_reports, host_ids.size(),
		("OK" if ids_match else "DIFF h=%s c=%s" % [str(host_ids), str(client_ids)]),
		dhp, dx,
		("OK(%d)" % host_bids.size() if bids_match
			else "DIFF h=%s c=%s" % [str(host_bids), str(client_bids)]),
		("OK(%d)" % hp_pids.size() if pids_match
			else "DIFF h=%s c=%s" % [str(hp_pids), str(cl_pids)]),
		("OK(%d)" % hp_sids.size() if sids_match
			else "DIFF h=%s c=%s" % [str(hp_sids), str(cl_sids)]),
		("" if phantom_ids.is_empty() else " | PHANTOM=%s" % str(phantom_ids))])


## 这一类这一拍对不对：**只有连续不对**才算 persistent（为什么见 `_transient` 的注释）
func _classify(key: StringName, ok: bool) -> void:
	if ok:
		_prev_ok[key] = true
		return
	if bool(_prev_ok.get(key, true)):
		_transient += 1
	else:
		_persistent += 1
	_prev_ok[key] = false


## 主机这一刻眼里的"场上长什么样"
func _view() -> Dictionary:
	var mg := Global.main_game
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
