extends RefCounted
## 一次性迁移工具：把关卡 .tres 翻译成关卡脚本 .gd（**一个关卡 = 一个 .gd**）
##
## 翻译规则（保真优先，机械翻译，不做智能压缩）：
##   1. [resource] 段的属性 → _init() 里的赋值
##      （原 .tres 里没写的字段不生成，沿用 LevelScriptBase 的默认值）
##   2. 内联 [sub_resource]（戴夫对话 / 教程 / 预种植…）→ _init() 里就地 new + 字段赋值，
##      构造顺序照 .tres 里的定义顺序（被依赖的先定义）
##   3. timeline = SubResource(...) 的事件数组 → run_flow() 里**按顺序平铺**的
##      `await xxx()`，事件的 note 变成注释，is_first_round_only 变成 if 包裹
##   4. `;` 开头的原版考据注释 → 原样保留（转成 `##`），**不经过 ResourceSaver**，
##      所以不会有「保存冲掉注释」的问题（见 tool_inline_timelines.gd 的踩坑）
##
## 跑法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario tool_level_tres_to_script
##
## ONLY 留空 = 跑全部关卡；填上文件名片段（如 "adventure_01_02"）只跑那一关，用来对样例。

## 只跑这一关（文件名片段，留空 = 全部）
const ONLY := ""
## 关卡资源根目录
const ROOT := "res://src/levels"
## [resource] 段里不需要搬进脚本的键
const SKIP_KEYS := ["script", "metadata/_custom_type_script", "format_version"]

## 事件脚本文件名 → LevelScriptBase 上的流程方法名
const EVENT_METHOD := {
	"level_timeline_event_bowling_stripe.gd": "bowling_stripe",
	"level_timeline_event_camera_back.gd": "camera_back",
	"level_timeline_event_choose_card.gd": "choose_card",
	"level_timeline_event_clear_field.gd": "clear_field",
	"level_timeline_event_dave_dialog.gd": "dave_dialog",
	"level_timeline_event_dave_sell.gd": "dave_sell",
	"level_timeline_event_ready_set_plant.gd": "ready_set_plant",
	"level_timeline_event_show_zombie.gd": "show_zombie",
	"level_timeline_event_start_battle.gd": "start_battle",
	"level_timeline_event_system_plant.gd": "system_plant",
	"level_timeline_event_tutorial.gd": "tutorial",
	"level_timeline_event_wait.gd": "wait",
}
## 事件上要作为流程方法参数传的字段（其余字段事件自己从关卡数据取）
const EVENT_ARGS := ["wait_time", "timeout", "plants"]

## 类型是枚举的字段：.tres 里存的是裸 int，直接 `=` 会触发 INT_AS_ENUM_WITHOUT_CAST。
## 写成 `EnumType.Member` 成员名形式（GDScript 里 enum 不是可调用类型，
## 写 `EnumType(值)` 会报 "Member ... is not a function"），
## 成员名按值反查 enum 定义得到：[脚本路径, enum 名, 类名]
## 按**字段名**匹配，所以顶层属性和内联子资源的属性都生效
## （子资源上的 plant_type 就是靠这条转的；教程步骤的 pointer_target / finish_type
## 随教程系统一并删除了，迁移工具不再认这两个字段）
const ENUM_FIELDS := {
	"game_sences": ["res://src/core/autoload/main_scene_registry.gd", "MainScenes", "MainSceneRegistry"],
	"game_BG": ["res://src/core/consts/const_level_data.gd", "GameBg", "ConstLevelData"],
	"game_BGM": ["res://src/core/consts/const_level_data.gd", "GameBGM", "ConstLevelData"],
	"monster_mode": ["res://src/core/consts/const_level_data.gd", "E_MonsterMode", "ConstLevelData"],
	"card_mode": ["res://src/core/consts/const_level_data.gd", "E_CardMode", "ConstLevelData"],
	"pot_mode": ["res://src/core/consts/const_level_data.gd", "E_PotMode", "ConstLevelData"],
	"plant_type": ["res://src/core/autoload/character_registry.gd", "PlantType", "CharacterRegistry"],
	## 出怪表是**枚举数组**：`start_battle(10, [1, 3])` 这种写法同样会触发
	## INT_AS_ENUM_WITHOUT_CAST（这类警告只在 Godot 编辑器输出面板里报，无头跑批完全安静，
	## 2026-10-03 全仓扫出 154 处），所以逐元素换成员名交给 _enumed_array()
	"zombie_refresh_types": ["res://src/core/autoload/character_registry.gd", "ZombieType", "CharacterRegistry"],
}


