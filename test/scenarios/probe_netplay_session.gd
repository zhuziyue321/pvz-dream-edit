extends RefCounted

## 妯＄粍鎼埌 `user://mods/` 鍚?class_name 涓嶅啀娉ㄥ唽涓哄叏灞€绫伙紝鎺㈤拡杩欓噷 preload 鎴愬父閲忓啀寮曠敤
const NetplayActionGateway := preload("res://mods_builtin/netplay/netplay_action_gateway.gd")
const NetplayBattleSync := preload("res://mods_builtin/netplay/netplay_battle_sync.gd")
const NetplayCardSpawnSync := preload("res://mods_builtin/netplay/netplay_card_spawn_sync.gd")
const NetplayCardSync := preload("res://mods_builtin/netplay/netplay_card_sync.gd")
const NetplayCommand := preload("res://mods_builtin/netplay/netplay_command.gd")
const NetplayDropSync := preload("res://mods_builtin/netplay/netplay_drop_sync.gd")
const NetplayMod := preload("res://mods_builtin/netplay/netplay_mod.gd")
const NetplayReadyFlow := preload("res://mods_builtin/netplay/netplay_ready_flow.gd")
const NetplaySession := preload("res://mods_builtin/netplay/netplay_session.gd")
const NetplayStateSync := preload("res://mods_builtin/netplay/netplay_state_sync.gd")
const NetplaySunSync := preload("res://mods_builtin/netplay/netplay_sun_sync.gd")
const NetplayWaveSync := preload("res://mods_builtin/netplay/netplay_wave_sync.gd")
## 探针：联机模组的地基（会话挂载 + 三个本体扩展点 + 联机面板）
## 覆盖（都是「编译门禁抓不到、只能跑起来才知道」的那类）：
##   1. 会话节点真的挂进了 /root（autoload 阶段直接 add_child 会被拒，已改成延迟挂）
##   2. `EventBus` 拦截器：装上 → push 事件被拦到 → 摘掉 → 不再被拦
##   3. `GameRng`：未播种时可用；播种后同种子两次取值完全一致；clear_seed 回到未播种
##   4. `Character000Base.entity_id`：分配器自增、重置生效
##   5. 联机面板（模组页面右侧）：输入框 + 三个按钮 + 状态；状态变了能刷到 probe 值上
##      （这一份界面已经从控制台搬出来：控制台里不再有「联机」那一栏）
##   6~9. 房里谁说了算：房主进关 ⇒ 全屋跟进 / 选卡协商 / 房主退关 ⇒ 全屋退 + 通关以房主为准 /
##        客户端先报准备，准备好了房主才按得动「开始」
##   10~13. 主机权威：操作上行 + 种子同源；**每一波由主机下发**（编号一起下发）；
##          阳光由主机下发 + 拾取走主机权威；**主机按「快照频率」（默认每秒 60 次，模组页面里可调）
##          广播全份战斗快照**，客户端按 entity_id 对齐
##          （客户端的刷新定时器不再自己推进波次，闸门默认为空 = 单机零影响）
##   12. 阳光同步：天降由主机下发（客户端本地不掉）+ 拾取按**实体编号**走主机权威
##      （只接管主机下发过的那些；客户端自己长的阳光照单机那样本地生效）
## 机器可读汇总：最后一行 [NETPLAY] result=PASS|FAIL failed=<n>

const SESSION_PATH := "/root/NetplaySession"
## 用一个肯定没人订阅的事件名，避免 push 到真实业务链路上
const FAKE_EVENT := "netplay_probe_fake_event"

var _failed := 0
## 拦截器记到的事件名
var _seen_events: Array[String] = []


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 联机地基：会话 + 三个扩展点 + 联机面板 ==========")
	if not ModManager.is_mod_enabled(ModIds.NETPLAY):
		ModManager.set_mod_enabled(ModIds.NETPLAY, true)
		a.log("  已启用联机模组（ModIds.NETPLAY）")
	## 会话是**懒加载**的：启用模组 ≠ 开了房间（root 下此刻不该有它），
	##  等到 `_check_session()` 里真的造出来之后才要给它几帧进树
	await a.frames(2)
	## ⚠️ 这一段里有 `await`（会话造出来之后要给它几帧进树），必须 await 调用
	await _check_session(a)
	_check_interceptor(a)
	_check_game_rng(a)
	_check_entity_id(a)
	_check_panel_entries(a)
	_check_room_level_sync(a)
	_check_card_negotiation(a)
	_check_leave_and_verdict(a)
	_check_ready_flow(a)
	_check_battle_sync(a)
	_check_wave_sync(a)
	_check_card_spawn_sync(a)
	## ⚠️ 这一段里有 `await`（要等阳光节点进树），必须 await 调用 ——
	## 不 await 的话 `run()` 会一路走到 `_finish()` 提前收尾，后半段的断言根本没跑
	await 	_check_sun_sync(a)
	_check_state_sync(a)
	_check_drop_sync(a)
	_check_leave_room(a)
	_finish(a)


#region 断言与收尾
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[NETPLAY] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion


#region 1. 会话挂载
## ★ 纪律：**没开房间 = 零行为** —— 会话**懒加载**，只有真的开 / 加入房间（或下面那句
##   `_ensure_session()`）才挂上 root。单机开着模组时 root 下不该有它，也不该有任何联机日志。
func _check_session(a) -> void:
	a.log("")
	a.log("--- 1. 会话节点挂载（懒加载：没开房间就不该有它） ---")
	var mod := ModManager.get_mod(ModIds.NETPLAY) as NetplayMod
	if mod == null:
		_check(a, "（前置）拿到模组实例", false)
		return
	_check(a, "★ 没开房间时 /root 下没有会话（联机零行为）",
		a.get_node_or_null(SESSION_PATH) == null)
	## 按「开启房间」那一侧造会话（这里不真开房：不占端口，状态留在未连接）
	var created = mod._ensure_session()
	if created == null:
		_check(a, "（前置）造出会话", false)
		return
	_check(a, "造完之后立刻就在场景树里（RPC 靠节点路径，不能延迟挂）",
		created.is_inside_tree())
	await a.frames(2)
	var session: Node = a.get_node_or_null(SESSION_PATH)
	if session == null:
		_check(a, "（前置）/root/NetplaySession 存在", false, "节点没挂上（add_child 被拒？）")
		return
	_check(a, "/root/NetplaySession 存在", true)
	_check(a, "会话在场景树里", session.is_inside_tree())
	_check(a, "会话未连线时 is_linked=false", not session.is_linked(),
		"role=%s state=%s" % [str(session.role), str(session.state)])
#endregion


#region 2. EventBus 拦截器
func _check_interceptor(a) -> void:
	a.log("")
	a.log("--- 2. EventBus 拦截器 ---")
	var cb := _on_intercept
	EventBus.add_interceptor(cb)
	EventBus.push_event(FAKE_EVENT, [1])
	_check(a, "装上后能拦到事件", _seen_events.has(FAKE_EVENT), str(_seen_events))
	_seen_events.clear()
	EventBus.remove_interceptor(cb)
	EventBus.push_event(FAKE_EVENT, [2])
	_check(a, "摘掉后不再拦到", not _seen_events.has(FAKE_EVENT), str(_seen_events))


## 只记录，不接管（返回 false：本体照旧派发）
func _on_intercept(event_name: String, _payload: Array) -> bool:
	_seen_events.append(event_name)
	return false
#endregion


#region 3. GameRng
func _check_game_rng(a) -> void:
	a.log("")
	a.log("--- 3. GameRng 可播种随机 ---")
	GameRng.clear_seed()
	_check(a, "默认未播种", not GameRng.is_seeded())
	var unseeded_ok := true
	for _i in range(20):
		var v := GameRng.randf()
		if v < 0.0 or v >= 1.0:
			unseeded_ok = false
	_check(a, "未播种时 randf() 落在 [0,1)", unseeded_ok)

	## 每次取值前都要重新播种：播种只把发生器拨回起点，之后仍是连续取值
	GameRng.set_seed(20261008)
	var first := _take_three()
	GameRng.set_seed(20261008)
	var second := _take_three()
	_check(a, "同种子两次取值完全一致", first == second, "%s vs %s" % [str(first), str(second)])
	GameRng.set_seed(20261009)
	var other := _take_three()
	_check(a, "换种子取值不同", other != first, str(other))
	GameRng.clear_seed()
	_check(a, "clear_seed 回到未播种", not GameRng.is_seeded())


func _take_three() -> Array:
	return [GameRng.randi(), GameRng.randf(), GameRng.randi_range(0, 1000)]
#endregion


