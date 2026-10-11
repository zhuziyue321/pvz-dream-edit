extends AnimComponentBase
class_name AnimComponentNorm
## 普通动画组件,使用AnimationTree的角色使用
##
## ★ **本组件要求角色的 AnimationTree 长成这样**（全仓角色已统一，改造过程见
##   [2026-10-11 工作记录](../../../../../docs/工作记录/2026-10-11_统一动画树结构与playback取值.md)）：
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

@onready var animation_tree: AnimationTree = $"../AnimationTree"

## 状态机 playback 的参数路径（结构统一后所有角色都一样，见类注释）
const PLAYBACK_PARAM := "parameters/StateMachine/playback"
## 时间缩放的参数路径（同样所有角色都一样）
const TIMESCALE_PARAM := "parameters/TimeScale/scale"

## 「缺 playback」的 WARN 每次运行只报一次：怕的是有人把树改坏，而不是想刷屏
static var _warned_missing_playback := false

func component_ready() -> void:
	animation_origin_speed = animation_tree.get(TIMESCALE_PARAM)
	animation_tree.animation_finished.connect(_on_animation_finished)


## 刷新当前动画：从状态机的 playback **逐层下钻**到真正在播的那一条
##
## ★ 为什么必须下钻：顶层状态机给的是**状态名**（普僵是 `Walk` / `Idle` / `Death` / `eat`），
##   前三个是**子状态机**、`eat` 是**子混合树**，都不是动画名；真正在播的 `Zombie_walk`
##   要再钻一层才拿得到 —— 状态名与动画名只在**叶子**那一层才重合。
func update_current_anim() -> void:
	if _anim_probe_frame == Engine.get_frames_drawn():
		return
	_anim_probe_frame = Engine.get_frames_drawn()
	anim_name_now = &""
	anim_position_now = -1.0
	_drill_playback(PLAYBACK_PARAM)


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
func owner_update_speed(speed_factor_product:float):
	animation_tree.set(TIMESCALE_PARAM, animation_origin_speed * speed_factor_product)

## 更新动画速度(动画播放速度)
func update_anim_speed_scale(speed_scale:float):
	animation_tree.set(TIMESCALE_PARAM, speed_scale)

## 停止动画
func stop_anim():
	animation_tree.active = false
