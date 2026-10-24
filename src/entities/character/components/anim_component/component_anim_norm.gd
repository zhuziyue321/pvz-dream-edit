extends AnimComponentBase
class_name AnimComponentNorm
## 普通动画组件,使用AnimationTree的角色使用
##
## ★ **本组件要求角色的 AnimationTree 长成这样**（全仓角色已统一；驱动源与迁移做法见
##   [动画封装](../../../../../docs/参考存档/动画封装.md)）：
##
##   树根 AnimationNodeBlendTree
##     ├─ TimeScale     : AnimationNodeTimeScale     ← 速度钩子 parameters/TimeScale/scale
##     └─ StateMachine  : AnimationNodeStateMachine  ← playback 钩子 parameters/StateMachine/playback
##   node_connections : output ← TimeScale ← StateMachine
##
## ★ **为什么树根必须是混合树、且 TimeScale 必须在状态机之上**：
##   `TimeScale` 挂在根上，`parameters/TimeScale/scale` 才是**所有角色都一样**的一条路径
##   （`owner_update_speed()` 写它，`stinky.gd` / `garden_flower_pot.gd` 这类自己驱动树的也认它）；
##   而且时间缩放必须**压在状态机上游** —— 缩放写在状态机之上时，
##   `get_current_play_position()` 读到的就是已经被缩放过的那条时间轴，动画同步才对得上
##   （把 TimeScale 塞进状态机里的话，读出来的位置会是未经缩放的原速，客户端越播越偏）。
##
## ⚠️ 这两句之所以能写成常量，是因为结构统一了。统一之前这里是一套"按名猜"的探测：
##    一张候选状态机名字表 + 一张候选动画叶子名字表，猜不中就是"这一类角色静默退出动画同步"
##    （不报错、不刷日志，各播各的），谁改了某棵树里的节点名同步也会悄悄失效。
##    现在**猜的那条分支整个删掉了**，取不到就直接报一次 WARN（见 `_warn_missing_playback()`）。

@onready var animation_tree: AnimationTree = Character000Base.host_node_of(owner, ^"AnimationTree") as AnimationTree

## 状态机 playback 的参数路径（结构统一后所有角色都一样，见类注释）
const PLAYBACK_PARAM := "parameters/StateMachine/playback"
## 时间缩放的参数路径（同样所有角色都一样）
const TIMESCALE_PARAM := "parameters/TimeScale/scale"

## 「缺 playback」的 WARN 每次运行只报一次：怕的是有人把树改坏，而不是想刷屏
static var _warned_missing_playback := false

## 播放器缓存（`AnimationTree.anim_player` 是 NodePath，每次取都要解析一遍）
var _anim_player_cache: AnimationPlayer = null
## 被远端接管之前树是否在跑（`release()` 原样还回去）
var _tree_active_before_take_over := true

func component_ready() -> void:
	if not is_instance_valid(animation_tree):
		_warn_missing_playback()
		return
	animation_origin_speed = animation_tree.get(TIMESCALE_PARAM)
	animation_tree.animation_finished.connect(_on_animation_finished)


## 刷新当前动画：从状态机的 playback **逐层下钻**到真正在播的那一条
##
## ★ 为什么必须下钻：顶层状态机给的是**状态名**（普僵是 `Walk` / `Idle` / `Death` / `eat`），
##   前三个是**子状态机**、`eat` 是**子混合树**，都不是动画名；真正在播的 `Zombie_walk`
##   要再钻一层才拿得到 —— 状态名与动画名只在**叶子**那一层才重合。
##
## ★ 远端驱动下不走下钻：树已被冻结，此时只有 `AnimationPlayer.current_animation` 是准的
##   （见 `_read_from_player()`）。
func update_current_anim() -> void:
	if _anim_probe_frame == Engine.get_frames_drawn():
		return
	_anim_probe_frame = Engine.get_frames_drawn()
	anim_name_now = &""
	anim_position_now = -1.0
	if driver == E_Driver.REMOTE:
		_read_from_player()
		return
	_drill_playback(PLAYBACK_PARAM)


## 远端驱动下读播放器：`apply_anim_index()` 播的就是这一条，播放头也是它自己的
func _read_from_player() -> void:
	var player := get_animation_player()
	if player == null or player.current_animation == &"":
		return
	anim_name_now = player.current_animation
	anim_position_now = player.current_animation_position


