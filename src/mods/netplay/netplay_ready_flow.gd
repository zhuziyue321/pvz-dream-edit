extends Node
class_name NetplayReadyFlow
## 联机的「开始摇滚吧」：**客户端那一颗变成「准备」**，所有人都准备好之后房主才按得动「开始」
##
## 为什么单开一个文件：`NetplayCardSync` 管的是**挑哪几张卡**（去重 / 撞车让路），
## 这里管的是**什么时候收工**（准备 = "我不再改了"）—— 挑哪张与何时收工不是一个问题；
## 而且这里是唯一一处**动选卡界面的样子**（把贴图的英文 LET'S ROCK! 换成中文标签），
## 跟"只算数据、不碰界面"的同步也不该混在一处。
##
## 为什么不直接用原版那颗按钮：它的文字**烘焙在贴图里**（`SeedChooser_Button_Glow.png`），
## 改不了文案 —— 只能把原按钮藏起来，再照它的位置尺寸补一颗长得差不多的。

const SELF_NODE_NAME := "NetplayReadyFlow"
## 换上去的那一颗跟本体「开始战斗！」那一颗同一份主题（中文字体 + 按钮底纹都在里面）
const READY_BUTTON_THEME := preload("res://data/ui/themes/pvz_theme.tres")
const READY_BUTTON_THEME_VARIATION := &"PanelButtonBG"
## 补出来的那一颗的名字（方便排障时在场景树里找）
const READY_BUTTON_NAME := "NetplayReadyButton"
## 选卡界面里原版那颗「LET'S ROCK!」（`card_slot_norm.tscn` 里的节点名）
const NATIVE_START_BUTTON := "TextureButton"

var _session: NetplaySession = null
var _main_game: MainGameManager = null
## 换上去的那一颗（中文标签）
var _button: BaseButton = null
var _label: Label = null
## 被藏起来的原版按钮（退场要还原，免得下一局缺了一块）
var _native_button: TextureButton = null
## 房主喊了「开始」⇒ 客户端这一下才准真的推进
var _start_allowed := false
var _was_in_choose := false
## 房主**按过**开始、但那一刻还有人没准备 ⇒ 等他们准备好补按一次（见 `start_gate()`）
var _pending_start := false
## 一条话写到控制台「最近一条」上（由 `NetplayMod` 传进来）
var _notice: Callable = Callable()


## 挂上来之后要先接线：[param notice] `func(text: String) -> void`
func setup(session: NetplaySession, main_game: MainGameManager, notice: Callable = Callable()) -> void:
	_session = session
	_main_game = main_game
	_notice = notice
	if _session != null:
		if not _session.ready_state_changed.is_connected(_on_ready_state_changed):
			_session.ready_state_changed.connect(_on_ready_state_changed)
		if not _session.choose_card_start_requested.is_connected(_on_choose_card_start_requested):
			_session.choose_card_start_requested.connect(_on_choose_card_start_requested)
		_session.clear_ready()
	## 多轮关卡第二轮选卡时整棵树是暂停的（见 `start_pause_on_re_choose_card_progress()`），
	## 这一颗按钮照样要刷得出「准备」—— 不然第二轮它又变回英文贴图了
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	_remove_button()


func _process(_delta: float) -> void:
	if _session == null or _main_game == null:
		return
	if not _session.is_linked() or not _in_choose_phase():
		_leave_choose_phase()
		return
	_was_in_choose = true
	if _button == null and not _build_button():
		return
	_refresh()
	_maybe_retry_start()


