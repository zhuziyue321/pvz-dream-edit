extends Node2D
## PAM 动画播放器 —— 直接画 `.pam.bin`，不生成节点树
##
## 由模组「PAM 动画播放器」（`mods_builtin/pam/`）提供，谁想播 PVZ2 的 PopAnim 就开这个模组。
##
## ★ 为什么不做成动画资源：一段 PAM 动辄几百帧 × 几十个部件，
##   换算成 Godot 的 `AnimationPlayer` 要几十万关键帧（火焰豌豆那样的一株就是 1.5 MB `.tscn`，
##   恐龙级只会更夸张）。所以这里只收**一份烘焙产物**：一张图集 + 一个 `.pam.bin`，
##   由本节点在 `_draw()` 里按帧把部件画成四边形 —— 零节点、零动画轨道。
##
## ★ 数据来源：`tools/bake_pam_bin.py`（PAM json + 图集矩形 → `PAM2 v1` 二进制）。
##   运行时**不解析 PAM / 不解析 json**，只读压平后的每帧快照。
##
## ★ 公开 API（与源工程 `pam_animator.gd` 同口径，另加跨模组用的 `texture_override`）：
##   · 播放：`set_state()` / `has_state()` / `get_state_names()` / `get_current_state()` /
##     `set_looping()` / `set_state_time()` / `get_state_time()` / `reset_state_time()` /
##     `set_speed_scale()` / `get_current_state_frame_count()` / `get_state_duration()`
##   · 帧号：`get_current_frame_index()` / `get_state_frame_index()`
##   · 部件：`get_part_names()` / `get_composite_part_names()` / `get_part_draw_data()` /
##     `get_part_texture()` / `get_part_src_rect()` / `hide_sprite()` / `show_sprite()` /
##     `hide_all_sprites()` / `show_all_sprites()`
##   · 度量：`get_render_rect()`（当前帧包围盒，量卡面 / 摆放用）/ `get_sprite_position()`
##   · 信号：`animation_loaded` / `state_changed` / `loop_completed` / `animation_finished` /
##     `state_frame_changed`
##
## ⚠️ 画面「整段冻住几秒、零件一换又突然跳一下」（帧号照走、像素不动）**先怀疑 bin 本身**，
##   不是这个播放器：烘焙时帧快照少了一次拷贝（别名共享）就会烘出那种数据。判据看工具打印的
##   「相邻帧完全相同占比」（正常是个位数百分比）。这一层不做运行时兜底 —— 数据坏就该在烘焙侧报错。
##
## ⚠️ 同一个 `.bin` 全工程只解析一次：按路径缓存在 `_cache` 里，多实例共享。
##   共享的是**解析结果 + 贴图绑定**，所以「同一个 bin 配不同贴图」是不支持的
##   （一株植物一个 bin，本来不会撞上）。
##
## ⚠️ 本目录的脚本跑在 `user://mods/pam/` 下时**不会注册成全局类**，所以这里一律不写 `class_name`，
##   相互引用全部走 `preload`。也**故意不加 `@tool`**（编辑器预览需要 autoload，而它们不是 tool 脚本）。

const PAMBinaryReader := preload("pam_binary_reader.gd")

## 动画播完一段（非循环状态走到最后一帧）——**每段只发一次**
signal animation_finished(state_name: String)
## 循环状态转过一圈
signal loop_completed(state_name: String)
## 切换了状态
signal state_changed(state_name: String)
## 状态内的帧号变了
signal state_frame_changed(state_name: String, frame: int)
## 数据加载完成
signal animation_loaded


## 动画二进制（由 `tools/bake_pam_bin.py` 生成）
@export_file("*.pam.bin") var binary_path := "":
	set(value):
		if value == binary_path:
			return
		binary_path = value
		if is_node_ready() and not value.is_empty():
			load_bin(value)

## 不画的部件 —— 填 sprite 名或部件名（PVZ2 的装扮就靠这个关掉）
@export var hidden_parts: Array[String] = []:
	set(value):
		hidden_parts = value
		queue_redraw()

## 强制单次播放的状态名（即使在循环模式下也只播一遍）
@export var oneshot_states: Array[String] = []

## 状态默认是否循环
@export var default_looping := true

@export_category("渲染")
## 渲染原点相对画布中心的偏移（PVZ2 的画布是 390×390，中心对齐节点原点）
@export var pivot_offset := Vector2.ZERO:
	set(value):
		pivot_offset = value
		queue_redraw()

