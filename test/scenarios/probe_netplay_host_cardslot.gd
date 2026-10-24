extends RefCounted
class_name probe_netplay_host_cardslot

const NetplayMod := preload("res://mods_builtin/netplay/netplay_mod.gd")
const LEVEL_SCRIPT := "res://src/levels/mode_adventure/adventure_01_01.gd"
const PORT := 8913

func run(a) -> void:
	a.log("=== host candidate area check (netplay) ===")
	a.log("AllCards catalog.plants = %d" % AllCards.get_seed_chooser_catalog().plants.size())
	a.log("AllCards plant_card_ids = %d" % AllCards.plant_card_ids.size())
	a.log("AllCards all_plant_card_prefabs = %d" % AllCards.all_plant_card_prefabs.size())
	a.log("curr_plant (save) = %d : %s" % [Global.global_game_state.curr_plant.size(), str(Global.global_game_state.curr_plant)])
	## 复刻用户"多植物存档"：解锁全部植物后再进关
	var all_types: Array[StringName] = AllCards.plant_card_ids.keys()
	all_types.append(PlantIds.IMITATER)
	Global.global_game_state.curr_plant = all_types
	a.log("after unlock-all curr_plant = %d" % Global.global_game_state.curr_plant.size())

	if not ModManager.is_mod_enabled(ModIds.NETPLAY):
		ModManager.set_mod_enabled(ModIds.NETPLAY, true)
	await a.frames(5)
	var mod := ModManager.get_mod(ModIds.NETPLAY) as NetplayMod
	var session = mod._ensure_session() if mod != null else null
	if session == null or not session.create_host(PORT):
		a.log("!! 建房间失败")
		a.quit_game()
		return
	a.log("host room up")
	await a.frames(5)

	var script := load(LEVEL_SCRIPT) as GDScript
	var para: ResourceLevelData = script.new()
	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	var t := 0.0
	while (GameContext.curr_main_game == null or not is_instance_valid(GameContext.curr_main_game)) and t < 25.0:
		await a.wait(0.5)
		t += 0.5
	if GameContext.curr_main_game == null:
		a.log("!! 没进成关卡")
		a.quit_game()
		return
	a.log("entered level, phase=%d" % GameContext.curr_main_game.main_game_progress)
	await a.frames(10)

	var mg := GameContext.curr_main_game
	var cand = null
	if mg.card_manager != null and mg.card_manager.card_slot_norm != null:
		cand = mg.card_manager.card_slot_norm.card_slot_candidate
	if cand == null:
		a.log("!! candidate null (card_slot_norm missing?)")
	else:
		a.log("candidate containers (plant) = %d" % cand.all_card_candidate_containers_plant.size())
		var vis := 0
		for c in cand.all_card_candidate_containers_plant.values():
			if c.visible:
				vis += 1
		a.log("candidate VISIBLE (plant) = %d" % vis)
		a.log("candidate containers (imitater) = %d" % cand.all_card_candidate_containers_plant_imitater.size())
	a.quit_game()
