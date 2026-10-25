extends PanelContainer
## 僵尸卡模组的「玩家对战」**选僵尸卡面板**（贴在植物选卡面板右面）
##
## 挂在 `CardSlotNorm` 底下（与 `CardSlotCandidate` 同级）：
##   - 外观：PVZ2 `SeedChooser_Background_I_Zombie` 做九宫格（边距照边框厚度收窄，
##     465 宽的原图压成一行五张的窄面板）；
##   - 内容：从候选容器池（`SceneRegistry.acquire_candidate_container()`）取**全部**
##     已登记的僵尸卡（`AllCards.zombie_card_ids` 的登记序），一行五张，超出可视高度
##     用滚动条（不设翻页按钮 —— 本体待选区走翻页是两条路，这里卡少一屏装得下）；
##   - **不做解锁门槛**：本体待选区按存档解锁名单点亮，僵尸卡通道本是调试特性、
##     存档里没人解锁过 —— 这里全亮，本模组本身就是开关；
##   - 点一张卡 → 飞进出战卡槽的**僵尸块**（第 6~11 格，上限 = 块宽 6）；
##     再点 → 飞回容器（分块的槽里空位不挤占，别的卡不挪窝）。
##     行为照抄本体 `CardSlotNorm._on_card_click` 的分块分支 + `move_card_to`：
##     经 `TemporaryCard` 中转的 0.2s 飞行。
##
## 出场 / 收场与本体待选区同一套（0.2s 平移，y 615 ↔ 89）：
## **出场是跟拍** —— 盯着本体待选区的位置，它开始向上滑（`appear_choose`，选卡事件、
## 开场相机平移完之后）就跟着滑入；⚠️ 不能挂在 `MAIN_GAME_PROGRESS_UPDATE` 上出场：
## 进度在主游戏 `_ready` 一进来就是选卡阶段，跟进度走会「出早了」。
## 收场仍走进度事件（选卡收尾推 PREPARE，与本体待选区滑出同一拍）。
##
## 选卡结束（`signal_choose_card_finished`）由接线转成 `finish_choose()`：
## 只管发牌收尾（一张都没选就发默认六张，见 `zombie_card_settings.gd`），滑出交给阶段事件。

const Settings := preload("zombie_card_settings.gd")
const PvpWiring := preload("zombie_card_pvp_wiring.gd")

## 选中的僵尸卡放进出战卡槽的**僵尸块**（第 0 块留给植物卡，见接线 `_configure_slot`）
const ZOMBIE_BLOCK := 1

## 一行五张
const PAGE_COLS := 5

## 背景九宫格边距：照原图边框厚度（465×513，边框 ~15px，顶部带两颗装饰星 ~32px）
const BG_MARGIN_LEFT := 20.0
const BG_MARGIN_TOP := 32.0
const BG_MARGIN_RIGHT := 20.0
const BG_MARGIN_BOTTOM := 20.0

## 出场 / 收场（照本体 `CardSlotNorm.move_card_slot_candidate` 的 0.2s 平移）
const APPEAR_TIME := 0.2
const APPEAR_POS_Y := 89.0
const HIDE_POS_Y := 615.0
## 本体待选区的隐藏停靠位是 y=600（offset_top），离开它 = 选卡界面开始滑入
const CHOOSE_UI_TRIGGER_Y := 595.0

## 选中的卡放进出战卡槽的僵尸块（第 6~11 格；存储、冷却、点卡全走本体那套）
var _zombie_slot: CardSlotBattle = null
var _zombie_seed_tex: Texture2D = null
## 飞行卡片的临时存放点（借用本体 `CardSlotNorm` 的 `TemporaryCard`：
## 画在整组卡槽的最上层，飞行途中不被面板 / 卡槽挡住）
var _temp_card: Control = null

## 进行中的平移动画（新动画来了先杀旧的，避免两个 tween 抢 position）
var _move_tween: Tween = null

@onready var card_scroll: ScrollContainer = $PageHolder/CardScroll


## ⚠️ 出场走跟拍（见类注释），不走进度事件；收场走进度事件。
## 跳过选卡的局（无选卡界面 / 系统预选）直接就位在屏幕下方外也无妨 ——
## 收场事件会把它停在 615（反正选卡收尾本来就要滑出）。
func _ready() -> void:
	EventBus.subscribe(ConstEventName.MAIN_GAME_PROGRESS_UPDATE, _on_main_game_progress_update)