## 整体不透明度（淡入淡出用；与动画自带的 color.alpha 相乘）
@export_range(0.0, 1.0) var render_alpha := 1.0:
	set(value):
		render_alpha = clampf(value, 0.0, 1.0)
		queue_redraw()

## 整体染色（与动画自带颜色相乘；受击闪白走 `flash_white`）
@export var color_tint := Color.WHITE:
	set(value):
		color_tint = value
		queue_redraw()

## 帧色 alpha 提升倍率：PVZ2 的特效 PAM 常把帧色写死 50% 透明（显得发暗），
## 设 2.0 可让 0.5 的部件恢复实心（> 1 按 clamp 处理）
@export var alpha_boost := 1.0:
	set(value):
		alpha_boost = maxf(value, 0.0)
		queue_redraw()

## 受击闪白强度，0 = 无
@export_range(0.0, 1.0) var flash_white := 0.0:
	set(value):
		flash_white = clampf(value, 0.0, 1.0)
		queue_redraw()

## 播放速度倍率
@export_range(0.0, 200.0) var speed_scale := 1.0

## 贴图覆盖：跨模组用（模组会被拷到 `user://mods/`，bin 里内嵌的 `res://` 贴图路径就指不到了）。
## 由调用方按自己的加载根读好贴图再塞进来；给了它就**不再读 bin 里的贴图路径**。
var texture_override: Texture2D = null:
	set(value):
		texture_override = value
		if _data != null:
			_bind_textures("")
			queue_redraw()

## 按路径缓存解析结果：同一个 `.bin` 只读一次，多实例共享
static var _cache: Dictionary = {}

var _data = null
var _canvas_size := Vector2(390.0, 390.0)
var _current_state := ""
var _state_start := 0
var _state_count := 0
var _state_time := 0.0
var _looping := true
var _finished_emitted := false
var _pending_state := ""
var _prev_state_frame := -1
var _total_loops := 0


#region 加载

func _ready() -> void:
	if not binary_path.is_empty():
		load_bin(binary_path)


## 清掉解析缓存（贴图随之释放）
##
## 平时**不用调**：缓存的意义就是多个实例共用一份。探针 / 换关时想让「N resources still
## in use at exit」那条引擎告警消失，就在退出前清一次。
static func clear_cache() -> void:
	_cache.clear()


## 加载（或复用）一个 `.pam.bin`；成功返回 true
func load_bin(path: String) -> bool:
	if path.is_empty():
		Log.error("[PAM] binary_path 为空")
		return false

	var data = _cache.get(path)
	if data == null:
		data = PAMBinaryReader.read_path(path)
		if data == null:
			return false
		_cache[path] = data

	if _data != data:
		_data = data
		_bind_textures(path)
	elif texture_override != null:
		_bind_textures(path)

	_canvas_size = data.canvas_size
	_reset_playback()
	animation_loaded.emit()
	return true


## 把贴图绑到每张图上
##
## 单图集模式（本仓库全部植物都是）：只有一张贴图，所有部件都从它上面切；
## 多贴图模式（碎图烘焙）：按 `part_name` 与贴图文件名精确匹配，**匹配不上就报错**，
## 绝不拿别的图顶上（顶上去的画面是「能跑但部件错乱」，比直接报错更难查）。
func _bind_textures(path: String) -> void:
	var data = _data
	if data == null:
		return

	if texture_override != null:
		for idef in data.images:
			idef.texture = texture_override
		return

	data.texture_map.clear()
	for texture_path in data.texture_paths:
		if not ResourceLoader.exists(texture_path):
			Log.error("[PAM] 贴图不存在: ", texture_path)
			continue
		var texture: Texture2D = ResourceLoader.load(texture_path, "Texture2D") as Texture2D
		if texture == null:
			Log.error("[PAM] 贴图加载失败: ", texture_path)
			continue
		data.texture_map[texture_path.get_file().get_basename()] = texture

	var single: Texture2D = null
	if data.texture_map.size() == 1:
		single = data.texture_map.values()[0]

	var missing := 0
	for idef in data.images:
		var texture: Texture2D = data.texture_map.get(idef.part_name, single)
		if texture == null:
			missing += 1
		idef.texture = texture
	if missing > 0:
		Log.error("[PAM] ", missing, " 张部件没绑上贴图（part_name 与贴图名都不匹配）: ", path)


func _reset_playback() -> void:
	_state_time = 0.0
	_finished_emitted = false
	_prev_state_frame = -1
	_total_loops = 0
	_looping = default_looping
	_current_state = ""
	_state_start = 0
	_state_count = 0
	if not _pending_state.is_empty() and has_state(_pending_state):
		var pending := _pending_state
		_pending_state = ""
		set_state(pending)
	elif _data != null and not _data.states.is_empty():
		set_state(_data.states.keys()[0])
	queue_redraw()