#region 5. 联机面板（模组页面右侧）
func _check_panel_entries(a) -> void:
	a.log("")
	a.log("--- 5. 联机面板（输入框 + 三个按钮 + 状态） ---")
	## 联机的界面已经从**控制台**搬到**模组页面**：条目不再登记进注册表，
	## 而是由 `NetplayMod.create_detail_control()` 拿着这一份条目现造控件。
	## 所以这里不再查 `Global.console_registry`，直接问模组要这一批条目。
	var mod := ModManager.get_mod(ModIds.NETPLAY) as NetplayMod
	if mod == null:
		_check(a, "（前置）拿到模组实例", false)
		return
	var by_id: Dictionary[StringName, ConsoleEntry] = {}
	for item in mod._build_panel_entries():
		var entry := item as ConsoleEntry
		if entry != null:
			by_id[entry.id] = entry
	a.log("  联机面板条目=%d" % by_id.size())
	var target := by_id.get(&"netplay_target") as ConsoleEntry
	var host := by_id.get(&"netplay_host") as ConsoleEntry
	var join := by_id.get(&"netplay_join") as ConsoleEntry
	var leave := by_id.get(&"netplay_leave_room") as ConsoleEntry
	_check(a, "输入框条目是 Text 形态",
		target != null and target.kind == ConsoleEntry.E_Kind.Text)
	_check(a, "「开启房间」按钮在面板里", host != null and host.kind == ConsoleEntry.E_Kind.Button)
	_check(a, "「加入房间」按钮在面板里", join != null and join.kind == ConsoleEntry.E_Kind.Button)
	_check(a, "「退出房间」按钮在面板里", leave != null and leave.kind == ConsoleEntry.E_Kind.Button)
	_check(a, "四条都在「联机」组",
		target != null and target.category == "联机"
		and host != null and host.category == "联机"
		and join != null and join.category == "联机"
		and leave != null and leave.category == "联机",
		"" if target == null else target.category)
	## ★ 反断言：控制台里不该再有联机的影子（搬干净了才算完）
	if Global.console_registry != null:
		var in_console := Global.console_registry.get_entries("联机")
		_check(a, "控制台里不再有「联机」那一栏", in_console.is_empty(),
			str(in_console.size()))

	var r1 := mod._parse_target("192.168.1.9:9000")
	_check(a, "解析 地址:端口", r1["address"] == "192.168.1.9" and r1["port"] == 9000, str(r1))
	var r2 := mod._parse_target("9001")
	_check(a, "只写端口时用默认地址",
		r2["address"] == NetplaySession.DEFAULT_ADDRESS and r2["port"] == 9001, str(r2))
	var r3 := mod._parse_target("   ")
	_check(a, "空输入回退默认值",
		r3["address"] == NetplaySession.DEFAULT_ADDRESS and r3["port"] == NetplaySession.DEFAULT_PORT, str(r3))

	## 只读文本只剩「状态」一行：「最近一条」「房间关卡」两行已撤销
	var status := by_id.get(&"netplay_status") as ConsoleEntry
	_check(a, "状态条目已登记且是 Readout 形态",
		status != null and status.kind == ConsoleEntry.E_Kind.Readout)
	var status_text := str(status.get_value()) if status != null else ""
	_check(a, "状态初值为「未连接」", status_text.contains("未连接"), status_text)
	_check(a, "面板里不再有「最近一条」", not by_id.has(&"netplay_last_log"))
	_check(a, "面板里不再有「房间关卡」", not by_id.has(&"netplay_room_level"))

	## 值在外面被改了：模组页面要能收到「重读一遍」的通知
	## （刷新的总线还是 `ConsoleRegistry` 的 `values_changed`：模组不再往控制台登记条目，
	##   只是借这条信号告诉前台「值变了，重读一遍」）
	var fired := {"v": false}
	if Global.console_registry == null:
		_check(a, "（前置）拿到刷新总线", false)
		return
	Global.console_registry.values_changed.connect(func(): fired["v"] = true)
	Global.console_registry.request_refresh()
	_check(a, "request_refresh 会通知前台重读", fired["v"])

	## 会话一动前台就该重读（用 close()：不占端口，且必定发一条流水）——
	## 流水不再占面板上一行，这里只验「会话一动 ⇒ 前台收到重读通知」
	var session := a.get_node_or_null(SESSION_PATH) as NetplaySession
	if session == null:
		_check(a, "（前置）拿到会话", false)
		return
	var fired_on_close := {"v": false}
	Global.console_registry.values_changed.connect(func(): fired_on_close["v"] = true)
	session.close()
	_check(a, "会话一有动静就通知前台重读", fired_on_close["v"])
#endregion


#region 6. 房主进关 ⇒ 全屋跟进
func _check_room_level_sync(a) -> void:
	a.log("")
	a.log("--- 6. 房主进关 ⇒ 全屋跟进 ---")
	var session := a.get_node_or_null(SESSION_PATH) as NetplaySession
	if session == null:
		_check(a, "（前置）拿到会话", false)
		return

	## 用一关**真的内置关卡**跑一遍：「打包键值 → 客房照着重建 → 存档键一致」
	var ids := LevelRegistry.all_ids()
	a.log("  LevelRegistry 扫到 %d 个内置关卡" % ids.size())
	if ids.is_empty():
		_check(a, "（前置）LevelRegistry 扫到内置关卡", false)
		return
	var level_id := ids[0]
	var para := LevelRegistry.get_level(level_id)
	para.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelAdventure, 0, "0001")

	var key := NetplayMod._level_key_of(para)
	_check(a, "键值带上 LevelRegistry 的 id", str(key["id"]) == level_id, str(key))
	_check(a, "选关三件套进了键值（客房靠它拼 save_game_name）",
		key["page"] == 0 and str(key["level_id"]) == "0001", str(key))

	var rebuilt := NetplayMod._load_level(key)
	if rebuilt == null:
		_check(a, "客房照键值重建出关卡", false)
		return
	_check(a, "客房照键值重建出关卡", true)
	rebuilt.set_choose_level(int(key["mode"]), int(key["page"]), str(key["level_id"]))
	_check(a, "重建后存档键一致（通关不会写到别的键上）",
		rebuilt.save_game_name == para.save_game_name,
		"%s vs %s" % [rebuilt.save_game_name, para.save_game_name])

	## 方位由房主定：客户端喊「进这一关」应该什么都不发生
	session.role = NetplaySession.E_Role.Client
	session.request_enter_level(key)
	_check(a, "客户端喊进关无效", session.room_level_id.is_empty(), session.room_level_id)

	## 房主喊了就记进房间状态（后加入的人靠这份记录补拉）；断开后清掉
	if not session.create_host(18912):
		_check(a, "（前置）起得到房主", false)
		return
	session.request_enter_level(key)
	_check(a, "房主进关后房间记下这一关", session.room_level_id == level_id, session.room_level_id)
	session.close()
	_check(a, "断开后房间关卡清掉", session.room_level_id.is_empty(), session.room_level_id)
#endregion


#region 7. 选卡协商
func _check_card_negotiation(a) -> void:
	a.log("")
	a.log("--- 7. 选卡协商（不跳过选卡 + 不重复 + 撞车规则） ---")
	var session := a.get_node_or_null(SESSION_PATH) as NetplaySession
	if session == null:
		_check(a, "（前置）拿到会话", false)
		return
	var ids := LevelRegistry.all_ids()
	if ids.is_empty():
		_check(a, "（前置）LevelRegistry 扫到内置关卡", false)
		return

	## 复现用户的现场：默认存档只解锁了极少数植物，卡槽系统判定「没有选择权」→ 跳过选卡
	var para := LevelRegistry.get_level(ids[0])
	para.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelAdventure, 0, "0001")
	para.init_para()
	a.log("  拥有植物 %d 张，卡槽 %d 个" % [
		Global.global_game_state.curr_plant.size(), para.get_max_choosed_card_num()])
	_check(a, "（前置）默认存档下这关被判定为「无选卡权」（会跳过选卡）",
		para.is_no_choose_permission(), str(para.is_locked_card_slot))

	## 没连线时（单机）不许动它：这是本体原有的行为
	NetplayMod.keep_choose_card_ui(session, para)
	_check(a, "单机时保留系统替选（不改动原有行为）", para.is_no_choose_permission())

	## 连上了就一定要把选卡界面找回来
	if not session.create_host(18913):
		_check(a, "（前置）起得到房主", false)
		return
	NetplayMod.keep_choose_card_ui(session, para)
	_check(a, "联机时改回完整选卡界面（不再跳过）", not para.is_no_choose_permission(),
		"锁=%s 预选=%d" % [str(para.is_locked_card_slot), para.prechosen_cards.size()])
	session.close()

	## 撞车规则：peer id 大的让
	_check(a, "房主（id=1）不让路", not NetplayCardSync.must_yield(1, 9000))
	_check(a, "客户端（id 大）让路", NetplayCardSync.must_yield(9000, 1))

	## 卡身份：只有植物卡参与协商，模仿者按同一株算
	var sync := NetplayCardSync.new()
	var plant_card := {"card_type": ResourceCardReference.CardType.Plant,
		"content_id": PlantIds.SUN_FLOWER, "is_imitater": false}
	_check(a, "认出植物卡", sync._plant_type_of(plant_card) == PlantIds.SUN_FLOWER,
		str(sync._plant_type_of(plant_card)))
	_check(a, "模仿者按同一张植物卡算",
		sync._plant_type_of({"card_type": ResourceCardReference.CardType.Plant,
			"content_id": PlantIds.SUN_FLOWER, "is_imitater": true}) == PlantIds.SUN_FLOWER)
	_check(a, "僵尸卡不参与植物去重",
		sync._plant_type_of({"card_type": ResourceCardReference.CardType.Zombie,
			"content_id": ZombieIds.CONE, "is_imitater": false})
			== PlantIds.NULL)
	sync.free()
#endregion


