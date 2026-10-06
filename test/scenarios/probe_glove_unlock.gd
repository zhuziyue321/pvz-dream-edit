extends RefCounted
## 探针 PROBE12：手套解锁进度 + 冒险 4-6 戴夫赠礼对话
## 覆盖：
##   1. 静态：ConstUnlockLevel.GLOVE_UNLOCK_ADVENTURE_LEVEL = 35（通关 4-5），34 未解锁 / 35 已解锁
##   2. 静态：adventure_04_06.tres 挂着赠送对话（8 句、第 5/6/7 句举手套、末句发疯、只播一次、
##      手持手套场景能实例化）—— 手写的 .tres 只有真加载才知道对不对，这一段专治它
##   3. 实机（模拟只通关到 4-4 = 34）：4-6 手套组件禁用、卡槽不出现手套，戴夫对话照播
##   4. 实机（模拟通关 4-5 = 35）：4-6 手套组件启用、卡槽出现手套
##   5. 实机：逐句点完赠礼对话，核对句数 / 「手套！」那句戴夫手上举着物品 / 末句发疯
## 机器可读汇总：最后一行 [GLOVEUNLOCK] result=PASS|FAIL failed=<n>

const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const LEVEL_04_06 := "res://src/levels/mode_adventure/adventure_04_06.gd"
## 4-6 在选关界面上的位置：第 4 个页（0 起 = 3）的第 6 关，关卡编号 0036
const PAGE_04 := 3
const ID_04_06 := "0036"
const GLOVE_SLOT := "/root/MainGame/CanvasLayerCardSlot/CardSlotRoot/CardSlotContainer/ShovelContainer/UIGlove"
## 戴夫对话的点击位置（800x600 下的屏幕中心；戴夫的点击面板覆盖全屏，点哪都能推进）
const DAVE_CLICK_POS := Vector2(400, 300)
## 赠礼对话里戴夫举起手套的那句
const GLOVE_TALK := "手套！"
const EXPECT_TALK_NUM := 8
## 赠礼对话的完整台词（顺序必须一致；不能用 const：带类型的数组字面量不是常量表达式）
var _expect_talks := [
	"雾这么大，我差点撞到你的房子！",
	"今晚有僵尸会从地底下挖过来！",
	"他们直接钻到你最后面那排！",
	"别慌，我给你带了个东西！",
	"手套！",
	"把种下去的植物拎起来，换个地方放下！",
	"不用铲掉，不用重种，跟原来一模一样！",
	"拿去用吧，别谢我——因为我疯了！！！",
]

var _failed := 0
## 逐句点对话时记录下来的台词
var _talks: Array[String] = []
## 念到「手套！」时戴夫手上物品是否可见
var _hand_item_visible_on_glove_talk := false
## 最后一句是否为发疯
var _last_talk_crazy := false


func run(a) -> void:
	a.log("")
	a.log("========== PROBE12 手套解锁进度 + 4-6 戴夫赠礼 ==========")
	## 手套功能总开关关闭时整支探针无意义：直接跳过（改回 true 后自动恢复全部检查）
	if not ConstFeatureSwitch.GLOVE_ENABLED:
		a.log("  !! GLOVE_ENABLED=false，手套功能已隐藏，跳过本探针")
		_finish(a)
		return
	_check_const(a)
	_check_dialog_resource(a)
	## 34 = 只通关到 4-4：手套还没拿到
	await _run_level(a, 34, false)
	## 35 = 已通关 4-5：戴夫刚把手套交出来
	await _run_level(a, 35, true)
	_check_dave_talks(a)
	_finish(a)


#region 断言与收尾
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[GLOVEUNLOCK] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion


#region 静态
## 解锁常量：与铲子同一套口径，通关 4-5（关卡序号 35）后才拿到手套
func _check_const(a) -> void:
	a.log("")
	a.log("--- 1. 手套解锁常量 ---")
	a.log("  GLOVE_UNLOCK_ADVENTURE_LEVEL=%d（%s）" % [
		ConstUnlockLevel.GLOVE_UNLOCK_ADVENTURE_LEVEL,
		ConstUnlockLevel.get_adventure_level_name(ConstUnlockLevel.GLOVE_UNLOCK_ADVENTURE_LEVEL)])
	_check(a, "解锁关卡 = 4-5（序号 35）", ConstUnlockLevel.GLOVE_UNLOCK_ADVENTURE_LEVEL == 35,
		str(ConstUnlockLevel.GLOVE_UNLOCK_ADVENTURE_LEVEL))
	_check(a, "34（通关到 4-4）未解锁", not ConstUnlockLevel.is_glove_unlocked(34))
	_check(a, "35（通关 4-5）已解锁", ConstUnlockLevel.is_glove_unlocked(35))


