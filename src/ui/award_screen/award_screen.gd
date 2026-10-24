extends CanvasLayer
class_name AwardScreen
## **原版「领奖屏」的新植物那一支**（原版 AWARD_FORLEVEL）
##
## 原版出处：PvZ-Portable `src/Lawn/Widget/AwardScreen.cpp` 的 `DrawAwardSeed()`：
##   · 底图     IMAGE_AWARDSCREEN_BACK = `pak/images/AwardScreen_Back.jpg`（800x600）
##   · 标题     "[NEW_PLANT]" 画在 (400, 58)，金色 (213, 159, 43)
##              （58 是基线，标题顶边约 34；种子卡顶边 59，二者不重叠）
##   · 种子包   放大 2 倍画在 (350, 129)
##              （本仓库的种子包本来就是原版的 2 倍，见 SeedPacket 的 PACKET_SIZE）
##   · 植物名   画在 (400, 326)，白色
##   · 植物说明 画在 (285, 360, 230, 90)，深蓝 (40, 50, 90)
##   · 底部     一个「继续」按钮
##
## 什么时候弹：冒险模式**首次通关拿到新植物**时 —— 结算白屏之后、切下一场景之前
## （见 `MgmRewardManager.win_main_game`）。原版那里是
## `ShowAwardScreen(AWARD_FORLEVEL, true)`，点「继续」才回选关界面。
##
## 本仓库把它做成主游戏之上的一层（layer 120，在白屏层 100 之上），等玩家点「继续」期间
## 主游戏还在原地、不切场景。

## 玩家点了「继续」（MgmRewardManager 在等这个信号）
signal continue_pressed

## 整屏淡入的秒数（原版 mFadeInCounter = 180 帧 = 3 秒）
const FADE_IN_TIME := 180.0 / 60.0

@onready var root: Control = $Root
@onready var title_label: Label = $Root/Title
@onready var plant_container: Node2D = $Root/Packet/PlantContainer
@onready var cost_label: Label = $Root/Packet/Cost
@onready var plant_name_label: Label = $Root/PlantName
@onready var description_label: Label = $Root/Description
@onready var continue_button: BaseButton = $Root/ContinueButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	## 原版整屏淡入（mFadeInCounter 那条）
	root.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(root, "modulate", Color(1, 1, 1, 1), FADE_IN_TIME)


## 显示这株植物：放大的种子包 + 植物名 + 植物说明
## （必须在节点入树之后调：要用到 @onready 的挂点）
func show_plant(plant_type: StringName) -> void:
	## 种子包里的植物形象（与出战卡片、掉落种子包同一套，见 SeedPacket.set_plant）
	var plant := CharacterShowFactory.create_show_plant(plant_type, plant_container)
	if plant != null:
		plant.scale = Vector2(1, 1)
	## 底部的阳光花费
	cost_label.text = str(int(Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.SunCost)))
	## 名字与说明：图鉴数据里那一份（键是植物的注册名，见 data/almanac/almanac_data.json）
	var plant_key: String = str(Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.PlantName))
	Global.global_read_data.ensure_almanac_loaded()
	var all_plant_data: Dictionary = Global.global_read_data.data_almanac.get("Plant", {})
	var entry: Dictionary = all_plant_data.get(plant_key, {})
	plant_name_label.text = str(entry.get("名字", plant_key))
	description_label.text = str(entry.get("描述", ""))


## 「继续」被点了
func _on_continue_pressed() -> void:
	continue_pressed.emit()
