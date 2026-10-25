extends Node
## 僵尸卡模组的「玩家对战」接线：**12 槽合一** + 右上银行视图 + 选僵尸卡面板
##
## 对战关卡里只有**一个**出战卡槽（本体那张，12 格）：
##   - 第 0~5 格：植物卡 —— 本体选卡流程，花**阳光**；
##   - 第 6~11 格：僵尸 / 僵王卡 —— 选僵尸卡面板选进来，花**脑子**（起始 150）。
## 卡与冷却都存在同一份 `curr_cards` 里（分块规则见 `card_slot_battle.gd`
## 的 `card_type_blocks` / `block_sizes`），「卡槽第几格」是**整槽 12 格**的口径
## （与联机模组的合并卡表同一套思想：眼前是两块，存储是一份）。
##
## 分池：通过卡槽的两个通用口子接进来 ——
##   - `currency_of_card`：每张卡判「够不够」问哪个池（僵尸 / 僵王卡问脑子，其余问阳光）；
##   - `on_card_cost`：用卡后扣哪笔（僵尸 / 僵王卡扣脑子，其余扣 sun_value）。
## 收的阳光照旧只进 `sun_value`（本体 `ADD_SUN_VALUE` 订阅），脑子不随阳光涨。
## 快捷键：对战整槽不占 1~0（`shortcuts_enabled = false`）。
##
## 右上那条反转银行（`zombie_card_battle_slot.tscn`）是**纯外观**：
## 底图 + 脑子计数 + 占位格 6~11 的宿主 —— 占位格从本体卡槽挪进来，
## 卡还挂在占位格里，存储 / 冷却 / 点卡全走本体那套。
##
## ⚠️ 只管卡槽与选卡：对战胜负 / 放置限制是对战逻辑的事，本接线不碰。
## 脑子的「账本」在这（`_brains` + `add_brains()`）：目前唯一的收入口是
## 产脑光墓碑（见 `vsgravestone/component_create_brains.gd`），日后做脑子收入也归这一口。

const Settings := preload("zombie_card_settings.gd")
const BankView := preload("zombie_card_battle_slot.tscn")
const ChoosePanel := preload("zombie_card_choose_panel.tscn")
## 脑子阳光皮（与「我是僵尸」接线同一套素材与挂法）
const BrainSun := preload("zombie_card_brain_sun.gd")

## 模组素材（相对模组目录；`ModManager.load_mod_asset()` 两个加载根都认）
const ASSET_SEED_BANK := "ZombieSeedBank.png"
const ASSET_ZOMBIE_SEED := "ZombieSeed.png"
const ASSET_CHOOSER_BACKGROUND := "SeedChooser_Background_I_Zombie.png"
const ASSET_BRAIN_SUN := "BrainSun.png"
const ASSET_BRAIN_GLOW_BIG := "BrainGlowBig.png"

## 银行视图节点名（重复接线时靠它防重）
const BANK_NAME := "ZombieCardBattleSlot"

## 底图两侧的九宫格留边（与银行视图的边距同一套，只用来算**槽总宽**好贴到右上角）
const BANK_MARGIN_LEFT := 12.0
const BANK_MARGIN_RIGHT := 78.0

## 卡面宽（占位剪影 50×70）
const CARD_WIDTH := 50.0

## 僵尸块号：`card_type_blocks` 里僵尸 / 僵王卡登记的块（第 0 块留给植物卡）
const ZOMBIE_BLOCK := 1

## 出战卡槽（12 格的那张本体槽） / 银行视图 / 选卡面板（面板保持无类型 —— 调它自己的 `finish_choose()`）
var _slot: CardSlotBattle = null
var _bank = null
var _choose_panel = null
## 脑光的收集落点（银行视图里脑子计数旁的标记，见 `get_brain_fly_target()`）
var _brain_target_marker: Marker2D = null
## 僵尸方的脑子（分池：这笔账记在接线这里，银行计数与僵尸卡判钱都读它）
var _brains := 0


## 装到这一局上（由入口脚本调用）
func setup(main_game: MainGameManager) -> void:
	var card_manager: CardManager = main_game.card_manager
	if card_manager == null or card_manager.card_slot_battle == null:
		Log.error("僵尸卡模组（玩家对战）：拿不到出战卡槽，本局装不上")
		return
	_slot = card_manager.card_slot_battle
	if _slot.cards_placeholder.size() < Settings.PLAYER_BATTLE_SLOT_NUM * 2:
		Log.error("僵尸卡模组（玩家对战）：出战卡槽不足 12 格（关卡应配 max_choosed_card_num = 12），装不上僵尸块")
		return
	_configure_slot()
	_install_bank(card_manager)
	_install_choose_panel(main_game, card_manager)


