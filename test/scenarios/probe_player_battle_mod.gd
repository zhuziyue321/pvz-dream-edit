extends RefCounted

## 探针 玩家对战模组：木牌入口 → 玩家对战选关界面（页里有一关「玩家对战：白天」）
##
## 五段：
##   1. 模组**关着**时：木牌上那块「MULTIPLAYER」牌不显示（没开模组就没有这个入口）
##   2. 模组**开着**时：牌出现了，且注册表槽位 `ChooseLevelPlayerBattle` 注入的是玩家对战选关界面
##   3. 那块牌的常态 / 按下贴图都是多人版，按下能进那一页
##   4. 那一页：标题是「玩 家 对 战」，页里挂着**一个**对局条目「玩家对战：白天」
##   5. 点那一关 ⇒ 进白天的关卡（选卡阶段场上还没有僵尸），验「12 槽合一」：
##      一个 12 格出战卡槽（前 6 植物 / 后 6 僵尸，分块分池），右上反转银行只是外观
##      （僵尸卡模组装的，脑子计数在右）
##   6. 选卡收尾后，关卡每行摆一只**靶子僵尸**（共 5 只，原地不动）
##   7. 退回主菜单也没崩
##
## 无头可跑：`powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_player_battle_mod`

## 僵尸卡面底图问僵尸卡模组的共享常量（所有僵尸卡同一张），探针别另抄一份文件名
const ZombieCardSettings := preload("res://mods_builtin/zombie_card/zombie_card_settings.gd")

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 玩家对战模组 ==========")
	await a.wait_stable("/root/StartMenu", 8.0)
	await a.wait(1.0)

	var mode := MainSceneRegistry.MainScenes.ChooseLevelPlayerBattle
	var map: Dictionary = Global.main_scene_registry.MainScenesMap
	var root := (Engine.get_main_loop() as SceneTree).root

	var start_menu := root.get_node_or_null("StartMenu")
	_check(a, "主菜单已加载", start_menu != null)
	if start_menu == null:
		_finish(a)
		return

	var sign_btn := start_menu.get_node_or_null("WoodSign/ButtonMultiplayer") as TextureButton
	_check(a, "木牌上有「MULTIPLAYER」牌这个节点", sign_btn != null)
	if sign_btn == null:
		_finish(a)
		return

	## ---- 模组关着时：那块牌不该显示 ----
	## （模组默认开着（工程默认 mod_config.tres 里含 &"player_battle"），但玩家存档可能把它关了，
	##   所以这里先显式关一遍、再显式开一遍，两种状态都看一眼）
	ModManager.set_mod_enabled(ModIds.PLAYER_BATTLE, false)
	await a.wait(0.5)
	_check(a, "模组关着时木牌上那块「MULTIPLAYER」牌不显示", not sign_btn.visible)

	## ---- 模组装上：牌出现 + 注册表槽位被注入 ----
	ModManager.set_mod_enabled(ModIds.PLAYER_BATTLE, true)
	await a.wait(0.5)
	_check(a, "模组打开后那块牌出现了", sign_btn.visible)
	var scene_path := str(map.get(mode, ""))
	_check(a, "模组开着时槽位 ChooseLevelPlayerBattle 注入的是玩家对战选关界面",
		scene_path.ends_with("player_battle_choose_level.tscn"), scene_path)

	## ---- 木牌上的「MULTIPLAYER」牌 ----
	var normal_tex := sign_btn.texture_normal
	_check(a, "牌的常态贴图是多人游戏那张（SelectorScreen_WoodSign3.png）",
		normal_tex != null and normal_tex.resource_path.ends_with("SelectorScreen_WoodSign3.png"),
		str(normal_tex))
	var press_tex := sign_btn.texture_pressed
	_check(a, "牌的按下贴图是多人游戏那张（SelectorScreen_WoodSign3_press.png）",
		press_tex != null and press_tex.resource_path.ends_with("SelectorScreen_WoodSign3_press.png"),
		str(press_tex))
	## 换贴图前那块牌是 TextureRect：它的最小尺寸就是贴图尺寸（279x83），
	## 所以牌面本来就是按贴图原大小画的（编辑器里存的 92x40 偏移运行时会被撑大）
	_check(a, "牌的尺寸没动（约 279x83，与换贴图前那张 TextureRect 同一口径）",
		absf(sign_btn.size.x - 279.0) < 1.0 and absf(sign_btn.size.y - 83.0) < 1.0,
		"实际=" + str(sign_btn.size))

	## ---- 按下那张牌 ⇒ 进玩家对战选关界面 ----
	sign_btn.emit_signal("pressed")
	await a.wait(2.0)

	var page = root.get_node_or_null("ChooseLevel")
	_check(a, "按下木牌进了玩家对战选关界面", page != null)
	if page == null:
		_finish(a)
		return
	_check(a, "那一页的 game_mode 就是玩家对战槽位",
		int(page.get("game_mode")) == int(mode), str(page.get("game_mode")))
	var title := page.get_node_or_null("Label") as Label
	_check(a, "标题写着「玩 家 对 战」",
		title != null and title.text == "玩 家 对 战",
		"" if title == null else title.text)

	## ---- 页里的对局条目 ----
	var grid := page.get_node_or_null("AllPage/GridContainer")
	var buttons: Array = []
	if grid != null:
		for child in grid.get_children():
			if child is ChooseLevelButton:
				buttons.append(child)
	_check(a, "页里只有一个对局条目", buttons.size() == 1, "数到 %d 个" % buttons.size())
	if buttons.size() != 1:
		_finish(a)
		return
	var btn: ChooseLevelButton = buttons[0]
	var btn_label := btn.get_node_or_null("TextureButton/Label") as Label
	_check(a, "那个条目写着「玩家对战：白天」",
		btn_label != null and btn_label.text == "玩家对战：白天",
		"" if btn_label == null else btn_label.text)
	_check(a, "条目挂的是本模组自己的关卡脚本",
		btn.level_script != null and btn.level_script.resource_path.ends_with("player_battle_day.gd"),
		"" if btn.level_script == null else btn.level_script.resource_path)
	_check(a, "关卡存档名是 106_0_0001（玩家对战 + 第 0 页 + 第 1 关）",
		btn.curr_level_data_game_para != null \
			and btn.curr_level_data_game_para.save_game_name == "106_0_0001",
		"" if btn.curr_level_data_game_para == null else btn.curr_level_data_game_para.save_game_name)

	## ---- 点那一关 ⇒ 进白天的关卡 ----
	## 对战的僵尸卡槽由「僵尸卡」模组装：先显式开它（默认开，但玩家存档可能关了）
	ModManager.set_mod_enabled(ModIds.ZOMBIE_CARD, true)
	btn.get_node("TextureButton").emit_signal("pressed")
	var entered: bool = await a.wait_scene("main_game", 20.0)
	_check(a, "点了那一关进了主游戏", entered)
	var mg = await _wait_main_game(a, 10.0)
	_check(a, "主游戏已起来", mg != null and is_instance_valid(mg))
	if mg != null and is_instance_valid(mg):
		_check(a, "这一局的关卡数据就是那个空关卡",
			mg.game_para != null and mg.game_para.save_game_name == "106_0_0001",
			"" if mg.game_para == null else mg.game_para.save_game_name)
		_check(a, "这一关不出怪（monster_mode = Null）",
			mg.game_para != null and mg.game_para.monster_mode == ConstLevelData.E_MonsterMode.Null,
			"" if mg.game_para == null else str(mg.game_para.monster_mode))
		## 现在这一关会在**选卡收尾、放开操作之后**每行摆一只靶子僵尸
		## （见 `mods_builtin/player_battle/levels/player_battle_day.gd`）——
		## 所以「场上干净」只在选卡阶段成立，摆靶子的检查放到卡槽检查之后
		var znum := 0
		if mg.zombie_manager != null:
			znum = mg.zombie_manager.all_zombies_1d.size()
		_check(a, "选卡阶段草坪上没有僵尸", znum == 0, "场上 %d 只" % znum)
		await _check_card_slots(a, mg)
		await _check_target_zombies(a, mg)

	## ---- 退回主菜单（空关卡没有结束条件，玩家只能自己退出）----
	GlobalUtils.change_scene(
		Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.StartMenu))
	await a.wait(3.0)
	_check(a, "退回主菜单", root.get_node_or_null("StartMenu") != null)
	_check(a, "退出后主游戏已释放", not is_instance_valid(GameContext.curr_main_game))

	_finish(a)


