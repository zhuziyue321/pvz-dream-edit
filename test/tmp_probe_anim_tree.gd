extends SceneTree
## 临时探针：用**真正的 AnimComponentNorm** 去问「此刻在播哪条、播到第几秒」
##
## 判据：`anim_name_now` 非空且真的是动画库里的一条动画，`anim_position_now >= 0`
## （这正是 netplay_state_sync.gd 采的东西 —— 空了就变成下标 255，客户端从不接管）
##
## ⚠️ 没用真实场景实例化：工程里塞/abs lone 的角色实例要一堆上下文。
##    这里把场景里的**树根子资源**和**动画库**捞出来，临时搭一个
##    「AnimationPlayer + AnimationTree + AnimComponentNorm」的小布景来跑，
##    问的是同一个组件的同一套代码，跑出来的结论一样有效。

const FRAMES := 20

func _initialize() -> void:
	var rows := _load_manifest()
	var ok := 0
	var bad := []
	for row in rows:
		var info: Dictionary = await _probe(row)
		print(info["text"])
		if bool(info["ok"]):
			ok += 1
		else:
			bad.append(str(info["text"]))
	print("[SUMMARY] total=", rows.size(), " ok=", ok, " bad=", bad.size())
	quit()


func _load_manifest() -> Array:
	var txt := FileAccess.get_file_as_string("res://tools/tmp_manifest.json")
	var parsed = JSON.parse_string(txt)
	return parsed if parsed is Array else []


func _probe(row: Dictionary) -> Dictionary:
	var scene: String = str(row.get("scene", ""))
	var root_id: String = str(row.get("root", ""))
	## ⚠️ 必须先整包 load 一遍场景并且**把句柄留在变量里**：
	## `res://x.tscn::SubId` 这种「内部资源路径」依赖 Godot 已经把场景读进来；
	## 而 Resource 是引用计数的，场景句柄不当场留住就会被立刻释放，后面又取不到子资源。
	var packed = load("res://" + scene)
	var treeroot = load("res://" + scene + "::" + root_id)
	if treeroot == null:
		return {"ok": false, "text": "FAIL load-tree-root %s::%s" % [scene, root_id]}

	var holder := Node2D.new()
	root.add_child(holder)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	holder.add_child(player)
	for entry in row.get("libs", []):
		var parts: PackedStringArray = str(entry).split("|")
		if parts.size() < 3:
			continue
		var lib = null
		if parts[1] == "sub":
			lib = load("res://" + scene + "::" + parts[2])
		else:
			lib = load("res://" + parts[2])
		if lib == null:
			holder.free()
			return {"ok": false, "text": "FAIL load-lib %s::%s" % [scene, entry]}
		player.add_animation_library(parts[0], lib)

	var tree := AnimationTree.new()
	tree.name = "AnimationTree"
	holder.add_child(tree)
	tree.tree_root = treeroot
	tree.anim_player = tree.get_path_to(player)
	tree.active = true

	var comp := Node2D.new()
	comp.name = "AnimComponent"
	comp.set_script(load("res://src/entities/character/components/anim_component/component_anim_norm.gd"))
	holder.add_child(comp)
	for _i in FRAMES:
		await self.process_frame

	var anim := String(comp.anim_name_now)
	var pos := float(comp.anim_position_now)
	var has := player.has_animation(anim) if anim != "" else false
	holder.free()

	if anim == "":
		if str(root_id).begins_with("AnimationNodeBlendTree") and _start_transition_has_expression(treeroot):
			return {"ok": true, "text": "SKIP %-58s (Start 处的 advance_expression 依赖宿主变量，裸树无法起步)" % scene}
		return {"ok": false, "text": "FAIL empty-anim %s::%s" % [scene, root_id]}
	if not has:
		return {"ok": false, "text": "FAIL not-a-library-anim %-46s anim=%s" % [scene, anim]}
	if pos < 0.0:
		return {"ok": false, "text": "FAIL bad-pos %s" % scene}
	return {"ok": true, "text": "OK   %-58s anim=%-32s pos=%.3f" % [scene, anim, pos]}


## 这棵树 Start 出去的转移有没有写 `advance_expression`？
## 有的话裸树必然卡在 Start（宿主变量不存在），属于探针环境限制，不是改造问题。
func _start_transition_has_expression(treeroot) -> bool:
	var sm = treeroot.get_node(&"StateMachine") if treeroot is AnimationNodeBlendTree else null
	if sm == null:
		return false
	for i in sm.get_transition_count():
		if String(sm.get_transition_from(i)) != "Start":
			continue
		var tr = sm.get_transition(i)
		if tr != null and str(tr.get("advance_expression")) != "":
			return true
	return false
