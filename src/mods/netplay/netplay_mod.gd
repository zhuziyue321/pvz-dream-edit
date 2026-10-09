extends ModBase
class_name NetplayMod
## 模组「联机」（骨架）：两人 / 多人**合作共守一块草坪**
##
## ★ 为什么是模组：原版《植物大战僵尸》没有联机，这是同人加的玩法 ——
##   照 [模组机制](../../docs/参考存档/模组机制.md) 的判据「原版有 → 本体；原版没有 → 模组」，
##   整条链路（连接 / 命令上行 / 界面）都在模组里，本体只认 `ModManager` 与 `ModIds`。
##
## 现在装的两样东西：
##   1. `NetplaySession`（挂 SceneTree.root）—— 跨场景存活的连线与命令收发
##   2. 控制台「联机」一栏（`register_console_entries()`）—— **联机唯一的界面**：
##      目标 `地址:端口` 输入框 + 「开启房间」「加入房间」两个按钮 + 状态 / 最近流水，都在这栏里
##   3. 每局把 `EventBus` 拦截器装上 —— 玩家操作采集成命令上行
##   4. 房主进关 ⇒ 全屋跟进：房主进 `MainGameManager` 那一刻把关卡键值广播出去，
##      客户端照着它 `Global.game_para` + `GlobalUtils.change_scene()` 切进同一关
##      （后加入的人由 `NetplaySession._on_peer_connected()` 补拉）
##
## ★ 为什么界面就放控制台：这一阶段联机还在探路（没做实体级的快照同步），
##   值得先看数据对不对，而不是先做一个漂亮房间 —— 控制台是本体给模组的调试槽位
##   （一行一条、不改场景、不改 `ConfigService`、关模组自动撤销），正合适。
##   真要做正式 UI 时再按 `glove_slot.tscn` 的方式落成场景，届时搬走即可。
##
## ★ 战斗同步（阶段三，见文档 §4.6）：**主机权威** —— 客户端按下的一次操作**不在本地生效**，
##   上行给主机，主机在自己这一局上跑成的那一遍再下行给全屋，大家重放同一串操作。
##   仍然**没有**实体级的状态下行（阶段四）：波次 / 出怪各跑各的定时器，实体增删不对齐。
##
## 本体留给本模组的槽位：
##   · `EventBus.add_interceptor()`（拦截器钩子，通用能力，不带模组名）
##   · `Character000Base.entity_id`（实体稳定标识）
##   · `GameRng`（可播种随机，两端抽同样的怪）
##   · `ZombieManager.set_wave_source()`（下一阶段把出怪权收归主机）
##   · `ConsoleEntry` / `ConsoleRegistry`（控制台条目注册表，本模组的界面全挂在上面）
##
## 开关：`data/mods/mod_config.tres` 的 `enabled_mods` 加 `&"netplay"`，默认关闭。
## 关联：[联机模组](../../docs/参考存档/联机模组.md) ｜ [NetplaySession](netplay_session.gd)

## 会话挂 root 时的节点名（两端 RPC 路径一致，靠的就是这个名字固定）
const SESSION_NODE_NAME := "NetplaySession"
## 控制台里这一栏的分组名
const CONSOLE_CATEGORY := "联机"
## 控制台输入框的持久化键（落在 `ConfigService` 的通用键值区，不用改 `ConfigService`）
const CONSOLE_KEY_TARGET := "netplay.target"
## 输入框的默认值 / 占位提示：`地址:端口`
const TARGET_PLACEHOLDER := "127.0.0.1:8912"
## 没接过任何流水时状态栏里的占位文字
const NO_LOG_YET := "（还没有动作）"

var _session: NetplaySession = null
## 最近一条会话流水（控制台那一行显示的就是它；完整流水去日志输出看）
var _last_log: String = NO_LOG_YET
## 本机当前 / 最后一次进入的那一关的键值（房主退关时要靠它退回正确的选关页）
var _last_level_key: Dictionary = {}
## 房主对每关结果的裁决：{`save_game_name` = true}；客户端只有在上榜的这些关写通关存档
var _host_verdicts: Dictionary = {}
## 客户端正在替房主"补写"这一关的通关（`_write_gate()` 要对这一次临时放行）
var _applying_host_verdict := false