## 关卡资源上挂的赠礼对话资源（手写的 .tres 只有真加载才验证得了）
func _check_dialog_resource(a) -> void:
	a.log("")
	a.log("--- 2. 4-6 赠礼对话资源 ---")
	## 4-6 已是关卡脚本（.gd）：实例化后才拿得到关卡数据
	var level_script = load(LEVEL_04_06)
	var para = level_script.new() if level_script is GDScript else level_script
	if para == null:
		_check(a, "（前置）4-6 关卡资源可加载", false, LEVEL_04_06)
		return
	## 对话在 run_flow() 里现场构造（见 adventure_04_06._build_dave_dialog），这里直接调它取
	var dialog: CrazyDaveDialogResource = para._build_dave_dialog()
	if dialog == null:
		_check(a, "（前置）4-6 挂着开场戴夫对话", false)
		return
	_check(a, "4-6 挂着开场戴夫对话", true)
	_check(a, "赠礼对话只播一次（重玩已通关的 4-6 不再播）", para.dave_dialog_only_first_playthrough)

	var details: Array = dialog.dialog_detail_list
	_check(a, "赠礼对话共 %d 句" % EXPECT_TALK_NUM, details.size() == EXPECT_TALK_NUM, str(details.size()))
	## 第 5/6/7 句（下标 4/5/6）戴夫举起手套，末句（下标 7）发疯收尾
	for idx in [4, 5, 6]:
		if idx >= details.size():
			_check(a, "第 %d 句存在" % (idx + 1), false)
			continue
		var d: CrazyDaveDialogDetailResource = details[idx]
		_check(a, "第 %d 句举起手套（is_hand + hand_item_id=0）" % (idx + 1),
			d.is_hand and d.hand_item_id == 0, "is_hand=%s id=%d" % [str(d.is_hand), d.hand_item_id])
	if details.size() == EXPECT_TALK_NUM:
		var last: CrazyDaveDialogDetailResource = details[EXPECT_TALK_NUM - 1]
		_check(a, "末句发疯收尾", last.is_crazy, str(last.is_crazy))
		_check(a, "末句收起手上物品", not last.is_hand, str(last.is_hand))

	_check(a, "手持物品配置 1 个（手套）", dialog.all_hand_itmes_scene.size() == 1,
		str(dialog.all_hand_itmes_scene.size()))
	if dialog.all_hand_itmes_scene.is_empty():
		return
	var item: Node = dialog.all_hand_itmes_scene[0].instantiate()
	_check(a, "手套场景可实例化且是 Node2D", item is Node2D, str(item))
	var sprite: Sprite2D = _find_sprite(item)
	_check(a, "手套场景带 Sprite2D 且贴图非空", sprite != null and sprite.texture != null,
		"" if sprite == null else str(sprite.texture))
	## 没进过场景树，直接 free（queue_free 要等到帧末，退出时会报 ObjectDB 泄漏）
	item.free()


func _find_sprite(root: Node) -> Sprite2D:
	if root is Sprite2D:
		return root as Sprite2D
	for ch in root.get_children():
		var s := _find_sprite(ch)
		if s != null:
			return s
	return null
#endregion


#region 实机
## 进 4-6 并把「已通关的最大关卡序号」设成 max_level，核对手套的启用与卡槽显隐
func _run_level(a, max_level: int, expect_unlocked: bool) -> void:
	a.log("")
	a.log("--- 3. 实机 4-6（模拟已通关到 %s）---" % ConstUnlockLevel.get_adventure_level_name(max_level))
	Global.global_game_state.curr_plant.assign([CharacterRegistry.PlantType.P001PeaShooterSingle])
	_set_progress(max_level)
	a.log("  max_success_adventure_level=%d" % Global.global_game_state.get_max_success_adventure_level())

	var para: ResourceLevelData = (load(LEVEL_04_06) as GDScript).new()
	para.set_choose_level(ADV, PAGE_04, ID_04_06)
	Global.game_para = para
	a.log("[场景] 进入 4-6（%s）" % para.save_game_name)
	await a.wait(2.0)
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	if not await _wait_main_game(a, 60.0):
		_check(a, "4-6 进入 MAIN_GAME", false, "超时")
		return
	_check(a, "4-6 进入 MAIN_GAME", true)

	var comp := _glove_comp()
	if comp == null:
		_check(a, "（前置）手套组件已注册", false)
		return
	_check(a, "手套组件 is_enabling=%s" % str(expect_unlocked), comp.is_enabling == expect_unlocked,
		"is_enabling=%s" % str(comp.is_enabling))
	var slot: CanvasItem = a.get_node_or_null(GLOVE_SLOT)
	if slot == null:
		_check(a, "（前置）手套卡槽存在", false)
		return
	_check(a, "手套卡槽显示=%s" % str(expect_unlocked), slot.visible == expect_unlocked,
		"visible=%s" % str(slot.visible))
	if expect_unlocked:
		var icon: CanvasItem = a.get_node_or_null(GLOVE_SLOT + "/Glove")
		_check(a, "空手时显示手套图标", icon != null and icon.visible)