#region 8. 退出关卡 / 通关裁决
func _check_leave_and_verdict(a) -> void:
	a.log("")
	a.log("--- 8. 退出关卡 ⇒ 退回该模式该回的场景；通关裁决以房主为准 ---")

	## 退回哪个场景：mode 值本身就是那个选关页的场景 id
	var adv := NetplayMod.choose_level_scene_of_mode(MainSceneRegistry.MainScenes.ChooseLevelAdventure)
	_check(a, "冒险模式没有选关页，退回主菜单", adv.contains("start_menu"), adv)
	var mini := NetplayMod.choose_level_scene_of_mode(MainSceneRegistry.MainScenes.ChooseLevelMiniGame)
	_check(a, "迷你模式退回迷你选关页", mini.contains("mini_game_choose_level"), mini)
	_check(a, "mode 没记录时不乱跑（返回空）", NetplayMod.choose_level_scene_of_mode(0).is_empty())
	_check(a, "认不出选关页的 mode 也回主菜单（不扣在关卡里）",
		NetplayMod.choose_level_scene_of_mode(
			MainSceneRegistry.MainScenes.StartMenu).contains("start_menu"),
		NetplayMod.choose_level_scene_of_mode(MainSceneRegistry.MainScenes.StartMenu))

	## 客户端写不写档：只看房主裁决过没有
	var verdicts := {"101_0_0001": true}
	_check(a, "房主裁决过的这一关可以写", NetplayMod.client_may_write(verdicts, "101_0_0001"))
	_check(a, "房主没裁决的关卡不写（自己打通也不写）",
		not NetplayMod.client_may_write(verdicts, "101_0_0002"))
	_check(a, "空存档键一律不写", not NetplayMod.client_may_write(verdicts, ""))

	## 退关 / 裁决的方位：只有房主喊得动
	var session := a.get_node_or_null(SESSION_PATH) as NetplaySession
	if session == null:
		_check(a, "（前置）拿到会话", false)
		return
	if not session.create_host(18914):
		_check(a, "（前置）起得到房主", false)
		return
	session.request_enter_level({"id": "adventure_01_01", "path": "", "mode": 101, "page": 0, "level_id": "0001"})
	session.role = NetplaySession.E_Role.Client
	session.request_leave_level()
	_check(a, "客户端喊退关无效（房里还在打）", session.room_level_id == "adventure_01_01", session.room_level_id)
	session.role = NetplaySession.E_Role.Host
	session.request_leave_level()
	_check(a, "房主喊了才退（房间关卡清空）", session.room_level_id.is_empty(), session.room_level_id)
	session.close()
#endregion


#region 9. 选卡收工：客户端报准备，人都准备好了房主才开始
func _check_ready_flow(a) -> void:
	a.log("")
	a.log("--- 9. 客户端这一颗是「准备」，人都准备好了房主才按得动「开始」 ---")

	## 判据本身（抽成 static 就是为了这一段）
	_check(a, "没别人时直接可以开始（一个人也不卡）", NetplayReadyFlow.all_ready({}, []))
	_check(a, "有一个人没准备就不许开始", not NetplayReadyFlow.all_ready({2: true, 3: false}, [2, 3]))
	_check(a, "名单里的人全准备好才可以开始", NetplayReadyFlow.all_ready({2: true, 3: true}, [2, 3]))
	_check(a, "准备进度写得对",
		NetplayReadyFlow.ready_count_text({2: true, 3: false}, [2, 3]) == "1/2",
		NetplayReadyFlow.ready_count_text({2: true, 3: false}, [2, 3]))

	## 两颗按钮各写什么
	var host_wait := NetplayReadyFlow.button_text_of(true, false, false, "0/2")
	_check(a, "房主还在等人时写「等准备 0/2」", host_wait == "等准备 0/2", host_wait)
	var host_go := NetplayReadyFlow.button_text_of(true, false, true, "2/2")
	_check(a, "人都齐了房主写「开始」", host_go == "开始", host_go)
	var client_todo := NetplayReadyFlow.button_text_of(false, false, true, "0/0")
	_check(a, "客户端没准备时写「准备」", client_todo == "准备", client_todo)
	var client_done := NetplayReadyFlow.button_text_of(false, true, true, "0/0")
	_check(a, "客户端准备好之后提示等房主", client_done == "已准备（等房主开始）", client_done)

	## 真跑一道：这道闸门只看会话的角色与准备名单，用不着真的进关卡
	var session := a.get_node_or_null(SESSION_PATH) as NetplaySession
	if session == null:
		_check(a, "（前置）拿到会话", false)
		return
	if not session.create_host(18915):
		_check(a, "（前置）起得到房主", false)
		return
	var flow := NetplayReadyFlow.new()
	flow.setup(session, null, Callable())
	_check(a, "房主一个人的时候按「开始」放得行", flow.start_gate())
	_check(a, "房里只有自己时没有别人要等", session.other_peer_ids().is_empty(), str(session.other_peer_ids()))

	## 冒充当客户端（同一份会话上改角色）：这一下必须被拦下来，改成给自己报个准备
	## （无头一个进程里没有真的客房，把 state 也一起改成已连上 —— `is_linked()` 认这个）
	session.role = NetplaySession.E_Role.Client
	session.state = NetplaySession.E_State.Connected
	_check(a, "客户端按「开始摇滚吧」不会开始（改成报准备）", not flow.start_gate())
	_check(a, "按过之后本机记为已准备", bool(session.ready_peers.get(session.local_peer_id, false)))
	## 「准备」是一颗可以来回按的切换钮（ `_on_button_pressed()` 就是按钮按下的那一路）
	flow._on_button_pressed()
	_check(a, "客户端再按一次可以取消准备", not bool(session.ready_peers.get(session.local_peer_id, false)))
	flow._on_button_pressed()
	_check(a, "客户端还能再按回已准备", bool(session.ready_peers.get(session.local_peer_id, false)))
	session.clear_ready()
	_check(a, "新一轮选卡时准备状态清零", session.ready_peers.is_empty())
	flow.free()
	session.role = NetplaySession.E_Role.Host
	session.close()
#endregion


