extends Node
class_name DaveSellManager
## 戴夫推销管理器(原版:商店解锁之前,戴夫在冒险模式的夜晚关卡开场推销卡槽扩充)
##
## 触发范围(见 is_can_sell()):冒险模式 + 本关序号 >= 2-2(ConstUnlockLevel.DAVE_SELL_ADVENTURE_LEVEL)
## + 商店尚未解锁(通关 3-4 之前) + 本关可以选卡 + 卡槽还没到上限。
## **什么时候推销由关卡脚本说了算**:2-2 ~ 3-4 这几关在 run_flow() 开头写一行
## `await dave_sell_card_slot()`(见 LevelScriptBase),本关有戴夫对话的关卡不写这一句
## —— 免得一关开场连播两段戴夫。
## 金币不够当前档价时戴夫不出现(2-2 例外:预告一次"攒到 $N 我就卖给你"),
## 所以那句快捷工具可以放心写在每一关的流程里,**只在钱足够时才真推销**。
##
## 本仓库的推销节奏(对齐原版"攒够了就来烦你"):
##   1. 2-2 开场:无论钱够不够,戴夫都出现。钱够就当场推销;
##      钱不够就报当前金币数并预告下一档价 —— 即"攒到 $750 我就卖给你"的预告,
##      这句预告只在 2-2 说一次(金币从 2-1 才开始掉落)。
##   2. 2-2 之后到商店解锁(通关 3-4)之前:只要玩家攒够了当前档位的价钱,开场立即推销;
##      钱还没攒够就不出现,免得每关开场都被戴夫打断。
##   3. 商店解锁后卡槽扩充改由商店出售,戴夫不再开场推销。
##
## 原版流程,文案取自 data/strings/lawn_strings.txt(原版中文字符串表):
##   1. 金币不够下一档价(CRAZY_DAVE_1401 / CRAZY_DAVE_1402):
##      戴夫报出当前金币数,说攒到多少钱才卖东西 —— 即"钱"的流程
##   2. 金币够了(CRAZY_DAVE_1501~1520 = 6->7 槽,CRAZY_DAVE_1551~1570 = 7->8 槽):
##      戴夫报价并给出同意 / 不同意选项(选项框标题 UPGRADE_DIALOG_BODY)—— 即"卖卡槽"的流程
##   3. 同意:扣钱 + 卡槽 +1(本关立刻生效),戴夫预告下一档价(CRAZY_DAVE_1510)后离场
##      不同意:戴夫抱怨一句(CRAZY_DAVE_1520 / CRAZY_DAVE_1570)后离场
##
## 价格表见 ConstShop.CARD_SLOT_UPGRADE_PRICES,与商店的 GoodsCardSlot 共用,不要在这里另写价格。

#region 原版话术模板
## 金币提示:当前金币数(CRAZY_DAVE_1401)
const TEXT_MONEY := "嘿，你目前已经收集了 %d 枚金币！"
## 金币提示:攒够钱才卖东西(CRAZY_DAVE_1402)
const TEXT_MONEY_HINT := "当你收集到 $%d 时，我会卖给你一些实用的东西！"
## 第一次推销的开场,6 槽 -> 7 槽(CRAZY_DAVE_1501)
const TEXT_OFFER_FIRST := "嘿！想再增加一个卡片槽吗？"
## 之后每次推销的开场(CRAZY_DAVE_1551)
const TEXT_OFFER_NEXT := "嘿！想多加一个卡片槽吗？"
## 报价与收益:价格 / 新卡槽数 / 旧卡槽数(CRAZY_DAVE_1502 / CRAZY_DAVE_1552)
const TEXT_OFFER_COST := "这将花费你 $%d，之后你每关能选%d种植物而不是%d种！"
## 选项句,说出这一句时弹出同意 / 不同意按钮(CRAZY_DAVE_1503 / CRAZY_DAVE_1553)
const TEXT_OFFER_CHOOSE := "听起来怎么样？"
## 同意后预告下一档价格:下一档价格 / 下一档槽数(CRAZY_DAVE_1510)
const TEXT_AGREE := "太好了！然后当你攒到$%d，我将给你升级到%d个卡片槽！"
## 已是最后一档时的同意回复(CRAZY_DAVE_1510 + CRAZY_DAVE_1511)
const TEXT_AGREE_MAX := "太好了！回见！"
## 不同意(CRAZY_DAVE_1520 / CRAZY_DAVE_1570)
const TEXT_DISAGREE := "真扫兴啊!"
## 选项框标题:目标槽数(UPGRADE_DIALOG_BODY)
const TEXT_CHOOSE_TITLE := "升级到 %d 个卡片槽？"
#endregion