func run(a) -> void:
	var paths := _list_tres(ROOT)
	if ONLY != "":
		paths = paths.filter(func(p): return p.get_file().contains(ONLY))
	a.log("")
	a.log("========== 迁移：关卡 .tres → .gd（共 %d 关）==========" % paths.size())
	var ok := 0
	var failed := 0
	for path in paths:
		if _gen_one(a, path):
			ok += 1
		else:
			failed += 1
	a.log("")
	a.log("[TRES2GD] 完成：成功 %d 关，失败 %d 关" % [ok, failed])
	a.log("[TRES2GD] result=DONE")
	a.finish()


#region 生成单个关卡脚本

func _gen_one(a, path: String) -> bool:
	var src := FileAccess.get_file_as_string(path)
	if src == "":
		a.log("  [FAIL] %s 读不到内容" % path.get_file())
		return false
	var p := _parse(src)
	var ctx := {
		"exts": p.exts,
		"var_names": {},   ## SubResource id → 脚本里的变量名
	}

	## --- 1. 内联子资源（时间轴容器和它的事件除外：那些已转成 run_flow）---
	var skip_ids := _timeline_ids(p)
	var init_lines: Array[String] = []
	var counters := {}
	for sid in (p.subs_order as Array):
		if skip_ids.has(sid):
			continue
		var sub: Dictionary = (p.subs as Dictionary)[sid]
		var script_path := _ext_path(sub.script_path, p.exts)
		if script_path == "" or script_path.contains("/timeline_event/"):
			continue
		var base := script_path.get_file().get_basename()
		var idx: int = counters.get(base, 0)
		counters[base] = idx + 1
		var var_name := "%s_%d" % [base, idx]
		ctx.var_names[sid] = var_name
		init_lines.append("\tvar %s := %s.new()" % [var_name, _class_of(script_path)])
		for kv in (sub.props as Array):
			var k: String = kv[0]
			var v: String = kv[1]
			for c in ((sub.comments as Dictionary).get(k, []) as Array):
				init_lines.append("\t" + _comment(c))
			init_lines.append("\t" + _assign(var_name + "." + k, _enumed(k, _value(v, ctx))))

	## --- 2. 关卡属性（[resource] 段）---
	var is_one_shot := false
	var prop_lines: Array[String] = []
	for kv in (p.res_props as Array):
		var k: String = kv[0]
		var v: String = kv[1]
		if k in SKIP_KEYS:
			continue
		if k == "timeline":
			var tl: Dictionary = (p.subs as Dictionary).get(_first_quoted(v), {})
			is_one_shot = _has_prop(tl, "is_one_shot", "true")
			continue
		for c in ((p.res_comments as Dictionary).get(k, []) as Array):
			prop_lines.append("\t" + _comment(c))
		prop_lines.append("\t" + _assign(k, _enumed(k, _value(v, ctx))))
	if is_one_shot:
		prop_lines.insert(0, "\tis_one_shot_flow = true")

	## --- 3. run_flow：事件数组平铺成顺序程序 ---
	var flow_lines := _gen_flow(p, ctx)

	## --- 4. 拼文件 ---
	var out: Array[String] = [
		"extends LevelScriptBase",
		"## %s —— 由同目录的 %s 迁移而来" % [path.get_file().get_basename(), path.get_file()],
		"##",
		"## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。",
		"## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。",
	]
	var head_comments: Array = (p.res_comments as Dictionary).get("", [])
	for c in head_comments:
		out.append(_comment(c))
	out.append("")
	out.append("")
	var init_block: Array[String] = []
	init_block.append_array(init_lines)
	if not init_lines.is_empty() and not prop_lines.is_empty():
		init_block.append("")
	init_block.append_array(prop_lines)
	## 没有需要预置的属性就整个不写 _init：GDScript 的空函数体是 Parse Error
	## （批量删属性后曾留下 4 个空壳 _init 编译不过，见 docs/工作记录/2026-10-03_卡槽数改由存档决定.md）
	if not init_block.is_empty():
		out.append("func _init() -> void:")
		out.append_array(init_block)
		out.append("")
		out.append("")
	out.append("func run_flow(%s: MainGameManager) -> void:" % ("mg" if _uses_mg(flow_lines) else "_mg"))
	if flow_lines.is_empty():
		out.append("\tpass")
	out.append_array(flow_lines)

	var dst := path.get_base_dir() + "/" + path.get_file().get_basename() + ".gd"
	var f := FileAccess.open(dst, FileAccess.WRITE)
	if f == null:
		a.log("  [FAIL] %s 写不了 %s" % [path.get_file(), dst])
		return false
	var text := ""
	for l in out:
		text += _strip_typed_dicts(l) + "\n"
	f.store_string(text)
	f.close()
	a.log("  [OK] %s → %s" % [path.get_file(), dst.get_file()])
	return true


