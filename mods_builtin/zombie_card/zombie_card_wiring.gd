extends Node
## 僵尸卡模组的每局接线
##
## 挂在主游戏节点底下（入口脚本 `install_to_main_game()` 里建的），干四件事：
##   1. 出战卡槽 / 选卡界面 / 僵尸卡卡面 换 PVZ2 的贴图
##   2. 直接把僵尸卡发进出战卡槽（**不去动**本体那个全局的「僵尸卡总开关」）
##   3. 脑光：脑子上的粉色星芒（被啃一口闪一下，脑子被吃掉时爆一下）
##   4. 脑子阳光：天上掉的阳光换成 PVZ2 的 BrainSun（只换外观，收集行为不变）
##
## 只在「我是僵尸」关卡里装（入口脚本判过 `game_para.is_zombie_mode`）。

const Settings := preload("zombie_card_settings.gd")
const BrainGlow := preload("zombie_card_brain_glow.gd")
const BrainSun := preload("zombie_card_brain_sun.gd")

## 模组素材（相对模组目录；`ModManager.load_mod_asset()` 两个加载根都认）
const ASSET_SEED_BANK := "ZombieSeedBank.png"
const ASSET_ZOMBIE_SEED := "ZombieSeed.png"
const ASSET_CHOOSER_BACKGROUND := "SeedChooser_Background_I_Zombie.png"
const ASSET_BRAIN_GLOW_BIG := "BrainGlowBig.png"
const ASSET_BRAIN_GLOW_SMALL := "BrainGlowSmall.png"
const ASSET_BRAIN_SUN := "BrainSun.png"

## 出战卡槽底图（PVZ2 的 ZombieSeedBank 是 446×87，边距照原版那张）
const SEED_BANK_MARGIN_LEFT := 78.0
const SEED_BANK_MARGIN_TOP := 10.0
const SEED_BANK_MARGIN_RIGHT := 12.0
const SEED_BANK_MARGIN_BOTTOM := 10.0

## 主游戏
var _main_game: MainGameManager
## 脑子 → 脑光节点（脑子被吃掉后连着一起没了，键会顺手清掉）
var _glows: Dictionary = {}
## 脑子 → 上一次看到的血量（血少了 = 被啃了一口 ⇒ 闪一下脑光）
var _last_hp: Dictionary = {}


## 装到这一局上（由入口脚本调用）
func setup(main_game: MainGameManager) -> void:
	_main_game = main_game
	if main_game == null or main_game.game_para == null:
		return
	if not main_game.game_para.is_zombie_mode:
		return
	_apply_card_slot_skin()
	_deal_zombie_cards()
	## 天上掉的阳光换成脑子（PVZ2 的「我是僵尸」里掉下来的就是脑子）
	EventBus.subscribe(ConstEventName.SUN_SPAWNED, _on_sun_spawned)


#region 卡槽外观
## 出战卡槽 = 僵尸卡槽；选卡界面（待选区）背景换成「我是僵尸」那张
func _apply_card_slot_skin() -> void:
	var card_manager: CardManager = _main_game.card_manager
	if card_manager == null:
		return
	## 出战卡槽（僵尸卡槽）：底图换成 PVZ2 的那张
	var battle: CardSlotBattle = card_manager.card_slot_battle
	if battle != null:
		var seed_bank_tex := _load_texture(ASSET_SEED_BANK)
		if seed_bank_tex != null:
			var style := StyleBoxTexture.new()
			style.texture = seed_bank_tex
			style.texture_margin_left = SEED_BANK_MARGIN_LEFT
			style.texture_margin_top = SEED_BANK_MARGIN_TOP
			style.texture_margin_right = SEED_BANK_MARGIN_RIGHT
			style.texture_margin_bottom = SEED_BANK_MARGIN_BOTTOM
			battle.add_theme_stylebox_override("panel", style)
	## 选卡界面（待选区）背景：换成 PVZ2 的「我是僵尸」那张（尺寸与原版那张一致）
	var norm: CardSlotNorm = card_manager.card_slot_norm
	if norm != null and norm.card_slot_candidate != null:
		var chooser_tex := _load_texture(ASSET_CHOOSER_BACKGROUND)
		if chooser_tex != null:
			norm.card_slot_candidate.texture = chooser_tex
#endregion