## 跟拍本体待选区：它开始向上滑（y 离开 600 的隐藏位）就跟着滑入
func _process(_delta: float) -> void:
	var candidate := _find_candidate()
	if candidate == null:
		return
	if candidate.position.y < CHOOSE_UI_TRIGGER_Y:
		set_process(false)
		if _is_choosing_progress():
			_slide_to(APPEAR_POS_Y)


func _find_candidate() -> Control:
	var card_slot_norm = get_parent()
	return card_slot_norm.card_slot_candidate if card_slot_norm != null else null


## 装这一面（由 `zombie_card_pvp_wiring.gd` 调，必须在进树之后；
## 初始停靠在屏幕下方外，滑入由阶段事件驱动）
func setup(zombie_slot: CardSlotBattle, zombie_seed_tex: Texture2D, chooser_bg: Texture2D) -> void:
	_zombie_slot = zombie_slot
	_zombie_seed_tex = zombie_seed_tex
	## 本面板由接线挂在 `CardSlotNorm` 底下（见 `zombie_card_pvp_wiring._install_choose_panel`），
	## 借它的 `TemporaryCard` 当飞行的中转点（与本体的选卡飞行动画同款）
	var norm := get_parent()
	_temp_card = norm.temporary_card if norm != null else null
	_apply_style(chooser_bg)
	_build_grid()


## 选卡结束（由接线挂在 `MainGameManager.signal_choose_card_finished` 上转进来）：
## 玩家一张僵尸卡都没选就发默认六张（`set_cards` 按块放位，不动植物那半）；
## 给僵尸块所有卡换卡面并刷一遍战斗状态
## （滑出屏幕不在这里做 —— 由阶段变化事件驱动，与本体待选区同拍）
func finish_choose() -> void:
	if _count_zombie_cards() == 0:
		_zombie_slot.set_cards(ResourceCardReference.create_zombie_list(Settings.PLAYER_BATTLE_ZOMBIE_CARDS))
	PvpWiring.restyle_zombie_cards(_zombie_slot, _zombie_seed_tex)
	_zombie_slot.main_game_refresh_card()


## 僵尸块里已经放了几张（空位不算）
func _count_zombie_cards() -> int:
	return _zombie_slot.count_cards_in_block(ZOMBIE_BLOCK)


#region 外观 / 出场收场
func _apply_style(bg_tex: Texture2D) -> void:
	if bg_tex == null:
		return
	var style := StyleBoxTexture.new()
	style.texture = bg_tex
	style.texture_margin_left = BG_MARGIN_LEFT
	style.texture_margin_top = BG_MARGIN_TOP
	style.texture_margin_right = BG_MARGIN_RIGHT
	style.texture_margin_bottom = BG_MARGIN_BOTTOM
	add_theme_stylebox_override("panel", style)


## 阶段变化：选卡 / 重选滑入，其余滑出（与本体待选区同拍同速）
func _on_main_game_progress_update(main_game_progress: MainGameManager.E_MainGameProgress) -> void:
	match main_game_progress:
		MainGameManager.E_MainGameProgress.CHOOSE_CARD, \
		MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD:
			_slide_to(APPEAR_POS_Y)
		_:
			_slide_to(HIDE_POS_Y)


func _slide_to(target_y: float) -> void:
	if is_equal_approx(position.y, target_y):
		return
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position:y", target_y, APPEAR_TIME)
#endregion


## 建卡格：全部已登记的僵尸卡（去掉没选卡资格的，末尾补僵王），一行五张
## （容器从池里取，关卡销毁自动还池）
##
## ⚠️ 挂进格子要用 `reparent()`：池取出的容器**还挂在池存放节点下**
## （`CardCandidatePoolStorage`），裸 `add_child` 会炸 already has a parent ——
## 本体待选区取件后也是同一招（见 `CardSlotCandidate._build_plant_page_slots`）
func _build_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = PAGE_COLS
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	card_scroll.add_child(grid)
	for zombie_type: StringName in AllCards.zombie_card_ids:
		if zombie_type in Settings.PLAYER_BATTLE_EXCLUDED_ZOMBIES:
			continue
		var source: Card = AllCards.all_zombie_card_prefabs.get(zombie_type)
		if source == null:
			continue
		_add_candidate_to_grid(grid, source)
	## 僵王卡接在普通僵尸后面（选卡层两者同一个连续编号空间，见 `AllCards.rebuild`）
	for boss_source: Card in AllCards.all_boss_card_prefabs.values():
		_add_candidate_to_grid(grid, boss_source)
	## 产脑光墓碑接在最后：**植物类卡**但花脑子（僵尸方的产钱单位，50 脑光）——
	## 选中 / 退回 / 用卡全走同一套（它落僵尸块、由接线的货币路由扣脑子），
	## 卡面用运行期注册时画好的墓碑形象，不换 PVZ2 僵尸卡面
	var tombstone_ref := ResourceCardReference.create(
		ResourceCardReference.CardType.Plant, Settings.TOMBSTONE_PLANT_ID)
	if AllCards.has_template(tombstone_ref):
		_add_candidate_to_grid(grid, AllCards.get_template(tombstone_ref))
	else:
		Log.warn("僵尸卡模组：产脑光墓碑没注册上（模组入口 install 失败？），选卡面板不放它")


