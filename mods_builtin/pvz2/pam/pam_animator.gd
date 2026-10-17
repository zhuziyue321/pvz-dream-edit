extends Node2D
## PAM 动画播放器 —— 直接画 `.pam.bin`，不生成节点树
##
## ★ 为什么不用本体那套「reanim → `.tres` → AnimationTree」：
##   PVZ2 的美术是 PopAnim（PAM），一段动画 = 573 帧 × 平均 24 个部件。
##   换算成 Godot 动画资源要几十万个关键帧（菜问那种「57 个 Sprite2D 复用槽 +
##   AnimationPlayer」的做法在本株上是 4.8 MB 的 `.tscn`，潜伏芹菜只会更夸张）。
##   所以这里只收**一份烘焙产物**：一张图集贴图 + 一个 `.pam.bin`，
##   由本节点在 `_draw()` 里按帧把部件画成四边形 —— 零节点、零动画轨道。
##
## ★ 数据来源：`tools/bake_pam_bin.py`（离线烘焙，见该脚本头部注释）。
##   运行时**不解析 PAM**，只读压平后的每帧快照。
##
## ★ 同一个 `.bin` 全工程只解析一次：按路径缓存在 `_cache` 里，多实例共享。
##
## ⚠️ 本目录的脚本跑在 `user://mods/pvz2/` 下时**不会注册成全局类**，所以这里一律不写
##    `class_name`，相互引用全部走 `preload`（与 `pvz2_mod.gd` 里那条口径一致）。
## ⚠️ 故意**不加 `@tool`**：编辑器预览需要 autoload（`Log`）在编辑器里可用，而它不是 tool 脚本；
##    本节点只在运行时用，加 `@tool` 反而会在编辑器里报错。

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

## 不画的部件 —— 填 sprite 名或部件名（PVZ2 的装扮就靠这个关掉，见场景文件注释）
@export var hidden_parts: Array[String] = []:
	set(value):
		hidden_parts = value
		queue_redraw()

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

## 受击闪白强度，0 = 无
@export_range(0.0, 1.0) var flash_white := 0.0:
	set(value):
		flash_white = clampf(value, 0.0, 1.0)
		queue_redraw()

## 播放速度倍率
@export_range(0.0, 5.0) var speed_scale := 1.0

@export_category("播放")
## 状态默认是否循环
@export var default_looping := true
## 强制单次播放的状态名（即使在循环模式下也只播一遍）
@export var oneshot_states: Array[String] = []

## 按路径缓存解析结果：同一个 `.bin` 只读一次，多实例共享
static var _cache: Dictionary = {}

var _data = null
var _current_state := ""
var _state_start := 0
var _state_count := 0
var _state_time := 0.0
var _looping := true
var _finished_emitted := false
var _total_loops := 0
var _canvas_size := Vector2(390.0, 390.0)


#region 加载

func _ready() -> void:
	if not binary_path.is_empty():
		load_bin(binary_path)


## 清掉解析缓存（贴图随之释放）
##
## 平时**不用调**：缓存的意义就是多个实例共用一份。探针 / 换关时想让「3 resources still
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
		_bind_textures(data, path)
		_cache[path] = data

	_data = data
	_canvas_size = data.canvas_size
	_reset_playback()
	animation_loaded.emit()
	return true


## 把 bin 里内嵌的贴图路径加载成 Texture2D，并绑到每张图上
##
## 单图集模式（潜伏芹菜就是）：只有一张贴图，所有部件都从它上面切；
## 多贴图模式（碎图烘焙）：按 `part_name` 与贴图文件名精确匹配，**匹配不上就报错**，
## 绝不拿别的图顶上（顶上去的画面是「能跑但部件错乱」，比直接报错更难查）。
func _bind_textures(data, path: String) -> void:
	for texture_path in data.texture_paths:
		if not ResourceLoader.exists(texture_path):
			Log.error("[PAM] 贴图不存在: ", texture_path)
			continue
		var texture := ResourceLoader.load(texture_path, "Texture2D") as Texture2D
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
	_total_loops = 0
	_looping = default_looping
	_current_state = ""
	if not _data.states.is_empty():
		set_state(_data.states.keys()[0])
	queue_redraw()

