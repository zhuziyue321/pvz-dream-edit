@abstract
extends ComponentNormBase
class_name AnimComponentBase
## 动画组件基类
## 由于部分僵尸可能没有AnimationTree或者AnimationPlayer
## 使用该组件统一进行一些动画速度的控制
## 子类实现具体方法
##
## 已接入组件体系（`ComponentNormBase`），子类初始化写在 `component_ready()` 里。
##
## 本类的 `owner_update_speed()` 与组件基类同名 —— 那不是「漏了 extends」的痕迹，
## 而是组件体系本来就约定了这个速度钩子，接入后正好对上。
##
## 关于禁用机制：动画是攻击帧的驱动者（`_shoot_bullet()` 由动画轨调用），一旦被禁用
## 就表现为「全体不攻击」且不报错。但全仓无任何代码对 `anim_component` 调
## `disable_component()`，所以继承来的 `is_enabling` 恒为 true。
## （曾经接入后出现过该回归，但元凶是攻击组件改名漏了 `super()`，与本类无关 ——
##   回退本类后症状并未消失。见 2026-10-07 的工作记录。）

## 动画结束信号
signal signal_animation_finished(anim_name:StringName)

## **动画事件**（动画方法轨 → 逻辑的通道）
##
## 动画 `.tres` 的方法轨只调 `on_anim_event("shoot")` 这一个方法，由本组件转发成信号；
## 攻击组件 / 受击窗口 / 奖杯这类玩法逻辑改成订阅这里，动画资源里不再出现玩法方法名。
## 事件名是逻辑侧自己认的词，动画资源只负责"第几帧发生了这件事"。
signal anim_event(event:StringName)

## 角色动画原始速度
var animation_origin_speed :float = -1


#region 当前动画上报（★ 通用只读能力：谁都能问，不参与任何判定）
##
## ★ **为什么要有这一段**：动画树（AnimationTree）驱动角色时，`AnimationPlayer.current_animation`
##   **是空的** —— 树走的是自己的 playback，从不调 `play()`，所以从外面读播放器根本问不出
##   "此刻在播哪一条、播到第几秒"。只有动画组件自己知道，于是由它来报。
##
## ★ 与 `entity_id` / `BodyCharacter.body_light_count` 同款：本体提供的**通用能力**，
##   不含联机字样、不改任何状态、不参与判定，谁需要谁读。
##
## 用法：先 `update_current_anim()` 刷新，再读 `anim_name_now` / `anim_position_now`。
## 拿不到时名字为 `&""`、位置为 `-1.0` ⇒ 读的一方按"这一帧没有动画"处理。
##
## 关联：[联机模组](../../../../../docs/参考存档/联机模组.md) §4.9（动画同步）
var _anim_probe_frame := -1
## 当前正在播的动画名（没有在播的是 `&""`）
var anim_name_now := &""
## 当前动画播到第几秒（没有在播的是 `-1.0`）
var anim_position_now := -1.0

## 刷新 `anim_name_now` / `anim_position_now`
##
## ⚠️ 同一帧内重复调用是廉价的（内部按帧缓存）：一个角色一帧可能被问好几次。
func update_current_anim() -> void:
	if _anim_probe_frame == Engine.get_frames_drawn():
		return
	_anim_probe_frame = Engine.get_frames_drawn()
	anim_name_now = &""
	anim_position_now = -1.0
#endregion


#region 驱动源（★ 单人 = 本地代码控制；客户端 = 包分发控制）
##
## ★★ **为什么要有"驱动源"这一层**：同一株植物 / 同一只僵尸有两种完全不同的
##   "该播哪条动画"的来源 ——
##
##   | 场景 | 谁说了算 | 走哪个 API |
##   |---|---|---|
##   | 单人 / 主机 | 角色自己的逻辑（植物脚本改状态字段、攻击组件发 OneShot） | `request_state()` / `request_one_shot()` |
##   | 联机客户端 | 主机下发的包（"播哪条 + 播到第几秒"） | `take_over()` + `apply_anim_index()` / `apply_anim_phase()` |
##
## ★ **为什么要收进组件**：客户端那条路曾经写在联机模组里 —— 模组自己递归找
##   `AnimationPlayer`、自己 `animation_tree.active = false`、自己往角色身上打 meta 标记。
##   那等于把"角色内部长什么样"暴露给包分发方：宿主结构一改（树挪进 Body），
##   模组就静默取不到播放器，表现为"客户端动画不动"且不报错。
##   现在这些都收进组件：**包分发方只说"播第几条、第几秒"，剩下的由角色自己完成**。
##
## ★ **植物 / 僵尸 / 僵王 / 花园僵尸全部共用**：它们的 `Character000Base.anim_component`
##   都是本类，所以驱动源对全体角色一次性生效，不需要各写一套。
const PHASE_RESYNC_EPS := 0.05
## 下标占位：拿不到播放器 / 没在播 / 下标越界 ⇒ 本次不应用
## （与联机快照里的 `ANIM_NONE` 同值，模组直接透传即可）
const ANIM_NONE := 255
## 播放器的动画列表缓存键（列表在角色实例化之后就不再变，两端同源 .tscn ⇒ 下标天然对齐）
const ANIM_LIST_META := &"anim_component_anim_list"