#region 闸门：房主的「开始」要等所有人都准备好
## 挂在 `MainGameManager.choose_card_start_gate` 上的闸门（由 `NetplayMod` 装上）：
## 返回 true 才准收工
##
## · 房主：屋里**其他人都点了准备**才放行，顺手把「开始」发下去让客户端跟着走
## · 客户端：这一下永远不放行 —— 「开始摇滚吧」在客户端这里的意思就是**报准备**
func start_gate() -> bool:
	if _session == null or not _session.is_linked():
		return true
	if _session.is_host():
		var others := _session.other_peer_ids()
		if all_ready(_session.ready_peers, others):
			_session.request_choose_card_start()
			return true
		## ★ 记下"这一下按过开始"，等大家都准备好由 `_maybe_retry_start()` 补按。
		## 为什么非补不可：传送带 / 卡槽被锁死这类关**没有选卡界面**，进关就自动跳过
		## （见 `MainGameManager.enter_choose_card_progress()`），而主机跳过的那一刻
		## 客户端往往**还没被拉进关**，屋里自然没人准备好 ⇒ 闸门返回 false，主机停在选卡阶段。
		## 客户端随后报的准备再也等不到第二次"开始" —— **整局永远开不了战**。
		## （这是双进程实测抓到的：两端都停在 CHOOSE_CARD，场上一个僵尸都没有。）
		_pending_start = true
		_notify("还有人没准备（%s）—— 等大家都点了准备才能开始" % ready_count_text(_session.ready_peers, others))
		return false
	## 房主喊了开始：这一下是房主替本机按的
	if _start_allowed:
		_start_allowed = false
		return true
	_session.declare_ready(true)
	_notify("客户端这一颗是「准备」，等房主统一开始")
	return false


## 名单里的人是不是都准备好了（名单为空 = 没别人，没什么好等的）
static func all_ready(ready_map: Dictionary, peer_ids: Array) -> bool:
	for peer_id in peer_ids:
		if not bool(ready_map.get(peer_id, false)):
			return false
	return true


## 「开始」被闸门挡过一次之后再补按一次 —— 只在"确实按过 + 现在都准备好了"时才补
##
## ⚠️ 必须限定 `_in_choose_phase()`：已经开战之后再补按会把 `CARD_SLOT_NORM_START_GAME`
## 又推一遍（多轮关卡第二轮会因此被提前收工）。
func _maybe_retry_start() -> void:
	if not _pending_start or _session == null or not _session.is_host():
		return
	if not _in_choose_phase():
		_pending_start = false
		return
	if not all_ready(_session.ready_peers, _session.other_peer_ids()):
		return
	_pending_start = false
	_notify("大家都准备好了，补按开始")
	_press_start()


## 「1/2」这样的准备进度
static func ready_count_text(ready_map: Dictionary, peer_ids: Array) -> String:
	var ready_num := 0
	for peer_id in peer_ids:
		if bool(ready_map.get(peer_id, false)):
			ready_num += 1
	return "%d/%d" % [ready_num, peer_ids.size()]


## 这一颗按钮现在该写什么（抽成 static 是为了让探针不进 UI 也能验文案规则）
static func button_text_of(local_is_host: bool, myself_ready: bool, others_all_ready: bool, count_text: String) -> String:
	if local_is_host:
		if others_all_ready:
			return "开始"
		return "等准备 %s" % count_text
	if myself_ready:
		return "已准备（等房主开始）"
	return "准备"
#endregion


#region 界面：把英文贴图换成中文标签
## 照着原版按钮的位置尺寸补一颗（原版那颗只是**藏起来**，数据一概不动）
func _build_button() -> bool:
	var candidate := _candidate()
	if candidate == null:
		return false
	var native_button := candidate.get_node_or_null(NATIVE_START_BUTTON) as TextureButton
	if native_button == null or not is_instance_valid(native_button):
		return false
	_native_button = native_button
	native_button.visible = false

	var button := BaseButton.new()
	button.name = READY_BUTTON_NAME
	button.theme = READY_BUTTON_THEME
	button.custom_minimum_size = native_button.size
	button.position = native_button.position
	button.size = native_button.size
	candidate.add_child(button)
	## 底纹：与原生「开始战斗！」那颗同一个主题变体
	button.add_child(_new_filled(Panel.new(), READY_BUTTON_THEME_VARIATION))
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(_label)
	button.pressed.connect(_on_button_pressed)
	_button = button
	return true


## 铺满整颗按钮，且不抢走父节点的点击
func _new_filled(control: Control, theme_variation: StringName = &"") -> Control:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if theme_variation != &"":
		control.theme_type_variation = theme_variation
	return control


