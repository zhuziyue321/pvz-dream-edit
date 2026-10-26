extends RefCounted
## 探针：模组「玩家对战」的产脑光墓碑（DLC 对战墓碑 VSGravestone → 运行期**僵尸**）
##
## 2026-10-25 它从「运行期植物 + 三处补丁」改成**僵尸单位**，本探针跟着改口径：
##   ① 素材可加载（动画场景 / 两段动画 / 实体场景）
##   ② 玩家对战模组装上后：注册表登记（僵尸 id、50 脑光 / 7.5 s 冷却）、
##      AllCards 有**僵尸**卡模板、卡面画好
##   ③ 对战选卡面板里有墓碑候选（它是普通僵尸卡，自然排进列表）；点它 → 落僵尸块（第 6~11 格）
##   ④ 收尾进主游戏：货币路由 —— 僵尸卡问脑子池（150 起始，够花）；用卡扣脑子
##   ⑤ 放下去（走 `ZombieManager.create_norm_zombie`，与玩家点格子同一入口）：
##      动画两段在、待机在播、产脑子组件在；**占格**生效（该格 `can_common_zombie = false`）
##   ⑥ 受损动画五阶：break1~5 都在库里；掉到 5/6 血播 break1（Stone 换 Stone1）、播完停在裂纹姿态、
##      再一把打到 1/6 血直接跳 break5（中间几阶不补播）
##   ⑦ 产脑子：组件立即产一次 → 银行脑子 +25；点收才入账
##   ⑧ 被打死 → 占格放开（同一格能再放）；收尾关模组 → 注册表 / 卡片目录全撤
## 机器可读汇总：最后一行 [PLAYER_BATTLE_TOMB] result=PASS|FAIL failed=<n>
##
## 无头可跑：`powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_player_battle_vsgravestone`

const Settings := preload("res://mods_builtin/player_battle/player_battle_settings.gd")
const TombstoneScript := preload("res://mods_builtin/player_battle/vsgravestone/vsgravestone_zombie.gd")