## 关卡开场尝试让戴夫推销一次;不需要推销时直接返回,不产生任何戴夫节点
func start_sell_flow() -> void:
	if not is_can_sell():
		return
	## Global 是自动加载节点(无 class_name),不能用 := 推断,这里显式声明类型
	var game_state: GlobalGameState = Global.global_game_state
	var price := ConstShop.get_card_slot_upgrade_price(game_state.get_card_slot_upgrade_num())
	if price <= 0:
		return
	## 攒够了钱:立刻推销,玩家同意就当场买下
	if game_state.coin_value >= price:
		await _play_offer_dialog(price)
		return
	## 钱还没攒够:只在 2-2 说一次"攒到 $N 我就卖给你",之后各关等玩家攒够了再出现
	if _get_curr_adventure_level() != ConstUnlockLevel.DAVE_SELL_ADVENTURE_LEVEL:
		return
	await _play_money_dialog(price)


## 本关是否让戴夫推销
func is_can_sell() -> bool:
	var main_game: MainGameManager = Global.main_game
	if main_game == null or main_game.game_para == null:
		return false
	var game_para: ResourceLevelData = main_game.game_para
	## 只有冒险模式的出战卡槽吃商店 / 推销的扩充(见 ResourceLevelData.get_max_choosed_card_num)
	if game_para.game_mode != MainSceneRegistry.MainScenes.ChooseLevelAdventure:
		return false
	## 2-2 起才开始推销:金币从 2-1 掉落,2-2 是第一次有可能带钱进关的关卡
	if _get_curr_adventure_level() < ConstUnlockLevel.DAVE_SELL_ADVENTURE_LEVEL:
		return false
	## 商店解锁(通关 3-4)后卡槽扩充改由商店出售,戴夫不再开场推销
	## (关卡数据侧 ResourceLevelData.is_dave_sell_possible() 也判了一次,两处互为保险)
	if Global.global_game_state.is_shop_unlocked():
		return false
	## 不能选卡的关卡(传送带 / 不可选卡)买了卡槽也没有地方用
	if not game_para.can_choosed_card:
		return false
	if Global.global_game_state.is_card_slot_upgrade_max():
		return false
	return true


## 本关的冒险模式关卡序号(1-1 = 1 …… 5-10 = 50)
func _get_curr_adventure_level() -> int:
	var main_game: MainGameManager = Global.main_game
	if main_game == null or main_game.game_para == null:
		return 0
	return Global.global_game_state.get_adventure_level_on_save_game_name(main_game.game_para.save_game_name)


#region 两种对话
## 金币不足:戴夫报当前金币数并预告售价
func _play_money_dialog(price: int) -> void:
	var coin_value: int = Global.global_game_state.coin_value
	var detail_list: Array[CrazyDaveDialogDetailResource] = []
	## 一枚金币都还没有时不报数,免得说"你收集了 0 枚金币"(2-2 开场可能一枚都没捡到)
	if coin_value > 0:
		detail_list.append(_create_detail(TEXT_MONEY % coin_value))
	detail_list.append(_create_detail(TEXT_MONEY_HINT % price))
	var dialog := CrazyDaveDialogResource.new()
	dialog.dialog_detail_list = detail_list
	await _play_dave(dialog, "", Callable(), Callable())


