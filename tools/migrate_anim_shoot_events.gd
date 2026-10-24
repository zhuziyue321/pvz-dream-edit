extends SceneTree

## 一次性迁移工具：把「开火」动画的方法轨从**直调攻击组件**改成**走表现层事件**。
##
## 改什么（只动这两条方法，其它方法轨原样保留）：
##   · `tracks/N/path` 里的 `AttackComponent` → `AnimComponent`
##   · `"method": &"_shoot_bullet"`   → `&"on_anim_event"`，`"args": []` → `["shoot"]`
##   · `"method": &"_shoot_bullet_2"` → `&"on_anim_event"`，`"args": []` → `["shoot_2"]`
##
## 为什么这么改：动画资源从此只认得「第几帧发生了一件事」，事件名由逻辑侧解释；
## 攻击组件订阅 `AnimComponentBase.anim_event` 后自己决定发子弹（见组件里的 `_on_anim_event`）。
##
## 只处理文本 `.tres`；二进制 `.res` 不动（没迁移的那几条方法轨照样能工作，
## 因为攻击组件的 `_shoot_bullet()` 仍然在，两条路并存）。
##
## 用法：godot --headless --path . --script res://tools/migrate_anim_shoot_events.gd

const METHOD_EVENTS := {
	&"_shoot_bullet": "shoot",
	&"_shoot_bullet_2": "shoot_2",
}
const TARGET_FROM := "AttackComponent"
const TARGET_TO := "AnimComponent"
const EVENT_METHOD := &"on_anim_event"

var _changed_files: Array[String] = []
var _changed_tracks := 0
var _scanned := 0


func _initialize() -> void:
	_walk("res://animation")
	## ⚠️ 这里只能 `print`：`--script` 模式下 autoload（含 `Log`）还没注册，
	##    写 `Log.info` 会直接编译不过（与 `test/scenarios/tool_semantic_scan.gd` 同口径）
	print("[migrate] scanned=%d files=%d tracks=%d" % [_scanned, _changed_files.size(), _changed_tracks])
	for changed_path in _changed_files:
		print("  · %s" % changed_path)
	print("[migrate] result=%s" % ("DONE" if _changed_tracks > 0 else "NOOP"))
	quit()


func _walk(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				_walk(full)
			elif entry.ends_with(".tres"):
				_migrate_file(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _migrate_file(path: String) -> void:
	_scanned += 1
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() or not text.contains(TARGET_FROM):
		return
	## ⚠️ 必须转成 Array：`PackedStringArray` 是值类型，传进函数改不动外面的数组
	var lines := Array(text.split("\n"))
	var changed := false
	## 逐块处理：`tracks/<N>/type = "method"` 起，到下一条 `tracks/` 行为止
	var i := 0
	while i < lines.size():
		if not lines[i].begins_with("tracks/") or not lines[i].contains("\"method\""):
			i += 1
			continue
		var prefix: String = str(lines[i]).get_slice("/", 0) + "/" + str(lines[i]).get_slice("/", 1) + "/"
		## ⚠️ 块结束于**下一条别的轨道**（同一个 `tracks/N/` 前缀的行不算）
		var end := i + 1
		while end < lines.size():
			if lines[end].begins_with("tracks/") and not lines[end].begins_with(prefix):
				break
			end += 1
		var block_migrated := _migrate_block(lines, i, end, prefix)
		if block_migrated > 0:
			changed = true
			_changed_tracks += block_migrated
		i = end
	if not changed:
		return
	## 保留原文件末尾换行习惯
	var out := "\n".join(lines)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[migrate] 写不进去：%s" % path)
		return
	f.store_string(out)
	f.close()
	_changed_files.append(path)


## 迁移一个方法轨块，返回改掉的轨道条数（0 = 没这条方法）
func _migrate_block(lines: Array, from: int, to: int, prefix: String) -> int:
	var path_index := -1
	var method_hits: Array[Dictionary] = []
	var last_args := -1
	## ⚠️ keys 字典里的行**带缩进**（两个空格），判定前先剥掉左侧空白，写回时再把缩进补上
	for i in range(from, to):
		var line: String = lines[i]
		var body := line.strip_edges(true, false)
		if body.begins_with(prefix + "path = "):
			path_index = i
		elif body.begins_with("\"args\": "):
			last_args = i
		elif body.begins_with("\"method\": "):
			var method_name := StringName(body.get_slice("&\"", 1).get_slice("\"", 0))
			if METHOD_EVENTS.has(method_name) and last_args >= 0:
				method_hits.append({"index": i, "args": last_args, "event": METHOD_EVENTS[method_name]})
	if method_hits.is_empty():
		return 0
	if path_index < 0 or not str(lines[path_index]).contains(TARGET_FROM):
		push_warning("[migrate] 目标节点不是 %s，跳过：%s" % [TARGET_FROM, lines[from]])
		return 0
	lines[path_index] = str(lines[path_index]).replace(TARGET_FROM, TARGET_TO)
	for hit in method_hits:
		var method_line: String = lines[hit["index"]]
		var method_indent := method_line.substr(0, method_line.length() - method_line.strip_edges(true, false).length())
		lines[hit["index"]] = method_indent + "\"method\": &\"%s\"" % EVENT_METHOD
		var args_line: String = lines[hit["args"]]
		var args_indent := args_line.substr(0, args_line.length() - args_line.strip_edges(true, false).length())
		## 参数原样为空才改；已经有参数说明不是这套写法，留着不动，让人去确认
		if args_line.strip_edges() == "\"args\": [],":
			lines[hit["args"]] = args_indent + "\"args\": [\"%s\"]," % hit["event"]
		else:
			push_warning("[migrate] 参数不是空数组，未改参数：%s" % args_line)
	return method_hits.size()