func get_mod_id() -> StringName:
	return ModIds.NETPLAY


func get_mod_name() -> String:
	return "联机（骨架）"


func get_mod_description() -> String:
	return "多人合作共守一块草坪：ENet 连线 + 玩家操作命令上行（骨架，未做状态同步）；原版没有联机"


#region 生命周期
func install() -> void:
	_ensure_session()
	## ★ 占住本体的进关闸门：客户端在房间里不能自己进关（打哪一关由房主决定）
	GlobalUtils.enter_level_gate = _client_may_enter_level


func uninstall() -> void:
	if GlobalUtils.enter_level_gate == _client_may_enter_level:
		GlobalUtils.enter_level_gate = Callable()
	if _session == null:
		return
	_disconnect_session_signals(_session)
	_session.close()
	if is_instance_valid(_session):
		_session.queue_free()
	_session = null


## 关卡数据刚算好（卡槽还没建）：**联机时无论如何都别替玩家跳过选卡**
##
## 原版那条"没有选择权就跳过选卡"（`ResourceLevelData.is_no_choose_permission()`）在联机里不成立：
## 拿着再少的植物，也得**两个人都当面挑一遍** —— 不然谁带哪张全由系统固定，既可能重复，也没得商量。
## 时机必须在这一刻（见 `ModBase.on_level_para_ready()`）：晚了卡槽已经被预选卡填好了。
func on_level_para_ready(main_game: MainGameManager) -> void:
	if main_game == null:
		return
	keep_choose_card_ui(_session, main_game.game_para)


## 联机时把「系统替玩家选好」撤掉，改回完整的选卡界面
##
## 抽成 static 是因为它只看两个入参 —— 探针可以直接拿一关真的关卡资源验它，不必真起一局主游戏。
static func keep_choose_card_ui(session: NetplaySession, para: ResourceLevelData) -> void:
	if session == null or not session.is_linked() or para == null:
		return
	if not para.can_choosed_card or not para.has_norm_card_slot():
		## 传送带 / 不能选卡的关本来就没有选卡界面（`card_slot_norm` 是 null），不是我们能找回来的
		return
	if para.is_locked_card_slot or not para.prechosen_cards.is_empty():
		## 只动这两个"让 UI 被跳过"的字段：卡槽数量、关卡自己的预选规则都不受影响
		para.is_locked_card_slot = false
		para.prechosen_cards.clear()
		Log.info("联机模组: 本关改回完整的选卡界面（要商量，不能替大家选好）")