#endregion


#region 状态控制

## 切到某个状态（不存在则忽略，返回 false）
##
## 数据还没加载完时排队 —— 场景 / 代码里先 `set_state()` 后加载是常态（`binary_path` 走 `_ready`）。
func set_state(state_name: String) -> bool:
	_finished_emitted = false
	if _data == null:
		_pending_state = state_name
		return false
	var range_arr: Array = _data.states.get(state_name, [])
	if range_arr.is_empty():
		return false
	_current_state = state_name
	_state_start = int(range_arr[0])
	_state_count = maxi(1, int(range_arr[1]))
	_state_time = 0.0
	_prev_state_frame = -1
	_total_loops = 0
	queue_redraw()
	state_changed.emit(state_name)
	return true


func has_state(state_name: String) -> bool:
	return _data != null and _data.states.has(state_name)


func get_state_names() -> Array[String]:
	var names: Array[String] = []
	if _data != null:
		names.assign(_data.states.keys())
	return names


func get_current_state() -> String:
	return _current_state


func set_looping(enable: bool) -> void:
	_looping = enable


func is_loaded() -> bool:
	return _data != null


func get_current_state_frame_count() -> int:
	return maxi(1, _state_count)


## 某一段的总时长（秒）= 段帧数 / 帧率；未加载或段不存在返回 0
func get_state_duration(state_name: String) -> float:
	if _data == null:
		return 0.0
	var range_arr: Array = _data.states.get(state_name, [])
	if range_arr.is_empty():
		return 0.0
	return float(maxi(1, int(range_arr[1]))) / maxf(1.0, _data.frame_rate)


func get_state_time() -> float:
	return _state_time


func set_state_time(time_sec: float) -> void:
	_state_time = maxf(0.0, time_sec)
	queue_redraw()


func reset_state_time() -> void:
	_state_time = 0.0
	_finished_emitted = false
	_prev_state_frame = -1
	_total_loops = 0
	queue_redraw()


func set_speed_scale(value: float) -> void:
	speed_scale = clampf(value, 0.0, 200.0)

#endregion


#region 播放推进

func _process(delta: float) -> void:
	if _data == null or _state_count <= 0:
		return

	var looping := _is_current_looping()
	var duration := float(_state_count) / maxf(_data.frame_rate, 1.0)
	var prev_frame := get_state_frame_index()

	if looping or _state_time < duration:
		_state_time += delta * speed_scale
	if not looping:
		_state_time = minf(_state_time, duration)   # 停在最后一帧，别越界

	var cur_frame := get_state_frame_index()
	if cur_frame != prev_frame:
		if looping and cur_frame < prev_frame:
			_total_loops += 1
			loop_completed.emit(_current_state)
		state_frame_changed.emit(_current_state, cur_frame)

	## ⚠️ 只发一次：非循环状态停在末帧后 `_state_time` 不再增长，若不在这里判 `_finished_emitted`，
	## 会**每帧**发一遍 animation_finished（上游若拿它触发攻击，等于连发）。
	if not looping and not _finished_emitted and _state_time >= duration:
		_finished_emitted = true
		animation_finished.emit(_current_state)

	queue_redraw()


func _is_current_looping() -> bool:
	return _looping and not oneshot_states.has(_current_state)


## 状态内的帧号（从状态起点算，循环取模 / 单次夹在末帧）
func get_state_frame_index() -> int:
	if _data == null or _state_count <= 0:
		return 0
	var elapsed := int(_state_time * maxf(_data.frame_rate, 1.0))
	if _is_current_looping():
		return elapsed % _state_count
	return mini(elapsed, _state_count - 1)


## 主时间轴上的绝对帧号
func get_current_frame_index() -> int:
	if _data == null or _data.frames.is_empty():
		return 0
	var total: int = _data.frames.size()
	if _state_count <= 0:
		return int(_state_time * maxf(_data.frame_rate, 1.0)) % total
	return clampi(_state_start + get_state_frame_index(), 0, total - 1)

#endregion


#region 部件查询

func hide_sprite(part_name: String) -> void:
	if part_name not in hidden_parts:
		hidden_parts.append(part_name)
		queue_redraw()


func show_sprite(part_name: String) -> void:
	var idx := hidden_parts.find(part_name)
	if idx >= 0:
		hidden_parts.remove_at(idx)
		queue_redraw()


