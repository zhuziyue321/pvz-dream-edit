extends Panel
class_name AlmanacCharacterShowPanel
## 图鉴植物信息描述

const CharacterBgMap = {
	"Day": preload("res://assets/image/Almanac/Almanac_GroundDay.jpg"),
	"Ice":preload("res://assets/image/Almanac/Almanac_GroundIce.jpg"),
	"Night": preload("res://assets/image/Almanac/Almanac_GroundNight.jpg"),
	"Pool": preload("res://assets/image/Almanac/Almanac_GroundPool.jpg"),
	"Fog": preload("res://assets/image/Almanac/Almanac_GroundNightPool.jpg"),
	"Roof": preload("res://assets/image/Almanac/Almanac_GroundRoof.jpg")
}

## 背景
@onready var character_bg: TextureRect = $CharacterBg
## 角色名字
@onready var character_name: Label = $AllBg/CharacterName
## 描述
@onready var character_text_1: Label = $AllBg/ScrollContainer/VBoxContainer/CharacterText1
## 参数列表容器
@onready var character_text_2_para: VBoxContainer = $AllBg/ScrollContainer/VBoxContainer/CharacterText2Para
## 提示
@onready var character_text_3_hint: Label = $AllBg/ScrollContainer/VBoxContainer/CharacterText3Hint
## 介绍
@onready var character_text_4_introduction: Label = $AllBg/ScrollContainer/VBoxContainer/CharacterText4Introduction
##　花费
@onready var cost: HBoxContainer = $AllBg/PlantEndPara/Cost
## 冷却
@onready var cool_time: HBoxContainer = $AllBg/PlantEndPara/CoolTime

## 正在展示的角色
var show_character:Character000Base

## 更新图鉴植物信息
func almanac_update_plant_panel(curr_plant_type: StringName):
	var curr_plant_name = Global.character_registry.get_plant_info(curr_plant_type, CharacterRegistry.PlantInfoAttribute.PlantName)
	almanac_update_character_panel_common(Global.global_read_data.data_almanac["Plant"][curr_plant_name])
	_fill_plant_cost(curr_plant_type)
	## 展示植物
	create_plant(curr_plant_type)


## 更新图鉴「扩展植物」信息（调试模式植物 / 模组新增植物）
##
## 与 `almanac_update_plant_panel()` 只差「条目从哪来」：这两类植物没有原版图鉴文本，
## 条目由 `GlobalReadData.get_extra_almanac_entry()` 给出（本体那几株写在 json 的 ExtraPlant 段，
## 模组植物由模组自己登记；都没写就兜一条最简的）。花费 / 冷却 / 展示态照旧走注册表。
func almanac_update_extra_plant_panel(curr_plant_type: StringName):
	almanac_update_character_panel_common(
		Global.global_read_data.get_extra_almanac_entry(curr_plant_type))
	_fill_plant_cost(curr_plant_type)
	## 展示植物
	create_plant(curr_plant_type)


## 扩展植物页一株都没解锁时：面板清空并给一句提示，别停在上一株的内容上
func almanac_update_empty_extra_panel():
	almanac_update_character_panel_common({
		"名字": "扩展植物",
		"描述": "这一页收录调试模式专属植物与模组新增植物",
		"参数": {},
		"简介": "打开控制台「调试模式」，或装上带新植物的模组，这里就会出现它们的图鉴。",
		"背景": "Day",
	})
	show_empty_cost()
	clear_show_character()


## 填「花费 / 冷却时间」两项（植物页与扩展植物页共用）
func _fill_plant_cost(curr_plant_type: StringName):
	## 花费
	cost.get_node("Value").text = str(Global.character_registry.get_plant_info(curr_plant_type,  CharacterRegistry.PlantInfoAttribute.SunCost))
	## 冷却时间
	cool_time.get_node("Value").text = str(Global.character_registry.get_plant_info(curr_plant_type,  CharacterRegistry.PlantInfoAttribute.CoolTime))
	cool_time.get_node("Value").text += "(秒)"


## 没有选中任何植物时把「花费 / 冷却」两项清掉（留着会显示上一株的数值）
func show_empty_cost():
	cost.get_node("Value").text = "-"
	cool_time.get_node("Value").text = "-"

## 撤掉正在展示的角色（切换到一个没有角色的条目时用）
func clear_show_character():
	if is_instance_valid(show_character):
		show_character.queue_free()
	show_character = null

func create_plant(curr_plant_type: StringName):
	var new_show_plant := CharacterShowFactory.create_show_plant(curr_plant_type, character_bg, Vector2(100,120))
	if new_show_plant == null:
		return

	special_plant_update_pos(new_show_plant)

	if is_instance_valid(show_character):
		show_character.queue_free()

	show_character = new_show_plant

## 生成的特殊植物修改位置
func special_plant_update_pos(new_show_plant:Plant000Base):
	match new_show_plant.plant_type:
		PlantIds.COB_CANNON:
			new_show_plant.position = Vector2(60,130)


## 更新图鉴僵尸信息
func almanac_update_zombie_panel(curr_zombie_type: StringName):
	var curr_zombie_name = Global.character_registry.get_zombie_info(curr_zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName)
	almanac_update_character_panel_common(Global.global_read_data.data_almanac["Zombie"][curr_zombie_name])
	create_zombie(curr_zombie_type)

func create_zombie(curr_zombie_type: StringName):
	var new_show_zombie := CharacterShowFactory.create_show_zombie(curr_zombie_type, character_bg, Vector2(100,166))
	if new_show_zombie == null:
		return
	special_zombie_update_pos(new_show_zombie)
	if is_instance_valid(show_character):
		show_character.queue_free()
	show_character = new_show_zombie

## 生成的特殊僵尸修改位置
func special_zombie_update_pos(new_show_zombie:Zombie000Base):
	match new_show_zombie.zombie_type:
		ZombieIds.GARGANTUAR:
			new_show_zombie.position = Vector2(100,200)


## 更新通用数据
##
## 扩展植物的条目可能是运行期登记的（模组自己填的），字段不全很正常 ——
## 这里一律按「缺了就用空值兜」读，别裸索引（缺一个键就是一进图鉴就崩）。
## 参数项最多 5 条（面板里只摆了 PlantPara ~ PlantPara5），超出部分忽略。
func almanac_update_character_panel_common(data_almanac_character:Dictionary):
	character_bg.texture = CharacterBgMap.get(data_almanac_character.get("背景", "Day"),
		CharacterBgMap["Day"])
	## 名字
	character_name.text = str(data_almanac_character.get("名字", ""))
	## 描述
	character_text_1.text = str(data_almanac_character.get("描述", ""))
	var all_para: Dictionary = data_almanac_character.get("参数", {})
	var num_para: int = mini(all_para.size(), character_text_2_para.get_child_count())
	## 参数
	for i in range(num_para):
		var curr_plant_para = character_text_2_para.get_child(i)
		var curr_key = all_para.keys()[i]
		curr_plant_para.get_node("Key").text = curr_key
		curr_plant_para.get_node("Value").text = all_para[curr_key]
		curr_plant_para.visible = true
	for i in range(num_para, character_text_2_para.get_children().size()):
		character_text_2_para.get_child(i).visible = false
	## 提示
	if data_almanac_character.has("提示"):
		character_text_3_hint.text = data_almanac_character["提示"]
		character_text_3_hint.visible = true
	else:
		character_text_3_hint.visible = false
	## 简介
	character_text_4_introduction.text = str(data_almanac_character.get("简介", ""))


#endregion
