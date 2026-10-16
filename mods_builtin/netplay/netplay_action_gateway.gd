extends Node
## 联机的**玩家操作网关**：本体那一个统一上报口（`GlobalUtils.player_action_gate`）在这里被占住
##
## ★ 这是模组**唯一**把玩家操作发出去的地方。之前上行分散在四处
##   （`EventBus` 拦截器采点卡 / 点铲子、`HandManager.cell_click_gate` 采点格子、
##   `GlobalUtils.sun_click_gate` 采捡阳光、`GlobalUtils.drop_click_gate` 采捡掉落物），
##   每加一种操作就要新开一个本体闸门、还得记得来装它 —— 漏装的那一个正是
##   "闸门装了没人读"的同款坑（装上 ≠ 生效）。现在本体只认 `player_action_gate` 一个口，
##   模组只在这里翻译一次，**新增一种操作只多一个枚举值 + 这里一支 `match`**。
##
## 它不自己发命令 —— 翻译完交给 `NetplayBattleSync.handle_local_command()`：
##   · 客户端：上行一次**请求**，本地不动，等主机把"事实"下行回来再重放
##   · 主机：先在自己这一局上跑一遍，**跑成了**才下行给全屋
## 这样"跑不动的那一笔"两端都不会记（冷却 / 阳光不够 / 下标对不上），不会记歪账。
##
## ★ 为什么有的操作这里**不接管**（返回 false 让本体照单机跑）：
##   · 没连线 —— 单机必须完全照旧
##   · **拿起植物**（点卡）—— 纯本地：卡是自己卡槽里那一张，主机那一局上没有它；
##     摘不摘得动由本体自己判，种不种得下去才归主机（点格子那一步带上卡的身份上行）
##   · 主机自己捡阳光 / 掉落物 —— 主机就是事实来源，它自己的拾取不用绕一圈
##   · 客户端捡的那一个**不是主机下发过的**（没有主机编号）—— 主机那一局上没有它，
##     接管只会得到"点不动"，放它回本机的老路：宁可不同步，也不能让玩家点着没反应
##
## 关联：[联机模组](../../docs/参考存档/联机模组.md) ｜
## [联机模组规范](../../docs/参考存档/联机模组规范.md) §3.5 ｜
## [NetplayBattleSync](netplay_battle_sync.gd)

## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**（实测 Godot 4.6.2），
## 所以同目录 / 上级的文件一律 preload 成常量再引用，不能写 `extends Xxx` / `var x: Xxx`
const NetplayCommand := preload("netplay_command.gd")
const NetplaySunSync := preload("netplay_sun_sync.gd")
const NetplayDropSync := preload("netplay_drop_sync.gd")

const SELF_NODE_NAME := "NetplayActionGateway"

var _session = null
var _main_game: MainGameManager = null
## 一句话写进日志（回调由 `NetplayMod` 传进来；没接上就什么都不做）
var _notice: Callable = Callable()


## 挂上来之后要先接线：[param notice] `func(text: String) -> void`
func setup(session, main_game: MainGameManager, notice: Callable = Callable()) -> void:
	_session = session
	_main_game = main_game
	_notice = notice
	if _session == null or not _session.is_linked():
		return
	## ★ 占住本体那一个统一口：之后玩家在本局里的**每一个**操作都会先经过 `handle_action()`
	GlobalUtils.player_action_gate = handle_action


func _exit_tree() -> void:
	## 换关时旧节点会先灭：闸门要还回去，别把下一局的操作也拦住
	if GlobalUtils.player_action_gate == handle_action:
		GlobalUtils.player_action_gate = Callable()


#region 唯一入口：本体的一次玩家操作
## 本体报上来的一次玩家操作
##
## [return] true = 已接管（本体**不要**再走本地那一条路）；false = 照旧本地执行
func handle_action(action: int, payload: Array) -> bool:
	if _session == null or not _session.is_linked():
		return false
	## 捡东西这一类要先问"主机那一局上有没有它"，不接管时直接放回去（见文件头）
	if not _may_take(action, payload):
		return false
	var op := NetplayCommand.op_from_action(action)
	if op == &"":
		return false
	var args := NetplayCommand.args_from_action(action, payload)
	## 拿不出参数的（payload 里没有那个对象 / 对象没编号）不接管 ——
	## 与其上行一条主机必然跑不动的请求，不如让本体照单机那样本地跑掉
	if action != GlobalUtils.E_PlayerAction.ClickShovel and args.is_empty():
		return false
	return _send(op, args)


## 这一类操作现在该不该被接管（不接管的几种情况见文件头）
func _may_take(action: int, payload: Array) -> bool:
	match action:
		## ★ **拿起植物一律本地**：卡是自己卡槽里那一张，能不能拿（阳光 / 冷却 / 紫卡前置）
		##   本体在点下去那一刻就判过了，主机那一局里也**没有这一张卡**（两端各挑各的），
		##   上行一趟只换来半个 RTT 的空手等待 —— 而"拿起来"本身不改变场上任何东西。
		##   真正的战斗校验在**种下**那一步（点格子）由主机做，见 `NetplayBattleSync`。
		GlobalUtils.E_PlayerAction.ClickCard:
			return false
		GlobalUtils.E_PlayerAction.PickSun:
			return _session.is_client() and _is_host_spawned(payload, NetplaySunSync.SELF_NODE_NAME)
		GlobalUtils.E_PlayerAction.PickDrop:
			return _session.is_client() and _is_host_spawned(payload, NetplayDropSync.SELF_NODE_NAME)
	return true


## 这一个实体是不是**主机下发过的**（客户端只接管这些）
##
## 客户端自己长的那一个没有主机编号，主机那一局上根本不存在它 ——
## 接管只会得到"点不动"。照旧本地捡：不同步，但玩家点得动。
func _is_host_spawned(payload: Array, sync_node_name: String) -> bool:
	if payload.size() == 0:
		return false
	var target = payload[0]
	if target == null or not is_instance_valid(target):
		return false
	var sync_node := _sync_node(sync_node_name)
	if sync_node == null:
		return false
	return sync_node.is_host_spawned(target)


## ★ **唯一的发送出口**：交给战斗同步去定夺（客户端上行请求 / 主机跑成后下行）
func _send(op: StringName, args: Dictionary) -> bool:
	var battle_sync = _session.get_battle_sync()
	if battle_sync == null or not is_instance_valid(battle_sync):
		return false
	return battle_sync.handle_local_command(NetplayCommand.build(op, args))
#endregion


#region 小工具
## 本局的某一个同步节点（按固定名字找，与其它 sync 同一套）
func _sync_node(node_name: String) -> Node:
	var mg := _resolve_main_game()
	if mg == null:
		return null
	return mg.get_node_or_null(node_name)


## 本节点记录的这一局还活着就用它，否则退回去问 `GameContext.curr_main_game`
## （换关时旧节点会先灭再换新，用"活着的那一份"才不会对着空气操作）
func _resolve_main_game() -> MainGameManager:
	if _main_game != null and is_instance_valid(_main_game):
		return _main_game
	var mg: MainGameManager = GameContext.curr_main_game
	return mg if is_instance_valid(mg) else null


func _notify(text: String) -> void:
	if _notice.is_valid():
		_notice.call(text)
#endregion