func hide_all_sprites() -> void:
	for part_name in get_part_names():
		if part_name not in hidden_parts:
			hidden_parts.append(part_name)
	queue_redraw()


func show_all_sprites() -> void:
	hidden_parts.clear()
	queue_redraw()


## 全部部件名（PVZ2 一个部件可能被拆成多个同名图层，这里去重）
func get_part_names() -> PackedStringArray:
	var names := PackedStringArray()
	if _data == null:
		return names
	for part_name in _data.sprite_names:
		if not names.has(part_name):
			names.append(part_name)
	return names


## 收集聚合部件的全部后代部件名（不含自身）—— 如 particle_head 聚合头骨 / 下颚
func get_composite_part_names(root_part_name: String) -> Array[StringName]:
	var names: Array[StringName] = []
	if _data == null:
		return names
	var root_index := -1
	for i in _data.sprite_names.size():
		if _data.sprite_names[i] == root_part_name:
			root_index = i
			break
	if root_index < 0 or root_index >= _data.sprite_timelines.size():
		return names

	var visited := {root_index: true}
	var stack: Array[int] = []
	for frame: Array in _data.sprite_timelines[root_index]:
		for inst in frame:
			if inst.is_sprite and not visited.has(inst.resource):
				stack.append(inst.resource)
	while not stack.is_empty():
		var idx: int = stack.pop_back()
		if visited.has(idx):
			continue
		visited[idx] = true
		names.append(StringName(_data.sprite_names[idx]))
		if idx >= _data.sprite_timelines.size():
			continue
		for frame: Array in _data.sprite_timelines[idx]:
			for inst in frame:
				if inst.is_sprite and not visited.has(inst.resource):
					stack.append(inst.resource)
	return names


## 取某个部件第一帧引用的「贴图 + 图集矩形 + 绘制尺寸」（掉落件 / 卡面定格用）
func get_part_draw_data(part_name: String) -> Dictionary:
	if _data == null:
		return {}
	var index := -1
	for i in _data.sprite_names.size():
		if _data.sprite_names[i] == part_name:
			index = i
			break
	if index < 0 or index >= _data.sprite_timelines.size():
		return {}
	for frame: Array in _data.sprite_timelines[index]:
		for inst in frame:
			if inst.is_sprite or inst.resource < 0 or inst.resource >= _data.images.size():
				continue
			var idef = _data.images[inst.resource]
			if idef.texture != null:
				return {"texture": idef.texture, "rect": idef.src_rect, "size": idef.draw_size}
	return {}


func get_part_texture(part_name: String) -> Texture2D:
	if _data == null:
		return null
	var index: int = int(_data.part_map.get(part_name, -1))
	if index < 0 or index >= _data.images.size():
		return null
	return _data.images[index].texture


func get_part_src_rect(part_name: String) -> Rect2:
	if _data == null:
		return Rect2()
	var index: int = int(_data.part_map.get(part_name, -1))
	if index < 0 or index >= _data.images.size():
		return Rect2()
	return _data.images[index].src_rect


## 某个部件在当前帧的落点（节点局部坐标）—— 量子弹出生点 / 火焰位置用
func get_sprite_position(part_name: String) -> Vector2:
	if _data == null or _data.frames.is_empty():
		return Vector2.ZERO
	var frame_index: int = get_current_frame_index() % _data.frames.size()
	var found = _find_sprite_xform(_data.frames[frame_index], _root_xform(), part_name)
	if found == null:
		return Vector2.ZERO
	return (found as Transform2D) * Vector2.ZERO


func _find_sprite_xform(instances: Array, parent_xform: Transform2D, part_name: String):
	for inst in instances:
		var xform: Transform2D = parent_xform * inst.xform
		if inst.is_sprite:
			if inst.resource < 0 or inst.resource >= _data.sprite_timelines.size():
				continue
			if _data.sprite_names[inst.resource] == part_name:
				return xform
			var timeline: Array = _data.sprite_timelines[inst.resource]
			if timeline.is_empty():
				continue
			var found = _find_sprite_xform(timeline[inst.anim_frame % timeline.size()], xform, part_name)
			if found != null:
				return found
	return null

#endregion


#region 绘制

func _draw() -> void:
	if _data == null or _data.frames.is_empty():
		return
	var frame_index: int = get_current_frame_index() % _data.frames.size()
	_draw_instances(_data.frames[frame_index], _root_xform(), Color.WHITE)


