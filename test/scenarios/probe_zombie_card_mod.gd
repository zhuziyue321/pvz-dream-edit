extends RefCounted
## 探针：模组「僵尸卡」（我是僵尸的僵尸卡牌 + PVZ2 外观）
##
## 验：① 登记与素材 ② 「我是僵尸」关卡里发得出僵尸卡 ③ 外观换掉了
##      ④ 脑光 / 脑子阳光 ⑤ 收尾关模组
## 机器可读汇总：最后一行 [ZOMBIE_CARD] result=PASS|FAIL failed=<n>

const ModScript := preload("res://mods_builtin/zombie_card/zombie_card_mod.gd")
const Wiring := preload("res://mods_builtin/zombie_card/zombie_card_wiring.gd")
const BrainGlow := preload("res://mods_builtin/zombie_card/zombie_card_brain_glow.gd")
const BrainSun := preload("res://mods_builtin/zombie_card/zombie_card_brain_sun.gd")
## 卡面底图问模组自己的共享常量（所有僵尸卡同一张），探针别另抄一份文件名
const Settings := preload("res://mods_builtin/zombie_card/zombie_card_settings.gd")

const LEVEL_PATH := "res://data/levels/params/vase_zombie.gd"
const ASSET_SEED_BANK := "ZombieSeedBank.png"
const ASSET_CHOOSER := "SeedChooser_Background_I_Zombie.png"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：僵尸卡（我是僵尸） ==========")
	_check(a, "模组入口脚本可加载", ModScript != null, "mods_builtin/zombie_card/")
	_check(a, "模组 id 已登记", ModManager.MOD_SCRIPT_PATHS.has(ModIds.ZOMBIE_CARD), str(ModIds.ZOMBIE_CARD))
	for asset in [ASSET_SEED_BANK, Settings.ASSET_ZOMBIE_CARD_BG, ASSET_CHOOSER, "BrainGlowBig.png", "BrainGlowSmall.png", "BrainSun.png"]:
		var tex := ModManager.load_mod_asset(ModIds.ZOMBIE_CARD, str(asset)) as Texture2D
		_check(a, "素材可加载：%s" % str(asset), tex != null, "" if tex == null else str(tex.get_size()))
	ModManager.set_mod_enabled(ModIds.ZOMBIE_CARD, true)
	await a.wait(1.0)
	var mg := await _boot_level(a, LEVEL_PATH)
	if mg == null:
		_check(a, "已进入「我是僵尸」关卡", false, "curr_main_game 为空")
		_finish(a)
		return
	_check(a, "关卡是「我是僵尸」模式", mg.game_para != null and mg.game_para.is_zombie_mode)
	await _check_cards(a, mg)
	await _check_skin(a, mg)
	await _check_glow(a, mg)
	ModManager.set_mod_enabled(ModIds.ZOMBIE_CARD, false)
	ModManager.save_mods()
	_finish(a)


func _check_cards(a, mg) -> void:
	var battle: CardSlotBattle = mg.card_manager.card_slot_battle
	_check(a, "出战卡槽存在", battle != null)
	if battle == null:
		return
	var zombie_cards := 0
	for card in battle.curr_cards:
		if card != null and card.card_type == ResourceCardReference.CardType.Zombie:
			zombie_cards += 1
	_check(a, "出战卡槽里发得出僵尸卡（预选 3 张）", zombie_cards == 3, "%d 张" % zombie_cards)


func _check_skin(a, mg) -> void:
	var battle: CardSlotBattle = mg.card_manager.card_slot_battle
	var seed_bank_tex := ModManager.load_mod_asset(ModIds.ZOMBIE_CARD, ASSET_SEED_BANK) as Texture2D
	var panel := battle.get_theme_stylebox("panel") as StyleBoxTexture
	_check(a, "出战卡槽底图换成僵尸卡槽", panel != null and panel.texture == seed_bank_tex)
	var zombie_seed_tex := ModManager.load_mod_asset(ModIds.ZOMBIE_CARD, Settings.ASSET_ZOMBIE_CARD_BG) as Texture2D
	var zombie_cards := 0
	var face_ok := 0
	for card in battle.curr_cards:
		if card == null:
			continue
		if card.card_type != ResourceCardReference.CardType.Zombie \
				and card.card_type != ResourceCardReference.CardType.ZombieBoss:
			continue
		zombie_cards += 1
		if is_instance_valid(card.card_bg) and card.card_bg.texture == zombie_seed_tex:
			face_ok += 1
	_check(a, "僵尸卡卡面全换成模组共用那张（Seeds_ZombieSun）",
		zombie_cards > 0 and face_ok == zombie_cards, "%d/%d" % [face_ok, zombie_cards])
	var norm: CardSlotNorm = mg.card_manager.card_slot_norm
	var chooser_tex := ModManager.load_mod_asset(ModIds.ZOMBIE_CARD, ASSET_CHOOSER) as Texture2D
	_check(a, "选卡界面背景换成「我是僵尸」那张",
		norm != null and norm.card_slot_candidate != null and norm.card_slot_candidate.texture == chooser_tex)


func _check_glow(a, mg) -> void:
	var brains: Array = mg.game_item_manager.gim_brain.curr_brain
	_check(a, "场上有脑子", brains.size() > 0, "%d 个" % brains.size())
	var glow_count := 0
	for brain in brains:
		if not is_instance_valid(brain):
			continue
		var parent: Node = brain.get_parent()
		if parent == null:
			continue
		for child in parent.get_children():
			if str(child.name).begins_with("BrainGlow"):
				glow_count += 1
				break
	_check(a, "每个脑子都挂着脑光", glow_count == brains.size(), "%d / %d" % [glow_count, brains.size()])
	var suns := mg.get_node_or_null("Suns") as Node2D
	_check(a, "找得到阳光容器", suns != null)
	if suns != null:
		var sun := SceneRegistry.SUN.instantiate() as Sun
		suns.add_child(sun)
		EventBus.push_event(ConstEventName.SUN_SPAWNED, [sun])
		_check(a, "掉下来的阳光换成脑子阳光", sun.get_node_or_null("ZombieCardBrainSun") != null)
		sun.queue_free()


## 进一个关（照 probe_arknights_elite.gd 的进关法）
func _boot_level(a, level_path: String) -> MainGameManager:
	var para: ResourceLevelData = (load(level_path) as GDScript).new()
	if para == null:
		return null
	para.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelAdventure, 0, "vase_zombie")
	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	await a.wait(4.0)
	return GameContext.curr_main_game


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  <- " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[ZOMBIE_CARD] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
