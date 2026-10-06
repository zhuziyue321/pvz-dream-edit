extends RefCounted
## 探针：冒险模式「首次通关掉落本关奖励」代替奖杯
## 覆盖：
##   1. 首次通关 1-2：由僵尸掉一包种子（樱桃炸弹），此时不出奖杯
##   2. 点开种子包 -> 直接结算（不再抛奖杯），回冒险模式选关界面
##   3. 反例：重打 1-2 不再掉奖励，直接出奖杯
##   4. 首次通关 1-4：掉的是铲子（ConstAdventureReward 的道具类奖励，仍走礼物盒）
##   5. 首次通关 2-4：掉的是大图鉴（LEVEL_ITEM_REWARD 第 14 关，原版行为），
##      点开后直接打开图鉴（同 3-4 拿到车钥匙后直接进商店）
##   6. 首次通关 5-4：掉的是禅境花园的洒水壶（LEVEL_ITEM_REWARD 第 44 关）
## 机器可读汇总：最后一行 [ADVREWARD] result=PASS|FAIL failed=<n>

var _failed := 0
const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure


func run(a) -> void:
	a.log("")
	a.log("========== 探针 冒险模式首次通关奖励（代替奖杯）==========")
	## 等主菜单自身初始化完再切场景，否则切场景会撞上「父节点正忙」的报错
	await a.wait(2.0)

	var state = Global.global_game_state

	# ------------------------------------------------ STEP1 首次通关 1-2 掉奖励
	a.log("STEP1 进入 1-2（已通关 1-1，1-2 未通关）")
	_mark_cleared(state, 1)
	if not await _enter_level(a, "adventure_01_02", 0, "0002"):
		_finish(a)
		return

	var temp_before: int = Global.main_game.canvas_layer_temp.get_child_count()
	var new_drop = await _trigger_win_and_find_drop(a)
	if new_drop == null:
		_finish(a)
		return
	_check(a, "掉出了首次通关奖励", true)
	_check(a, "奖励提示里带新植物名（樱桃炸弹）", "樱桃炸弹" in new_drop.tip_text,
		new_drop.tip_text)
	_check_seed_packet(a, new_drop)
	_check(a, "掉奖励时还没抛奖杯",
		Global.main_game.canvas_layer_temp.get_child_count() == temp_before,
		str(temp_before) + " -> " + str(Global.main_game.canvas_layer_temp.get_child_count()))

	# ------------------------------------------------ STEP2 点开奖励直接结算
	a.log("STEP2 点开奖励（应直接结算，不再抛奖杯）")
	new_drop._on_texture_button_pressed()
	await a.wait(8.0)
	_check(a, "点开奖励后直接结算回选关界面",
		"adventure_choose_level" in a.get_tree().current_scene.scene_file_path,
		str(a.get_tree().current_scene.scene_file_path))
	_check(a, "1-2 已写成通关",
		state.curr_all_level_state_data.get("101_0_0002", {}).get("IsSuccess", false))

	# ------------------------------------------------ STEP3 反例：重打不再掉奖励
	a.log("STEP3 重打 1-2（不再掉奖励，直接出奖杯）")
	if not await _enter_level(a, "adventure_01_02", 0, "0002"):
		_finish(a)
		return
	var temp_before2: int = Global.main_game.canvas_layer_temp.get_child_count()
	var parents2 := [
		Global.main_game.drop_item_manager.dim_seed_packet.all_drop_seed_packet_parent,
		Global.main_game.drop_item_manager.dim_garden_plant.all_drop_garden_plant_parent,
	]
	var drop_before2 := 0
	for parent2 in parents2:
		drop_before2 += parent2.get_child_count()
	Global.main_game.reward_manager.create_trophy(Vector2(600, 300))
	await a.wait(1.5)
	var drop_after2 := 0
	for parent2 in parents2:
		drop_after2 += parent2.get_child_count()
	_check(a, "重打不再掉奖励", drop_after2 == drop_before2,
		str(drop_before2) + " -> " + str(drop_after2))
	_check(a, "重打直接出奖杯",
		Global.main_game.canvas_layer_temp.get_child_count() == temp_before2 + 1,
		str(temp_before2) + " -> " + str(Global.main_game.canvas_layer_temp.get_child_count()))

	# ------------------------------------------------ STEP4 道具类奖励：1-4 掉铲子
	a.log("STEP4 首次通关 1-4（掉铲子）")
	_mark_cleared(state, 3)
	if not await _enter_level(a, "adventure_01_04", 0, "0004"):
		_finish(a)
		return
	var shovel_drop = await _trigger_win_and_find_drop(a)
	if shovel_drop == null:
		_finish(a)
		return
	_check(a, "1-4 掉的是铲子贴图", shovel_drop.icon_texture != null
		and "Shovel" in shovel_drop.icon_texture.resource_path,
		str(shovel_drop.icon_texture.resource_path if shovel_drop.icon_texture != null else "null"))
	_check(a, "1-4 奖励提示提到铁铲", "铁铲" in shovel_drop.open_tip_text, shovel_drop.open_tip_text)
	_check(a, "道具奖励仍走礼物盒贴图，不做种子包",
		(shovel_drop is Present) and shovel_drop.icon_texture != null)

	# ------------------------------------------------ STEP5 道具类奖励：2-4 掉大图鉴
	a.log("STEP5 首次通关 2-4（掉大图鉴）")
	_mark_cleared(state, 13)
	if not await _enter_level(a, "adventure_02_04", 1, "0014"):
		_finish(a)
		return
	var almanac_drop = await _trigger_win_and_find_drop(a)
	if almanac_drop == null:
		_finish(a)
		return
	_check(a, "2-4 掉的是大图鉴贴图", almanac_drop.icon_texture != null
		and "Almanac" in almanac_drop.icon_texture.resource_path,
		str(almanac_drop.icon_texture.resource_path if almanac_drop.icon_texture != null else "null"))
	_check(a, "2-4 奖励提示提到大图鉴", "大图鉴" in almanac_drop.open_tip_text,
		almanac_drop.open_tip_text)
	_check(a, "图鉴奖励仍走礼物盒贴图，不做种子包",
		(almanac_drop is Present) and almanac_drop.icon_texture != null)

	# ------------------------------------------------ STEP6 点开大图鉴直接打开图鉴
	a.log("STEP6 点开大图鉴（应直接打开图鉴，不再回选关界面）")
	almanac_drop._on_texture_button_pressed()
	await a.wait(8.0)
	_check(a, "点开大图鉴后直接打开图鉴",
		"almanac" in a.get_tree().current_scene.scene_file_path,
		str(a.get_tree().current_scene.scene_file_path))
	_check(a, "图鉴已解锁", state.is_almanac_unlocked(), str(state.is_almanac_unlocked()))

	# ------------------------------------------------ STEP7 道具类奖励：5-4 掉洒水壶
	a.log("STEP7 首次通关 5-4（掉禅境花园的洒水壶）")
	_mark_cleared(state, 43)
	if not await _enter_level(a, "adventure_05_04", 4, "0044"):
		_finish(a)
		return
	var can_drop = await _trigger_win_and_find_drop(a)
	if can_drop == null:
		_finish(a)
		return
	_check(a, "5-4 掉的是洒水壶贴图", can_drop.icon_texture != null
		and "WateringCan" in can_drop.icon_texture.resource_path,
		str(can_drop.icon_texture.resource_path if can_drop.icon_texture != null else "null"))
	_check(a, "5-4 奖励提示提到洒水壶", "洒水壶" in can_drop.open_tip_text,
		can_drop.open_tip_text)
	_check(a, "洒水壶奖励仍走礼物盒贴图，不做种子包",
		(can_drop is Present) and can_drop.icon_texture != null)

	_finish(a)