func _remove_button() -> void:
	if _button != null:
		if is_instance_valid(_button):
			_button.queue_free()
		_button = null
	_label = null
	if _native_button != null and is_instance_valid(_native_button):
		_native_button.visible = true
	_native_button = null


func _refresh() -> void:
	if _session == null or _label == null:
		return
	var others := _session.other_peer_ids()
	var local_is_host := _session.is_host()
	var others_all_ready := all_ready(_session.ready_peers, others)
	var count_text := ready_count_text(_session.ready_peers, others)
	_label.text = button_text_of(local_is_host, is_local_ready(), others_all_ready, count_text)
	if _button != null:
		## 房主没等到人就点不动（变灰）；客户端随时可以按 —— 按下就是切换自己的准备状态
		_button.disabled = local_is_host and not others_all_ready
#endregion


#region 两头的按键
func _on_button_pressed() -> void:
	if _session == null or not _session.is_linked():
		return
	if _session.is_host():
		## 房主这一颗就是「开始」：走玩家点原版按钮那条一模一样的路
		## （存好本次选卡 + 通知本体），能不能真的开始交给 `_start_gate()` 判
		_press_start()
		return
	## 客户端：切换自己的准备状态
	var next_ready := not is_local_ready()
	_session.declare_ready(next_ready)
	_notify("已准备，等房主开始" if next_ready else "取消了准备")
	_refresh()


## 房主喊了「开始」：客户端这一下跟着走 —— 同样按"自己也按了按钮"那两步来
func _on_choose_card_start_requested() -> void:
	if _session == null or _session.is_host():
		return
	_start_allowed = true
	_notify("房主点了开始，收工")
	_press_start()


func _on_ready_state_changed(peer_id: int, ready: bool) -> void:
	if _session == null or peer_id == _session.local_peer_id:
		return
	_refresh()
	_maybe_retry_start()
	_notify("玩家 %d %s" % [peer_id, "已准备" if ready else "取消了准备"])


## 照原版按钮那两步：保存本次选卡（"重选上次卡片"要用）+ 通知本体收工
func _press_start() -> void:
	var norm := _card_slot_norm()
	if norm != null:
		norm.save_choosed_cards()
	EventBus.push_event(ConstEventName.CARD_SLOT_NORM_START_GAME)
#endregion


#region 小工具
func is_local_ready() -> bool:
	if _session == null:
		return false
	return bool(_session.ready_peers.get(_session.local_peer_id, false))


## 离开选卡阶段：把补出来的那一颗拆掉，还给界面原来的样子
func _leave_choose_phase() -> void:
	if _was_in_choose:
		_was_in_choose = false
		_remove_button()
	## 已经离开选卡阶段：那一下"补按开始"不必再等了（多半是已经开战了）
	_pending_start = false
	## 没走上选卡界面的那一局（传送带 / 没有选卡权）：没有「准备」可以按，
	## 那就替本机直接报个准备 —— 免得房主永远在等一个不可能按下准备的人
	if _session != null and _session.is_linked() and _session.is_client() and not is_local_ready():
		_session.declare_ready(true)


func _in_choose_phase() -> bool:
	if _main_game == null or not is_instance_valid(_main_game):
		return false
	var progress := _main_game.main_game_progress
	return progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD \
		or progress == MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD


## 待选区（原版那颗「LET'S ROCK!」就挂在它下面）
func _candidate() -> CardSlotCandidate:
	var norm := _card_slot_norm()
	if norm == null:
		return null
	var candidate: CardSlotCandidate = norm.card_slot_candidate
	return candidate if is_instance_valid(candidate) else null


func _card_slot_norm() -> CardSlotNorm:
	if _main_game == null or not is_instance_valid(_main_game) or _main_game.card_manager == null:
		return null
	var norm: CardSlotNorm = _main_game.card_manager.card_slot_norm
	return norm if is_instance_valid(norm) else null


func _notify(text: String) -> void:
	if _notice.is_valid():
		_notice.call(text)
#endregion