#endregion


#region 状态控制

## 切到某个状态（不存在则忽略，返回 false）
func set_state(state_name: String) -> bool:
	if _data == null:
		return false
	var range_arr: Array = _data.states.get(state_name, [])
	if range_arr.is_empty():
		return false
	_current_state = state_name
	_state_start = int(range_arr[0])
	_state_count = maxi(1, int(range_arr[1]))
	_state_time = 0.0
	_finished_emitted = false
	_total_loops = 0
	queue_redraw()
	state_changed.emit(state_name)
	return true


func has_state(state_name: String) -> bool:
	return _data != null and _data.states.has(state_name)


func get_state_names() -> PackedStringArray:
	var names := PackedStringArray()
	if _data != null:
		for key in _data.states:
			names.append(key)
	return names


func get_current_state() -> String:
	return _current_state


func set_looping(enable: bool) -> void:
	_looping = enable


func is_loaded() -> bool:
	return _data != null


func get_current_state_frame_count() -> int:
	return maxi(1, _state_count)


func get_state_time() -> float:
	return _state_time


func set_state_time(time_sec: float) -> void:
	_state_time = maxf(0.0, time_sec)
	queue_redraw()


func reset_state_time() -> void:
	_state_time = 0.0
	_finished_emitted = false
	_total_loops = 0
	queue_redraw()


func set_speed_scale(value: float) -> void:
	speed_scale = clampf(value, 0.0, 5.0)

#endregion


#region 播放推进

func _process(delta: float) -> void:
	if _data == null or _state_count <= 0:
		return

	var looping := _is_current_looping()
	var duration := float(_state_count) / maxf(_data.frame_rate, 1.0)
	var prev_frame := get_state_frame_index()

	_state_time += delta * speed_scale
	if not looping and _state_time >= duration:
		_state_time = duration   # 停在最后一帧，别越界

	var cur_frame := get_state_frame_index()
	if cur_frame != prev_frame:
		if looping and cur_frame < prev_frame:
			_total_loops += 1
			loop_completed.emit(_current_state)
		state_frame_changed.emit(_current_state, cur_frame)

	## ⚠️ 只发一次：`_state_time` 到了 duration 就不再增长，若不在这里判 `_finished_emitted`，
	## 非循环状态会**每帧**发一遍 animation_finished（上游若拿它触发攻击，等于连发）。
	if not looping and not _finished_emitted and _state_time >= duration:
		_finished_emitted = true
		animation_finished.emit(_current_state)

	queue_redraw()


func _is_current_looping() -> bool:
	return _looping and _current_state not in oneshot_states


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
	var total: int = _data.frames.size() if _data != null else 0
	if total <= 0:
		return 0
	if _state_count <= 0:
		return int(_state_time * maxf(_data.frame_rate, 1.0)) % total
	return clampi(_state_start + get_state_frame_index(), 0, total - 1)

#endregion


#region 部件显隐

func hide_sprite(name: String) -> void:
	if name not in hidden_parts:
		hidden_parts.append(name)
		queue_redraw()


func show_sprite(name: String) -> void:
	var idx := hidden_parts.find(name)
	if idx >= 0:
		hidden_parts.remove_at(idx)
		queue_redraw()


func hide_all_sprites() -> void:
	for name in get_part_names():
		if name not in hidden_parts:
			hidden_parts.append(name)
	queue_redraw()


func show_all_sprites() -> void:
	hidden_parts.clear()
	queue_redraw()


## 全部部件名（不含图片部件；PVZ2 一个部件可能被拆成多个同名图层，这里去重）
func get_part_names() -> PackedStringArray:
	var names := PackedStringArray()
	if _data == null:
		return names
	for name in _data.sprite_names:
		if not names.has(name):
			names.append(name)
	return names

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
			parent_color.a * inst.color.a
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

#endregion
