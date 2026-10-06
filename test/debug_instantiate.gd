extends SceneTree

func _init() -> void:
	var map: Resource = load("res://data/map/map_front.tres")
	if map == null:
		print("map_front load failed")
		quit(1)
		return
	var scene: PackedScene = map.map_bg_scene
	if scene == null:
		print("map_bg_scene is null")
		quit(1)
		return
	print("scene path=%s" % scene.resource_path)
	var st = scene.get_state()
	if st != null:
		print("node count=%d, root parent idx=%d, root name=%s" % [st.get_node_count(), st.get_node_parent(0), st.get_node_name(0)])
	var inst = scene.instantiate()
	print("instantiate result=%s" % str(inst))
	quit(0)