## 产一次脑子后等光效弹出（秒）
const PRODUCE_WAIT := 0.6

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：玩家对战 · 产脑光墓碑（僵尸） ==========")
	var mod_script := ModManager.load_mod_asset(ModIds.PLAYER_BATTLE, "player_battle_mod.gd")
	_check(a, "模组入口脚本可加载", mod_script != null)
	var anim_scene := ModManager.load_mod_asset(ModIds.PLAYER_BATTLE, "animation/character/plant/VSGravestone/VSGravestone.tscn")
	_check(a, "动画场景（部件树）可加载", anim_scene != null)
	var idle_anim := ModManager.load_mod_asset(ModIds.PLAYER_BATTLE, "animation/character/plant/VSGravestone/VSGravestone_idle.tres")
	var rise_anim := ModManager.load_mod_asset(ModIds.PLAYER_BATTLE, "animation/character/plant/VSGravestone/VSGravestone_rise.tres")
	_check(a, "idle / rise 两段动画可加载", idle_anim != null and rise_anim != null)
	var tomb_scene := ModManager.load_mod_asset(ModIds.PLAYER_BATTLE, "vsgravestone/zombie_vsgravestone.tscn") as PackedScene
	_check(a, "实体场景可加载", tomb_scene != null)

	## 玩家对战模组装上（注册运行期僵尸 + 注入选关页；选卡面板归僵尸卡模组，依赖会把它一并打开）
	## ★ 先关再开：模组可能随存档默认就是开着的（开局已 install 过一次），
	##   直接再开一次会「卡牌身份重复注册」，卸载也只摘得到后装的那份
	ModManager.set_mod_enabled(ModIds.PLAYER_BATTLE, false)
	await a.wait(0.5)
	ModManager.set_mod_enabled(ModIds.PLAYER_BATTLE, true)
	await a.wait(1.0)
	var tomb_id: StringName = Settings.TOMBSTONE_ZOMBIE_ID
	_check(a, "注册表里有这只运行期僵尸", Global.character_registry.is_runtime_zombie(tomb_id))
	var sun_cost: int = Global.character_registry.get_zombie_info(
		tomb_id, CharacterRegistry.ZombieInfoAttribute.SunCost)
	var cool_time: float = Global.character_registry.get_zombie_info(
		tomb_id, CharacterRegistry.ZombieInfoAttribute.CoolTime)
	_check(a, "脑子价 = 50", sun_cost == Settings.TOMBSTONE_SUN_COST, str(sun_cost))
	_check(a, "冷却 = 7.5 秒", absf(cool_time - Settings.TOMBSTONE_COOL_TIME) < 0.01, str(cool_time))
	_check(a, "行类型 = 陆地（对战红线右边是草地）",
		Global.character_registry.get_zombie_info(
			tomb_id, CharacterRegistry.ZombieInfoAttribute.ZombieRowType)
			== CharacterRegistry.ZombieRowType.Land)
	var ref := ResourceCardReference.create(ResourceCardReference.CardType.Zombie, tomb_id)
	_check(a, "AllCards 里有它的**僵尸**卡模板", AllCards.has_template(ref))

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
	ModManager.set_mod_enabled(ModIds.PLAYER_BATTLE, true)
	btn.get_node("TextureButton").emit_signal("pressed")
	var entered: bool = await a.wait_scene("main_game", 20.0)
	_check(a, "进了对战主游戏", entered)
	var mg = await _wait_main_game(a, 10.0)
	if mg == null or not is_instance_valid(mg):
		_check(a, "主游戏已起来", false)
		_finish(a)
		return

	## ---- 选卡面板：有墓碑候选（普通僵尸卡）；点它落僵尸块 ----
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
				if c != null and c.card_type == ResourceCardReference.CardType.Zombie \
						and c.card_zombie_type == tomb_id:
					tombstone_container = container
					break
		_check(a, "面板里有墓碑候选（僵尸卡身份）", tombstone_container != null)
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

	## ---- 放下去：走玩家点格子那条同样的入口（`ZombieManager.create_norm_zombie`） ----
	var spot := _find_free_cell(mg)
	_check(a, "找得到一块空的僵尸侧格子（第 7 列起）", spot != null)
	var tomb: Zombie000Base = null
	if spot != null:
		tomb = _spawn_tombstone(mg, spot)
	_check(a, "放得下去", tomb != null)
	if tomb != null:
		## 卡面是延迟绘制的：进关跑了这么久早该画好，这里补一道确认
		var template := AllCards.get_template(ref)
		_check(a, "卡模板的卡面已画好（character_static 非空）",
			template != null and is_instance_valid(template.character_static)
			and template.character_static.get_child_count() > 0)
		_check(a, "根节点脚本正确", tomb.get_script() == TombstoneScript)
		var anim_root := tomb.get_node_or_null("Body/VSGravestoneMask/VSGravestoneAnim")
		_check(a, "动画节点在且无缩放", anim_root != null and anim_root.scale == Vector2.ONE)
		var mask := tomb.get_node_or_null("Body/VSGravestoneMask")
		## 裁剪模式必须是 2（CLIP_CHILDREN_AND_DRAW）：1（ONLY）裁不到「动画挂点」下面的部件，
		## 整棵会被裁没（见 zombie_vsgravestone.tscn 里那段黑底格子实测）
		_check(a, "出土裁剪板在且开了 clip_children",
			mask != null and mask.clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW)
		var anim_lib: AnimationPlayer = tomb.get_node_or_null(
			"Body/VSGravestoneMask/VSGravestoneAnim/AnimLib")
		_check(a, "AnimLib 在且有三段基础动画（idle / rise / break1）",
			anim_lib != null and anim_lib.has_animation(&"VSGravestone_idle")
			and anim_lib.has_animation(&"VSGravestone_rise")
			and anim_lib.has_animation(&"VSGravestone_break1"))
		## 出土 0.5 s 播完回待机（待机是 0 长度静帧，播完 `current_animation` 不一定还挂着名），
		## 所以直接验**姿态**：出土/立定后 Stone 部件应停在 idle 第 0 帧的位置
		await a.wait(0.8)
		var stone_node: Node2D = anim_root.get_node_or_null("Stone") if anim_root != null else null
		_check(a, "出土播完立定（Stone 停在 idle 姿态位）",
			stone_node != null and stone_node.position == Vector2(-3, 6.3),
			str(stone_node.position) if stone_node != null else "no node")
		## 受损动画（掉血 → break1~5，播完停在裂纹姿态不回待机）
		if anim_lib != null and anim_root != null:
			await _check_damage_anim(a, tomb, anim_lib, anim_root)
		var comp = tomb.get_node_or_null("CreateSunComponent")
		_check(a, "产脑子组件在（脚本 = 模组子类）", comp != null \
			and comp.get_script() == preload("res://mods_builtin/player_battle/vsgravestone/component_create_brains.gd"))

		## ---- 僵尸身份：受击 / 索敌层是僵尸本体那两层（不需要再打补丁） ----
		_check(a, "不再需要「谁都能打它」补丁（僵尸天然是植物方的敌人）",
			not tomb.is_enemy_to_all_camps)
		var hurt_detection := tomb.hurt_box_component.get_node_or_null("HurtBoxDetection") as Area2D
		var hurt_real := tomb.hurt_box_component.get_node_or_null("HurtBoxReal") as Area2D
		_check(a, "索敌层 = 僵尸检测层（植物索敌框 mask 4 看得见墓碑）",
			hurt_detection != null and hurt_detection.collision_layer == 4,
			"" if hurt_detection == null else str(hurt_detection.collision_layer))
		_check(a, "受击层 = 僵尸受击层（植物子弹 mask 512 打得中）",
			hurt_real != null and hurt_real.collision_layer == 512,
			"" if hurt_real == null else str(hurt_real.collision_layer))

		## ---- 占格：同一格不能放第二块（本体墓碑那套的僵尸侧版本） ----
		if spot != null:
			_check(a, "占格生效：该格 `can_common_zombie = false`",
				not spot.can_common_zombie)
			_check(a, "占格状态可查（is_occupied_by_zombie）", spot.is_occupied_by_zombie())

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
					"res://mods_builtin/player_battle/vsgravestone/sun_brain.gd"))
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
		var brains_before: int = pvp_wiring._brains
		pvp_wiring._on_card_cost(tomb_card)
		_check(a, "用卡 → 扣 50 脑子", pvp_wiring._brains == brains_before - 50,
			"%d -> %d" % [brains_before, pvp_wiring._brains])

	## ---- 被植物子弹打：第 1 行摆一株豌豆射手，看第 7 列的墓碑掉不掉血 ----
	await _check_plant_bullet_hit(a, mg)

	## ---- 死亡 → 占格放开（同一格能再放第二块） ----
	if tomb != null and is_instance_valid(tomb) and spot != null:
		if not tomb.is_death:
			_deal_damage(a, tomb, tomb.hp_component.curr_hp)
		await a.wait(0.5)
		_check(a, "墓碑被打死后占格放开（`can_common_zombie` 恢复）",
			spot.can_common_zombie and not spot.is_occupied_by_zombie())

	## ---- 收尾：关玩家对战模组 → 墓碑随它一起撤（注册表 / 卡片目录） ----
	ModManager.set_mod_enabled(ModIds.PLAYER_BATTLE, false)
	await a.wait(0.5)
	_check(a, "关模组后注册表已清", not Global.character_registry.is_runtime_zombie(tomb_id))
	_check(a, "关模组后卡片目录已清", not AllCards.has_template(ref))
	_finish(a)