## 时间轴容器 + 它引用的事件：这些不生成到 _init（已转成 run_flow 里的 await）
func _timeline_ids(p: Dictionary) -> Dictionary:
	var ids := {}
	for kv in (p.res_props as Array):
		if kv[0] != "timeline":
			continue
		var tl_id := _first_quoted(kv[1])
		ids[tl_id] = true
		var tl: Dictionary = (p.subs as Dictionary).get(tl_id, {})
		for eid in _sub_ids_in(_prop_value(tl, "events")):
			ids[eid] = true
		break
	return ids


## 事件数组 → run_flow 里的 await 序列（顺序结构，一条事件一行 await）
func _gen_flow(p: Dictionary, ctx: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var timeline_id := ""
	for kv in (p.res_props as Array):
		if kv[0] == "timeline":
			timeline_id = _first_quoted(kv[1])
			break
	if timeline_id == "" or not (p.subs as Dictionary).has(timeline_id):
		return lines
	var events := _prop_value((p.subs as Dictionary)[timeline_id], "events")
	for sid in _sub_ids_in(events):
		var ev: Dictionary = (p.subs as Dictionary).get(sid, {})
		var script_path := _ext_path(ev.script_path, p.exts)
		var method: String = EVENT_METHOD.get(script_path.get_file(), "")
		if method == "":
			lines.append("\t## [未识别的事件] %s" % script_path.get_file())
			continue
		var note := _prop_value(ev, "note").trim_prefix("\"").trim_suffix("\"")
		if _has_prop(ev, "is_enabled", "false"):
			lines.append("\t## [已禁用] %s" % note)
			continue
		var args: Array[String] = []
		for arg_name in EVENT_ARGS:
			var raw := _prop_value(ev, arg_name)
			if raw != "":
				args.append(_enumed_array(arg_name, _value(raw, ctx)))
		var call := "await %s(%s)" % [method, ", ".join(args)]
		if _has_prop(ev, "is_first_round_only", "true"):
			## 教程：播不播由关卡脚本自己判（已通关过就跳过，见 LevelScriptBase.is_curr_level_success）
			var cond := "mg.curr_game_round == 1"
			if method == "tutorial":
				cond += " and not is_curr_level_success()"
			lines.append("\tif %s:" % cond)
			lines.append("\t\t## %s（仅第 1 轮）" % note)
			lines.append("\t\t" + call)
		else:
			lines.append("\t## %s" % note)
			lines.append("\t" + call)
	return lines
#endregion


#region .tres 解析

func _parse(src: String) -> Dictionary:
	var exts := {}          ## ExtResource id → 路径
	var subs := {}          ## SubResource id → {script_path, props, comments}
	var subs_order: Array[String] = []
	var res_props := []     ## [[key, value]]
	var res_comments := {}  ## 属性名 → 注释行数组（"" = 文件头）
	var cur := ""
	var anchor := ""
	var pending := ""       ## 跨多行的值（括号还没闭合：多行字典 / 多行数组）
	for line in src.split("\n"):
		var s := line.strip_edges()
		if pending != "":
			## 多行值还没收尾：整行照收（保留原缩进），等括号闭合
			pending += "\n" + line
			if _depth(pending) <= 0:
				anchor = _commit_prop(cur, subs, res_props, anchor, pending)
				pending = ""
			continue
		if s.begins_with("[ext_resource"):
			exts[_first_quoted_after(s, "id=")] = _first_quoted_after(s, "path=")
			cur = ""
			continue
		if s.begins_with("[sub_resource"):
			var sid := _first_quoted_after(s, "id=")
			subs[sid] = {"script_path": "", "props": [], "comments": {}}
			subs_order.append(sid)
			cur = "sub:" + sid
			anchor = ""
			continue
		if s.begins_with("[resource]"):
			cur = "res"
			anchor = ""
			continue
		if s.is_empty():
			continue
		if s.begins_with(";"):
			## 注释按「所属属性名」归档，取用时插回那个属性前面
			if cur == "res":
				_push_comment(res_comments, anchor, line)
			elif cur.begins_with("sub:"):
				_push_comment(((subs[cur.substr(4)] as Dictionary).comments as Dictionary), anchor, line)
			continue
		if s.begins_with("["):
			cur = ""
			continue
		if _depth(s) > 0:
			## 值在这一行没写完（多行字典 / 多行数组），攒起来等闭合
			pending = s
			continue
		anchor = _commit_prop(cur, subs, res_props, anchor, s)
	return {
		"exts": exts,
		"subs": subs,
		"subs_order": subs_order,
		"res_props": res_props,
		"res_comments": res_comments,
	}


## 把一行 `key = value` 存进对应容器，返回新的 anchor（后面的注释归到这个属性名下）
func _commit_prop(cur: String, subs: Dictionary, res_props: Array, anchor: String, line: String) -> String:
	var eq := line.find("=")
	if eq <= 0:
		return anchor
	var k := line.substr(0, eq).strip_edges()
	var v := line.substr(eq + 1).strip_edges()
	if cur == "res":
		res_props.append([k, v])
	elif cur.begins_with("sub:"):
		var sub: Dictionary = subs[cur.substr(4)]
		if k == "script":
			sub.script_path = v
		else:
			(sub.props as Array).append([k, v])
	return k


## 括号净深度（忽略字符串里的括号）：0 = 这一段写完整了
func _depth(s: String) -> int:
	var depth := 0
	var in_str := false
	for i in s.length():
		var ch := s[i]
		if in_str:
			if ch == "\"":
				in_str = false
			continue
		if ch == "\"":
			in_str = true
			continue
		if ch in "([{":
			depth += 1
		elif ch in ")]}":
			depth -= 1
	return depth


func _push_comment(bucket: Dictionary, anchor: String, line: String) -> void:
	if not bucket.has(anchor):
		bucket[anchor] = []
	(bucket[anchor] as Array).append(line)


## 值表达式 → GDScript 表达式
##   SubResource("X") → 脚本里那个内联对象的变量名
##   ExtResource("Y") → preload(路径)
##   Array[...]([...]) → [元素]（typed array 由 _assign 决定用 .assign()）
func _value(v: String, ctx: Dictionary) -> String:
	v = v.strip_edges()
	if v.begins_with("SubResource("):
		return (ctx.var_names as Dictionary).get(_first_quoted(v), "null") as String
	if v.begins_with("ExtResource("):
		var p: String = (ctx.exts as Dictionary).get(_first_quoted(v), "")
		if p == "":
			return "null"
		return "preload(\"%s\")" % p
	if v.begins_with("Array["):
		var parts := PackedStringArray([])
		for item in _array_items(v):
			parts.append(_value(item, ctx))
		return "[%s]" % ", ".join(parts)
	if v.begins_with("Dictionary["):
		## typed 字典：剥掉 Dictionary[K, V](...) 这层壳，留下 {...} 字面量
		var i := v.find("(")
		if i < 0:
			return "{}"
		return v.substr(i + 1, v.length() - i - 2).strip_edges()
	return v


## typed array / typed dict 字段要用 .assign()，直接 `=` 会因类型不匹配编译不过
func _assign(target: String, expr: String) -> String:
	## `metadata/_custom_type_script` 这类是 .tres 的编辑器元数据、不是真属性，
	## 生成 `x.metadata/... = ...` 会编译失败，统一丢掉
	if target.contains("metadata/"):
		return "# (已丢弃 .tres 编辑器元数据 %s = %s)" % [target, expr]
	if expr.begins_with("[") or expr.begins_with("{"):
		return "%s.assign(%s)" % [target, expr]
	return "%s = %s" % [target, expr]


## 脚本路径 → class_name（读不到就退回 preload(...)，由它 .new()）
func _class_of(script_path: String) -> String:
	var src := FileAccess.get_file_as_string(script_path)
	if src == "":
		return 'preload("%s")' % script_path
	for line in src.split("\n"):
		var s := line.strip_edges()
		if s.begins_with("class_name "):
			return s.substr("class_name ".length()).strip_edges()
	return 'preload("%s")' % script_path


## ExtResource("x") → 实际路径
func _ext_path(v: String, exts: Dictionary) -> String:
	if v.begins_with("ExtResource("):
		return exts.get(_first_quoted(v), "")
	return v


func _first_quoted(s: String) -> String:
	return _first_quoted_after(s, "")


## 取 s 里第一对引号之间的内容；prefix 非空时只在该前缀之后找
func _first_quoted_after(s: String, prefix: String) -> String:
	var from := 0
	if prefix != "":
		from = s.find(prefix)
		if from < 0:
			return ""
		from += prefix.length()
	var a := s.find("\"", from)
	if a < 0:
		return ""
	var b := s.find("\"", a + 1)
	if b < 0:
		return ""
	return s.substr(a + 1, b - a - 1)


## 取 .tres 数组字面量 `Array[...]([a, b])` 的顶层元素（去掉外层方括号）
func _array_items(v: String) -> PackedStringArray:
	var inner := v
	var i := v.find("](")
	if i >= 0:
		inner = v.substr(i + 2, v.length() - i - 3)
	elif v.begins_with("Array("):
		inner = v.substr(6, v.length() - 7)
	inner = inner.strip_edges()
	if inner.begins_with("[") and inner.ends_with("]"):
		inner = inner.substr(1, inner.length() - 2)
	return _split_top(inner)


## 括号感知地按顶层逗号切分（元素里可能有 Vector2i(3, 5) 这种内含逗号的）
func _split_top(s: String) -> PackedStringArray:
	var out := PackedStringArray([])
	var depth := 0
	var cur := ""
	var in_str := false
	for i in s.length():
		var ch := s[i]
		if in_str:
			cur += ch
			if ch == "\"":
				in_str = false
			continue
		if ch == "\"":
			in_str = true
			cur += ch
			continue
		if ch in "([{":
			depth += 1
		elif ch in ")]}":
			depth -= 1
		if ch == "," and depth == 0:
			out.append(cur.strip_edges())
			cur = ""
			continue
		cur += ch
	if cur.strip_edges() != "":
		out.append(cur.strip_edges())
	return out


## 取字典里某属性的原始值（没有则返回 ""）
func _prop_value(d: Dictionary, key: String) -> String:
	for kv in (d.get("props", []) as Array):
		if kv[0] == key:
			return kv[1]
	return ""


func _has_prop(d: Dictionary, key: String, expect: String) -> bool:
	return _prop_value(d, key) == expect


## 从 `events = ...([SubResource("A"), ...])` 里按序取出 SubResource id
func _sub_ids_in(v: String) -> Array[String]:
	var out: Array[String] = []
	for item in _array_items(v):
		var s := item.strip_edges()
		if s.begins_with("SubResource("):
			out.append(_first_quoted(s))
	return out


func _uses_mg(lines: Array[String]) -> bool:
	for l in lines:
		if l.contains("mg."):
			return true
	return false


## `;` 注释行 → `##` 注释行
func _comment(line: String) -> String:
	return "##" + line.strip_edges().trim_prefix(";")


## 剥掉 typed 字典的构造壳：`Dictionary[K, V]({...})` → `{...}`
## 顶层那个 _value() 已经剥过，但嵌在数组 / 字典里层的还在
## （比如 pot_config_on_round 里一层层的罐子配置），GDScript 不认这种构造语法，
## 所以写文件前对整行统一扫一遍（递归，处理任意层嵌套）
func _strip_typed_dicts(text: String) -> String:
	var out := ""
	var i := 0
	while i < text.length():
		if text.substr(i, 11) != "Dictionary[":
			out += text[i]
			i += 1
			continue
		var p := text.find("(", i)
		if p < 0:
			out += text.substr(i)
			break
		var depth := 0
		var end := -1
		var j := p
		while j < text.length():
			var ch := text[j]
			if ch == "(":
				depth += 1
			elif ch == ")":
				depth -= 1
				if depth == 0:
					end = j
					break
			j += 1
		if end < 0:
			out += text.substr(i)
			break
		out += _strip_typed_dicts(text.substr(p + 1, end - p - 1))
		i = end + 1
	return out


## 是不是裸整数（枚举字段要拿它反查成员名）
func _is_int(s: String) -> bool:
	return s != "" and s.is_valid_int()


## 枚举字段的裸 int → `Type.Member`（查不到成员名就原样返回，由人工补）
## 顶层属性和内联子资源的属性都走这里（按字段名匹配 ENUM_FIELDS）
func _enumed(key: String, expr: String) -> String:
	var enum_info: Array = ENUM_FIELDS.get(key, [])
	if enum_info.is_empty() or not _is_int(expr):
		return expr
	var member: String = (_enum_names(enum_info[0], enum_info[1]) as Dictionary).get(expr, "")
	if member == "":
		return expr
	return "%s.%s.%s" % [enum_info[2], enum_info[1], member]


## 枚举**数组**参数（出怪表）：元素是裸 int 时逐项换成 `Type.Member`
## 单个元素的转换直接复用 _enumed()，这里只负责拆数组再拼回去
func _enumed_array(key: String, expr: String) -> String:
	if not ENUM_FIELDS.has(key) or not expr.begins_with("["):
		return expr
	var parts := PackedStringArray([])
	for item in _split_top(expr.substr(1, expr.length() - 2)):
		parts.append(_enumed(key, item.strip_edges()))
	return "[%s]" % ", ".join(parts)


## 读脚本里的 enum 定义，得到「值 → 成员名」（隐式值按声明顺序递增，显式 `= n` 会重置计数）
func _enum_names(script_path: String, enum_name: String) -> Dictionary:
	var out := {}
	var src := FileAccess.get_file_as_string(script_path)
	if src == "":
		return out
	var in_enum := false
	var idx := 0
	for line in src.split("\n"):
		var s := line.strip_edges()
		if not in_enum:
			## `enum Name {` / `enum Name{` 两种写法都要认（花括号前可能有空格）
			if s.begins_with("enum "):
				var rest := s.substr("enum ".length()).strip_edges()
				if rest.begins_with(enum_name) and rest.substr(enum_name.length()).strip_edges().begins_with("{"):
					in_enum = true
					idx = 0
			continue
		if s.begins_with("}"):
			break
		var code := s.split("##")[0].strip_edges()
		if code == "":
			continue
		var parts := code.split("=")
		var name_part := parts[0].strip_edges().trim_suffix(",")
		if not name_part.is_valid_identifier():
			continue
		if parts.size() > 1 and parts[1].strip_edges().trim_suffix(",").is_valid_int():
			idx = parts[1].strip_edges().trim_suffix(",").to_int()
		out[str(idx)] = name_part
		idx += 1
	return out


func _list_tres(root: String) -> Array[String]:
	var out: Array[String] = []
	var dirs := [root]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		var da := DirAccess.open(d)
		if da == null:
			continue
		for name in da.get_files():
			if name.ends_with(".tres"):
				out.append(d + "/" + name)
		for name in da.get_directories():
			if name != "script":
				dirs.append(d + "/" + name)
	out.sort()
	return out
#endregion
