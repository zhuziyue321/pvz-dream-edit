extends Node
class_name NetplayWaveSync
## 联机的**波次同步**：每一波由主机下发，客户端不再按自己本地的刷新定时器推进
##
## 为什么必须下发：波次刷新靠的是 `Timer` + `randf_range(25,31)` 秒的真实时间
## （见 [关卡时间轴](../../docs/参考存档/关卡时间轴.md)）—— 两端各跑各的定时器，
## 连第一波都不会在同一刻来。操作层已经做到主机权威（`NetplayBattleSync`），
## 波次却还是各跑各的，于是"两端在打同一局"这句话只成立了一半。这一层补上之后，
## 两端才是同一波、同一批怪、落在同一行。
##
## 做法 —— 波次也是"主机上已经发生了的事实"，所以复用战斗同步那条通道 `battle_op`：
##   host  开了一波 ──▶ `ZombieWaveManager.wave_started` ──▶ 下发 `wave_next(波次号)`
##   client 收到 ──▶ 放行一次 `start_next_wave_gate` ──▶ 自己开同一波
##
## 出什么怪 / 落在哪一行由 `GameRng` 同源保证（种子是房主进关时下的那一颗）：
## 两端跑的是同一串 `start_next_wave()`，随机调用序列自然一致 ——
## 所以**只有"两端调用次数必然相同"的随机才走 `GameRng`**（波次 / 出怪行 / 大波特殊僵尸），
## 由战斗结果触发的那些（掉落、天降阳光）留在全局随机，否则会打乱共享的那条序列。
##
## 只接管**普通出怪模式**（`monster_mode == Norm` 且没有外部出怪器）：
## 锤僵尸这类玩法有自己的出怪器与节奏，联机不碰（一次性玩法归关卡脚本，见硬约束 §1-8）。
##
## 关联：[联机模组](../../docs/参考存档/联机模组.md) ｜ [联机模组规范](../../docs/参考存档/联机模组规范.md)

const SELF_NODE_NAME := "NetplayWaveSync"

var _session: NetplaySession = null
var _main_game: MainGameManager = null
var _notice: Callable = Callable()
## 正在按主机的下发开波：`start_next_wave_gate` 在这一下里放行
var _applying_host_wave := false


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
		## 客户端：本地的刷新定时器不再推进波次，只认主机下发的那一次
		wave_manager.start_next_wave_gate = _host_wave_gate
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
	if wave_manager != null and wave_manager.start_next_wave_gate == _host_wave_gate:
		wave_manager.start_next_wave_gate = Callable()


## 闸门：只有"正在按主机的下发开波"那一下才放行
func _host_wave_gate() -> bool:
	return _applying_host_wave


## 主机开了一波 ⇒ 波次号 + 这一波每只僵尸的编号一起发下去
##
## 编号必须主机指定：客户端自己开这一波时也会自增分配一批编号，而两端的分配器早就因
## "谁先多生一颗阳光 / 先死一只僵尸"错开了 —— 编号对不上，状态广播就认不出同一只僵尸。
func _on_wave_started(wave: int) -> void:
	if _session == null or not _session.is_host():
		return
	_session.request_battle_op(NetplayCommand.build(NetplayCommand.OP_WAVE_NEXT, {
		NetplayCommand.ARG_WAVE: wave,
		NetplayCommand.ARG_ZOMBIE_IDS: _collect_wave_zombie_ids(),
	}))


## 主机这一波刚生成的僵尸的编号（顺序即生成顺序）
func _collect_wave_zombie_ids() -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	var wave_manager: ZombieWaveManager = _wave_manager()
	if wave_manager == null or wave_manager.zombie_wave_create_manager == null:
		return ids
	for z in wave_manager.zombie_wave_create_manager.wave_all_zombies:
		if is_instance_valid(z) and z.entity_id != 0:
			ids.append(z.entity_id)
	return ids


## 客户端收到主机开的那一波 ⇒ 自己照着开同一波
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
	## 中途进屋 / 丢过包的人会落后：先把波次号对齐到主机，再开这一波
	## （补不回中间那几波的僵尸，但至少后面每一波都是同一波）
	if wave_manager.curr_wave + 1 != wave:
		_notify("波次落后，已按主机对齐（本机第 %d 波 → 主机第 %d 波）" % [wave_manager.curr_wave + 1, wave])
		wave_manager.curr_wave = wave - 1
	_applying_host_wave = true
	wave_manager.start_next_wave()
	_applying_host_wave = false
	## 开完这一波，把主机给的编号贴到本地刚生成的那批僵尸上（顺序就是生成顺序）
	_assign_wave_zombie_ids(wave_manager, args.get(NetplayCommand.ARG_ZOMBIE_IDS, PackedInt32Array()))


## 按主机下发的顺序给本波僵尸编号 —— 之后状态广播才能认出"同一只"
func _assign_wave_zombie_ids(wave_manager: ZombieWaveManager, ids: PackedInt32Array) -> void:
	if wave_manager == null or wave_manager.zombie_wave_create_manager == null:
		return
	## ⚠️ 全局 `min()` 返回的是 Variant，`var x := min(...)` 会被"警告当错误"打回
	##   （仓库把这条警告当错误），所以这里不图省事，类型自己写清楚、也不用 `min()`
	var created: Array[Zombie000Base] = wave_manager.zombie_wave_create_manager.wave_all_zombies
	var count: int = created.size()
	if ids.size() < count:
		count = ids.size()
	for i in range(count):
		if is_instance_valid(created[i]):
			created[i].assign_entity_id(int(ids[i]))


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