#region 发僵尸卡
## 把僵尸卡发进出战卡槽
##
## ★ 为什么不用本体那条「僵尸卡总开关」：它是**全局**的，一打开，普通关卡的选卡界面
##   也会冒出僵尸页，玩家能在正常关里放僵尸。这里只在「我是僵尸」关卡里直接发牌。
func _deal_zombie_cards() -> void:
	var battle: CardSlotBattle = _main_game.card_manager.card_slot_battle
	if battle == null:
		return
	## 卡槽一个占位都没有（关卡把卡槽数写成 0）时发不了牌，硬发会越界
	if battle.cards_placeholder.is_empty():
		Log.warn("僵尸卡模组：出战卡槽没有占位格，这一局发不出僵尸卡")
		return
	## 已经有僵尸卡了就不重复发（本体那条通道也可能已经发过）
	for card in battle.curr_cards:
		if card != null and card.card_type == ResourceCardReference.CardType.Zombie:
			_restyle_zombie_cards()
			return
	var zombie_refs: Array[ResourceCardReference] = []
	## 关卡自己写好的僵尸预选卡优先（「我是僵尸」关卡写的就是它）
	for reference in _main_game.game_para.prechosen_cards:
		if reference != null and reference.card_type == ResourceCardReference.CardType.Zombie:
			zombie_refs.append(reference)
	## 关卡没写就用默认那几张
	if zombie_refs.is_empty():
		zombie_refs = ResourceCardReference.create_zombie_list(Settings.DEFAULT_ZOMBIE_CARDS)
	## 槽里已有的卡保持在前面
	var all_refs: Array[ResourceCardReference] = []
	for card in battle.curr_cards:
		if card != null and card.card_reference != null:
			all_refs.append(card.card_reference)
	all_refs.append_array(zombie_refs)
	battle.set_cards(all_refs)
	_restyle_zombie_cards()


## 僵尸卡的卡面换成 PVZ2 的僵尸卡牌
func _restyle_zombie_cards() -> void:
	var battle: CardSlotBattle = _main_game.card_manager.card_slot_battle
	if battle == null:
		return
	var zombie_seed_tex := _load_texture(ASSET_ZOMBIE_SEED)
	if zombie_seed_tex == null:
		return
	for card in battle.curr_cards:
		if card == null or card.card_type != ResourceCardReference.CardType.Zombie:
			continue
		if is_instance_valid(card.card_bg):
			card.card_bg.texture = zombie_seed_tex
#endregion


#region 脑光
## 每帧盯一眼脑子：新的挂上脑光，血少了闪一下
func _process(_delta: float) -> void:
	if _main_game == null or not is_instance_valid(_main_game):
		return
	var item_manager: GameItemManager = _main_game.game_item_manager
	if item_manager == null:
		return
	_clean_dead_glows()
	for brain in item_manager.gim_brain.curr_brain:
		if not is_instance_valid(brain):
			continue
		var key: int = brain.get_instance_id()
		if not _glows.has(key):
			_spawn_glow(brain)
		var hp: int = brain.curr_hp
		var last_hp: int = int(_last_hp.get(key, hp))
		if hp < last_hp:
			var glow = _glows.get(key, null)
			if glow != null:
				glow.flash()
		_last_hp[key] = hp


## 给一个脑子挂上脑光
##
## ⚠️ 挂在**脑子的同级**上（脑子底下不行）：脑子被吃掉时会 `queue_free()`，
##   挂它底下的话「爆一下」那一下会跟着一起没了。
func _spawn_glow(brain: BrainOnZombieMode) -> void:
	var tex := _load_texture(ASSET_BRAIN_GLOW_SMALL)
	if tex == null:
		return
	var parent := brain.get_parent()
	if parent == null:
		return
	var glow = BrainGlow.new()
	glow.name = "BrainGlow"
	parent.add_child(glow)
	glow.setup(brain, tex)
	_glows[brain.get_instance_id()] = glow


## 清掉已经被吃掉的脑子留下的键
func _clean_dead_glows() -> void:
	for key in _glows.keys():
		var glow = _glows[key]
		if glow == null or not is_instance_valid(glow):
			_glows.erase(key)
			_last_hp.erase(key)
#endregion


#region 脑子阳光
## 天上掉了一颗阳光 ⇒ 换成「脑子阳光」（PVZ2 的「我是僵尸」里掉下来的就是脑子）
func _on_sun_spawned(sun: Sun) -> void:
	if sun == null or not is_instance_valid(sun):
		return
	if sun.get_node_or_null("ZombieCardBrainSun") != null:
		return
	## 原版那套阳光贴图先藏掉（动画树还在跑，藏的是它们的父节点）
	var body := sun.get_node_or_null("body") as CanvasItem
	if body != null:
		body.visible = false
	var holder = BrainSun.new()
	holder.name = "ZombieCardBrainSun"
	sun.add_child(holder)
	holder.setup(_load_texture(ASSET_BRAIN_SUN), _load_texture(ASSET_BRAIN_GLOW_BIG))
#endregion


## 读模组素材（`res://` 与 `user://` 两个加载根都认）
func _load_texture(rel_path: String) -> Texture2D:
	var res: Resource = ModManager.load_mod_asset(ModIds.ZOMBIE_CARD, rel_path)
	return res as Texture2D
