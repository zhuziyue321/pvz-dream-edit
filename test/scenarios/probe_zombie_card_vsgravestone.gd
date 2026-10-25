extends RefCounted
## 探针：模组「僵尸卡」的产脑光墓碑（DLC 对战墓碑 VSGravestone → 运行期植物）
##
## 场景 = 玩家对战（走 `probe_player_battle_mod.gd` 同一条进关路）：
##   ① 素材可加载（动画场景 / 两段动画 / 实体场景）
##   ② 僵尸卡模组装上后：注册表登记（50 脑光 / 7.5 s 冷却）、AllCards 有卡模板、卡面画好
##   ③ 对战选卡面板末尾有墓碑候选；点它 → 落僵尸块（第 6~11 格）
##   ④ 收尾进主游戏：货币路由 —— 墓碑卡问脑子池（150 起始，够花）；用卡扣脑子
##   ⑤ 种下去（真实种植条件判定，落位资格跟僵尸走）：动画两段在、待机在播、产脑子组件在
##   ⑥ 产脑子：组件立即产一次 → 银行脑子 +25
##   ⑦ 收尾：关僵尸卡模组 → 注册表 / 卡片目录全撤
## 机器可读汇总：最后一行 [ZOMBIE_CARD_TOMB] result=PASS|FAIL failed=<n>
##
## 无头可跑：`powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_zombie_card_vsgravestone`

const Settings := preload("res://mods_builtin/zombie_card/zombie_card_settings.gd")
const TombstoneScript := preload("res://mods_builtin/zombie_card/vsgravestone/vsgravestone_plant.gd")