## 每局安装：把这一局的操作接进命令上行，房主再顺便把全屋拉进这一关
func install_to_main_game(main_game: MainGameManager) -> void:
	if main_game == null:
		return
	if _session == null:
		Log.warn("联机模组：会话未建好，本局不接命令上行")
		return
	_session.attach_main_game(main_game)
	## 房主进关 ⇒ 全屋跟进（客户端走不到这条：`request_enter_level()` 里就被挡掉了）
	if _session.is_host() and _session.is_linked():
		_last_level_key = _level_key_of(main_game.game_para)
		_session.request_enter_level(_last_level_key)
	## ★ 房主退关 ⇒ 全屋退：盯住本局节点的退场（`tree_exited` 只在真正离开这一局时响）
	if _session.is_host():
		if not main_game.tree_exited.is_connected(_on_main_game_exited):
			main_game.tree_exited.connect(_on_main_game_exited)
	## ★ 通关与否以房主为准：把"要不要写档"的裁决口占住（见 `MgmSaveManager.level_success_write_gate`）
	if main_game.save_manager != null:
		main_game.save_manager.level_success_write_gate = _write_gate
	## ★ 客户端的「开始摇滚吧」变「准备」：所有人都准备好之后房主才按得动「开始」
	##   （闸门挂在 `MainGameManager.choose_card_start_gate` 上，按钮由这一节点自己补）
	if _session.is_linked():
		var ready_flow := NetplayReadyFlow.new()
		ready_flow.name = NetplayReadyFlow.SELF_NODE_NAME
		main_game.add_child(ready_flow)
		ready_flow.setup(_session, main_game, _set_last_log)
		main_game.choose_card_start_gate = ready_flow.start_gate
	## 加装选卡协商（联网的那一刻才会装，单机连吃亏都没有）
	if _session.is_linked() and main_game.card_manager != null and main_game.card_manager.card_slot_norm != null:
		var sync := NetplayCardSync.new()
		sync.name = NetplayCardSync.SELF_SYNC_NODE_NAME
		main_game.add_child(sync)
		sync.setup(_session, main_game, _set_last_log)
	## ★ 战斗同步（主机权威）：客户端的操作不在本地生效，上行给主机；
	##   主机跑成的那一遍再下行给全屋重放 —— 大家眼里是**同一串**操作
	if _session.is_linked():
		var battle_sync := NetplayBattleSync.new()
		battle_sync.name = NetplayBattleSync.SELF_NODE_NAME
		main_game.add_child(battle_sync)
		battle_sync.setup(_session, main_game, _set_last_log)
		if main_game.hand_manager != null:
			main_game.hand_manager.cell_click_gate = battle_sync.handle_cell_click
	## ★ 波次同步：每一波由主机下发 —— 客户端的刷新定时器不再自己推进波次
	##   （不然两端各跑各的定时器，第一波都不在同一刻来）
	if _session.is_linked():
		var wave_sync := NetplayWaveSync.new()
		wave_sync.name = NetplayWaveSync.SELF_NODE_NAME
		main_game.add_child(wave_sync)
		wave_sync.setup(_session, main_game, _set_last_log)
	## ★ 状态广播：主机每帧把"场上现在长什么样"整份广播，客户端照着对齐
	##   （命令同步管"做了什么"，这一层管"现在是什么样" —— 两端本地模拟的分叉靠它抹平）
	if _session.is_linked():
		var state_sync := NetplayStateSync.new()
		state_sync.name = NetplayStateSync.SELF_NODE_NAME
		main_game.add_child(state_sync)
		state_sync.setup(_session, main_game, _set_last_log)
	## ★ 阳光同步：天上掉哪一颗由主机说了算，捡走哪一颗也要主机点头
	##   （天降是 `randf_range` 摇的，两端摇不出同一颗；拾取要说清"哪一颗"，光有数值不够）
	if _session.is_linked():
		var sun_sync := NetplaySunSync.new()
		sun_sync.name = NetplaySunSync.SELF_NODE_NAME
		main_game.add_child(sun_sync)
		sun_sync.setup(_session, main_game, _set_last_log)
	## ★ 掉落物同步：掉不掉、掉哪一种由主机说了算（"这只僵尸死了掉什么"是战斗逻辑，
	##   客户端不该自己掷骰），捡走哪一枚也要主机点头
	if _session.is_linked():
		var drop_sync := NetplayDropSync.new()
		drop_sync.name = NetplayDropSync.SELF_NODE_NAME
		main_game.add_child(drop_sync)
		drop_sync.setup(_session, main_game, _set_last_log)
#endregion


