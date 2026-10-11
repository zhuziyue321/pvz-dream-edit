extends SceneTree
## 探一小撮细节：OneShot 到底有几个输入端口？某些树里的 StateMachine 为什么卡在 Start？

func _initialize() -> void:
	for c in [
		"res://src/entities/character/plant/plant_pea_shooter_single.tscn::AnimationNodeBlendTree_ul06u",
		"res://src/entities/character/plant/plant_sun_flower.tscn::AnimationNodeBlendTree_kbloa",
		"res://src/entities/character/plant/plant_cherry_bomb.tscn::AnimationNodeBlendTree_dniyj",
	]:
		load(String(c).split("::")[0])
		var r = load(c)
		print("== ", c, " root=", r != null)
		if r == null:
			continue
		var names := PackedStringArray([
			"OneShot", "TimeScale 2", "Add2", "Animation 2", "Animation 3", "StateMachine", "TimeScale",
		])
		for n in names:
			if r.has_node(StringName(n)):
				var node = r.get_node(StringName(n))
				print("   %-14s %-28s input_count=%d" % [n, node.get_class(), node.get_input_count()])
	quit()
