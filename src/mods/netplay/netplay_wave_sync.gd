extends Node
class_name NetplayWaveSync
## 联机的**波次同步**：每一波由主机下发，客户端**完全不出怪**
##
## 为什么必须下发：波次刷新靠的是 `Timer` + `randf_range(25,31)` 秒的真实时间
## （见 [关卡时间轴](../../docs/参考存档/关卡时间轴.md)）—— 两端各跑各的定时器，
## 连第一波都不会在同一刻来。
##
## ★ 这一层只同步"**波次这件事**"，**不下发"出了什么怪"**：
##   host  开了一波 ──▶ `ZombieWaveManager.wave_started` ──▶ 下发 `wave_next(波次号/大波/升旗)`
##   client 收到    ──▶ 只播演出（升旗 +「一大波僵尸正在接近」），**一个僵尸都不造**
##
## 那客户端场上的僵尸从哪来：**状态广播**（`NetplayStateSync`）每帧把主机场上的僵尸整份
## 报下来，客户端按 `entity_id` 补出来。于是"出怪"整件事彻底归主机：
##   · 不必赌两端的随机序列一致 —— `GameRng` 是一条共享序列，一端多调一次就全串位，
##     而这类串位**没有任何报错**，只表现为两端的怪不一样；
##   · 珊瑚 / 蹦极 / 墓碑伏击那几批"额外生成"也一并覆盖 —— 它们本来就没有下发通道，
##     以前只能靠 `GameRng` 撞运气；
##   · 中途加入的人进来就开始收快照，不用补种子、也不用对齐序列位置。
## 代价只有一个：僵尸出现比主机晚约一个 RTT（局域网几毫秒）。
##
## ⚠️ 客户端因此**永远不许自己开波**：`start_next_wave_gate` 恒 false（见 `_client_wave_gate`），
## 刷新定时器也一并停掉（`stop_refresh()`）—— 客户端没有任何一条本地路径需要开波。
##
## 只接管**普通出怪模式**（`monster_mode == Norm` 且没有外部出怪器）：
## 锤僵尸这类玩法有自己的出怪器与节奏，联机不碰（一次性玩法归关卡脚本，见硬约束 §1-8）。
##
## 关联：[联机模组](../../docs/参考存档/联机模组.md) ｜ [联机模组规范](../../docs/参考存档/联机模组规范.md)

const SELF_NODE_NAME := "NetplayWaveSync"

var _session: NetplaySession = null
var _main_game: MainGameManager = null
var _notice: Callable = Callable()


## 挂上来之后要先接线：[param notice] `func(text: String) -> void`
func setup(session: NetplaySession, main_game: MainGameManager, notice: Callable = Callable()) -> void:
	_session = session
	_main_game = main_game
	_notice = notice
	if _session == null or not _session.is_linked():
		return
	## ⚠️ 不能在 `setup()` 里直接接线：模组装在 `zombie_manager.init_manager()` **之前**
	## （`MainGameManager.init_manager()` 里模组那一步排在前），那一刻 `monster_mode` 还没赋值、
	## 关卡脚本的出怪器也可能还没注入，"接不接管"判断不了。推到帧末，那时子管理器已初始化完，
	## 而开战（第一波）远在后面几帧，闸门来得及生效。
	call_deferred("_install")


## 真正接线（帧末执行一次）
func _install() -> void:
	if _session == null or not _session.is_linked():
		return
	var wave_manager: ZombieWaveManager = _wave_manager()
	if wave_manager == null:
		return
	if _session.is_client():
		## 客户端：自己一次波都不开 —— 波次时机由 `wave_next` 下发，僵尸由快照补种，
		## 这里把本地刷新定时器也停掉，闸门是双保险（守的是"刷新信号漏过来"那条路）
		wave_manager.start_next_wave_gate = _client_wave_gate
		if wave_manager.zombie_wave_refresh_manager != null:
			wave_manager.zombie_wave_refresh_manager.stop_refresh()
	if _session.is_host():
		if not wave_manager.wave_started.is_connected(_on_wave_started):
			wave_manager.wave_started.connect(_on_wave_started)
	if not _session.battle_op_received.is_connected(_on_battle_op_received):
		_session.battle_op_received.connect(_on_battle_op_received)


func _exit_tree() -> void:
	## 换关时旧节点会先灭：闸门要还回去，别把下一局的波次也锁住
	var wave_manager: ZombieWaveManager = _wave_manager()
	if wave_manager != null and wave_manager.start_next_wave_gate == _client_wave_gate:
		wave_manager.start_next_wave_gate = Callable()


## 闸门：客户端**永远不开波**（返回 false = 这一次不许本地开波）
##
## 为什么可以无条件关闭：出怪归主机（僵尸由快照补种），波次演出归 `wave_next` 命令
## （见 `_on_battle_op_received`）—— 客户端没有任何一条本地路径还需要开波。
func _client_wave_gate() -> bool:
	return false