#region 断言与工具
## 进关：改存档后切到对应关卡场景，等场景就绪
func _enter_level(a, level_file: String, page: int, level_id: String) -> bool:
	var p = (load("res://src/levels/mode_adventure/" + level_file + ".gd") as GDScript).new()
	p.set_choose_level(ADV, page, level_id)
	Global.game_para = p
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[p.game_sences])
	if not await a.wait_scene("main_game", 15.0):
		_check(a, "进入 " + level_id, false, str(a.get_tree().current_scene))
		return false
	await a.wait(5.0)
	return true


## 触发通关掉落，返回新掉出来的奖励（种子包 / 礼包），没掉出来返回 null
func _trigger_win_and_find_drop(a):
	var dim = Global.main_game.drop_item_manager
	var parents := [
		dim.dim_seed_packet.all_drop_seed_packet_parent,
		dim.dim_garden_plant.all_drop_garden_plant_parent,
	]
	var drop_before := 0
	for parent in parents:
		drop_before += parent.get_child_count()
	Global.main_game.reward_manager.create_trophy(Vector2(600, 300))
	await a.wait(1.5)
	var new_drop: Node = null
	for parent in parents:
		var found := _find_new_drop(parent)
		if found != null:
			new_drop = found
	if new_drop == null:
		var drop_after := 0
		for parent in parents:
			drop_after += parent.get_child_count()
		_check(a, "掉出了首次通关奖励", false, str(drop_before) + " -> " + str(drop_after))
	return new_drop


