extends RefCounted
## `.pam.bin`（PAM2 v1）读取器
##
## 格式由 `tools/bake_pam_bin.py` 生成，两边字段一一对应：
##
##     "PAM2" | version:u32 | flags:u32
##     frame_rate:f32 | canvas_w:f32 | canvas_h:f32 | image_count:u32 | sprite_count:u32
##     texture_paths: u32 n → (u16 len + utf8)
##     images:         (src_rect 4×f32, u16+part_name, draw_size 2×f32, T2D 6×f32)
##     states:         (u16+name, start:u32, count:u32)
##     sprite names:   (u16+name)
##     main timeline:  u32 frames → (u32 insts → inst)
##     sprite timelines: sprite_count 份同上
##     inst: index:u32 | resource:u32 | is_sprite:u8 | anim_frame:u32 | color 4×f32 | T2D 6×f32
##
## 读失败一律 `Log.error` 并返回 null —— **不做半截兜底**（少一张图宁可报错，
## 也不要拿别的图顶上：那样画面会「看着能跑但部件错乱」）。

const MAGIC := "PAM2"
const VERSION := 1

const PAMAnimData := preload("pam_anim_data.gd")
const PAMImageDef := preload("pam_image_def.gd")
const PAMInstanceState := preload("pam_instance_state.gd")


## 读一个 `.pam.bin`；失败返回 null
static func read_path(path: String):
	if not FileAccess.file_exists(path):
		Log.error("[PAM] 找不到动画文件: ", path)
		return null

	# 用 get_file_as_bytes：既能读 PCK 里的文件，也不受编辑器沙箱的 FileAccess.open 限制
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		Log.error("[PAM] 动画文件为空或读不动: ", path)
		return null

	var buffer := StreamPeerBuffer.new()
	buffer.data_array = bytes
	buffer.big_endian = false

	var magic := buffer.get_string(4)
	if magic != MAGIC:
		Log.error("[PAM] 不是 PAM2 文件（magic=", magic, "）: ", path)
		return null
	var version := buffer.get_32()
	if version > VERSION:
		Log.warn("[PAM] 文件版本高于读取器（file=%d reader=%d）: %s" % [version, VERSION, path])
	buffer.get_32()  # flags，目前保留

	var data = PAMAnimData.new()
	data.frame_rate = buffer.get_float()
	data.canvas_size = Vector2(buffer.get_float(), buffer.get_float())
	var image_count := buffer.get_32()
	var sprite_count := buffer.get_32()

	for _i in buffer.get_32():
		var path_len := buffer.get_16()
		data.texture_paths.append(buffer.get_string(path_len))

	for _i in image_count:
		var idef = PAMImageDef.new()
		idef.src_rect = Rect2(buffer.get_float(), buffer.get_float(),
			buffer.get_float(), buffer.get_float())
		var name_len := buffer.get_16()
		idef.part_name = buffer.get_string(name_len)
		idef.draw_size = Vector2(buffer.get_float(), buffer.get_float())
		idef.local_xform = _read_xform(buffer)
		data.images.append(idef)
		data.part_map[idef.part_name] = data.images.size() - 1

	for _i in buffer.get_32():
		var name_len := buffer.get_16()
		var state_name := buffer.get_string(name_len)
		data.states[state_name] = [buffer.get_32(), buffer.get_32()]

	for _i in sprite_count:
		var name_len := buffer.get_16()
		data.sprite_names.append(buffer.get_string(name_len))

	data.frames = _read_timeline(buffer)
	for _i in sprite_count:
		data.sprite_timelines.append(_read_timeline(buffer))

	if buffer.get_position() != bytes.size():
		Log.warn("[PAM] 读完后还剩 ", bytes.size() - buffer.get_position(),
			" 字节（格式对不上，可能烘焙工具版本不一致）: ", path)

	return data


static func _read_xform(buffer: StreamPeerBuffer) -> Transform2D:
	return Transform2D(
		Vector2(buffer.get_float(), buffer.get_float()),
		Vector2(buffer.get_float(), buffer.get_float()),
		Vector2(buffer.get_float(), buffer.get_float())
	)


static func _read_timeline(buffer: StreamPeerBuffer) -> Array:
	var timeline: Array = []
	for _f in buffer.get_32():
		var frame: Array = []
		for _i in buffer.get_32():
			var inst = PAMInstanceState.new()
			inst.index = buffer.get_32()
			inst.resource = buffer.get_32()
			inst.is_sprite = buffer.get_8() != 0
			inst.anim_frame = buffer.get_32()
			inst.color = Color(buffer.get_float(), buffer.get_float(),
				buffer.get_float(), buffer.get_float())
			inst.xform = _read_xform(buffer)
			frame.append(inst)
		timeline.append(frame)
	return timeline