## 往控制台挂**整个联机界面**：目标输入框 + 开启/加入房间 + 状态 / 最近流水
##
## 这是模组自己登记的（本体面板不认识联机，见 [控制台](../../../docs/参考存档/控制台.md)）：
## 面板只按 `kind` 把条目变成控件，所以这一栏不用碰场景、不用改 `ConfigService`。
## 模组被关掉时 `ModManager` 会按模组 id 整组撤销。
func register_console_entries(registry: ConsoleRegistry) -> void:
	if registry == null:
		return
	registry.register_entry(ConsoleEntry.create_text(&"netplay_target", "目标（地址:端口）", _default_target())
		.set_category(CONSOLE_CATEGORY)
		.set_placeholder(TARGET_PLACEHOLDER)
		.set_tooltip("开启房间时只看端口；加入房间时填主机的 地址:端口（只写端口也认，地址按 127.0.0.1）")
		.bind_config(CONSOLE_KEY_TARGET, _default_target()))
	registry.register_entry(ConsoleEntry.create_button(&"netplay_host", "开启房间", _on_console_create_host)
		.set_category(CONSOLE_CATEGORY)
		.set_tooltip("用上面的端口开一个房间，等别人加入；再点一次会重开"))
	registry.register_entry(ConsoleEntry.create_button(&"netplay_join", "加入房间", _on_console_join)
		.set_category(CONSOLE_CATEGORY)
		.set_tooltip("按上面的 地址:端口 加入别人的房间"))
	registry.register_entry(ConsoleEntry.create_readout(&"netplay_status", "状态", _status_text)
		.set_category(CONSOLE_CATEGORY)
		.set_tooltip("本机角色与连接情况；会话一有动静就自动刷新这一行"))
	registry.register_entry(ConsoleEntry.create_readout(&"netplay_last_log", "最近一条", func() -> String:
			return _last_log)
		.set_category(CONSOLE_CATEGORY)
		.set_tooltip("最近一条会话流水；完整流水去看输出里的「联机模组:」日志"))
	registry.register_entry(ConsoleEntry.create_readout(&"netplay_room_level", "房间关卡", _room_level_text)
		.set_category(CONSOLE_CATEGORY)
		.set_tooltip("房里正在打的这一关；房主一开关，其余人会被自动拉进同一关"))


#region 会话
## 会话挂 root：连线要跨场景存活（先连上、再一起进关卡）
func _ensure_session() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if _session != null and is_instance_valid(_session):
		return
	var existing := tree.root.get_node_or_null(SESSION_NODE_NAME)
	if existing is NetplaySession:
		_session = existing
		_connect_session_signals(_session)
		return
	var session := NetplaySession.new()
	session.name = SESSION_NODE_NAME
	## ⚠️ 不能直接 add_child：模组是在 autoload 的 `_ready()` 里装的，那一刻
	##   SceneTree.root 还在装配子节点，直接挂会被拒
	##   （`Parent node is busy setting up children, add_child()` failed`），
	##   节点进不了树 → `multiplayer` 与 RPC 全废。推到帧末再挂。
	tree.root.call_deferred("add_child", session)
	_session = session
	_connect_session_signals(session)
	Log.info("联机模组：会话已就绪（默认端口 %d）" % NetplaySession.DEFAULT_PORT)


## 会话的动静 ⇒ 控制台那两行只读文本跟着变
func _connect_session_signals(session: NetplaySession) -> void:
	if session == null:
		return
	## 状态变化与有人进出都只影响「状态」那一行，共用一个回调够用
	if not session.state_changed.is_connected(_on_session_changed):
		session.state_changed.connect(_on_session_changed)
	if not session.peer_joined.is_connected(_on_session_changed):
		session.peer_joined.connect(_on_session_changed)
	if not session.peer_left.is_connected(_on_session_changed):
		session.peer_left.connect(_on_session_changed)
	if not session.level_enter_requested.is_connected(_on_level_enter_requested):
		session.level_enter_requested.connect(_on_level_enter_requested)
	if not session.level_leave_requested.is_connected(_on_level_leave_requested):
		session.level_leave_requested.connect(_on_level_leave_requested)
	if not session.level_result_received.is_connected(_on_level_result_received):
		session.level_result_received.connect(_on_level_result_received)
	if not session.session_log.is_connected(_on_session_log):
		session.session_log.connect(_on_session_log)


func _disconnect_session_signals(session: NetplaySession) -> void:
	if session == null:
		return
	if session.state_changed.is_connected(_on_session_changed):
		session.state_changed.disconnect(_on_session_changed)
	if session.peer_joined.is_connected(_on_session_changed):
		session.peer_joined.disconnect(_on_session_changed)
	if session.peer_left.is_connected(_on_session_changed):
		session.peer_left.disconnect(_on_session_changed)
	if session.level_enter_requested.is_connected(_on_level_enter_requested):
		session.level_enter_requested.disconnect(_on_level_enter_requested)
	if session.level_leave_requested.is_connected(_on_level_leave_requested):
		session.level_leave_requested.disconnect(_on_level_leave_requested)
	if session.level_result_received.is_connected(_on_level_result_received):
		session.level_result_received.disconnect(_on_level_result_received)
	if session.session_log.is_connected(_on_session_log):
		session.session_log.disconnect(_on_session_log)