## 给本体卡槽配分块 / 快捷键 / 货币路由（幂等：块配置过就不再配第二遍）
func _configure_slot() -> void:
	if _slot.card_type_blocks.is_empty():
		_slot.card_type_blocks = {
			ResourceCardReference.CardType.Zombie: ZOMBIE_BLOCK,
			ResourceCardReference.CardType.ZombieBoss: ZOMBIE_BLOCK,
		}
		_slot.block_sizes.assign([
			Settings.PLAYER_BATTLE_SLOT_NUM,
			Settings.PLAYER_BATTLE_SLOT_NUM,
		])
	_slot.shortcuts_enabled = false
	_slot.currency_of_card = _currency_for_card
	_slot.on_card_cost = _on_card_cost
	_brains = Settings.PLAYER_BATTLE_START_BRAINS


## 每张卡判「够不够」用哪个池：僵尸 / 僵王卡与产脑光墓碑卡问脑子，其余（植物）问阳光
func _currency_for_card(card: Card) -> int:
	return _brains if costs_brains(card) else _slot.sun_value


## 用卡之后扣哪笔：僵尸 / 僵王卡与产脑光墓碑卡扣脑子（刷计数 + 重判够不够），其余扣阳光
func _on_card_cost(card: Card) -> void:
	if costs_brains(card):
		_brains = _brains - card.sun_cost
		if _bank != null:
			_bank.set_brains(_brains)
		_rejudge_brain_cards()
	else:
		_slot.sun_value = _slot.sun_value - card.sun_cost


static func is_zombie_card(card: Card) -> bool:
	return card != null and (card.card_type == ResourceCardReference.CardType.Zombie \
		or card.card_type == ResourceCardReference.CardType.ZombieBoss)


## 产脑光墓碑卡：**植物类卡**（运行期植物，走植物种植那套落位）但**花脑子** ——
## 它是僵尸方的产钱单位，50 脑光放一株、周期性给脑子入账
## （数值见 `zombie_card_settings.gd`；入账走 `add_brains()`）
static func is_tombstone_card(card: Card) -> bool:
	return card != null and card.card_type == ResourceCardReference.CardType.Plant \
		and card.card_plant_type == Settings.TOMBSTONE_PLANT_ID


## 这张卡花不花脑子：僵尸 / 僵王卡，加上墓碑卡
static func costs_brains(card: Card) -> bool:
	return is_zombie_card(card) or is_tombstone_card(card)


## 脑子变了之后把槽里花脑子的卡（僵尸 / 僵王 / 墓碑）按新脑子数重判一遍
## （其余植物卡认阳光池，不受影响）
func _rejudge_brain_cards() -> void:
	for card in _slot.curr_cards:
		if costs_brains(card):
			card.judge_sun_enough(_brains)


## 僵尸方脑子入账（产脑光墓碑的产出走这里；日后做脑子收入也归这一口）
func add_brains(amount: int) -> void:
	_brains += amount
	if _bank != null:
		_bank.set_brains(_brains)
	_rejudge_brain_cards()


## 脑光飞行的落点：右上银行里脑子计数的那个标记
##
## 换算与植物阳光计数器同一套口径（见 `Sun.pick()` 的注释）：银行挂在 CanvasLayer 里，
## 位置与摄像头有偏移，`标记全局位 + 相机位` 才是阳光（世界节点）该飞去的点。
## [return] 拿不到银行 / 标记时返回 Vector2.ZERO（调用方原地淡出，与基类口径一致）
func get_brain_fly_target() -> Vector2:
	var main_game = GameContext.curr_main_game
	if _brain_target_marker == null or not is_instance_valid(_brain_target_marker) \
			or main_game == null or not is_instance_valid(main_game.camera_2d):
		return Vector2.ZERO
	return _brain_target_marker.global_position + main_game.camera_2d.global_position


## 把一颗阳光换成「脑子阳光」外观（产脑光墓碑的产出用；与「我是僵尸」接线同款）——
## 原版阳光贴图先藏掉，挂上 BrainSun 皮（脑子 + 呼吸脑光），收集行为由换上的脚本管
func restyle_sun_as_brain(sun: Sun) -> void:
	if sun == null or not is_instance_valid(sun):
		return
	if sun.get_node_or_null("ZombieCardBrainSun") != null:
		return
	var body := sun.get_node_or_null("body") as CanvasItem
	if body != null:
		body.visible = false
	var holder = BrainSun.new()
	holder.name = "ZombieCardBrainSun"
	sun.add_child(holder)
	holder.setup(_load_texture(ASSET_BRAIN_SUN), _load_texture(ASSET_BRAIN_GLOW_BIG))