## 受损动画五阶：血量分 6 段（满血 + 5 阶），每掉 1/6 血换一档 `breakN`；
## 段末**停在最后一帧**（裂纹与碎块淡出后的样子），不回待机 —— 回待机就等于把裂缝盖回去。
## 顺便证明素材口径：每段是「第 N 阶裂纹贴图 StoneN 换掉 Stone + 这一下崩飞的碎块」。
func _check_damage_anim(a, tomb: Character000Base, anim_lib: AnimationPlayer, anim_root: Node2D) -> void:
	a.log("STEP 受损动画（掉血 → break1~5）")
	for i in range(1, 6):
		var state := StringName("VSGravestone_break%d" % i)
		_check(a, "库里第 %d 阶受损动画在（%s）" % [i, state], anim_lib.has_animation(state))
	var max_hp: int = tomb.hp_component.max_hp
	if max_hp < 6:
		_check(a, "墓碑血量上限够分段", false, str(max_hp))
		return
	var step := max_hp / 6
	## 第 1 阶：掉到 5/6 血（300 血的 250）
	_deal_damage(a, tomb, step)
	await a.wait(0.3)
	_check(a, "掉到 5/6 血 → 播 break1",
		anim_lib.current_animation == &"VSGravestone_break1", str(anim_lib.current_animation))
	_check(a, "第 1 阶外观：Stone 隐、Stone1 显",
		not _sprite_visible(anim_root, "Stone") and _sprite_visible(anim_root, "Stone1"),
		"Stone=%s Stone1=%s" % [str(_sprite_visible(anim_root, "Stone")),
			str(_sprite_visible(anim_root, "Stone1"))])
	## 等 break1 播完（长度 1.08 s）：该停在段尾姿态，不该回待机
	await a.wait(1.4)
	_check(a, "break1 播完停在裂纹姿态（没回待机，Stone 仍隐）",
		not anim_lib.is_playing() and not _sprite_visible(anim_root, "Stone"),
		"playing=%s Stone=%s" % [str(anim_lib.is_playing()),
			str(_sprite_visible(anim_root, "Stone"))])
	## 一把打到剩 1/6 血：跳级只播最高那阶，不补播中间几段
	_deal_damage(a, tomb, tomb.hp_component.curr_hp - step)
	await a.wait(0.3)
	_check(a, "掉到 1/6 血 → 直接跳到 break5（中间几阶不补播）",
		anim_lib.current_animation == &"VSGravestone_break5", str(anim_lib.current_animation))
	_check(a, "第 5 阶外观：Stone5 显，Stone / Stone4 隐",
		_sprite_visible(anim_root, "Stone5") and not _sprite_visible(anim_root, "Stone")
		and not _sprite_visible(anim_root, "Stone4"),
		"Stone5=%s Stone=%s Stone4=%s" % [str(_sprite_visible(anim_root, "Stone5")),
			str(_sprite_visible(anim_root, "Stone")), str(_sprite_visible(anim_root, "Stone4"))])