## 产一次脑子后等光效弹出（秒）
const PRODUCE_WAIT := 0.6

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：僵尸卡 · 产脑光墓碑（玩家对战） ==========")
	var mod_script := ModManager.load_mod_asset(ModIds.ZOMBIE_CARD, "zombie_card_mod.gd")
	_check(a, "模组入口脚本可加载", mod_script != null)
	var anim_scene := ModManager.load_mod_asset(ModIds.ZOMBIE_CARD, "animation/character/plant/VSGravestone/VSGravestone.tscn")
	_check(a, "动画场景（部件树）可加载", anim_scene != null)
	var idle_anim := ModManager.load_mod_asset(ModIds.ZOMBIE_CARD, "animation/character/plant/VSGravestone/VSGravestone_idle.tres")
	var rise_anim := ModManager.load_mod_asset(ModIds.ZOMBIE_CARD, "animation/character/plant/VSGravestone/VSGravestone_rise.tres")
	_check(a, "idle / rise 两段动画可加载", idle_anim != null and rise_anim != null)
	var plant_scene := ModManager.load_mod_asset(ModIds.ZOMBIE_CARD, "vsgravestone/plant_vsgravestone.tscn") as PackedScene
	_check(a, "实体场景可加载", plant_scene != null)

	## 僵尸卡模组装上（注册运行期植物；玩家对战选关页由 player_battle 模组注入）
	## ★ 先关再开：模组可能随存档默认就是开着的（开局已 install 过一次），
	##   直接再开一次会「卡牌身份重复注册」，卸载也只摘得到后装的那份
	ModManager.set_mod_enabled(ModIds.ZOMBIE_CARD, false)
	await a.wait(0.5)
	ModManager.set_mod_enabled(ModIds.ZOMBIE_CARD, true)
	await a.wait(1.0)
	var plant_id: StringName = Settings.TOMBSTONE_PLANT_ID
	_check(a, "注册表里有这株运行期植物", Global.character_registry.is_runtime_plant(plant_id))
	var sun_cost: int = Global.character_registry.get_plant_info(
		plant_id, CharacterRegistry.PlantInfoAttribute.SunCost)
	var cool_time: float = Global.character_registry.get_plant_info(
		plant_id, CharacterRegistry.PlantInfoAttribute.CoolTime)
	_check(a, "脑子价 = 50", sun_cost == Settings.TOMBSTONE_SUN_COST, str(sun_cost))
	_check(a, "冷却 = 7.5 秒", absf(cool_time - Settings.TOMBSTONE_COOL_TIME) < 0.01, str(cool_time))
	var ref := ResourceCardReference.create(ResourceCardReference.CardType.Plant, plant_id)
	_check(a, "AllCards 里有它的卡模板", AllCards.has_template(ref))

	## ---- 进玩家对战（照 probe_player_battle_mod.gd 的路：木牌 → 选关页 → 点那一关） ----
	var root := (Engine.get_main_loop() as SceneTree).root
	await a.wait_stable("/root/StartMenu", 8.0)
	ModManager.set_mod_enabled(ModIds.PLAYER_BATTLE, true)
	await a.wait(0.5)
	var start_menu := root.get_node_or_null("StartMenu")
	var sign_btn: TextureButton = null
	if start_menu != null:
		sign_btn = start_menu.get_node_or_null("WoodSign/ButtonMultiplayer") as TextureButton
	if sign_btn == null:
		_check(a, "主菜单上找得到「MULTIPLAYER」牌", false)
		_finish(a)
		return
	sign_btn.emit_signal("pressed")
	await a.wait(2.0)
	var page := root.get_node_or_null("ChooseLevel")
	_check(a, "进了玩家对战选关界面", page != null)
	var btn: ChooseLevelButton = null
	if page != null:
		var grid := page.get_node_or_null("AllPage/GridContainer")
		if grid != null:
			for child in grid.get_children():
				if child is ChooseLevelButton:
					btn = child
					break
	if btn == null:
		_check(a, "选关页里找得到「玩家对战：白天」条目", false)
		_finish(a)
		return
	ModManager.set_mod_enabled(ModIds.ZOMBIE_CARD, true)
	btn.get_node("TextureButton").emit_signal("pressed")
	var entered: bool = await a.wait_scene("main_game", 20.0)
	_check(a, "进了对战主游戏", entered)
	var mg = await _wait_main_game(a, 10.0)
	if mg == null or not is_instance_valid(mg):
		_check(a, "主游戏已起来", false)
		_finish(a)
		return

	## ---- 选卡面板：末尾有墓碑候选；点它落僵尸块 ----
	var norm = mg.card_manager.card_slot_norm
	var panel = norm.get_node_or_null("ZombieCardChoosePanel") if norm != null else null
	_check(a, "选僵尸卡面板装上了", panel != null)
	var slot = mg.card_manager.card_slot_battle
	var tombstone_container: Control = null
	if panel != null:
		var card_scroll = panel.get_node("PageHolder/CardScroll")
		var grid = card_scroll.get_child(0) if card_scroll != null \
			and card_scroll.get_child_count() > 0 else null
		if grid != null:
			for container in grid.get_children():
				var c = container.card
				if c != null and c.card_type == ResourceCardReference.CardType.Plant \
						and c.card_plant_type == plant_id:
					tombstone_container = container
					break
		_check(a, "面板末尾有墓碑候选（植物类卡）", tombstone_container != null)
		if tombstone_container != null:
			## 诊断卡面：种子包底图 + 卡面形象里带贴图的精灵数（灰包多半是脸没画出来）
			var cand_card: Card = tombstone_container.card
			a.log("   [诊断] card_bg.texture = %s" % str(cand_card.card_bg.texture))
			_dump_face(a, cand_card.character_static, "候选卡")
			_dump_face(a, AllCards.get_template(ref).character_static, "模板卡")
		## 等面板滑入（跟拍本体待选区），到位才点得动
		var waited := 0.0
		while is_instance_valid(mg) and waited < 20.0 \
				and not is_equal_approx(panel.position.y, 89.0):
			await a.wait(0.25)
			waited += 0.25
		_screenshot(a, "tomb_card_panel")
		if tombstone_container != null:
			tombstone_container.card.signal_card_click.emit()
			await a.wait(0.5)
			_screenshot(a, "tomb_card_slot")
			_check(a, "点候选 → 墓碑卡落进僵尸块（第 6~11 格）",
				_find_tombstone_card_index(slot) >= 6,
				"在第 %d 格" % _find_tombstone_card_index(slot))
			var tomb_card: Card = slot.curr_cards[_find_tombstone_card_index(slot)]
			_check(a, "墓碑卡脑子价 = 50", tomb_card != null and tomb_card.sun_cost == 50,
				str(tomb_card.sun_cost) if tomb_card != null else "no card")

	## ---- 收尾：跳过点「开始战斗」，直接 finish（对战探针同款） ----
	if panel != null:
		panel.finish_choose()
	await a.wait(2.0)
	var pvp_wiring = mg.get_node_or_null("ZombieCardPvpWiring")
	_check(a, "对战接线在（脑子账本挂它上面）", pvp_wiring != null)

	## ---- 种下去：走真实种植条件判定（落位资格跟僵尸走） ----
	var planted: Plant000Base = null
	var judge: ResourcePlantCondition = Global.character_registry.get_plant_info(
		plant_id, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	var eligible := 0
	for row in mg.plant_cell_manager.all_plant_cells:
		for cell in row:
			if cell != null and judge.judge_is_can_plant(cell, plant_id):
				eligible += 1
				if planted == null:
					planted = cell.create_plant(plant_id, false)
	_check(a, "判得出可种格（对战空关无禁种标记，任意空草地都行）", eligible > 0, "%d 个" % eligible)
	_check(a, "种得下去", planted != null)
	if planted != null:
		## 卡面是延迟绘制的：进关跑了这么久早该画好，这里补一道确认
		var template := AllCards.get_template(ref)
		_check(a, "卡模板的卡面已画好（character_static 非空）",
			template != null and is_instance_valid(template.character_static)
			and template.character_static.get_child_count() > 0)
		_check(a, "根节点脚本正确", planted.get_script() == TombstoneScript)
		var anim_root := planted.get_node_or_null("Body/VSGravestoneMask/VSGravestoneAnim")
		_check(a, "动画节点在且无缩放", anim_root != null and anim_root.scale == Vector2.ONE)
		var mask := planted.get_node_or_null("Body/VSGravestoneMask")
		_check(a, "出土裁剪板在且开了 clip_children",
			mask != null and mask.clip_children == CanvasItem.CLIP_CHILDREN_ONLY)
		var anim_lib: AnimationPlayer = planted.get_node_or_null(
			"Body/VSGravestoneMask/VSGravestoneAnim/AnimLib")
		_check(a, "AnimLib 在且有两段动画",
			anim_lib != null and anim_lib.has_animation(&"VSGravestone_idle")
			and anim_lib.has_animation(&"VSGravestone_rise"))
		## 出土 0.5 s 播完回待机（待机是 0 长度静帧，播完 `current_animation` 不一定还挂着名），
		## 所以直接验**姿态**：出土/立定后 Stone 部件应停在 idle 第 0 帧的位置
		await a.wait(0.8)
		var stone_node: Node2D = anim_root.get_node_or_null("Stone") if anim_root != null else null
		_check(a, "出土播完立定（Stone 停在 idle 姿态位）",
			stone_node != null and stone_node.position == Vector2(-3, 6.3),
			str(stone_node.position) if stone_node != null else "no node")
		var comp = planted.get_node_or_null("CreateSunComponent")
		_check(a, "产脑子组件在（脚本 = 模组子类）", comp != null \
			and comp.get_script() == preload("res://mods_builtin/zombie_card/vsgravestone/component_create_brains.gd"))

		## ---- 立即产一颗：像向日葵一样弹跳落地，点收才入脑子账 ----
		if comp != null and pvp_wiring != null:
			var before: int = pvp_wiring._brains
			comp.create_sun()
			await a.wait(1.2)
			var brain_sun: Node = null
			var suns = mg.get_node_or_null("Suns")
			if suns != null:
				for node in suns.get_children():
					if node.get_node_or_null("ZombieCardBrainSun") != null:
						brain_sun = node
						break
			_check(a, "产出了一颗脑子阳光（BrainSun 皮挂在上面）", brain_sun != null)
			_check(a, "没点收之前不入账", pvp_wiring._brains == before,
				"%d" % pvp_wiring._brains)
			if brain_sun != null:
				_check(a, "脑子阳光换了收账脚本", brain_sun.get_script() == preload(
					"res://mods_builtin/zombie_card/vsgravestone/sun_brain.gd"))
				## 落点该是右上银行（x 在右半屏），不是左上植物卡槽的阳光计数
				var brain_target: Vector2 = pvp_wiring.get_brain_fly_target()
				var plant_target: Vector2 = mg.marker_2d_sun_target.global_position \
					+ mg.camera_2d.global_position if is_instance_valid(mg.marker_2d_sun_target) \
					else Vector2.ZERO
				_check(a, "脑光落点在右上银行（x > 400）", brain_target.x > 400.0, str(brain_target))
				_check(a, "脑光落点 ≠ 植物阳光计数", plant_target == Vector2.ZERO
					or brain_target.distance_to(plant_target) > 1.0,
					"brain=%s plant=%s" % [str(brain_target), str(plant_target)])
				brain_sun.pick()
				await a.wait(0.5)
				_check(a, "点收 → 脑子入账 +25", pvp_wiring._brains == before + 25,
					"%d -> %d" % [before, pvp_wiring._brains])
				var bank = mg.card_manager.card_slot_root.get_node_or_null("ZombieCardBattleSlot")
				var label = bank.get_node_or_null("SunLabelControl/CurrSunValue") if bank != null else null
				_check(a, "银行脑子计数刷新", label != null and label.text == str(before + 25),
					"" if label == null else label.text)

	## ---- 用卡扣脑子：直接走卡片使用结束的扣费回调（不用模拟点击格子） ----
	var tomb_index := _find_tombstone_card_index(slot)
	if tomb_index >= 0 and pvp_wiring != null:
		var tomb_card: Card = slot.curr_cards[tomb_index]
		var before: int = pvp_wiring._brains
		pvp_wiring._on_card_cost(tomb_card)
		_check(a, "用卡 → 扣 50 脑子", pvp_wiring._brains == before - 50,
			"%d -> %d" % [before, pvp_wiring._brains])

	## ---- 收尾：关僵尸卡模组全撤（对战选关页归 player_battle 模组管，不动它） ----
	ModManager.set_mod_enabled(ModIds.ZOMBIE_CARD, false)
	await a.wait(0.5)
	_check(a, "关模组后注册表已清", not Global.character_registry.is_runtime_plant(plant_id))
	_check(a, "关模组后卡片目录已清", not AllCards.has_template(ref))
	_finish(a)


## 递归打印卡面里的带贴图精灵（诊断「种子包一片灰」：脸到底画没画出来）
func _dump_face(a, node: Node, tag: String) -> void:
	if node == null or not is_instance_valid(node):
		a.log("   [诊断] %s：节点为空" % tag)
		return
	var found: Array[String] = []
	_collect_textures(node, found)
	if found.is_empty():
		a.log("   [诊断] %s：没有任何带贴图的精灵！" % tag)
	for line in found:
		a.log("   [诊断] %s %s" % [tag, line])


func _collect_textures(node: Node, found: Array[String]) -> void:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null:
			found.append("sprite '%s' tex=%s pos=%s scale=%s modulate=%s visible=%s" % [
				node.name, sprite.texture.resource_path.get_file(),
				str(sprite.position), str(sprite.scale), str(sprite.self_modulate), str(sprite.visible)])
	for child in node.get_children():
		_collect_textures(child, found)


## 墓碑卡在出战卡槽的第几格（不在返回 -1）
func _find_tombstone_card_index(slot) -> int:
	for i in slot.curr_cards.size():
		var card = slot.curr_cards[i]
		if card != null and card.card_type == ResourceCardReference.CardType.Plant \
				and card.card_plant_type == Settings.TOMBSTONE_PLANT_ID:
			return i
	return -1


## 截一张当前画面（**开窗口跑时**才有内容；无头模式下是空图，存了也没用）
func _screenshot(a, tag: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var img := tree.root.get_texture().get_image()
	if img == null or img.is_empty():
		a.log("   [截图] %s：取不到画面（headless？）" % tag)
		return
	var path := "user://autopilot_reports/shot_%s.png" % tag
	var err := img.save_png(path)
	a.log("   [截图] %s err=%d -> %s" % [tag, err, ProjectSettings.globalize_path(path)])


## 等主游戏起来（场景切过去之后管理器还要一会儿才建好）
func _wait_main_game(a, timeout: float):
	var waited := 0.0
	while waited < timeout:
		var mg = GameContext.curr_main_game
		if mg != null and is_instance_valid(mg):
			return mg
		await a.wait(0.25)
		waited += 0.25
	return null


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  <- " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[ZOMBIE_CARD_TOMB] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
