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
## 脑子的「账本」在这（`_brains` + `add_brains()`）：目前唯一的收入口是**玩家对战模组**的
## 产脑光墓碑（`mods_builtin/player_battle/vsgravestone/component_create_brains.gd`，
## 它按节点名 `ZombieCardPvpWiring` 找到本接线入账），日后做脑子收入也归这一口。

const Settings := preload("zombie_card_settings.gd")
const BankView := preload("zombie_card_battle_slot.tscn")
const ChoosePanel := preload("zombie_card_choose_panel.tscn")
## 脑子阳光皮（与「我是僵尸」接线同一套素材与挂法）
const BrainSun := preload("zombie_card_brain_sun.gd")

## 模组素材（相对模组目录；`ModManager.load_mod_asset()` 两个加载根都认）
## 僵尸卡卡面不在这里：全模组共用 `Settings.ASSET_ZOMBIE_CARD_BG`（所有僵尸卡一张底图）
const ASSET_SEED_BANK := "ZombieSeedBank.png"
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


## 每张卡判「够不够」用哪个池：僵尸 / 僵王卡问脑子，其余（植物）问阳光
## （产脑光墓碑本身也是僵尸卡 —— 它 2026-10-25 从植物改成僵尸单位，不用再单判）
func _currency_for_card(card: Card) -> int:
	return _brains if costs_brains(card) else _slot.sun_value


## 用卡之后扣哪笔：僵尸 / 僵王卡扣脑子（刷计数 + 重判够不够），其余扣阳光
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


## 这张卡花不花脑子：僵尸 / 僵王卡
##
## ★ 产脑光墓碑（玩家对战模组）2026-10-25 已从**植物**改成**僵尸单位**：
##   它是 `CardType.Zombie`，`is_zombie_card()` 直接判中 —— 本文件不再需要
##   向玩家对战模组确认「这是不是那张植物类卡」，货币路由与卡面统一走僵尸这条线。
static func costs_brains(card: Card) -> bool:
	return is_zombie_card(card)


#region 对战花费（PVZ DLC Edition 对战口径）
## 这张僵尸 / 僵王卡在对战里花多少脑子；不是这两类 / 表里没登记时返回 -1
##
## 表在 `zombie_card_settings.gd` 的 `PLAYER_BATTLE_ZOMBIE_COSTS`（2026-10-25 从
## PVZ DLC Edition 对战模式同步）。**只改这张卡自己的 `sun_cost`**，不动角色注册表 ——
## 「我是僵尸」用的还是原口径，两边互不影响。
static func versus_cost_of(card: Card) -> int:
	if card == null:
		return -1
	if card.card_type == ResourceCardReference.CardType.Zombie:
		return int(Settings.PLAYER_BATTLE_ZOMBIE_COSTS.get(card.card_zombie_type, -1))
	if card.card_type == ResourceCardReference.CardType.ZombieBoss:
		return int(Settings.PLAYER_BATTLE_ZOMBIE_COSTS.get(card.card_zombie_boss_type, -1))
	return -1


## 把一张卡的费用换成对战口径（表里没登记就保持原值）
static func apply_versus_cost(card: Card) -> void:
	var cost := versus_cost_of(card)
	if cost >= 0:
		card.sun_cost = cost


## 候选容器也换：面板上显示的数字是**容器自己**的 `sun_cost`，
## 内层那张卡带着另一份（选中后原样搬进卡槽）—— 两份都要改
static func apply_versus_cost_to_container(container: CardCandidateContainer) -> void:
	if container == null or container.card == null:
		return
	var cost := versus_cost_of(container.card)
	if cost < 0:
		return
	container.sun_cost = cost
	container.card.sun_cost = cost


## 槽里所有僵尸 / 僵王卡换成对战花费（选卡收尾走一遍）
static func sync_versus_costs(slot: CardSlotBattle) -> void:
	if slot == null:
		return
	for card in slot.curr_cards:
		apply_versus_cost(card)
#endregion


#region 对战冷却（PVZ DLC Edition 对战口径）
## 这张僵尸 / 僵王卡在对战里冷却多少秒；不是这两类 / 表里没登记时返回 -1
##
## 表在 `zombie_card_settings.gd` 的 `PLAYER_BATTLE_ZOMBIE_COOLDOWNS`（2026-10-25 从
## PVZ DLC Edition wiki 同步；wiki 没写全，出处与「待核实」见那张表的注释）。
## **只改这张卡自己的 `cool_time`**，不动角色注册表 ——「我是僵尸」仍是 0 冷却。
static func versus_cooldown_of(card: Card) -> float:
	if card == null:
		return -1.0
	if card.card_type == ResourceCardReference.CardType.Zombie:
		return float(Settings.PLAYER_BATTLE_ZOMBIE_COOLDOWNS.get(card.card_zombie_type, -1.0))
	if card.card_type == ResourceCardReference.CardType.ZombieBoss:
		return float(Settings.PLAYER_BATTLE_ZOMBIE_COOLDOWNS.get(card.card_zombie_boss_type, -1.0))
	return -1.0


## 把一张卡的冷却换成对战口径（表里没登记就保持原值）
##
## ⚠️ 必须在**用卡之前**改：`Card.card_cool()` 是按当时的 `cool_time` 起表的，
##    用卡后再改只会影响下一次。
static func apply_versus_cooldown(card: Card) -> void:
	var cool := versus_cooldown_of(card)
	if cool >= 0.0:
		card.cool_time = cool


## 候选容器也换：`CardCandidateContainer._ready()` 会把内层卡的 `cool_time` 记进
## `source_cool_time`（还池时按它恢复），所以**只改内层卡**、不动源值 ——
## 下一关重新取件时容器会把卡的冷却写回本体口径，再由这里改一遍。
static func apply_versus_cooldown_to_container(container: CardCandidateContainer) -> void:
	if container == null or container.card == null:
		return
	apply_versus_cooldown(container.card)


## 槽里所有僵尸 / 僵王卡换成对战冷却（选卡收尾走一遍）
static func sync_versus_cooldowns(slot: CardSlotBattle) -> void:
	if slot == null:
		return
	for card in slot.curr_cards:
		apply_versus_cooldown(card)
#endregion


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
		## 本关没有选卡界面（比如以后出的快速开局入口）：僵尸块就空着
		## —— 没有「默认六张」兜底了，没选卡 = 这一局僵尸方没有卡可出
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
	panel.setup(_slot, _load_texture(Settings.ASSET_ZOMBIE_CARD_BG), chooser_bg)
	_choose_panel = panel
	## 选卡结束：收面板（僵尸块保持玩家点出来的那些，不再发默认牌）
	## （⚠️ 多轮重选不会重新拉起这一面 —— 对战目前没有多轮，先不管）
	main_game.signal_choose_card_finished.connect(_on_choose_card_finished)


func _on_choose_card_finished() -> void:
	if _choose_panel != null:
		_choose_panel.finish_choose()
		_choose_panel = null


## 给槽里所有**花脑子的卡**（僵尸 / 僵王，含产脑光墓碑这只僵尸）换上模组共用那张卡面
## （选卡收尾时用；图见 `Settings.ASSET_ZOMBIE_CARD_BG`）
static func restyle_zombie_cards(slot: CardSlotBattle, zombie_seed_tex: Texture2D) -> void:
	if zombie_seed_tex == null:
		return
	for card in slot.curr_cards:
		if not costs_brains(card):
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