## 走统一伤害入口打一记（`apply_damage` → `DamageSystem`，不绕过管线）
func _deal_damage(a, target: Character000Base, amount: int) -> void:
	if amount <= 0:
		_check(a, "测试用伤害值 > 0", false, str(amount))
		return
	target.apply_damage(DamageInfo.create(target, amount,
		ConstDamage.E_DamageMode.Norm, ConstDamage.E_DamageCause.Bullet))


## 动画部件当前是否可见（受损动画靠 visible 轨道换装）
func _sprite_visible(anim_root: Node2D, node_name: String) -> bool:
	var sprite := anim_root.get_node_or_null(node_name) as Sprite2D
	return sprite != null and sprite.visible


#region 僵尸放置（与玩家点格子同一条入口）
## 找一块空的、僵尸侧放得下的格子：第 7 列起（下标 6）、`can_common_zombie = true`）
func _find_free_cell(mg) -> PlantCell:
	var rows: Array = mg.plant_cell_manager.all_plant_cells
	if rows.is_empty():
		return null
	for cell in rows[0]:
		var plant_cell := cell as PlantCell
		if plant_cell == null:
			continue
		if plant_cell.row_col.y < 6:
			continue
		if plant_cell.can_common_zombie:
			return plant_cell
	return null


## 放一块墓碑：与 `hand_component_character.gd` 的僵尸分支同一组参数
## （位置 = 格子中心的 x + 该行出怪点的 y，入树前设好 —— 僵尸靠它反查占格）
func _spawn_tombstone(mg, cell: PlantCell) -> Zombie000Base:
	var lane: int = cell.row_col.x
	var row: ZombieRow = mg.zombie_manager.all_zombie_rows[lane]
	var init_para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType: row.zombie_row_type,
	}
	return mg.zombie_manager.create_norm_zombie(
		Settings.TOMBSTONE_ZOMBIE_ID, row, init_para,
		Vector2(cell.global_position.x + cell.size.x / 2,
			row.zombie_create_position.global_position.y))
#endregion


## 墓碑能不能被**植物子弹**打到（端到端）：第 1 行第 4 列放墓碑、第 0 列种豌豆射手。
## 这一条盖住三层：植物索敌框（mask 4）能锁定它、植物子弹（mask 512）碰得到它、
## 阵营判定（僵尸 ⇒ 植物方的敌人）不把它当自己人。任何一层没接上，豌豆都不会掉血。
## 只要掉一点血就算过（墓碑 300 血，不等它死）。
func _check_plant_bullet_hit(a, mg) -> void:
	a.log("STEP 墓碑被植物子弹打到（豌豆射手实弹）")
	var rows: Array = mg.plant_cell_manager.all_plant_cells
	if rows.size() < 2 or rows[1].size() < 7:
		_check(a, "第 1 行格子够做射击测试", false, "行=%d" % rows.size())
		return
	var row: Array = rows[1]
	var tomb_cell: PlantCell = row[6]
	_check(a, "第 1 行第 7 列能放墓碑（僵尸那半的空草地）", tomb_cell.can_common_zombie)
	var tomb := _spawn_tombstone(mg, tomb_cell)
	_check(a, "墓碑放得下去", tomb != null)
	if tomb == null:
		return
	var shooter_cell: PlantCell = row[0]
	var shooter: Plant000Base = shooter_cell.create_plant(PlantIds.PEA_SHOOTER_SINGLE)
	_check(a, "第 0 列种得下豌豆射手", shooter != null)
	if shooter == null:
		return
	var hp_before: int = tomb.hp_component.curr_hp
	var waited := 0.0
	while waited < 8.0 and is_instance_valid(tomb) \
			and tomb.hp_component.curr_hp >= hp_before:
		await a.wait(0.5)
		waited += 0.5
	var hp_after := tomb.hp_component.curr_hp if is_instance_valid(tomb) else -1
	_check(a, "豌豆射手的子弹打掉了墓碑的血（索敌 + 碰撞 + 阵营三层都通）",
		hp_after >= 0 and hp_after < hp_before,
		"%d -> %s（等了 %.1f 秒）" % [hp_before, str(hp_after), waited])


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
		if card != null and card.card_type == ResourceCardReference.CardType.Zombie \
				and card.card_zombie_type == Settings.TOMBSTONE_ZOMBIE_ID:
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
	a.log("[PLAYER_BATTLE_TOMB] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