#region 10. 战斗同步：主机权威（客户端本地不生效，下来的才生效）
func _check_battle_sync(a) -> void:
	a.log("")
	a.log("--- 10. 战斗同步：主机权威（上行的是请求，下来的才是事实） ---")

	## 命令的打包 / 解包
	var cmd := NetplayCommand.build(NetplayCommand.OP_CLICK_CELL, {
		NetplayCommand.ARG_ROW: 2, NetplayCommand.ARG_COL: 3})
	_check(a, "命令认得出自己的操作名", NetplayCommand.op_of(cmd) == NetplayCommand.OP_CLICK_CELL, str(cmd))
	_check(a, "命令参数原样取回", int(NetplayCommand.args_of(cmd).get(NetplayCommand.ARG_COL, -1)) == 3)
	_check(a, "空字典不是一条命令", not NetplayCommand.is_valid({}))
	_check(a, "手上没拿卡时取不到「手上那一张」", NetplayCommand.held_card() == null)
	## ★ 本体那几种玩家操作（统一上报口的口径）都要认得出对应的命令，
	##   认不出的那一种网关就不会接管 —— 新增操作时先在这里加一行
	_check(a, "★ 点卡**不在**命令表里（客户端自己拿起，不上行）",
		NetplayCommand.op_from_action(GlobalUtils.E_PlayerAction.ClickCard) == &"")
	_check(a, "点铲子 → 点铲子命令",
		NetplayCommand.op_from_action(GlobalUtils.E_PlayerAction.ClickShovel) == NetplayCommand.OP_CLICK_SHOVEL)
	_check(a, "点格子 → 点格子命令",
		NetplayCommand.op_from_action(GlobalUtils.E_PlayerAction.ClickCell) == NetplayCommand.OP_CLICK_CELL)
	_check(a, "捡阳光 → 捡阳光命令",
		NetplayCommand.op_from_action(GlobalUtils.E_PlayerAction.PickSun) == NetplayCommand.OP_PICK_SUN)
	_check(a, "捡掉落物 → 捡掉落物命令",
		NetplayCommand.op_from_action(GlobalUtils.E_PlayerAction.PickDrop) == NetplayCommand.OP_PICK_DROP)
	_check(a, "payload 里没有那一格时不崩（返回空参数 ⇒ 网关不接管）",
		NetplayCommand.args_from_action(GlobalUtils.E_PlayerAction.ClickCell, []).is_empty())
	var cell_args := NetplayCommand.args_from_action(GlobalUtils.E_PlayerAction.ClickCell, [_fake_plant_cell()])
	_check(a, "点格子带上 row / col", int(cell_args.get(NetplayCommand.ARG_ROW, -1)) == 2)
	_check(a, "手上没卡时点格子的参数里不带卡的身份（铲子那一类照旧只带格子）",
		not cell_args.has(NetplayCommand.ARG_CARD_REF))
	_check(a, "payload 里没有编号的实体不产出参数（网关不接管）",
		NetplayCommand.args_from_action(GlobalUtils.E_PlayerAction.PickSun, []).is_empty())

	## 路由：**没连线就一律不接管**（单机必须完全照旧）
	var sync := NetplayBattleSync.new()
	_check(a, "没会话时不接管本体事件", not sync.handle_local_command(cmd))
	_check(a, "重放完了 _executing 要复位", not sync.is_executing())
	_check(a, "没接的业务不会重放成功", not sync.execute(&"不存在的操作", {}))

	var session := a.get_node_or_null(SESSION_PATH) as NetplaySession
	if session == null:
		_check(a, "（前置）拿到会话", false)
		sync.free()
		return
	sync.setup(session, null, Callable())
	_check(a, "登记之后会话能找到这一颗", session._battle_sync == sync)
	_check(a, "没连线时不接管（单机照旧）", not sync.handle_local_command(cmd))

	## 随机种子：主机开一关换一颗，两端同源
	var seed_value := NetplaySession.new_battle_seed()
	if not session.create_host(18916):
		_check(a, "（前置）起得到房主", false)
		sync.free()
		return
	session.request_battle_seed(seed_value)
	_check(a, "主机记下了这一局的种子", session.room_seed == seed_value, str(session.room_seed))

	_check(a, "本机 `GameRng` 已按同一颗种子播种", GameRng.is_seeded() and GameRng.get_seed() == seed_value)
	## 同源 = 同结果：这正是"两端抽出同一只僵尸"的根据
	var first_draw := GameRng.randi()
	GameRng.set_seed(seed_value)
	_check(a, "同一颗种子两次开局抽到同一串随机数", GameRng.randi() == first_draw, str(first_draw))

	## ★ 有人**自己**退了关：房主不能再等他点准备（不然「开始」永远按不动）
	session.ready_peers[99] = true
	session._apply_level_left(99)
	_check(a, "有人自己退了关 ⇒ 不再等他准备", not session.ready_peers.has(99))
	_check(a, "退出关卡的人被记进名单（等待名单据此剔掉他）",
		bool(session._level_left_peers.has(99)) and not session.waiting_peer_ids().has(99))
	## 房主开新一关 ⇒ 上一局退过关的人重新算进来（他这次会被一起拉进这一关）
	session.request_enter_level({&"id": &"probe"})
	_check(a, "房主开新一关 ⇒ 退过关的人重新算进名单", session._level_left_peers.is_empty())
	## 换关不该把这一局的种子冲掉（种子是"两端抽出同一只僵尸"的根据）
	_check(a, "房主开新一关之后种子还在", GameRng.is_seeded())

	## 客户端：**本地不生效**，只把请求上行
	var fake_cell := _fake_plant_cell()
	session.role = NetplaySession.E_Role.Client
	session.state = NetplaySession.E_State.Connected
	_check(a, "客户端的一次操作会被接管（本体不再本地派发）", sync.handle_local_command(cmd))
	## ★ 本体的**统一上报口**：网关占住它之后，玩家在本局里的每一个操作都从这一处上行
	var gateway := NetplayActionGateway.new()
	gateway.setup(session, null, Callable())
	_check(a, "网关占住了本体的玩家操作上报口", GlobalUtils.player_action_gate.is_valid())
	_check(a, "客户端点那一格草地被网关接管（只上行，本地不落）",
		gateway.handle_action(GlobalUtils.E_PlayerAction.ClickCell, [fake_cell]))
	## ★ 点卡**不接管**：拿起植物是本地的（卡是自己卡槽里那一张，主机那一局上没有它），
	##   种不种得下去才交给主机 —— 点格子那一步带上卡的身份上行（见 `NetplayBattleSync`）
	_check(a, "点卡不被接管（客户端本地拿起，本地校验）",
		not gateway.handle_action(GlobalUtils.E_PlayerAction.ClickCard, [null]))
	fake_cell.free()
	## 网关未入树，`free()` 不会走 `_exit_tree` —— 手动把上报口还回去，别污染后面的用例
	GlobalUtils.player_action_gate = Callable()
	_check(a, "网关交还上报口之后，本体操作恢复本地执行",
		not GlobalUtils.player_action_gate.is_valid())
	gateway.free()

	## 主机：先在自己这一局上跑一遍，**跑得成才当成事实发下去**。
	## 探针里没有真草坪（`all_plant_cells` 空表），所以这一条必然跑不动 ——
	## 这里要守的就是"跑不动 ⇒ 不重放成功"这条：两端不会各自记一笔不同的账
	session.role = NetplaySession.E_Role.Host
	_check(a, "主机的一次操作也走同一个入口（先在自己这局上跑）", sync.handle_local_command(cmd))
	_check(a, "主机这一局上跑不动 ⇒ 不算重放成功",
		not sync.execute(NetplayCommand.OP_CLICK_CELL, NetplayCommand.args_of(cmd)))
	sync.free()
	session.close()
	GameRng.clear_seed()
#endregion


#region 11. 波次同步
func _check_wave_sync(a) -> void:
	a.log("")
	a.log("--- 11. 波次同步 + 进关闸门：每一波由主机下发；客户端不能自己进关 ---")

	## 命令：开新的一波（走的还是 `battle_op` 那条下行通道）
	var cmd := NetplayCommand.build(NetplayCommand.OP_WAVE_NEXT, {NetplayCommand.ARG_WAVE: 5})
	_check(a, "开波命令认得出自己的操作名", NetplayCommand.op_of(cmd) == NetplayCommand.OP_WAVE_NEXT, str(cmd))
	_check(a, "开波命令带得回波次号", int(NetplayCommand.args_of(cmd).get(NetplayCommand.ARG_WAVE, -1)) == 5)

	## 本体默认不接管：单机 / 模组没开时闸门必须是空的
	var wm := ZombieWaveManager.new()
	_check(a, "开波闸门默认是空的（单机照旧开波）", not wm.start_next_wave_gate.is_valid())
	_check(a, "波次管理器有「开了一波」这个观测口", wm.has_signal("wave_started"))

	## 开波命令带的是"演什么"，不是"出什么怪"（出怪彻底归主机，僵尸由快照补种）
	var cmd_show := NetplayCommand.build(NetplayCommand.OP_WAVE_NEXT, {
		NetplayCommand.ARG_WAVE: 9,
		NetplayCommand.ARG_FLAG: 0,
		NetplayCommand.ARG_FINAL: false,
		NetplayCommand.ARG_BIG: true,
	})
	var show_args := NetplayCommand.args_of(cmd_show)
	_check(a, "开波命令带得回「升哪面旗」", int(show_args.get(NetplayCommand.ARG_FLAG, -1)) == 0)
	_check(a, "开波命令带得回「是不是大波」", bool(show_args.get(NetplayCommand.ARG_BIG, false)))
	_check(a, "开波命令带得回「是不是最终波」", not bool(show_args.get(NetplayCommand.ARG_FINAL, true)))
	_check(a, "开波命令**不带**出怪清单（不出怪就是不出怪）", not show_args.has("z_ids"), str(show_args))

	## ★ 命令：这一段打完了 —— 客户端**自己算不出这一刻**（不开波 + 僵尸是木偶），只能由主机下发；
	##   少了它，客户端的关卡流程会卡在「开战」那一步，本关走不到判胜 ⇒ 拿不到本关给的植物
	var cmd_finished := NetplayCommand.build(NetplayCommand.OP_BATTLE_FINISHED, {})
	_check(a, "「这一段打完了」认得出自己的操作名",
		NetplayCommand.op_of(cmd_finished) == NetplayCommand.OP_BATTLE_FINISHED, str(cmd_finished))
	_check(a, "「这一段打完了」是一条能认的命令", NetplayCommand.is_valid(cmd_finished))

	## 闸门语义：客户端**永远不开波**（波次时机归 `wave_next`，僵尸归快照补种）
	var sync := NetplayWaveSync.new()
	_check(a, "客户端一次波都不自己开", not sync._client_wave_gate())
	var session := a.get_node_or_null(SESSION_PATH) as NetplaySession
	if session == null:
		_check(a, "（前置）拿到会话", false)
		sync.free()
		wm.free()
		return
	## 没连线（单机）时不接管 —— 与战斗同步同一条纪律
	## （`setup()` 里是 `call_deferred` 推到帧末的，探针直接喊那一步，免得 `run()` 提前收尾）
	sync.setup(session, null, Callable())
	sync._install()
	_check(a, "没连线时不接管波次（闸门没装到本体上）", not wm.start_next_wave_gate.is_valid())
	sync.free()
	wm.free()

	## 进关闸门：房主放行，客户端在房间里**不能自己进关**（打哪一关由房主决定）
	_check(a, "模组装载后本体进关闸门被占住", GlobalUtils.enter_level_gate.is_valid())
	session.role = NetplaySession.E_Role.Client
	session.state = NetplaySession.E_State.Connected
	_check(a, "客户端在房间里不自己进关", not bool(GlobalUtils.enter_level_gate.call()))
	session.role = NetplaySession.E_Role.Host
	_check(a, "房主自己进关放行", bool(GlobalUtils.enter_level_gate.call()))
	session.close()
	_check(a, "断开之后又能自己进关（单机照旧）", bool(GlobalUtils.enter_level_gate.call()))
#endregion


