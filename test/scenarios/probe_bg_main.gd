extends Node

func _ready():
	var paths := [
		"res://src/world/background/main_game_bg_front.tscn",
		"res://src/world/background/main_game_bg_pool.tscn",
		"res://src/world/background/main_game_bg_roof.tscn",
		"res://src/world/background/main_game_bg_front_5row.tscn",
	]
	for p in paths:
		var scn = load(p)
		if scn == null:
			print("FAIL load ", p)
			continue
		var inst = scn.instantiate()
		var home = inst.get_node_or_null("Home")
		var roof = inst.get_node_or_null("RoofSlope")
		if home != null:
			print(p, "  OK root=", inst.get_class(), " home_class=", home.get_class(), " isMainGameHome=", home is MainGameHome, " roof=", roof != null)
		else:
			print(p, "  HOME_NULL")
	get_tree().quit()