## 装右上角的银行视图，并把占位格 6~11 挪进去（幂等：已经挪过就不再挪）
func _install_bank(card_manager: CardManager) -> void:
	var slot_root: CardSlotRoot = card_manager.card_slot_root
	_bank = slot_root.get_node_or_null(BANK_NAME)
	if _bank == null:
		var bank_tex := _load_texture(ASSET_SEED_BANK)
		if bank_tex == null:
			return
		_bank = BankView.instantiate()
		_bank.name = BANK_NAME
		## 先摆位再进树：`_ready` 会按当前阶段对表滑入，进树后再赋位会把动画起点摁回屏幕外
		_place_top_right(slot_root, _bank)
		slot_root.add_child(_bank)
		_bank.set_bank_texture(bank_tex)
	var placeholders: Array = _slot.cards_placeholder
	var first_zombie := Settings.PLAYER_BATTLE_SLOT_NUM
	if placeholders[first_zombie].get_parent() != _bank.card_ui_list:
		var moved: Array = []
		for i in range(first_zombie, placeholders.size()):
			var placeholder = placeholders[i]
			placeholder.reparent(_bank.card_ui_list)
			moved.append(placeholder)
		## 槽的占位表 = 前 6 格（本体槽里）+ 后 6 格（银行里）；卡的存取全按这张表
		_slot.cards_placeholder = placeholders.slice(0, first_zombie) + moved
	_bank.set_brains(_brains)
	_brain_target_marker = _bank.marker_2d_brain_target
	_rejudge_brain_cards()


## 装选僵尸卡面板（贴在植物待选区右面），并接「选卡结束」收尾
func _install_choose_panel(main_game: MainGameManager, card_manager: CardManager) -> void:
	var card_slot_norm = card_manager.card_slot_norm
	var candidate = card_slot_norm.card_slot_candidate if card_slot_norm != null else null
	if candidate == null:
		## 本关没有选卡界面（比如以后出的快速开局入口）：直接发默认六张兜底
		_deal_default_zombie_cards()
		return
	var chooser_bg := _load_texture(ASSET_CHOOSER_BACKGROUND)
	var panel := ChoosePanel.instantiate()
	panel.name = "ZombieCardChoosePanel"
	## 先摆位再进树（同银行：`_ready` 按当前阶段对表滑入，进树后再赋位会盖回去）。
	## 贴到植物待选区右面（待选区 465 宽；当帧 size 还没算就用设计值），
	## 初始 y 停在屏幕下方外（615），选卡阶段由面板脚本滑入（与本体待选区同款）
	var panel_x: float = candidate.size.x
	if panel_x <= 0.0:
		panel_x = 465.0
	panel.position = Vector2(panel_x, 615.0)
	card_slot_norm.add_child(panel)
	panel.setup(_slot, _load_texture(ASSET_ZOMBIE_SEED), chooser_bg)
	_choose_panel = panel
	## 选卡结束：收面板；一张都没选就发默认六张
	## （⚠️ 多轮重选不会重新拉起这一面 —— 对战目前没有多轮，先不管）
	main_game.signal_choose_card_finished.connect(_on_choose_card_finished)


func _on_choose_card_finished() -> void:
	if _choose_panel != null:
		_choose_panel.finish_choose()
		_choose_panel = null


## 一张僵尸卡都没选时的兜底：给僵尸块发默认六张（`set_cards` 会按块放位，不动植物那半）
func _deal_default_zombie_cards() -> void:
	_slot.set_cards(ResourceCardReference.create_zombie_list(Settings.PLAYER_BATTLE_ZOMBIE_CARDS))
	restyle_zombie_cards(_slot, _load_texture(ASSET_ZOMBIE_SEED))
	_slot.main_game_refresh_card()


## 给槽里所有僵尸 / 僵王卡换上 PVZ2 的僵尸卡牌卡面（选卡收尾 / 默认发牌都要）
static func restyle_zombie_cards(slot: CardSlotBattle, zombie_seed_tex: Texture2D) -> void:
	if zombie_seed_tex == null:
		return
	for card in slot.curr_cards:
		if not is_zombie_card(card):
			continue
		if is_instance_valid(card.card_bg):
			card.card_bg.texture = zombie_seed_tex


## 贴到右上角：左侧植物半槽在左上，银行镜像到右上（脑区朝右贴屏幕边）
##
## 银行宽 = 僵尸格数 × 卡面宽 + 两侧九宫格留边；进树当帧布局还没跑，
## 直接按这套常量算，不读 `size`（那时还是 0）。
## 初始 y 停在屏幕上方外（-100），滑入由银行脚本按阶段事件驱动
func _place_top_right(slot_root: CardSlotRoot, bank: Control) -> void:
	var bank_width: float = Settings.PLAYER_BATTLE_SLOT_NUM * CARD_WIDTH \
		+ BANK_MARGIN_LEFT + BANK_MARGIN_RIGHT
	bank.position = Vector2(slot_root.get_viewport_rect().size.x - bank_width, -100.0)


## 读模组素材（`res://` 与 `user://` 两个加载根都认）
func _load_texture(rel_path: String) -> Texture2D:
	var res: Resource = ModManager.load_mod_asset(ModIds.ZOMBIE_CARD, rel_path)
	return res as Texture2D