#region 15. 出卡同步：传送带出哪一张由主机下发，客户端不自己抽
func _check_card_spawn_sync(a) -> void:
	a.log("")
	a.log("--- 15. 出卡同步：传送带出哪一张由主机下发（两端抽的不是同一张，点了会消失）---")

	## 命令带的是"卡的身份"，不是"你随便抽一张"
	var ref := ResourceCardReference.new()
	ref.card_type = ResourceCardReference.CardType.Plant
	ref.content_id = PlantIds.PEA_SHOOTER_SINGLE
	var cmd := NetplayCommand.build(NetplayCommand.OP_CARD_SPAWN, {
		NetplayCommand.ARG_CARD_REF: ref.to_dict(),
	})
	_check(a, "出卡命令认得出自己的操作名", NetplayCommand.op_of(cmd) == NetplayCommand.OP_CARD_SPAWN)
	## 身份过一趟网络要能原样还原（三个标量字段）
	var back := ResourceCardReference.from_dict(
		NetplayCommand.args_of(cmd).get(NetplayCommand.ARG_CARD_REF, {}))
	_check(a, "卡的身份过一趟网络还认得回来",
		back != null and back.card_type == ResourceCardReference.CardType.Plant \
			and back.content_id == PlantIds.PEA_SHOOTER_SINGLE)

	## 本体默认不接管：单机 / 模组没开时闸门必须是空的
	var belt := CardSlotConveyorBelt.new()
	_check(a, "传送带出卡闸门默认是空的（单机照旧抽）", not belt.create_card_gate.is_valid())
	_check(a, "传送带有「出了一张卡」这个观测口", belt.has_signal("card_created"))
	_check(a, "传送带有「按指定身份出一张」这个口", belt.has_method("spawn_card_by_reference"))
	belt.free()

	## 闸门语义：客户端**永远不自己出卡**（出哪一张归主机，客户端照着重建）
	var sync := NetplayCardSpawnSync.new()
	_check(a, "客户端一张卡都不自己出", not sync._client_card_gate())
	## 没本局时不能崩（关卡没配传送带的情况）
	sync.setup(null, null, Callable())
	_check(a, "没本局时取不到传送带也不崩", sync._conveyor() == null)
	sync.free()
#endregion