## 主机开了一波 ⇒ 只把"这一波演什么"发下去（波次号 / 是不是大波 / 升哪面旗）
##
## ★ **不下发出怪清单**：客户端不该有出怪逻辑 —— "出什么怪、落在哪一行"两端各算一遍，
##   就得一直赌随机序列一致（见 `GameRng`，一端多调一次就全串）；而场上的僵尸本来就被
##   状态广播每帧报着（`NetplayStateSync` 按 `entity_id` 补种），客户端照着补即可。
##   所以这里只发**一次性演出** —— 那是命令该干的事，连续量归快照。
func _on_wave_started(wave: int) -> void:
	if _session == null or not _session.is_host():
		return
	var wave_manager: ZombieWaveManager = _wave_manager()
	if wave_manager == null:
		return
	var is_final := wave_manager.curr_wave_type == ZombieWaveManager.E_WaveType.Final
	var is_big := is_final or wave_manager.curr_wave_type == ZombieWaveManager.E_WaveType.Flag
	## 升旗序号照抄本体 `start_next_wave()` 里调 `set_progress_bar()` 那两处的口径；
	## 非大波不升旗（-1）。⚠️ 不去读 `_flag_to_raise`：那是一次性的，主机抢读了
	## 主机自己的进度条就升不了旗（`take_flag_raise_index()` 读走即清）。
	var flag := -1
	if is_big:
		flag = int(wave_manager.curr_wave % wave_manager.max_wave_one_round / 10.0)
	_session.request_battle_op(NetplayCommand.build(NetplayCommand.OP_WAVE_NEXT, {
		NetplayCommand.ARG_WAVE: wave,
		NetplayCommand.ARG_FLAG: flag,
		NetplayCommand.ARG_FINAL: is_final,
		NetplayCommand.ARG_BIG: is_big,
	}))


## 客户端收到主机开的那一波 ⇒ **只播演出，不开波、不出怪**
##
## ★ 场上的僵尸一个都不在这里造：主机那边生成后会被状态广播（`NetplayStateSync`）采进快照，
##   客户端按 `entity_id` 补出来。于是"出怪"整件事彻底归主机 —— 不会因随机序列串位而抽出
##   不一样的怪，也不会多造 / 少造，更没有"主机这波出了、客户端没出"的竞态。
##
## 这里只做**一次性**的三件事：记波次号、升一面旗、播「一大波僵尸正在接近」。
## ⚠️ **进度条不在这一条里发**：它是**连续量**（开波跳一次，波次之间还按秒慢慢爬），
##   命令只在开波那一刻发，爬升那一段永远差着 —— 它走每帧快照，见 `NetplayStateSync` 的 `pr`。
func _on_battle_op_received(op: StringName, args: Dictionary) -> void:
	if _session == null or _session.is_host():
		return
	if op != NetplayCommand.OP_WAVE_NEXT:
		return
	var wave := int(args.get(NetplayCommand.ARG_WAVE, -1))
	if wave < 0:
		return
	var wave_manager: ZombieWaveManager = _wave_manager()
	if wave_manager == null:
		return
	## 波次号**只作记录**：客户端没有任何逻辑依赖它（判定全在主机）。
	## 留着是为了让下面 `set_progress_bar()` 算出来的中间值不离谱，以及日志好读。
	wave_manager.curr_wave = wave
	wave_manager.is_wave_started = true
	## 升旗：走本体的 `set_progress_bar()` —— 旗帜下标本来就是它写进 `_flag_to_raise` 的，
	## 它顺手重算的那个进度值下一帧就被快照覆盖（快照才是准的），不会留下副作用
	var flag := int(args.get(NetplayCommand.ARG_FLAG, -1))
	if flag >= 0:
		wave_manager.set_progress_bar(flag)
	## 「一大波僵尸正在接近」：只有大波才有这一段，最终波播的是"最终"那一版
	if bool(args.get(NetplayCommand.ARG_BIG, false)) and wave_manager.ui_remind_word != null:
		wave_manager.ui_remind_word.zombie_approach(bool(args.get(NetplayCommand.ARG_FINAL, false)))


## 本局的波次管理器（只接管普通出怪模式：没有外部出怪器的 `Norm` 关）
func _wave_manager() -> ZombieWaveManager:
	var mg: MainGameManager = _resolve_main_game()
	if mg == null or mg.zombie_manager == null:
		return null
	if mg.zombie_manager.monster_mode != ConstLevelData.E_MonsterMode.Norm:
		return null
	if mg.zombie_manager.wave_source != null:
		return null
	return mg.zombie_manager.zombie_wave_manager


## 本节点记录的这一局还活着就用它，否则退回去问 `Global.main_game`
## （换关时旧节点会先灭再换新，用"活着的那一份"才不会对着空气操作）
func _resolve_main_game() -> MainGameManager:
	if _main_game != null and is_instance_valid(_main_game):
		return _main_game
	var mg: MainGameManager = Global.main_game
	return mg if is_instance_valid(mg) else null


func _notify(text: String) -> void:
	if _notice.is_valid():
		_notice.call(text)