enum E_Driver {
	LOCAL,	## 本地驱动：植物 / 僵尸自己的代码决定播哪条（AnimationTree 状态机 + OneShot）
	REMOTE,	## 远端驱动：由包分发方决定播哪条、播到第几秒（客户端只渲染）
}

## 当前驱动源：LOCAL = 本地逻辑控制，REMOTE = 包分发控制
var driver: E_Driver = E_Driver.LOCAL


## 是否正在被包分发驱动
func is_remote_driven() -> bool:
	return driver == E_Driver.REMOTE


## 交给包分发驱动（幂等）：冻结本地驱动源，之后只有 `apply_*` 能改动画
func take_over() -> void:
	if driver == E_Driver.REMOTE:
		return
	driver = E_Driver.REMOTE
	_on_take_over()


## 交还本地驱动（幂等）：退出联机 / 重连后恢复角色自己的动画逻辑
func release() -> void:
	if driver == E_Driver.LOCAL:
		return
	driver = E_Driver.LOCAL
	_on_release()


## 子类钩子：冻结本地驱动源（如关掉 AnimationTree）
func _on_take_over() -> void:
	pass


## 子类钩子：恢复本地驱动源
func _on_release() -> void:
	pass


## **本地驱动 · 显式切状态**
##
## state 是环境状态机里的状态名（见各角色 `.tscn` 的 AnimationNodeStateMachine）。
## 默认空实现：没有状态机的角色（空动画 / 雪橇）忽略即可。
func request_state(_state: StringName) -> void:
	pass


## **本地驱动 · 显式播一次**（OneShot）
##
## 攻击组件、磁力菇这类"一次性动作"走这里，参数路径默认与攻击组件一致。
func request_one_shot(_param: StringName = &"parameters/OneShot/request") -> void:
	pass


## **本地驱动 · 取消正在播的一次性动画**（淡出）
##
## 仙人掌这类"起落两套 OneShot"的角色在停火时要把两条都撤掉；
## 没有 OneShot 的实现直接忽略。
func cancel_one_shot(_param: StringName = &"parameters/OneShot/request") -> void:
	pass


## **远端驱动 · 按动画下标切播**（下标 = `AnimationPlayer.get_animation_list()` 里的序号）
func apply_anim_index(anim_index: int) -> void:
	if anim_index == ANIM_NONE:
		return
	take_over()
	var player := get_animation_player()
	if player == null:
		return
	var anim_name := anim_name_at(anim_index)
	if anim_name == &"" or not player.has_animation(anim_name):
		return
	if player.current_animation == anim_name:
		return
	player.play(anim_name)


## **远端驱动 · 把播放头拉到指定秒数**
##
## ★ 速度差就是靠这一条抹平的：客户端按自己那份速度往前播，主机报的相位每包
##   前进得更远 —— 差出来的部分被这里一次次 `seek()` 抹掉，平均下来速度就对齐了。
##
## ⚠️ 只在偏得明显时才拉（`PHASE_RESYNC_EPS`）：播放头本来每帧都在往前走，
##   每帧硬拉会跟它打架，表现为动画抖动。
## ⚠️ 空播放头不能动（`current_animation` 为空时读位置 / 长度会刷 ERROR）。
func apply_anim_phase(phase: float) -> void:
	if phase < 0.0:
		return
	take_over()
	var player := get_animation_player()
	if player == null or player.current_animation == &"":
		return
	if absf(player.current_animation_position - phase) < PHASE_RESYNC_EPS:
		return
	player.seek(clampf(phase, 0.0, maxf(player.current_animation_length, 0.0)), true)


## **远端驱动 · 一次应用"播哪条 + 播到第几秒 + 速度"**
##
## speed_scale <= 0 表示沿用当前速度（现行协议不下发速度，靠相位硬拉对齐）。
func apply_packet(anim_index: int, phase: float = -1.0, speed_scale: float = -1.0) -> void:
	if speed_scale > 0.0:
		take_over()
		var player := get_animation_player()
		if player != null:
			player.speed_scale = speed_scale
	apply_anim_index(anim_index)
	apply_anim_phase(phase)