#region 13. 状态广播：主机每帧广播场上战斗状态，客户端照着对齐
func _check_state_sync(a) -> void:
	a.log("")
	a.log("--- 13. 状态广播：主机每秒广播 60 次全份战斗快照，客户端按 entity_id 对齐 ---")

	var sync := NetplayStateSync.new()
	## 没连线（单机）时不开物理帧 —— 与前面几层同一条纪律：模组没连上就完全不介入
	sync.setup(null, null, Callable())
	_check(a, "没会话时不广播（物理帧没开）", not sync.is_physics_processing())
	_check(a, "没本局时采集不崩（给回空快照）", sync.collect_snapshot(null).is_empty())
	## 僵王 + 玩家阳光总量（**卡片冷却刻意不同步** —— 那是本地域，两端各有各的卡槽）
	_check(a, "没本局时僵王列表为空（补种路径不崩）", NetplayStateSync._boss_list(null).is_empty())
	_check(a, "没本局时取不到僵王类型", NetplayStateSync._boss_type_of(null) == ZombieBossIds.NULL)
	_check(a, "没出战卡槽时不发阳光总量（照默认值取会把钱包清零）",
		not sync.collect_snapshot_extra(null).has(&"sv"))

	var session := a.get_node_or_null(SESSION_PATH) as NetplaySession
	if session == null:
		_check(a, "（前置）拿到会话", false)
		sync.free()
		return
	if not session.create_host(18917):
		_check(a, "（前置）起得到房主", false)
		sync.free()
		return
	sync.setup(session, null, Callable())
	_check(a, "房主才开物理帧（只有主机采快照）", sync.is_physics_processing())
	_check(a, "客户端那一份不采（收的一方）",
		not (NetplayStateSync.new()).is_physics_processing())
	## 主机 ⇒ 客户端：只有主机喊得动；没连线时连发都不发
	session.send_state_snapshot({})
	_check(a, "房主发快照不崩", true)

	## ★ 广播频率是**每秒多少次**（不是"每几帧"）—— 按时间攒，物理帧率变了频率不变
	_check(a, "默认每秒 60 次", NetplayStateSync.SEND_RATE_DEFAULT == 60.0)
	sync.set_send_rate(60.0)
	_check(a, "60 次/秒 ⇒ 每个物理帧都发", sync._tick_send(1.0 / 60.0))
	sync.set_send_rate(30.0)
	_check(a, "30 次/秒 ⇒ 第一个 1/60 秒还不够（隔帧才发）", not sync._tick_send(1.0 / 60.0))
	_check(a, "30 次/秒 ⇒ 攒满 1/30 秒就发", sync._tick_send(1.0 / 60.0))
	sync.set_send_rate(999.0)
	_check(a, "频率有上限（一帧最多发一次，调再高也不会更快）",
		sync.send_rate == NetplayStateSync.SEND_RATE_MAX)
	sync.set_send_rate(0.0)
	_check(a, "频率有下限（不能调到 0）", sync.send_rate == NetplayStateSync.SEND_RATE_MIN)
	sync.set_send_rate(NetplayStateSync.SEND_RATE_DEFAULT)

	## ★ 缺席够久才删：主机刚采到之前不能把客户端刚出生的僵尸删掉（否则会闪一下）
	var dummy := Node.new()
	sync._missing.clear()
	for _i in range(NetplayStateSync.MISS_FRAMES_BEFORE_DELETE - 1):
		sync._reap_missing(null, {1: dummy}, {}, sync._delete_zombie)
	_check(a, "缺席不够久不删（刚出生的僵尸不会被抹掉）", int(sync._missing.get(1, 0)) ==
		NetplayStateSync.MISS_FRAMES_BEFORE_DELETE - 1)
	sync._reap_missing(null, {1: dummy}, {}, sync._delete_zombie)
	_check(a, "连续缺席够了才判删", not sync._missing.has(1))
	## 主机那边还在的，计数要清零（不能攒着下次误删）
	sync._reap_missing(null, {1: dummy}, {}, sync._delete_zombie)
	sync._reap_missing(null, {1: dummy}, {1: true}, sync._delete_zombie)
	_check(a, "重新出现在快照里就清零", not sync._missing.has(1))

	## ★ 动画由主机下发"播哪一条 + 播到第几秒"，客户端**照播** —— 而不是下发一堆状态字段
	## 让客户端自己推导（那条路推导链断在哪儿就要往哪儿补，见 `netplay_state_sync.gd` 头注）。
	## 这里验的是这套**下标协议**的契约。
	var zz := Zombie000Base.new()
	_check(a, "拿不到播放器时不接管（返回 ANIM_NONE，而不是被当成 0 号动画）",
		NetplayStateSync._anim_index_of(zz) == NetplayStateSync.ANIM_NONE)
	_check(a, "ANIM_NONE 占住单字节的最大值（下标只能落在它之下）",
		NetplayStateSync.ANIM_NONE == 255)
	## ⚠️ 客户端收包的第一道防线：下标乱来也不能崩在这一行 —— 崩了就是整局断线
	NetplayStateSync._apply_anim(zz, NetplayStateSync.ANIM_NONE)
	NetplayStateSync._apply_anim(zz, 0)
	NetplayStateSync._apply_anim(zz, 250)
	NetplayStateSync._apply_anim(null, 0)
	_check(a, "★ 下标乱来（不接管 / 越界 / 空角色）都不会崩在这一行", true)
	## 接管动画树只做一次（重复关会跟快照打架）
	NetplayStateSync._take_over_anim(zz)
	NetplayStateSync._take_over_anim(zz)
	_check(a, "接管动画是幂等的（第二次不重复关）", zz.has_meta(&"netplay_anim_taken"))

	## ★ 下标协议的**核心假设**：两端实例化的是同一份 .tscn ⇒ 同一下标就是同一条动画，
	## 于是**不需要任何"动画名 → 编号"的硬编码表**（硬约束 §1-4 说的正是别散落这类映射）。
	## 这里把"取列表 → 按下标解回名字"整条跑一遍。
	var ap := AnimationPlayer.new()
	var lib := AnimationLibrary.new()
	ap.add_animation_library("", lib)
	lib.add_animation("walk", Animation.new())
	lib.add_animation("death", Animation.new())
	var anim_list := NetplayStateSync._anim_list_of(ap)
	_check(a, "动画列表缓存得住（不是每帧每只都重新取一遍）",
		NetplayStateSync._anim_list_of(ap) == anim_list)
	_check(a, "（前置）两条动画都在列表里", anim_list.size() == 2, str(anim_list))
	_check(a, "★ 下标 ↔ 名字 往返一致（两端同下标就是同一条动画）",
		anim_list[anim_list.find("walk")] == "walk"
		and anim_list[anim_list.find("death")] == "death")
	ap.free()

	## 变体（walk_status 等）只在 Zombie001Norm 上有 —— 现在动画走下标，这些字段不再下发，
	## 但 `_has_prop` 还在给"取可选组件"用，缓存键那个坑（按脚本而不是引擎基类）仍要守住。
	var zn := Zombie001Norm.new()
	## ⚠️ 缓存键必须按脚本算：`get_class()` 返回的是引擎基类，普僵和僵尸基类是同一个，
	## 共用键会让先查的那只污染另一只（这正是一开始 FAIL 的原因）
	_check(a, "缓存键按脚本算（不能退回引擎基类，否则两类僵尸串味）",
		sync._anim_prop_cache_key(zn) != sync._anim_prop_cache_key(zz))
	_check(a, "（前置）普僵确实有走路变体这个属性", sync._has_prop(zn, &"walk_status"))
	_check(a, "没有这个属性的僵尸类不算有（不能被 set 崩掉）",
		not sync._has_prop(zz, &"walk_status"))
	zn.free()
	zz.free()

	## ★ 客户端僵尸转"只渲染"：判定关掉，只留下渲染。
	## 这道闸门**必须是粘的** —— 死亡 / 魅惑 / 睡眠这些正常流程都会调
	## `enable_component(某个因素)`，如果它们能把闸门顶开，客户端就又开始自己判定了。
	var factor_netplay := ComponentNormBase.E_IsEnableFactor.Netplay
	_check(a, "联机用的是独立的禁用因素（不与死亡 / 全局等复用）",
		factor_netplay != ComponentNormBase.E_IsEnableFactor.Death
		and factor_netplay != ComponentNormBase.E_IsEnableFactor.Global
		and factor_netplay != ComponentNormBase.E_IsEnableFactor.Sleep)
	var mc := MoveComponent.new()
	mc.disable_component(factor_netplay)
	_check(a, "★ 这道闸门关得掉组件", not mc.is_enabling)
	mc.enable_component(ComponentNormBase.E_IsEnableFactor.Default)
	_check(a, "★ 别人启用别的因素拉不回这道闸门（否则死亡 / 睡眠会把它顶开）", not mc.is_enabling)
	mc.free()
	## 组件是 `@onready`，刚生出来那一帧还是 null —— 这时不能把 meta 记成"已经关过了"
	var zr := Zombie000Base.new()
	sync._make_zombie_render_only(zr)
	_check(a, "组件还没就绪时不落标记（下一帧再补）",
		not bool(zr.get_meta(NetplayStateSync.RENDER_ONLY_META, false)))
	zr.free()
	## ★ 客户端僵尸**完全不该有行为逻辑**：移动 / 索敌 / 跳跃 / 爆炸统统在关掉的名单里
	var behavior := NetplayStateSync.BEHAVIOR_COMPONENT_PROPS
	_check(a, "★ 移动组件也在「关掉」名单里（客户端的僵尸不该自己走）",
		behavior.has(&"move_component"))
	_check(a, "★ 索敌 / 跳跃 / 小丑爆炸也一并关掉（都会改判定的东西）",
		behavior.has(&"detect_component") and behavior.has(&"jump_component")
		and behavior.has(&"bomb_component_jackbox"))
	_check(a, "★ 纯表现的组件**不在**关掉名单里（血量阶段 / 焦黑 / 临界）",
		not behavior.has(&"hp_stage_change_component")
		and not behavior.has(&"charred_component")
		and not behavior.has(&"critical_value_component"))

	## ★ 子弹也要进快照：客户端不自己开火，场上的子弹全靠主机下发。
	## 没有它，客户端要么"没有豌豆"（停火），要么"豌豆穿过僵尸"（照旧开火而受击框被禁）。
	_check(a, "子弹实体编号默认为 0（还没领号）", Bullet000Base.new().entity_id == 0)
	var b1 := Bullet000Base.new()
	b1.assign_entity_id(77)
	_check(a, "子弹能盖上主机的编号（两端才对得上同一颗）", b1.entity_id == 77)
	b1.free()
	_check(a, "造子弹的闸门默认是空的（单机照旧造）",
		not GlobalUtils.bullet_spawn_gate.is_valid())
	## 闸门被占住时工厂造不出子弹（客户端本地不开火）；但"照主机数据重建"必须绕得过去，
	## 否则客户端一颗都造不出来 —— 场上会完全没有豌豆
	GlobalUtils.bullet_spawn_gate = func(): return true
	var gated := Global.bullet_registry.create_bullet(BulletIds.PEA)
	_check(a, "闸门被占住时本地不造子弹", gated == null)
	var rebuilt := Global.bullet_registry.create_bullet(BulletIds.PEA, true)
	_check(a, "★ 照主机数据重建时能绕过闸门（否则客户端一颗都造不出来）", rebuilt != null)
	if rebuilt != null:
		_check(a, "重建出来的子弹自动领到了编号", rebuilt.entity_id != 0)
		rebuilt.free()
	GlobalUtils.bullet_spawn_gate = Callable()

	## ★ 字节预算：ENet 不可靠包超 MTU 会整包丢弃，所以按字节排上限而不是按条数。
	## 现在拆成**两包**（僵尸+子弹 / 植物+阳光），各自一份预算（见 `NetplaySession`）。
	var z_cap := NetplayStateSync._cap_for(NetplayStateSync.BYTES_PER_ZOMBIE, 40,
		NetplayStateSync.BYTE_BUDGET - NetplayStateSync.RESERVE_BULLETS)
	_check(a, "僵尸上限按字节算得出来（不是写死 40）", z_cap > 0 and z_cap <= 40)
	_check(a, "第一包（僵尸 + 子弹）装得进 MTU",
		z_cap * NetplayStateSync.BYTES_PER_ZOMBIE + NetplayStateSync.RESERVE_BULLETS
		<= NetplayStateSync.BYTE_BUDGET)
	## ★ 第二包还要装**出战卡槽**（`cd_*`：每张卡的身份 + 剩余冷却），它的字节是从
	##   植物名册这份预算里扣的 —— 算上限时必须把它预留出来，不然"45 株装得下"只是纸面上的。
	var extra_fixed := NetplayStateSync.RESERVE_PROGRESS + NetplayStateSync.RESERVE_SUN_VALUE \
		+ NetplayStateSync.MAX_CARDS * NetplayStateSync.BYTES_PER_CARD
	var p_cap := NetplayStateSync._cap_for(NetplayStateSync.BYTES_PER_PLANT, 64,
		NetplayStateSync.BYTE_BUDGET - NetplayStateSync.RESERVE_SUNS - extra_fixed)
	_check(a, "第二包（植物 + 阳光 + 出战卡槽）也装得进 MTU",
		p_cap * NetplayStateSync.BYTES_PER_PLANT + NetplayStateSync.RESERVE_SUNS + extra_fixed
		<= NetplayStateSync.BYTE_BUDGET)
	## ★ 拆包的目的就在这一条：满盘（5 行 × 9 列 = 45 株）得真的装得下。
	## 挤在一包里时植物只能排到十几株，名册被截断就等于"植物这一档名存实亡"。
	_check(a, "★ 满盘 45 株 + 满槽 12 张卡一并装得下（否则名册被截断，植物等于没进快照）",
		p_cap >= 45)
	_check(a, "字节给 0 时一条都装不下（不是反过来放开）",
		NetplayStateSync._cap_for(NetplayStateSync.BYTES_PER_BULLET, 32, 0) == 0)

	## ★ 出战卡槽也要能照主机那一副重建：卡的身份压成数字发过来，客户端得还原得回同一张
	## 豌豆射手（模仿者是"同一张卡换个壳"，content_id 一样）
	var pea_ref := ResourceCardReference.create(ResourceCardReference.CardType.Plant,
		PlantIds.PEA_SHOOTER_SINGLE, false)
	var imit_ref := ResourceCardReference.create(ResourceCardReference.CardType.Plant,
		PlantIds.PEA_SHOOTER_SINGLE, true)
	var card_snap := {
		&"cd_type": PackedInt32Array([int(pea_ref.card_type), int(imit_ref.card_type)]),
		&"cd_id": PackedStringArray([pea_ref.content_id, imit_ref.content_id]),
		&"cd_imit": PackedByteArray([0, 1]),
		&"cd_cool": PackedFloat32Array([0.0, 3.5]),
	}
	var cards := NetplayStateSync._cards_of(card_snap)
	var refs: Array = cards[&"refs"]
	var cools: PackedFloat32Array = cards[&"cools"]
	_check(a, "卡的身份能还原成引用（照它才能在客户端补出同一张卡）",
		refs.size() == 2
		and refs[0].get_selection_key() == pea_ref.get_selection_key()
		and refs[1].get_selection_key() == imit_ref.get_selection_key())
	## ⚠️ 冷却必须与身份**成对**取回来：分成两趟各丢一次非法编号的话，冷却会张冠李戴
	_check(a, "剩余冷却与身份一一对应（第 i 个冷却就是第 i 张卡的）",
		cools.size() == 2 and is_equal_approx(cools[0], 0.0) and is_equal_approx(cools[1], 3.5))
	## ⚠️ 模仿者与普通版是**两张不同的卡**（`get_selection_key()` 带模仿位）：
	## 混成一张的话，客户端会把玩家带的那张模仿者换成普通版
	_check(a, "模仿者与普通版还原出来是两个不同身份", pea_ref.get_selection_key() != imit_ref.get_selection_key())
	## ⚠️ 身份变了要**比得出来**：比不出来就永远停在第一次那份名单上，主机中途加的卡进不来
	var changed_snap := card_snap.duplicate()
	changed_snap[&"cd_id"] = PackedStringArray([pea_ref.content_id, PlantIds.SUN_FLOWER])
	_check(a, "换了一张卡时身份序列变得出来（否则主机改了卡槽客户端不会跟着改）",
		NetplayStateSync._card_sig_of(card_snap) != NetplayStateSync._card_sig_of(changed_snap))
	_check(a, "没换卡时身份序列保持一致（否则卡槽会被每帧重建一次）",
		NetplayStateSync._card_sig_of(card_snap) == NetplayStateSync._card_sig_of(card_snap.duplicate()))
	## 非法 id（植物表里没有）要被丢掉，不能把坏引用塞进卡槽。
	## ⚠️ `cd_id` 现在是 `PackedStringArray`：还传 PackedInt32Array 会在解包时直接报
	##   "Trying to assign value of type 'PackedInt32Array' to a variable of type 'PackedStringArray'"
	var bad_snap := {&"cd_type": PackedInt32Array([1]), &"cd_id": PackedStringArray([&"no_such_plant"]),
		&"cd_imit": PackedByteArray([0]), &"cd_cool": PackedFloat32Array([0.0])}
	var bad_cards := NetplayStateSync._cards_of(bad_snap)
	_check(a, "id 非法的卡直接丢掉（不把坏引用塞进卡槽）",
		(bad_cards[&"refs"] as Array).is_empty() and (bad_cards[&"cools"] as PackedFloat32Array).is_empty())

	## 卡要能"按还剩几秒"摆冷却 —— 两端各跑各的计时器，攒下的误差靠它一次抹平
	var probe_card := Card.new()
	## ⚠️ 剩余秒数是**属性**（`cool_remain`），不是 `get_cool_remain()` ——
	##   内联写法的 getter 不会另外挂出一个方法，`has_method` 查不到
	_check(a, "卡能按剩余秒数摆冷却，也读得出剩余秒数",
		probe_card.has_method("set_card_cool_remain") and "cool_remain" in probe_card)
	probe_card.free()
	## 出战卡槽要能整体换成主机那份（缺的照模板补、多的退回待选区）
	var probe_slot := CardSlotBattle.new()
	_check(a, "出战卡槽能整体换成主机那一份卡", probe_slot.has_method("set_cards"))
	probe_slot.free()

	## ★ 植物名册带格子下标：解错了会把植物补种到**别的格子**上 —— 比不补更糟
	var probe_cell := PlantCell.new()
	probe_cell.row_col = Vector2i(3, 7)
	_check(a, "格子下标打包往返（种错格子比不种更糟）",
		NetplayStateSync._unpack_cell(NetplayStateSync._pack_cell(probe_cell)) == Vector2i(3, 7))
	probe_cell.free()

	## ★ 截断时不能回收：本地这几颗只是"主机这一帧没采到"，不是"主机那边没有了"
	_check(a, "主机截断过就不回收（装不下的那批不会被误删）",
		NetplayStateSync._is_cut({&"b_cut": true}, &"b_cut"))
	_check(a, "没截断才回收", not NetplayStateSync._is_cut({}, &"b_cut"))
	var bd := Node.new()
	sync._missing.clear()
	## 正好跑满阈值：再多跑一轮会把计数重新攒起来（删掉之后又从 1 开始数）
	for _i in range(NetplayStateSync.MISS_FRAMES_BEFORE_DELETE_BULLET):
		sync._reap_missing(null, {9: bd}, {}, sync._delete_bullet,
			NetplayStateSync.MISS_FRAMES_BEFORE_DELETE_BULLET)
	_check(a, "子弹缺席够了会判删（阈值比僵尸短得多）", not sync._missing.has(9))
	_check(a, "子弹阈值确实比僵尸短（它活得就那么几秒）",
		NetplayStateSync.MISS_FRAMES_BEFORE_DELETE_BULLET < NetplayStateSync.MISS_FRAMES_BEFORE_DELETE)
	bd.free()
	dummy.free()
	sync.free()
	session.close()
