extends TextureRect
class_name AlmanacExtraPlantPage
## 图鉴「扩展植物」页：调试模式专属植物 + 模组新增植物
##
## 与植物页（`AlmanacPlantPage`）只差「条目从哪来」：
## · **哪些植物进这一页** —— 与选卡界面同一口径 `AllCards.is_appended_plant()`
##   （调试模式专属 `ConstPlantUnlock.DEBUG_MODE_PLANT_TYPES` + 运行期注册的 = 模组新增），
##   顺序也照 `AllCards.get_plant_types_in_choose_order()`，两处必须同一口径，
##   否则同一株植物在选卡界面与图鉴里会落在不同位置；
## · **图鉴文本从哪来** —— 这两类植物没有原版文本，走
##   `GlobalReadData.get_extra_almanac_entry()`（本体那几株写在 `almanac_data.json` 的
##   ExtraPlant 段，模组植物由模组自己登记；都没写就兜一条最简的）。
##
## 是否显示仍按 `curr_plant`（已解锁）过滤，与植物页一致 —— 没解锁就是图鉴里还没收录：
## 开「调试模式」那四株才会出现，装了带新植物的模组那一株才会出现。

## 卡片父节点
@onready var card_grid_container: GridContainer = $CardGridContainer
@onready var almanac_character_show_panel: AlmanacCharacterShowPanel = $AlmanacCharacterShowPanel

## 本页实际收录的植物（已解锁的追加类植物，顺序照选卡界面）
var extra_plant_types: Array[StringName] = []


func init_almanac_page() -> void:
	init_extra_plant_card()
	## 一株都没解锁时给一句提示，别停在上一页看过的那株上
	if extra_plant_types.is_empty():
		almanac_character_show_panel.almanac_update_empty_extra_panel()
		return
	almanac_character_show_panel.almanac_update_extra_plant_panel(extra_plant_types[0])


## 生成卡片并连接点击信号（与植物页同一套：`AllCards.create_card` 出卡 + `set_almanac_card`）
func init_extra_plant_card() -> void:
	for plant_type in AllCards.get_plant_types_in_choose_order():
		## 普通植物归植物页，这里只收追加类
		if not AllCards.is_appended_plant(plant_type):
			continue
		## 没解锁 = 图鉴还没收录（与植物页同一判据）
		if not Global.global_game_state.curr_plant.has(plant_type):
			continue
		extra_plant_types.append(plant_type)
		var curr_plant_card: Card = AllCards.create_card(
			ResourceCardReference.create(ResourceCardReference.CardType.Plant, plant_type),
			Card.CardContext.Almanac)
		if curr_plant_card == null:
			continue
		card_grid_container.add_child(curr_plant_card)
		curr_plant_card.signal_card_click.connect(
			almanac_character_show_panel.almanac_update_extra_plant_panel.bind(curr_plant_card.card_plant_type))
		curr_plant_card.set_almanac_card()