## 动画名 → 下标（采集侧用；拿不到返回 `ANIM_NONE`）
func anim_index_of(anim_name: StringName) -> int:
	if anim_name == &"":
		return ANIM_NONE
	var player := get_animation_player()
	if player == null:
		return ANIM_NONE
	var idx := _anim_list_of(player).find(anim_name)
	## 下标必须落在 `ANIM_NONE` 之下 —— 它是单字节投递的，255 留作"不接管"的占位符
	return ANIM_NONE if idx < 0 or idx >= ANIM_NONE else idx


## 下标 → 动画名（应用侧用；越界返回 `&""`）
func anim_name_at(anim_index: int) -> StringName:
	var player := get_animation_player()
	if player == null:
		return &""
	var list := _anim_list_of(player)
	if anim_index < 0 or anim_index >= list.size():
		return &""
	return list[anim_index]


## **按后缀找状态名**（本地驱动用）：`*_sleep` / `*_idle` / `*_aquarium` 这类
##
## ★ 为什么要它：睡眠 / 花园水族是**所有植物共用**的一条状态切换，状态名却是
##   按植物拼出来的（`FumeShroom_sleep` / `PuffShroom_sleep`…）。有了后缀匹配，
##   基类写一次就覆盖全部植物，不必每株硬编码状态名。
##
## 找不到返回 `&""`（调用方决定要不要刷日志：共用的那条路刷一次就够了）。
func find_state_by_suffix(_suffix: StringName) -> StringName:
	return &""


## 采一份"此刻的动画状态"（采集侧一步到位：名字 + 下标 + 相位）
func snapshot() -> Dictionary:
	update_current_anim()
	return {
		&"name": anim_name_now,
		&"index": anim_index_of(anim_name_now),
		&"position": anim_position_now,
	}


## 本组件的**播放器访问器** —— 远端驱动、下标映射都要用，不要在外面自己递归找节点
##
## 默认 null：没有播放器的实现（空动画 / 走自绘的模组植物）直接忽略远端包。
func get_animation_player() -> AnimationPlayer:
	return null


## 播放器的动画列表（缓存：每帧每只调一次 `get_animation_list()` 太贵）
##
## ⚠️ 必须先 `has_meta` 再 `get_meta`：`get_meta(key, 默认值)` 在键不存在时**照样会
## push_error**（引擎日志里刷一行 ERROR），默认值只是让它不崩。
static func _anim_list_of(player: AnimationPlayer) -> PackedStringArray:
	if player.has_meta(ANIM_LIST_META):
		return player.get_meta(ANIM_LIST_META)
	var list := player.get_animation_list()
	player.set_meta(ANIM_LIST_META, list)
	return list
#endregion


## 获取动画原始速度
func get_animation_origin_speed():
	if animation_origin_speed == -1:
		Log.error("动画速度为-1")
	return animation_origin_speed

## 设置初始化速度(伴舞使用)
func set_animation_origin_speed(value:float):
	animation_origin_speed = value

## 更新动画速度(根据速度倍率)
@abstract
func owner_update_speed(speed_factor_product:float)

## 更新动画速度(动画播放速度)
@abstract
func update_anim_speed_scale(speed_scale:float)

## 停止动画
func stop_anim():
	pass

## 动画结束时发射信号
func _on_animation_finished(anim_name:StringName):
	signal_animation_finished.emit(anim_name)


#region 表现接口（动画事件 + 视觉操作）
##
## ★ 业务代码要表达"看起来怎样"时只走这里，不去抓 Sprite2D / 改 `z_index` / 改 `modulate`：
##   · 颜色统一在 `Body` 上合成（动画轨道每帧写回部件的 `self_modulate`，直接改部件会被盖掉，
##     见 `BodyCharacter.set_invisible()` 的注释）；与受击闪白 / 冰冻染色相乘，互不覆盖。
##   · 层级由这里记账（只收增量），旧的 `z_index += 10` 写法照样能并存。
##
## 用法：
##   comp.apply_visual({&"kind": AnimComponentBase.VISUAL_TINT, &"color": Color(2, 2, 2)})
##   comp.apply_visual({&"kind": AnimComponentBase.VISUAL_Z, &"offset": 10})
##   comp.apply_visual({&"kind": AnimComponentBase.VISUAL_PART_VISIBLE, &"part": ^"Anim_face", &"visible": false})
##   comp.apply_visual({&"kind": AnimComponentBase.VISUAL_SWAP_TEXTURE, &"part": ^"Anim_face", &"texture": tex})