#endregion


#region 14. 掉落物同步
func _check_drop_sync(a) -> void:
	a.log("")
	a.log("--- 14. 掉落物同步：掉不掉 / 掉哪一种由主机下发；拾取按编号走主机权威 ---")

	## 本体默认不接管：单机 / 模组没开时闸门必须是空的
	_check(a, "掉落闸门默认是空的（单机照旧掉）", not GlobalUtils.drop_gate.is_valid())
	_check(a, "玩家操作上报口默认是空的（单机照旧捡）", not GlobalUtils.player_action_gate.is_valid())
	_check(a, "「本局掉了一件」这个观测口已登记",
		ConstEventName.EVENT_PAYLOAD_SIGNATURES.has(ConstEventName.DROP_ITEM_SPAWNED))
	## 掉落物也要有编号，否则点一枚金币说不清"点的是哪一枚"
	var bare_coin := Coin.new()
	_check(a, "金币有实体编号字段（说清「哪一枚」）", bare_coin.entity_id == 0)
	bare_coin.free()
	var bare_choco := ChocolateDrop.new()
	_check(a, "巧克力有实体编号字段", bare_choco.entity_id == 0)
	bare_choco.free()
	_check(a, "掉落种类够分银币 / 金币 / 钻石 / 巧克力",
		DropItemManager.E_DropKind.size() == 4)

	## 命令：掉一件要带上编号 / 种类 / 起点 / 落点（两端才掉在同一处、掉成同一种）
	var drop_cmd := NetplayCommand.build(NetplayCommand.OP_DROP_ITEM, {
		NetplayCommand.ARG_SUN_ID: 9, NetplayCommand.ARG_DROP_KIND: DropItemManager.E_DropKind.Diamond,
		NetplayCommand.ARG_FROM: Vector2(300, 400), NetplayCommand.ARG_TO: Vector2(320, 480)})
	var drop_args := NetplayCommand.args_of(drop_cmd)
	_check(a, "掉落命令带得回实体编号", int(drop_args.get(NetplayCommand.ARG_SUN_ID, 0)) == 9)
	_check(a, "掉落命令带得回种类（分得清银币还是钻石）",
		int(drop_args.get(NetplayCommand.ARG_DROP_KIND, -1)) == DropItemManager.E_DropKind.Diamond)
	_check(a, "掉落命令带得回落点",
		Vector2(drop_args.get(NetplayCommand.ARG_TO, Vector2.ZERO)) == Vector2(320, 480))
	_check(a, "捡掉落物带的是编号而不是钱数",
		int(NetplayCommand.args_of(NetplayCommand.build(NetplayCommand.OP_PICK_DROP,
			{NetplayCommand.ARG_SUN_ID: 9})).get(NetplayCommand.ARG_SUN_ID, 0)) == 9)

	var sync := NetplayDropSync.new()
	var session := a.get_node_or_null(SESSION_PATH) as NetplaySession
	if session == null:
		_check(a, "（前置）拿到会话", false)
		sync.free()
		return
	sync.setup(session, null, Callable())
	_check(a, "没连线时不接管掉落（闸门没装到本体上）",
		not GlobalUtils.drop_gate.is_valid() and not GlobalUtils.player_action_gate.is_valid())
	if not session.create_host(18918):
		_check(a, "（前置）起得到房主", false)
		sync.free()
		return
	## 主机：自己照旧掉，闸门不装
	sync._install()
	_check(a, "主机自己掉战利品（不占掉落闸门）", not GlobalUtils.drop_gate.is_valid())
	## 客户端：本地一件都不掉
	## （点掉落物那一下不在这里 —— 统一网关会先问本节点一句 `is_host_spawned()`）
	session.role = NetplaySession.E_Role.Client
	session.state = NetplaySession.E_State.Connected
	sync._install()
	_check(a, "客户端占住掉落闸门（本地不掉）",
		GlobalUtils.drop_gate.is_valid() and bool(GlobalUtils.drop_gate.call()))
	## 只接管「主机下发过的」：客户端自己长的没有主机编号，照单机那样本地捡
	var stray := Coin.new()
	_check(a, "没身份的掉落物不接管（照单机那样本地捡）", not sync.is_host_spawned(stray))
	stray.assign_entity_id(77)
	sync._known_drop_ids[77] = true
	_check(a, "主机下发过的掉落物才接管", sync.is_host_spawned(stray))
	stray.free()

	sync.queue_free()
	await a.frames(1)
	_check(a, "同步节点退场后闸门还原", not GlobalUtils.drop_gate.is_valid())
	session.role = NetplaySession.E_Role.Host
	session.close()
#endregion