## 金币足够:戴夫推销下一档卡槽,玩家可选同意 / 不同意
func _play_offer_dialog(price: int) -> void:
	var game_state: GlobalGameState = Global.global_game_state
	var upgrade_num := game_state.get_card_slot_upgrade_num()
	var curr_slot_num := game_state.get_card_slot_num()
	var next_slot_num := curr_slot_num + 1
	## 结果句的内容要等玩家选完才知道,先占位,选完当场填文本(start_dialog 逐句现读 text)
	var result_detail := _create_detail("")
	var dialog := CrazyDaveDialogResource.new()
	dialog.dialog_detail_list = [
		_create_detail(TEXT_OFFER_FIRST if upgrade_num == 0 else TEXT_OFFER_NEXT),
		_create_detail(TEXT_OFFER_COST % [price, next_slot_num, curr_slot_num]),
		_create_choose_detail(TEXT_OFFER_CHOOSE),
		result_detail,
	]
	await _play_dave(
		dialog,
		TEXT_CHOOSE_TITLE % next_slot_num,
		func(): _on_agree(price, result_detail),
		func(): _on_disagree(result_detail),
	)
#endregion


#region 戴夫播放
## 播放一次戴夫对话并等他离场
## agree_callable / disagree_callable 为空的 Callable 表示本次对话没有选项(金币提示)
func _play_dave(dialog: CrazyDaveDialogResource, choose_title: String,
		agree_callable: Callable, disagree_callable: Callable) -> void:
	var crazy_dave: CrazyDave = SceneRegistry.CRAZY_DAVE.instantiate()
	crazy_dave.init_dave(dialog)
	Global.main_game.canvas_layer_ui.add_child(crazy_dave)
	if agree_callable.is_valid():
		crazy_dave.choose_content.text = choose_title
		crazy_dave.signal_agree_choose.connect(agree_callable)
		crazy_dave.signal_disagree_choose.connect(disagree_callable)
	await crazy_dave.signal_dave_leave_end
	crazy_dave.queue_free()


## 造一句普通对话
func _create_detail(text: String) -> CrazyDaveDialogDetailResource:
	var detail := CrazyDaveDialogDetailResource.new()
	detail.text = text
	return detail


## 造一句带同意 / 不同意选项的对话
func _create_choose_detail(text: String) -> CrazyDaveDialogDetailResource:
	var detail := _create_detail(text)
	detail.is_choosed = true
	return detail
#endregion


#region 玩家选择
## 同意购买:扣钱 + 卡槽 +1,并让本关立刻用上新卡槽
func _on_agree(price: int, result_detail: CrazyDaveDialogDetailResource) -> void:
	var game_state: GlobalGameState = Global.global_game_state
	if game_state.coin_value < price:
		Log.warn("夜晚戴夫推销:金币不足,本次购买取消")
		result_detail.text = TEXT_DISAGREE
		return
	game_state.coin_value -= price
	if not game_state.add_card_slot_upgrade():
		Log.warn("夜晚戴夫推销:卡槽已达上限,本次购买取消")
		result_detail.text = TEXT_DISAGREE
		return
	Global.save_service.save_now()
	Log.debug(str("夜晚戴夫卖出卡槽扩充,已购买次数:") + str(game_state.get_card_slot_upgrade_num()))
	## 卡槽数变了:重新结算冒险模式的锁定卡槽 / 预选卡,并给本关出战卡槽补一格
	Global.main_game.game_para.refresh_pre_choosed_card_on_card_slot_change()
	Global.main_game.card_manager.add_one_battle_card_placeholder()
	result_detail.text = _get_agree_text()


## 不同意购买
func _on_disagree(result_detail: CrazyDaveDialogDetailResource) -> void:
	result_detail.text = TEXT_DISAGREE
	Log.debug("夜晚戴夫推销:玩家拒绝了卡槽扩充")


## 同意后的回复:还有下一档就预告价格,已经是最后一档就道别
func _get_agree_text() -> String:
	var game_state: GlobalGameState = Global.global_game_state
	var next_price := ConstShop.get_card_slot_upgrade_price(game_state.get_card_slot_upgrade_num())
	if next_price < 0:
		return TEXT_AGREE_MAX
	return TEXT_AGREE % [next_price, game_state.get_card_slot_num() + 1]
#endregion