func _on_session_changed(_value: int = -1) -> void:
	_request_console_refresh()


func _on_session_log(text: String) -> void:
	_last_log = text
	_request_console_refresh()


## 让面板把只读条目的值重读一遍（面板没开就什么都不做）
func _request_console_refresh() -> void:
	if Global == null or Global.console_registry == null:
		return
	Global.console_registry.request_refresh()
#endregion


#region 控制台按钮
## 开启房间：用输入框里的端口开一个房间
func _on_console_create_host() -> void:
	if _session == null or not is_instance_valid(_session):
		Log.error("联机模组：会话还没建好，开不了房间")
		return
	var target := _console_target()
	_session.create_host(target["port"])


## 加入房间：按输入框里的 地址:端口 连过去
func _on_console_join() -> void:
	if _session == null or not is_instance_valid(_session):
		Log.error("联机模组：会话还没建好，加不了房间")
		return
	var target := _console_target()
	_session.join(target["address"], target["port"])


## 读输入框里填的目标（`ConfigService` 的控制台键值区，没填过就用默认值）
func _console_target() -> Dictionary:
	if Global == null or Global.config_service == null:
		return _parse_target(_default_target())
	return _parse_target(str(Global.config_service.get_console_value(CONSOLE_KEY_TARGET, _default_target())))


func _default_target() -> String:
	return TARGET_PLACEHOLDER


## 把 `地址:端口` 拆成 {address, port}
##
## 容错：只写端口（`8912`）或只写地址（`192.168.1.9`）都认 ——
## 少的那半边补默认值，解析不出来就整个回退到默认，不让玩家开出一个空地址的房间。
static func _parse_target(raw: String) -> Dictionary:
	var text := raw.strip_edges()
	if text.is_empty():
		text = TARGET_PLACEHOLDER
	var address := NetplaySession.DEFAULT_ADDRESS
	var port := NetplaySession.DEFAULT_PORT
	var colon := text.rfind(":")
	if colon > 0:
		var address_part := text.substr(0, colon).strip_edges()
		var port_part := text.substr(colon + 1).strip_edges()
		if not address_part.is_empty():
			address = address_part
		if port_part.is_valid_int() and int(port_part) > 0 and int(port_part) < 65536:
			port = int(port_part)
	elif text.is_valid_int():
		port = int(text)
	else:
		address = text
	return {"address": address, "port": port}
#endregion


#region 房间：一起进关卡
## 进关闸门（挂在 `GlobalUtils.enter_level_gate` 上）：房主随便进，**客户端不能自己进**
##
## 联机时"我们在哪"由房主独裁（见 [联机模组规范](../../docs/参考存档/联机模组规范.md) §二）：
## 客户端自己点选关页进去了也会被房主的下一次进关命令覆盖，白进一次还容易把两边搞乱。
## 没连线（单机）与房主自己一律放行 —— 模组默认关闭，闸门默认是空的，单机零影响。
func _client_may_enter_level() -> bool:
	if _session == null or not is_instance_valid(_session) or not _session.is_linked():
		return true
	if _session.is_host():
		return true
	_set_last_log("联机时由房主选关，等房主带你进去")
	Log.info("联机模组: 客户端不自己进关（打哪一关由房主决定）")
	return false


## 房主喊「进这一关」⇒ 本机跟着切过去（房主自己已经在关里了，不用再管）
func _on_level_enter_requested(level_key: Dictionary) -> void:
	if _session != null and _session.is_host():
		return
	var level_id := str(level_key.get("id", ""))
	var para := _load_level(level_key)
	if para == null:
		_set_last_log("房主的关卡本机没有：%s" % level_id)
		Log.error("联机模组：房主这一关本机进不去（id=%s）—— 关卡脚本可能没跟着进包" % level_id)
		return
	## 选关三件套必须补齐：`save_game_name` 就是靠它拼出来的，不写会把通关存档落到默认键上
	para.set_choose_level(
		int(level_key.get("mode", 0)),
		int(level_key.get("page", 0)),
		str(level_key.get("level_id", "")))
	Global.game_para = para
	_last_level_key = level_key
	_set_last_log("正在进入 [%s]" % level_id)
	## 唯一推荐的换场景封装（`call_deferred` 内部延迟，不能 await）
	GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap[para.game_sences])