#region 12. 阳光同步
func _check_sun_sync(a) -> void:
	a.log("")
	a.log("--- 12. 阳光同步：天降 + 向日葵都由主机下发；拾取按实体编号走主机权威 ---")

	## 本体默认不接管：单机 / 模组没开时两个闸门都必须是空的。
	## ⚠️ 生成闸门**只有全局那一个** —— 上一版在天降管理器上另开了一个同名口，
	## 模组却只装了全局的，结果天降根本没被拦住（探针只验"闸门装上了"，没验"被谁读"）。
	var dsm := DaySunsManagner.new()
	_check(a, "生成闸门默认是空的（单机照旧掉）", not GlobalUtils.sun_spawn_gate.is_valid())
	_check(a, "★ 生成闸门只有全局那一个（天降不再另开一个口，免得漏装）",
		dsm.get("spawn_sun_gate") == null)
	_check(a, "玩家操作上报口默认是空的（单机照旧拾取）",
		not GlobalUtils.player_action_gate.is_valid())
	dsm.free()
	_check(a, "「本局长了一颗阳光」这个观测口已登记",
		ConstEventName.EVENT_PAYLOAD_SIGNATURES.has(ConstEventName.SUN_SPAWNED))
	var bare_sun := Sun.new()
	_check(a, "阳光有实体编号字段（说清「哪一颗」）", bare_sun.entity_id == 0)
	## 「弹起来再落下」这套表现在四处生成点上都是同一串数字（弹 -15、落 +45、0.9 秒），
	## 收在 `Sun.mark_pop_up()` 一处 —— 落点算错了，联机两端就会落在不同地方
	bare_sun.position = Vector2(100, 200)
	bare_sun.mark_pop_up(10.0)
	_check(a, "落点 = 起点 + (横向偏移, 净位移 +30)",
		bare_sun.spawn_target == Vector2(110, 230), str(bare_sun.spawn_target))
	_check(a, "落点带着用时（0.9 秒，两端掉得一样快）",
		abs(bare_sun.spawn_fall - 0.9) < 0.001, str(bare_sun.spawn_fall))
	bare_sun.free()

	## 命令：那一颗要带上编号 / 值 / 起点 / 落点 / 时长（两端落在同一处、掉得一样快）
	var spawn_cmd := NetplayCommand.build(NetplayCommand.OP_SUN_SPAWN, {
		NetplayCommand.ARG_SUN_ID: 7, NetplayCommand.ARG_SUN_VALUE: 25,
		NetplayCommand.ARG_FROM: Vector2(120, -40), NetplayCommand.ARG_TO: Vector2(120, 300),
		NetplayCommand.ARG_FALL: 0.9})
	_check(a, "天降命令认得出操作名", NetplayCommand.op_of(spawn_cmd) == NetplayCommand.OP_SUN_SPAWN)
	var spawn_args := NetplayCommand.args_of(spawn_cmd)
	_check(a, "天降命令带得回实体编号", int(spawn_args.get(NetplayCommand.ARG_SUN_ID, 0)) == 7)
	_check(a, "天降命令带得回落点（Vector2 原样过网）",
		Vector2(spawn_args.get(NetplayCommand.ARG_TO, Vector2.ZERO)) == Vector2(120, 300),
		str(spawn_args.get(NetplayCommand.ARG_TO, "")))
	_check(a, "生成命令带得回下落时长（向日葵吐的那颗不会变成一闪而过）",
		abs(float(spawn_args.get(NetplayCommand.ARG_FALL, 0.0)) - 0.9) < 0.001)
	## 拾取带的是**编号**而不是数值 —— 主机才能在自己这一局上摘掉同一颗
	var pick_cmd := NetplayCommand.build(NetplayCommand.OP_PICK_SUN, {NetplayCommand.ARG_SUN_ID: 7})
	_check(a, "拾取命令带的是实体编号",
		int(NetplayCommand.args_of(pick_cmd).get(NetplayCommand.ARG_SUN_ID, 0)) == 7)
	## 上行的是**编号**而不是数值 —— "加了多少点"说不清点的是哪一颗，
	## 所以本体那条 `ADD_SUN_VALUE` 事件不再对应任何操作（采集一律按 `E_PlayerAction` 走）
	var sun_probe := Sun.new()
	sun_probe.assign_entity_id(7)
	var pick_action_args := NetplayCommand.args_from_action(
		GlobalUtils.E_PlayerAction.PickSun, [sun_probe])
	_check(a, "捡阳光这条命令只有编号、没有数值",
		pick_action_args.size() == 1 and int(pick_action_args.get(NetplayCommand.ARG_SUN_ID, 0)) == 7,
		str(pick_action_args))
	sun_probe.free()

	## 真的造一颗阳光：指定了编号就不再自动分配
	var root: Node = a.get_node_or_null("/root")
	if root == null:
		_check(a, "（前置）拿到场景根", false)
		return
	var sun: Sun = SceneRegistry.SUN.instantiate()
	sun.assign_entity_id(4242)
	root.add_child(sun)
	await a.frames(1)
	_check(a, "指定了编号的阳光不再自动分配", sun.entity_id == 4242, str(sun.entity_id))

	## 同步节点：没连线时不接管
	var sync := NetplaySunSync.new()
	var session := a.get_node_or_null(SESSION_PATH) as NetplaySession
	if session == null:
		_check(a, "（前置）拿到会话", false)
		sun.queue_free()
		sync.free()
		return
	sync.setup(session, null, Callable())
	_check(a, "没连线时不接管阳光（闸门没装到本体上）",
		not GlobalUtils.sun_spawn_gate.is_valid() and not GlobalUtils.player_action_gate.is_valid())

	if not session.create_host(18917):
		_check(a, "（前置）起得到房主", false)
		sun.queue_free()
		sync.free()
		return
	## 主机：自己照旧长，闸门不装；订阅的是**全局事件**（天降 / 向日葵 / 掉落都在这一条上）
	sync._install()
	_check(a, "主机自己长阳光（不占生成闸门）", not GlobalUtils.sun_spawn_gate.is_valid())
	## ⚠️ 主机"推一条事件 ⇒ 发一条命令"这一段在探针里验不到：`request_battle_op()` 走 `rpc`，
	## 没有对端时本地不回调，`battle_op_received` 收不到（实测 `sent` 恒为空）。
	## 真要验得开两个进程（属阶段五），这里只验"这一条路径不崩"。
	sun.spawn_target = Vector2(10, 20)
	sun.spawn_fall = 0.9
	EventBus.push_event(ConstEventName.SUN_SPAWNED, [sun])
	_check(a, "收到「长了一颗」时主机不崩（下发那条路要开双进程才验得到）", true)

	## 客户端：本地一条都不长
	## （点阳光那一下不在这里 —— 统一网关会先问本节点一句 `is_host_spawned()`）
	session.role = NetplaySession.E_Role.Client
	session.state = NetplaySession.E_State.Connected
	sync._install()
	_check(a, "客户端占住生成闸门（天降 + 向日葵都不自己长）",
		GlobalUtils.sun_spawn_gate.is_valid() and bool(GlobalUtils.sun_spawn_gate.call()))
	## 只接管「主机下发过的」：客户端自己长的那一颗主机那局上没有它，
	## 接管只会得到"点不动" —— 放它回本机的老路
	_check(a, "没身份的阳光不接管（照单机那样本地拾取）", not sync.is_host_spawned(sun))
	sync._known_sun_ids[sun.entity_id] = true
	_check(a, "主机下发过的阳光才接管", sync.is_host_spawned(sun))

	## 换关 / 断线：闸门要还回去，别把下一局的阳光也锁住
	sync.queue_free()
	await a.frames(1)
	_check(a, "同步节点退场后闸门还原", not GlobalUtils.sun_spawn_gate.is_valid())
	session.role = NetplaySession.E_Role.Host
	session.close()
	sun.queue_free()
#endregion


## 一颗"只用它的 row_col"的植物格子：点格子这条命令只按 row_col 上行
## （真的种植链条要真草坪，探针里验不到；这里验的是"这一下被网关接管了吗"）
func _fake_plant_cell(row: int = 2, col: int = 3) -> PlantCell:
	var cell := PlantCell.new()
	cell.row_col = Vector2i(row, col)
	return cell


#region 15. 退出房间
## 客户端**没有**单独的「退出关卡」：要离开就是退出房间（断开连接），关卡一并退掉
func _check_leave_room(a) -> void:
	a.log("")
	a.log("--- 15. 退出房间：客户端没有单独的「退出关卡」，断开即退关 ---")
	var session := a.get_node_or_null(SESSION_PATH) as NetplaySession
	if session == null:
		_check(a, "（前置）拿到会话", false)
		return
	## 房主关房间（不只是退关）⇒ 还站在关卡里的人得退回去
	var closed := [0]
	var on_closed := func() -> void: closed[0] += 1
	session.room_closed.connect(on_closed)
	session.ready_peers[99] = true
	session._on_server_disconnected()
	_check(a, "主机断开 ⇒ 发出「房间已关闭」（在关里的人据此退回选关页）", closed[0] == 1)
	_check(a, "房间都没了 ⇒ 不再等任何人准备", session.waiting_peer_ids().is_empty())
	session.room_closed.disconnect(on_closed)
	## 退关那条路（还连着、只是不打这一关了）与它分开：那种由 `_level_left_peers` 记账
	session.role = NetplaySession.E_Role.Host
	session._apply_level_left(99)
	_check(a, "只退关（还连着）也要从等待名单里剔掉",
		bool(session._level_left_peers.has(99)) and not session.waiting_peer_ids().has(99))
	session.close()
	_check(a, "断开之后「退过关」的账也清了", session._level_left_peers.is_empty())
#endregion


#region 4. 实体 id
func _check_entity_id(a) -> void:
	a.log("")
	a.log("--- 4. 实体 id 分配器 ---")
	Character000Base.reset_entity_id_allocator(1)
	var a1 := Character000Base.take_next_entity_id()
	var a2 := Character000Base.take_next_entity_id()
	_check(a, "分配器自增（1, 2）", a1 == 1 and a2 == 2, "%d, %d" % [a1, a2])
	Character000Base.reset_entity_id_allocator(100)
	var b1 := Character000Base.take_next_entity_id()
	_check(a, "重置后从新起点开始（100）", b1 == 100, str(b1))
#endregion