## 从 `path` 这一层状态机往下钻，把**最深那层**的结果写进 `anim_name_now` / `anim_position_now`
func _drill_playback(path: String) -> void:
	## ⚠️ 不能用 `var pb :=`：`get()` 返回的是 Variant，写死类型会让整份脚本解析失败
	var pb = animation_tree.get(path)
	if pb == null:
		_warn_missing_playback()
		return
	if not pb.has_method("get_current_node"):
		return
	var node := String(pb.get_current_node())
	if node.is_empty():
		return
	## 还能再往下一层（子节点也是状态机）就继续钻，别停在中间层
	var deeper := "%s/%s/playback" % [path.get_base_dir(), node]
	var child = animation_tree.get(deeper)
	if child != null and child.has_method("get_current_node"):
		_drill_playback(deeper)
		return
	## 到叶子了：名字必须是真有的动画才用
	## （挡掉 `eat` 这类"叶子其实是个混合树"的情况 —— 那里面没有 playback，钻不动）
	if animation_tree.has_animation(StringName(node)):
		anim_name_now = StringName(node)
		if pb.has_method("get_current_play_position"):
			anim_position_now = float(pb.get_current_play_position())


#region 本地驱动（植物 / 僵尸自己的代码）
##
## ★ **这是"单人由角色代码控制动画"的正式入口**：状态机不再只能靠
##   `advance_expression` 每帧读字段自己推导，角色脚本可以直接点名切状态。
##
## ⚠️ 用之前必须先确认**目标状态那条转换的 `advance_expression` 已经清空**：
##   状态机的自动推进优先级高于手动 `travel()` —— 表达式还是 true 的话，
##   下一帧就把状态切回去，表现为"调了 request_state 没反应"。
##   迁移做法：把 `<State>/<State> 的 transition.advance_expression` 置空，
##   由角色脚本在**所有**该切换的地方调本方法。
func request_state(state: StringName) -> void:
	if driver == E_Driver.REMOTE:
		return
	if not is_instance_valid(animation_tree):
		return
	var sm := _state_machine_root()
	if sm == null:
		_warn_missing_playback()
		return
	if not sm.has_node(state):
		## 状态名写错只可能是改场景时改漏了：喊一声，别静默（静默就是"动画不动"）
		Log.warn("[AnimComponentNorm] 状态机里没有状态 %s（宿主 %s）"
				% [state, String(owner.name) if owner != null else "?"])
		return
	var pb = animation_tree.get(PLAYBACK_PARAM)
	if pb == null or not pb.has_method("travel"):
		_warn_missing_playback()
		return
	## ⚠️ 已经在目标状态就别再 travel：重复 travel 会把该状态**从头重播**，
	##    而调用方常常是"每帧都会触发的检测信号"，不挡就是动画一直在第一帧抖
	if pb.has_method("get_current_node") and String(pb.get_current_node()) == String(state):
		return
	pb.travel(state)


## 按后缀找状态名（睡眠 / 花园水族这类"状态名带植物前缀"的通用切换用，见基类注释）
func find_state_by_suffix(suffix: StringName) -> StringName:
	var sm := _state_machine_root()
	if sm == null:
		return &""
	var text := String(suffix)
	for state_name in sm.get_node_list():
		if String(state_name).ends_with(text):
			return state_name
	return &""


## 顶层状态机节点：**树根是混合树**（本仓统一结构），状态机是它下面名为
## `StateMachine` 的那个节点（路径与 `PLAYBACK_PARAM` 的第二段一致）
##
## ⚠️ 不能只看 `animation_tree.tree_root is AnimationNodeStateMachine` ——
##    按约定树根永远是 `AnimationNodeBlendTree`，那样写判断恒为 false，
##    `request_state()` 会**静默什么都不做**（地刺不攻击就是这么来的）。
func _state_machine_root() -> AnimationNodeStateMachine:
	var root := animation_tree.tree_root
	if root is AnimationNodeStateMachine:
		return root
	if not (root is AnimationNodeBlendTree):
		return null
	var state_machine_name := StringName(PLAYBACK_PARAM.get_slice("/", 1))
	var node := (root as AnimationNodeBlendTree).get_node(state_machine_name)
	return node as AnimationNodeStateMachine