## ---- 靶子僵尸（每行一只、原地不动）----
##
## 关卡摆靶子是在 `allow_operation()` 之后（选卡收尾那一步），所以这里要轮询等它们出现。
## 「不动」是由靶子自己的脚本按住的（`target_zombie.gd` 的 `ready_norm()` 给移动组件上
## `E_MoveFactor.IsDisable`），探针只读 `move_component.is_move`。
func _check_target_zombies(a, mg) -> void:
	var zm = mg.zombie_manager
	_check(a, "僵尸管理器在", zm != null)
	if zm == null:
		return
	var count := 0
	for _i in range(50):
		await a.wait(0.2)
		count = zm.all_zombies_1d.size()
		if count >= 5:
			break
	_check(a, "每行摆了一只靶子僵尸（共 5 只）", count == 5, "场上 %d 只" % count)
	if count == 0:
		return
	var all_target := true
	var all_still := true
	for z in zm.all_zombies_1d:
		if z == null:
			continue
		if z.zombie_type != &"pb_target_zombie":
			all_target = false
		if z.move_component != null and z.move_component.is_move:
			all_still = false
	_check(a, "场上僵尸都是靶子僵尸", all_target)
	_check(a, "靶子僵尸都站着不动", all_still)


## ---- 一个 12 格出战卡槽（前 6 植物 / 后 6 僵尸）+ 右上银行视图 ----
func _check_card_slots(a, mg) -> void:
	var card_manager = mg.card_manager
	_check(a, "植物侧有常规卡槽", card_manager != null \
		and card_manager.card_slot_controller != null \
		and card_manager.card_slot_controller.has_card_slot())
	var slot = card_manager.card_slot_battle if card_manager != null else null
	_check(a, "出战卡槽 12 格（前 6 植物 + 后 6 僵尸，一个存储）",
		slot != null and slot.cards_placeholder.size() == 12,
		str(slot.cards_placeholder.size()) if slot != null else "no slot")
	if slot == null:
		return
	_check(a, "卡槽配了分块（僵尸 / 僵王卡 → 第 1 块）",
		slot.card_type_blocks.get(ResourceCardReference.CardType.Zombie, -1) == 1 \
			and slot.card_type_blocks.get(ResourceCardReference.CardType.ZombieBoss, -1) == 1,
		str(slot.card_type_blocks))
	_check(a, "分块宽是 [6, 6]",
		slot.block_sizes.size() == 2 and slot.block_sizes[0] == 6 and slot.block_sizes[1] == 6,
		str(slot.block_sizes))
	_check(a, "对战整槽不占数字快捷键", slot.shortcuts_enabled == false, str(slot.shortcuts_enabled))
	var slot_root = card_manager.card_slot_root if card_manager != null else null
	var bank = slot_root.get_node_or_null("ZombieCardBattleSlot") if slot_root != null else null
	_check(a, "右上装上了反转银行视图（僵尸卡模组装的）", bank != null)
	if bank == null:
		return
	_check(a, "银行贴在右上且收在屏幕上方外（x 应超过屏宽一半，y = -100）",
		bank.position.x > 400.0 and is_equal_approx(bank.position.y, -100.0),
		str(bank.position))
	var zpanel := bank.get_theme_stylebox("panel") as StyleBoxTexture
	_check(a, "银行底图是翻转后的 ZombieSeedBank（446×87 的 ImageTexture）",
		zpanel != null and zpanel.texture != null \
			and zpanel.texture.get_size() == Vector2(446, 87),
		"" if zpanel == null or zpanel.texture == null else str(zpanel.texture.get_size()))
	var bank_hbox = bank.get_node_or_null("CardUiList")
	var zplaceholders: Array = bank_hbox.get_children() if bank_hbox != null else []
	_check(a, "占位格 6~11 已挪进银行（6 格）", zplaceholders.size() == 6,
		str(zplaceholders.size()))
	var in_bank := true
	for i in range(6, slot.cards_placeholder.size()):
		if slot.cards_placeholder[i].get_parent() != bank_hbox:
			in_bank = false
	_check(a, "槽的占位表后 6 格指向银行里的占位", in_bank)
	_check(a, "装槽时僵尸块**不发卡**（僵尸卡由选卡面板选进来）",
		slot.count_cards_in_block(1) == 0, "%d 张" % slot.count_cards_in_block(1))
	var brains_label = bank.get_node_or_null("SunLabelControl/CurrSunValue")
	_check(a, "僵尸方起始脑子 150", brains_label != null and brains_label.text == "150",
		"" if brains_label == null else brains_label.text)
	await _check_zombie_choose_panel(a, mg, slot, bank)