## 把本局的关卡打包成「能跨进程传」的键值：客房照着它重建同一关
##
## 传 `LevelRegistry` 的 id 与资源路径**两份**：id 是首选（包约束 §1-4 规定业务不写死关卡路径），
## 路径是铺底 —— 有的包里 `LevelRegistry` 扫不到内置关卡（见 `rescan()` 那行日志），
## 那时候客房靠 id 就会报「找不到」，有路径还能救回来。
static func _level_key_of(para: ResourceLevelData) -> Dictionary:
	if para == null:
		return {}
	var res_path := ""
	var script := para.get_script() as Script
	if script != null:
		res_path = script.resource_path
	elif para.resource_path != "":
		res_path = para.resource_path
	return {
		"id": res_path.get_file().get_basename(),
		"path": res_path,
		"mode": para.game_mode,
		"page": para.level_page,
		"level_id": para.level_id,
	}


## 客房照着键值把关卡重建出来：注册表认得就走注册表，认不得才退回房主给的路径
static func _load_level(level_key: Dictionary) -> ResourceLevelData:
	var level_id := str(level_key.get("id", ""))
	if level_id != "" and LevelRegistry.has_level(level_id):
		return LevelRegistry.get_level(level_id)
	var res_path := str(level_key.get("path", ""))
	if res_path == "":
		return null
	## 拿房主给的路径也要过一遍白名单：是不是关卡仍由 `LevelRegistry` 定，
	## 免得名称像关卡的别的脚本被误当成关卡加载进来
	if not LevelRegistry.is_level_script(res_path):
		return null
	var res := load(res_path)
	if res is Script:
		res = (res as Script).new()
	return res as ResourceLevelData


## 控制台「最近一条」写一行（并让面板立刻重读 —— 面板没开就什么都不做）
func _set_last_log(text: String) -> void:
	_last_log = text
	_request_console_refresh()
#endregion


#region 状态显示
## 控制台「状态」那一行显示的内容：`连接状态 ／ 角色 ／ 本地 peer id ／ 房里几人`
func _status_text() -> String:
	if _session == null or not is_instance_valid(_session):
		return "会话未就绪"
	var peer_count := 1
	## 没连过的会话别去问 `multiplayer`：还没分配 peer 时引擎自己也要打一条 ERROR
	## （控制台每次重建 / 刷值都会读一次状态，不挡住的话日志里全是噪音）
	if _session.multiplayer != null and _session.multiplayer.multiplayer_peer != null:
		peer_count = _session.multiplayer.get_peers().size() + 1
	return "%s ／ %s ／ 本地 peer=%d ／ 房里 %d 人" % [
		_state_name(_session.state), _role_name(_session.role), _session.local_peer_id, peer_count]


#region 房间：房主退关 ⇒ 全屋退
## 本局节点退场：**同进同出**，房主退了大家就退
##
## 注意这是个**连带动作**：换一关（`GlobalUtils.change_scene()` 到另一份关卡）时旧节点也会退场，
## 那时 `_session.is_host()` 仍在、新的那一局马上又会来一次 `install_to_main_game()` 把大家拉进去，
## 所以这里按下 Bool 直接喊"退"是安全的 —— 真正的依据是房主**不再进任何一关**。
func _on_main_game_exited() -> void:
	if _session == null or not _session.is_host():
		return
	if not _session.is_linked():
		return
	_session.request_leave_level()


## 客户端收到「房主退了」：退回**进关时那个模式的选关页**（房主多半也是回到那里）
func _on_level_leave_requested() -> void:
	if _session != null and _session.is_host():
		return
	if Global.main_game == null:
		return
	var scene_path := choose_level_scene_of_mode(int(_last_level_key.get("mode", 0)))
	if scene_path.is_empty():
		Log.info("联机模组: 房主退出关卡，但记不住进关的模式，已留在原地")
		return
	_set_last_log("房主退出关卡，跟着返回选关页")
	GlobalUtils.change_scene(scene_path)