## 本地驱动 · 显式播一次（OneShot）—— 攻击组件、磁力菇这类一次性动作走这里
func request_one_shot(param: StringName = &"parameters/OneShot/request") -> void:
	if driver == E_Driver.REMOTE:
		return
	if not is_instance_valid(animation_tree):
		return
	animation_tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## 本地驱动 · 撤掉正在播的一次性动画（淡出）
func cancel_one_shot(param: StringName = &"parameters/OneShot/request") -> void:
	if driver == E_Driver.REMOTE:
		return
	if not is_instance_valid(animation_tree):
		return
	animation_tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
#endregion


#region 远端驱动（包分发）
##
## ★ 客户端接管动画必须**关掉树**：状态机每帧按 `is_death` / `is_attack` 等字段
##   **自己挑**动画，我们 `play()` 的那一条下一帧就被换回去 —— "发了等于没发"。
func _on_take_over() -> void:
	if not is_instance_valid(animation_tree):
		return
	_tree_active_before_take_over = animation_tree.active
	animation_tree.active = false


## 交还本地驱动：树重新跑起来，状态机会按当前字段自动选片，速度还原成原始值
func _on_release() -> void:
	if not is_instance_valid(animation_tree):
		return
	animation_tree.active = _tree_active_before_take_over
	animation_tree.set(TIMESCALE_PARAM, animation_origin_speed)
#endregion


## 本组件的播放器访问器：`AnimationTree.anim_player` 是 **NodePath**，不是节点本身
func get_animation_player() -> AnimationPlayer:
	if is_instance_valid(_anim_player_cache):
		return _anim_player_cache
	if not is_instance_valid(animation_tree):
		return null
	_anim_player_cache = animation_tree.get_node_or_null(animation_tree.anim_player) as AnimationPlayer
	return _anim_player_cache


## 树的结构约定被破坏了就喊一声 —— 这正是统一之前"静默失效"的那批角色会掉进来的地方
##
## ⚠️ 只有 `parameters/StateMachine/playback` **整个取不到**才报；
##    像普僵那样"卡在 Start、等宿主算完 `is_idle` 再跳"的（`get_current_node()` 返回 `"Start"`）
##    是正常工作现象，不报。
func _warn_missing_playback() -> void:
	if _warned_missing_playback:
		return
	_warned_missing_playback = true
	## ⚠️ `Log.warn()` 最多收 5 个参数（`msg` + `arg1..arg4`，见 `logger.gd`），
	## 传多了是**编译错误** ⇒ 整个脚本失效 ⇒ 挂它的 `AnimComponent` 节点退回 `Node2D`
	## ⇒ `%AnimComponent` 赋不进 `AnimComponentBase` ⇒ **所有角色的 anim_component 变成 null**。
	## 后果是整条动画同步静默空转，所以这里务必合成**一条**消息再发。
	var host := String(owner.name) if owner != null else "?"
	Log.warn("[AnimComponentNorm] 取不到 %s（宿主 %s）：该角色的 AnimationTree 已不符合"
			% [PLAYBACK_PARAM, host]
			+ "「树根混合树 + TimeScale + StateMachine」的约定，会静默退出动画同步，"
			+ "请按本文件顶部注释把树补齐。")


## 更新动画速度
##
## ⚠️ 远端驱动下不改树的缩放：树已经停了，写它等于什么都没做；
##    客户端的速度差由 `apply_anim_phase()` 的硬拉抹平（见基类）。
func owner_update_speed(speed_factor_product:float):
	if driver == E_Driver.REMOTE:
		return
	if not is_instance_valid(animation_tree):
		return
	animation_tree.set(TIMESCALE_PARAM, animation_origin_speed * speed_factor_product)


## 更新动画速度(动画播放速度)
func update_anim_speed_scale(speed_scale:float):
	if driver == E_Driver.REMOTE:
		return
	if not is_instance_valid(animation_tree):
		return
	animation_tree.set(TIMESCALE_PARAM, speed_scale)


## 停止动画
func stop_anim():
	if not is_instance_valid(animation_tree):
		return
	animation_tree.active = false