## 把通关记录写成「第 1 关 ~ 第 max_level 关全部通关」
func _set_progress(max_level: int) -> void:
	var state := Global.global_game_state
	state.curr_all_level_state_data = {}
	for i in range(1, max_level + 1):
		state.curr_all_level_state_data["%d_0_%04d" % [ADV, i]] = {"IsSuccess": true}


func _glove_comp() -> HandComponentGlove:
	if Global.main_game == null or Global.main_game.hand_manager == null:
		return null
	return Global.main_game.hand_manager.get_hand_component(
		HandComponentBase.E_HandComponentType.Glove) as HandComponentGlove


## 等进 MAIN_GAME；中途出现戴夫就逐句点完，并记录台词（只在第一次记录）
func _wait_main_game(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if Global.main_game != null:
			var dave := _find_dave()
			if dave != null:
				if not await _walk_dave_dialog(a):
					return false
			if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
				return true
		await a.wait(0.5)
		waited += 0.5
	return false


func _find_dave() -> CrazyDave:
	var mg = Global.main_game
	if mg == null:
		return null
	for child in mg.canvas_layer_ui.get_children():
		if child is CrazyDave:
			return child as CrazyDave
	return null


## 逐句点戴夫对话：记录每句台词、念到「手套！」时手上物品是否可见、末句是否发疯
func _walk_dave_dialog(a, timeout: float = 60.0) -> bool:
	var waited := 0.0
	var recording: bool = _talks.is_empty()
	while waited < timeout:
		var dave := _find_dave()
		if dave == null:
			return true
		## 戴夫刚进场、气泡还没弹出来时，Label 上还是场景里的占位文本，读了会多记一句
		if not dave.bubble_2.visible:
			await a.wait(0.3)
			waited += 0.3
			continue
		var text: String = dave.speech_text_label.text
		var hand_visible := false
		if dave.curr_hand_item_id >= 0 and dave.curr_hand_item_id < dave.all_hand_items.size():
			hand_visible = dave.all_hand_items[dave.curr_hand_item_id].visible
		## 发疯动画播完才会翻页，连点会读到同一句：同一句只记一次
		if recording and (_talks.is_empty() or _talks[-1] != text):
			_talks.append(text)
			if text == GLOVE_TALK:
				_hand_item_visible_on_glove_talk = hand_visible
			_last_talk_crazy = dave.is_crazy
			a.log("  戴夫[%d] %s（手持物品可见=%s 发疯=%s）" % [
				_talks.size(), text, str(hand_visible), str(dave.is_crazy)])
		await a.click(DAVE_CLICK_POS.x, DAVE_CLICK_POS.y)
		await a.wait(0.5)
		waited += 0.5
	return _find_dave() == null
#endregion


#region 对话结果
func _check_dave_talks(a) -> void:
	a.log("")
	a.log("--- 4. 赠礼对话逐句核对 ---")
	_check(a, "开场播了戴夫赠礼对话", not _talks.is_empty(), "共 %d 句" % _talks.size())
	## 开场前后可能还夹着别的戴夫对话，所以按「连续子序列」核对这 8 句，而不是比总数
	_check(a, "赠礼对话 8 句按序念完", "|".join(_talks).contains("|".join(_expect_talks)), str(_talks))
	_check(a, "念到「手套！」时戴夫手上举着物品", _hand_item_visible_on_glove_talk,
		str(_hand_item_visible_on_glove_talk))
	_check(a, "末句发疯收尾", _last_talk_crazy, str(_last_talk_crazy))
#endregion