## ---- 选僵尸卡面板（贴在植物待选区右面，一行五张）----
## 无头探针点不了按钮：选卡走卡的 `signal_card_click`（与点击同一个信号），
## 收尾直接调 `finish_choose()`（跳过点「开始战斗」那一步）。
## 出场/收场是阶段驱动的 0.2s 平移：等到选卡阶段后再多等 0.5s 让动画滑完。
func _check_zombie_choose_panel(a, mg, slot, bank) -> void:
	var norm = mg.card_manager.card_slot_norm
	var panel = norm.get_node_or_null("ZombieCardChoosePanel") if norm != null else null
	_check(a, "选僵尸卡面板装上了（挂在 CardSlotNorm 下）", panel != null)
	if panel == null:
		return
	_check(a, "面板贴在植物待选区右面（x ≥ 465）", panel.position.x >= 465.0, str(panel.position))
	## 等两块真正滑入到位：出场是跟拍本体待选区（选卡事件、开场相机平移完之后），
	## 不是进度事件 —— 所以等位置到位，别等进度枚举
	var waited := 0.0
	while is_instance_valid(mg) and waited < 20.0 \
			and (not is_equal_approx(panel.position.y, 89.0) \
				or not is_equal_approx(bank.position.y, 0.0)):
		await a.wait(0.25)
		waited += 0.25
	_check(a, "选卡阶段两块都滑入到位（面板 y=89 / 银行 y=0）",
		is_instance_valid(mg) and is_equal_approx(panel.position.y, 89.0) \
			and is_equal_approx(bank.position.y, 0.0),
		"panel=%s bank=%s" % [str(panel.position.y), str(bank.position.y)])
	var card_scroll = panel.get_node("PageHolder/CardScroll")
	var grid = card_scroll.get_child(0) if card_scroll != null \
		and card_scroll.get_child_count() > 0 else null
	_check(a, "面板卡格有内容（全部已登记的僵尸卡）",
		grid != null and grid.get_child_count() > 6,
		str(grid.get_child_count()) if grid != null else "no grid")
	var containers: Array = []
	if grid != null:
		for container in grid.get_children():
			containers.append(container)
	_check(a, "面板里的候选僵尸卡超过六张", containers.size() > 6, "%d 张" % containers.size())
	var excluded: Array[StringName] = [ZombieIds.BOBSLED_SINGLE, ZombieIds.DUCKYTUBE]
	var has_excluded := false
	var has_doctor := false
	## 普通僵尸在面板里的先后（僵王不算，它在最末尾单独补）
	var zombie_order: Array[StringName] = []
	for container in containers:
		var candidate_card = container.card
		if candidate_card == null:
			continue
		if candidate_card.card_type == ResourceCardReference.CardType.ZombieBoss \
				and candidate_card.card_zombie_boss_type == ZombieBossIds.DOCTOR:
			has_doctor = true
			continue
		if candidate_card.card_type == ResourceCardReference.CardType.Zombie:
			zombie_order.append(candidate_card.card_zombie_type)
		if candidate_card.card_zombie_type in excluded:
			has_excluded = true
	_check(a, "面板里没有单个雪橇车队员 / 鸭子救生圈", not has_excluded)
	_check(a, "面板里有僵王博士", has_doctor)
	## 显示顺序（`PLAYER_BATTLE_MOVE_AFTER` + **伴舞已放开可选**，2026-10-25 用户口径）：
	## 墓碑 ↔ 旗帜原来那格 ⇒ 墓碑紧跟普僵；旗帜挪到海豚骑士后面；伴舞按登记顺序排在舞王后面
	_check(a, "产脑光墓碑紧跟普僵（第 2 格）",
		_next_to(zombie_order, ZombieIds.NORM, &"zombie_card_vsgravestone"), str(zombie_order))
	_check(a, "伴舞僵尸在面板里、且紧跟舞王",
		_next_to(zombie_order, ZombieIds.JACKSON, ZombieIds.DANCER), str(zombie_order))
	_check(a, "旗帜僵尸挪到海豚骑士后面",
		_next_to(zombie_order, ZombieIds.DOLPHINRIDER, ZombieIds.FLAG), str(zombie_order))
	## 僵尸 / 僵王卡的卡面底图是模组共用那张（`Seeds_ZombieSun`，50×70）——
	## 比同一个资源对象（`==`），别只比尺寸（植物卡 norm 底图也是 50×70，比尺寸会漏判）；
	## 墓碑是植物类卡，保留它自己的卡面，不参与这条
	var panel_face_tex := ModManager.load_mod_asset(
		ModIds.ZOMBIE_CARD, ZombieCardSettings.ASSET_ZOMBIE_CARD_BG) as Texture2D
	var panel_zombie_cards := 0
	var panel_restyled := 0
	for container in containers:
		var panel_card = container.card
		if panel_card == null or panel_card.card_type == ResourceCardReference.CardType.Plant:
			continue
		panel_zombie_cards += 1
		if panel_card.card_bg != null and panel_card.card_bg.texture == panel_face_tex:
			panel_restyled += 1
	_check(a, "面板里的僵尸卡候选已经换上对战卡面（Seeds_ZombieSun）",
		panel_zombie_cards > 0 and panel_restyled == panel_zombie_cards,
		"%d/%d" % [panel_restyled, panel_zombie_cards])
	## 产脑光墓碑 2026-10-25 改成**僵尸单位**：它就是上面那圈僵尸卡里的一张
	## （`panel_restyled` 已经把它算进去了），这里额外确认它确实以僵尸卡身份出现
	var tombstone_as_zombie := false
	for container in containers:
		var tomb_card = container.card
		if tomb_card == null:
			continue
		if tomb_card.card_type == ResourceCardReference.CardType.Zombie \
				and tomb_card.card_zombie_type == &"zombie_card_vsgravestone":
			tombstone_as_zombie = true
			break
	_check(a, "产脑光墓碑以僵尸卡身份出现在面板里（不再混在植物堆里）", tombstone_as_zombie)
	## 面板上显示的花费 = 对战口径（容器自己那份 `sun_cost`）
	var panel_cost_ok := true
	var panel_cost_detail := ""
	for container in containers:
		var c = container.card
		if c == null or c.card_type != ResourceCardReference.CardType.Zombie:
			continue
		var expect: int = int(ZombieCardSettings.PLAYER_BATTLE_ZOMBIE_COSTS.get(c.card_zombie_type, -1))
		if expect >= 0 and container.sun_cost != expect:
			panel_cost_ok = false
			panel_cost_detail += "%s=%d(应 %d) " % [c.card_zombie_type, container.sun_cost, expect]
	_check(a, "面板候选卡显示的是对战花费（DLC Edition）", panel_cost_ok, panel_cost_detail)
	## 面板候选卡的冷却 = 对战口径（表见 `zombie_card_settings.gd` 的
	## `PLAYER_BATTLE_ZOMBIE_COOLDOWNS`；wiki 没写全的几只表里也标了「待核实」）
	var panel_cool_ok := true
	var panel_cool_detail := ""
	for container in containers:
		var cc = container.card
		if cc == null or cc.card_type != ResourceCardReference.CardType.Zombie:
			continue
		var expect_cool: float = float(
			ZombieCardSettings.PLAYER_BATTLE_ZOMBIE_COOLDOWNS.get(cc.card_zombie_type, -1.0))
		if expect_cool >= 0.0 and not is_equal_approx(cc.cool_time, expect_cool):
			panel_cool_ok = false
			panel_cool_detail += "%s=%.1f(应 %.1f) " % [cc.card_zombie_type, cc.cool_time, expect_cool]
	_check(a, "面板候选卡的冷却是对战口径（DLC Edition）", panel_cool_ok, panel_cool_detail)
	for i in 6:
		containers[i].card.signal_card_click.emit()
	_check(a, "点六张 → 僵尸块六张僵尸卡（占第 6~11 格）",
		slot.count_cards_in_block(1) == 6 and _block1_all_in_range(slot),
		"%d 张" % slot.count_cards_in_block(1))
	_check(a, "植物块还空着（选卡走的僵尸块，没占植物那半）", slot.count_cards_in_block(0) == 0)
	containers[5].card.signal_card_click.emit()
	_check(a, "再点最后一张 → 退回容器剩五张", slot.count_cards_in_block(1) == 5,
		str(slot.count_cards_in_block(1)))
	containers[5].card.signal_card_click.emit()
	_check(a, "又点回去 → 恢复六张", slot.count_cards_in_block(1) == 6,
		str(slot.count_cards_in_block(1)))
	_check(a, "整槽「卡槽第几格」口径还在（第 6 格查得到那张卡）",
		slot.index_of_card(slot.curr_cards[6]) == 6)
	panel.finish_choose()
	_check(a, "收尾后僵尸块还是玩家选的六张（不发默认牌）", slot.count_cards_in_block(1) == 6,
		str(slot.count_cards_in_block(1)))
	## 对战用的卡面底图是模组共用那张 `Seeds_ZombieSun`（50×70）—— 比同一个资源对象（`==`），
	## 别只比尺寸（植物卡 norm 底图也是 50×70，比尺寸会漏判）
	var face_tex := ModManager.load_mod_asset(
		ModIds.ZOMBIE_CARD, ZombieCardSettings.ASSET_ZOMBIE_CARD_BG) as Texture2D
	var restyled := 0
	for card in slot.curr_cards:
		if card != null and card.card_bg != null and card.card_bg.texture == face_tex:
			restyled += 1
	_check(a, "六张卡都换上僵尸卡模组共用那张卡面（Seeds_ZombieSun）", restyled == 6, "%d 张" % restyled)
	## 槽里僵尸卡的花费 = 对战口径（选卡选中带进来的那份 `sun_cost`，见
	## `zombie_card_pvp_wiring.sync_versus_costs()` / `zombie_card_settings.gd` 的表）
	var slot_cost_ok := true
	var slot_cost_detail := ""
	for card in slot.curr_cards:
		if card == null or card.card_type != ResourceCardReference.CardType.Zombie:
			continue
		var expect: int = int(ZombieCardSettings.PLAYER_BATTLE_ZOMBIE_COSTS.get(card.card_zombie_type, -1))
		if expect >= 0 and card.sun_cost != expect:
			slot_cost_ok = false
			slot_cost_detail += "%s=%d(应 %d) " % [card.card_zombie_type, card.sun_cost, expect]
	_check(a, "僵尸块里的卡费用是对战口径（DLC Edition）", slot_cost_ok, slot_cost_detail)
	## 槽里卡的冷却 = 对战口径（选中 / 收尾各同步一遍，见接线 `sync_versus_cooldowns()`）
	var slot_cool_ok := true
	var slot_cool_detail := ""
	for card in slot.curr_cards:
		if card == null or card.card_type != ResourceCardReference.CardType.Zombie:
			continue
		var expect_slot_cool: float = float(
			ZombieCardSettings.PLAYER_BATTLE_ZOMBIE_COOLDOWNS.get(card.card_zombie_type, -1.0))
		if expect_slot_cool >= 0.0 and not is_equal_approx(card.cool_time, expect_slot_cool):
			slot_cool_ok = false
			slot_cool_detail += "%s=%.1f(应 %.1f) " % [card.card_zombie_type, card.cool_time, expect_slot_cool]
	_check(a, "僵尸块里的卡冷却是对战口径（DLC Edition）", slot_cool_ok, slot_cool_detail)


## 顺序表里 [param b] 是不是紧跟 [param a]（两张都要在表里）
func _next_to(order: Array[StringName], a: StringName, b: StringName) -> bool:
	var ia := order.find(a)
	var ib := order.find(b)
	return ia >= 0 and ib == ia + 1


## 僵尸块（第 6~11 格）是不是每格都有卡
func _block1_all_in_range(slot) -> bool:
	for i in range(6, 12):
		if i >= slot.curr_cards.size() or slot.curr_cards[i] == null:
			return false
	return true


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


func _check(a, desc: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + desc)
	else:
		_failed += 1
		a.log("  [NG] " + desc + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[PLAYERBATTLE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