## 整体着色（在 `Body` 上合成）
const VISUAL_TINT := &"tint"
## 层级增量（记的是"相对基准的偏移"，不是绝对 z）
const VISUAL_Z := &"z"
## 单个部件显隐（按 `Body` 子树里的节点名找，名字写错只报一次 WARN）
const VISUAL_PART_VISIBLE := &"part_visible"
## 单个部件换贴图（只认 `Sprite2D`）
const VISUAL_SWAP_TEXTURE := &"swap_texture"
## 影子显隐（角色根下的 `Shadow`，不是 `Body` 里的部件）
const VISUAL_SHADOW_VISIBLE := &"shadow_visible"
## 影子透明度（隐形战争用；`alpha: float`）
const VISUAL_SHADOW_ALPHA := &"shadow_alpha"

## 当前层级增量（`VISUAL_Z` 的记账值）
var _visual_z_offset := 0
## 部件查找缓存：节点名 → 节点（`Body` 子树找一次，之后直接取）
var _visual_parts: Dictionary[StringName, Node] = {}
## 已经报过"找不到"的部件名：这条会被表现代码反复调，别刷屏
var _visual_part_warned: Dictionary[StringName, bool] = {}


## 动画方法轨的统一入口：动画资源里只认这一个方法，参数是逻辑侧认得的事件名
func on_anim_event(event: String) -> void:
	anim_event.emit(StringName(event))


## 表现操作统一入口（操作名见上面的 `VISUAL_*` 常量）
func apply_visual(op: Dictionary) -> void:
	var kind: StringName = op.get(&"kind", &"")
	match kind:
		VISUAL_TINT:
			_visual_tint(op.get(&"color", Color.WHITE))
		VISUAL_Z:
			_visual_z_offset_by(int(op.get(&"offset", 0)))
		VISUAL_PART_VISIBLE:
			_visual_part_visible(op.get(&"part", &""), bool(op.get(&"visible", true)))
		VISUAL_SWAP_TEXTURE:
			_visual_swap_texture(op.get(&"part", &""), op.get(&"texture", null))
		VISUAL_SHADOW_VISIBLE:
			_visual_shadow_visible(bool(op.get(&"visible", true)))
		VISUAL_SHADOW_ALPHA:
			_visual_shadow_alpha(float(op.get(&"alpha", 1.0)))
		_:
			Log.warn("[AnimComponent] 未知的视觉操作 %s（宿主 %s）"
					% [str(kind), String(owner.name) if owner != null else "?"])


## 角色的视觉根（身体部件与合成颜色都挂在它上面）
func _visual_body() -> BodyCharacter:
	return Character000Base.host_node_of(owner, ^"Body") as BodyCharacter


func _visual_tint(color: Color) -> void:
	var body := _visual_body()
	if body == null:
		return
	body.set_other_color(BodyCharacter.E_ChangeColors.PresentTint, color)


## 层级增量：只改差值，旧代码直接 `z_index += 10` 也不会被这里冲掉
func _visual_z_offset_by(offset: int) -> void:
	var node := owner as Node2D
	if node == null:
		return
	node.z_index += offset - _visual_z_offset
	_visual_z_offset = offset


func _visual_part_visible(part: StringName, value: bool) -> void:
	var part_node := _visual_part(part)
	if part_node == null:
		return
	(part_node as CanvasItem).visible = value


func _visual_swap_texture(part: StringName, texture: Resource) -> void:
	var part_node := _visual_part(part)
	if part_node == null:
		return
	var sprite := part_node as Sprite2D
	if sprite == null or texture == null:
		return
	sprite.texture = texture as Texture2D


## 角色根下的影子（`character_base.tscn` 的 `%Shadow`）
func _visual_shadow() -> Sprite2D:
	return Character000Base.host_node_of(owner, ^"Shadow") as Sprite2D


func _visual_shadow_visible(value: bool) -> void:
	var shadow_sprite := _visual_shadow()
	if shadow_sprite == null:
		return
	shadow_sprite.visible = value


func _visual_shadow_alpha(value: float) -> void:
	var shadow_sprite := _visual_shadow()
	if shadow_sprite == null:
		return
	shadow_sprite.modulate.a = clampf(value, 0.0, 1.0)


## 按名字在 `Body` 子树里找部件（找不到只 WARN 一次）
func _visual_part(part: StringName) -> Node:
	if part == &"":
		return null
	if _visual_parts.has(part) and is_instance_valid(_visual_parts[part]):
		return _visual_parts[part]
	var body := _visual_body()
	if body == null:
		return null
	var found := body.find_child(String(part), true, false)
	if found == null:
		if not _visual_part_warned.get(part, false):
			_visual_part_warned[part] = true
			Log.warn("[AnimComponent] Body 下没有部件 %s（宿主 %s）"
					% [str(part), String(owner.name) if owner != null else "?"])
		return null
	_visual_parts[part] = found
	return found
#endregion