func _add_candidate_to_grid(grid: GridContainer, source: Card) -> void:
	var container := SceneRegistry.acquire_candidate_container(source, false)
	container.visible = true
	if container.get_parent() == null:
		grid.add_child(container)
	else:
		container.reparent(grid, false)
	container.card.signal_card_click.connect(_on_card_click.bind(container.card))
	## ⚠️ 必须用 `bind(card)` 把卡绑上去：`signal_card_click` 声明了 `(card)` 参数
	## 但卡发射时不带参（见 `Card._on_button_pressed`），直接连的话处理函数
	## 收不到卡 —— 点卡选不进卡槽（本体 `CardSlotNorm` 也是同一套 bind 接法）


#region 选中 / 退回（行为照本体 `CardSlotNorm._on_card_click` 的分块分支，目标 = 僵尸块）
## 点一张候选僵尸卡：选中 → 飞进僵尸块的第一个空位；再点 → 飞回候选容器
func _on_card_click(card: Card) -> void:
	if not _is_choosing_progress():
		return
	if card.is_choosed_pre_card:
		_deselect(card)
		SoundManager.play_other_SFX("tap")
		return
	var free := _zombie_slot.free_index_in_block(ZOMBIE_BLOCK)
	if free == -1:
		SoundManager.play_other_SFX("buzzer")
		return
	card.is_choosed_pre_card = true
	_zombie_slot.put_card_at(card, free)
	_move_card_to_holder(card, _zombie_slot.cards_placeholder[free])
	SoundManager.play_other_SFX("tap")


## 退回一张卡：只清自己那格（分块的槽空位不挤占，别的卡不挪窝），本卡回候选容器
func _deselect(card: Card) -> void:
	if _zombie_slot.take_out_card(card) == -1:
		return
	card.is_choosed_pre_card = false
	_move_card_to_holder(card, card.card_candidate_container)


## 搬卡（照本体 `CardSlotNorm.move_card_to` 的同一套飞行动画）：
## 先挪进 `TemporaryCard`（画在整组卡槽最上层，途中不被挡），
## 0.2s 把 `global_position` 飞到目标位置，落定后再 `reparent` 进目标格。
## 面板 / 僵尸卡槽 / TemporaryCard 同在 `CanvasLayerCardSlot/CardSlotRoot` 一个 Canvas 里，
## 全局坐标可直接插值。取不到中转点（接线方式变了）就退化为原地换父，不炸。
func _move_card_to_holder(card: Card, holder: CanvasItem) -> void:
	if holder == null or not is_instance_valid(holder):
		return
	if card.get_parent() == holder:
		return
	if _temp_card == null or not is_instance_valid(_temp_card):
		if card.get_parent() == null:
			holder.add_child(card)
		else:
			## 传 false：卡是 50×70 定尺寸，不需要保留跨父节点的全局变换
			card.reparent(holder, false)
		card.position = Vector2.ZERO
		return
	card.button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.reparent(_temp_card)
	var tween := create_tween()
	tween.tween_property(card, "global_position", holder.global_position, APPEAR_TIME)
	await tween.finished
	card.reparent(holder)
	card.button.mouse_filter = Control.MOUSE_FILTER_PASS


## 只在选卡阶段响应（选卡收尾后点槽里的卡是「用卡」，不能再往回退）
func _is_choosing_progress() -> bool:
	var main_game = GameContext.curr_main_game
	if not is_instance_valid(main_game):
		return false
	return main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD \
		or main_game.main_game_progress == MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD
#endregion