## 画布中心对齐节点原点（PVZ2 的坐标原点在画布左上角，而角色应该绕中心站）
func _root_xform() -> Transform2D:
	return Transform2D(0.0, Vector2(-_canvas_size.x * 0.5, -_canvas_size.y * 0.5) + pivot_offset)


func _draw_instances(instances: Array, parent_xform: Transform2D, parent_color: Color) -> void:
	for inst in instances:
		var tint := Color(
			parent_color.r * inst.color.r,
			parent_color.g * inst.color.g,
			parent_color.b * inst.color.b,
			parent_color.a * clampf(inst.color.a * alpha_boost, 0.0, 1.0)
		)
		var xform: Transform2D = parent_xform * inst.xform

		if inst.is_sprite:
			if inst.resource < 0 or inst.resource >= _data.sprite_timelines.size():
				continue
			if _data.sprite_names[inst.resource] in hidden_parts:
				continue
			var timeline: Array = _data.sprite_timelines[inst.resource]
			if timeline.is_empty():
				continue
			var child_frame: int = inst.anim_frame % timeline.size()
			_draw_instances(timeline[child_frame], xform, tint)
		else:
			if inst.resource < 0 or inst.resource >= _data.images.size():
				continue
			var idef = _data.images[inst.resource]
			if idef.texture == null or idef.part_name in hidden_parts:
				continue
			_draw_image(idef, xform * idef.local_xform, tint)


func _draw_image(idef, xform: Transform2D, tint: Color) -> void:
	if idef.src_rect.size.x <= 0.0 or idef.src_rect.size.y <= 0.0:
		return

	var width: float = idef.draw_size.x
	var height: float = idef.draw_size.y
	var points := PackedVector2Array([
		xform * Vector2(0.0, 0.0),
		xform * Vector2(0.0, height),
		xform * Vector2(width, height),
		xform * Vector2(width, 0.0),
	])

	var texture_size: Vector2 = idef.texture.get_size()
	var uv_rect := Rect2(idef.src_rect.position / texture_size, idef.src_rect.size / texture_size)
	var uvs := PackedVector2Array([
		Vector2(uv_rect.position.x, uv_rect.position.y),
		Vector2(uv_rect.position.x, uv_rect.end.y),
		Vector2(uv_rect.end.x, uv_rect.end.y),
		Vector2(uv_rect.end.x, uv_rect.position.y),
	])

	var final_color := Color(
		tint.r * color_tint.r,
		tint.g * color_tint.g,
		tint.b * color_tint.b,
		tint.a * render_alpha
	)
	draw_colored_polygon(points, final_color, uvs, idef.texture)

	if flash_white > 0.001:
		var flash_color := Color(1.0, 1.0, 1.0, clampf(flash_white * final_color.a, 0.0, 1.0))
		draw_colored_polygon(points, flash_color, uvs, idef.texture)


## 当前帧所有可见部件的包围盒（节点局部坐标，已含画布居中变换）
## 给探针 / 工具量「这株多大」用（量卡面、手持立绘是否与实机一致）
func get_render_rect() -> Rect2:
	if _data == null or _data.frames.is_empty():
		return Rect2()
	var frame_index: int = get_current_frame_index() % _data.frames.size()
	var points: Array[Vector2] = []
	_collect_points(_data.frames[frame_index], _root_xform(), points)
	if points.is_empty():
		return Rect2()
	var box := Rect2(points[0], Vector2.ZERO)
	for point in points:
		box = box.expand(point)
	return box


func _collect_points(instances: Array, parent_xform: Transform2D, out: Array[Vector2]) -> void:
	for inst in instances:
		var xform: Transform2D = parent_xform * inst.xform
		if inst.is_sprite:
			if inst.resource < 0 or inst.resource >= _data.sprite_timelines.size():
				continue
			if _data.sprite_names[inst.resource] in hidden_parts:
				continue
			var timeline: Array = _data.sprite_timelines[inst.resource]
			if timeline.is_empty():
				continue
			_collect_points(timeline[inst.anim_frame % timeline.size()], xform, out)
		else:
			if inst.resource < 0 or inst.resource >= _data.images.size():
				continue
			var idef = _data.images[inst.resource]
			if idef.texture == null or idef.part_name in hidden_parts:
				continue
			var final_xform: Transform2D = xform * idef.local_xform
			var width: float = idef.draw_size.x
			var height: float = idef.draw_size.y
			out.append(final_xform * Vector2(0.0, 0.0))
			out.append(final_xform * Vector2(0.0, height))
			out.append(final_xform * Vector2(width, height))
			out.append(final_xform * Vector2(width, 0.0))

#endregion