## 这一局的 mode 值**就是**它所属选关页的场景 id（`ResourceLevelData.game_mode` 存的是
## `MainSceneRegistry.MainScenes.ChooseLevel*`），所以退回那页不需要额外维护一张对照表
static func choose_level_scene_of_mode(mode: int) -> String:
	if mode <= 0:
		return ""
	## `MainScenesMap` 是 `@export` 的（`:=` 推断不出类型，必须显式写 Dictionary）
	var map: Dictionary = Global.main_scene_registry.MainScenesMap
	if not map.has(mode):
		return ""
	var path := str(map[mode])
	## 保险：只认选关页（免得某个关卡的 mode 被写成别的场景，一退就直接飞去主菜单之外的地方）
	if not path.contains("choose_level"):
		return ""
	return path
#endregion


#region 房间：通关与否以房主为准
## 客户端要不要写这一关的通关存档：**只看房主有没有裁决过这一关**
static func client_may_write(host_verdicts: Dictionary, save_game_name: String) -> bool:
	if save_game_name.is_empty():
		return false
	return bool(host_verdicts.get(save_game_name, false))


## 挂在 `MgmSaveManager.level_success_write_gate` 上的裁决：返回 false = 这一次的通关不写档
##
## · 我是房主：照旧写（我就是事实来源），顺手把结果发给客户端
## · 我是客户端：只有房主已经裁决过这一关才写 —— 自己打通不算数
func _write_gate() -> bool:
	var main_game := Global.main_game
	if main_game == null or main_game.game_para == null:
		return true
	var save_game_name := main_game.game_para.save_game_name
	if _session == null or not _session.is_linked():
		return true
	if _session.is_host():
		_session.request_level_result(save_game_name, true)
		return true
	## 客户端：房主裁决过的才写；房主裁决后本机"补写"那一下由 `_applying_host_verdict` 临时放行
	return _applying_host_verdict or client_may_write(_host_verdicts, save_game_name)


## 客户端拿到房主裁决：把结果落到自己的存档上（走的是本体同一条写档函数，所以解锁 / 钉耙都是一致的）
func _on_level_result_received(save_game_name: String, success: bool) -> void:
	if not success:
		return
	_host_verdicts[save_game_name] = true
	var main_game := Global.main_game
	if main_game == null or main_game.game_para == null:
		Log.info("联机模组: 收到房主的通关裁决 [%s]，本机不在关里，已记下留着下一局生效" % save_game_name)
		return
	if main_game.game_para.save_game_name != save_game_name:
		return
	if main_game.save_manager == null:
		return
	## 这一关走完 UI 之后会被 `update_level_state_data_success()` 调一遍：
	## 这里主动补一次是给"本机还没到结算点但房主已经通关"的情况
	_applying_host_verdict = true
	main_game.save_manager.update_level_state_data_success()
	_applying_host_verdict = false
	_set_last_log("房主裁决：本关通关，已写入存档")
#endregion


## 控制台「房间关卡」那一行：房里正在打的这一关（房主还没进关时显示占位）
func _room_level_text() -> String:
	if _session == null or not is_instance_valid(_session):
		return "会话未就绪"
	if _session.room_level_id.is_empty():
		return "（房主还没进关）"
	return _session.room_level_id


func _state_name(state: int) -> String:
	match state:
		NetplaySession.E_State.Idle: return "未连接"
		NetplaySession.E_State.Hosting: return "主机等待中"
		NetplaySession.E_State.Connecting: return "连接中"
		NetplaySession.E_State.Connected: return "已连接"
		NetplaySession.E_State.Failed: return "连接失败"
	return "未知"


func _role_name(role: int) -> String:
	match role:
		NetplaySession.E_Role.None: return "无角色"
		NetplaySession.E_Role.Host: return "主机"
		NetplaySession.E_Role.Client: return "客户端"
	return "未知"
#endregion