## 植物奖励是一包种子：视觉逐项对齐出战卡片，而且是独立掉落物（不再包在礼物盒里）
func _check_seed_packet(a, new_drop) -> void:
	var seed_packet := new_drop as SeedPacket
	_check(a, "植物奖励掉的是种子包", seed_packet != null, str(new_drop))
	if seed_packet == null:
		return
	_check(a, "种子包里放了一株植物", seed_packet.plant_container.get_child_count() == 1,
		str(seed_packet.plant_container.get_child_count()))
	_check(a, "种子包点击区域按 100x140",
		abs(seed_packet.texture_button.size.x - 100.0) < 1.0,
		str(seed_packet.texture_button.size))

	## 与樱桃炸弹的出战卡片逐项对照：卡片 50x70，种子包整包放大 2 倍
	var card = AllCards.all_plant_card_prefabs.get(CharacterRegistry.PlantType.P003CherryBomb, null)
	if card == null:
		_check(a, "取到樱桃炸弹的出战卡片", false, str(AllCards.all_plant_card_prefabs.keys()))
		return
	var packet_bg: Sprite2D = seed_packet.get_node(^"SeedPacketBg")
	_check(a, "底图与出战卡片同一张", packet_bg.texture == card.card_bg.texture,
		str(packet_bg.texture.resource_path))
	_check(a, "种子包上写着阳光花费，与卡片一致", seed_packet.cost_label.text == card.cost.text,
		seed_packet.cost_label.text + " vs " + card.cost.text)
	var packet_cost_pos: Vector2 = seed_packet.cost_label.position + packet_bg.texture.get_size() / 2.0
	_check(a, "阳光花费文本位置是卡片的 2 倍", (packet_cost_pos - card.cost.position * 2.0).length() < 1.0,
		str(packet_cost_pos) + " vs " + str(card.cost.position * 2.0))
	_check(a, "阳光花费字号是卡片的 2 倍",
		seed_packet.cost_label.get_theme_font_size("font_size") == card.cost.get_theme_font_size("font_size") * 2,
		str(seed_packet.cost_label.get_theme_font_size("font_size")) + " vs "
			+ str(card.cost.get_theme_font_size("font_size")))

	var card_plant: Node2D = card.get_node(^"CardBg/CharacterStatic").get_child(0)
	var packet_plant: Node2D = seed_packet.plant_container.get_child(0)
	## 卡片底图左上角是 (0,0)，种子包底图居中、左上角是 -size/2，换算回同一原点再比
	var card_plant_pos: Vector2 = card_plant.position + card.get_node(^"CardBg/CharacterStatic").position
	var packet_plant_pos: Vector2 = packet_plant.position + seed_packet.plant_container.position \
		+ packet_bg.texture.get_size() / 2.0
	_check(a, "植物位置是卡片的 2 倍", (packet_plant_pos - card_plant_pos * 2.0).length() < 1.0,
		str(packet_plant_pos) + " vs " + str(card_plant_pos * 2.0))
	_check(a, "植物缩放是卡片的 2 倍", (packet_plant.scale - card_plant.scale * 2.0).length() < 0.01,
		str(packet_plant.scale) + " vs " + str(card_plant.scale * 2.0))


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[ADVREWARD] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}


## 掉落容器里新出现的奖励：种子包（植物类）或礼物盒（道具类）
func _find_new_drop(parent: Node) -> Node:
	var found: Node = null
	for k in parent.get_children():
		if (k is SeedPacket or k is Present) and not bool(k.get("is_opened")):
			found = k
	return found
#endregion
