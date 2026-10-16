extends Node
class_name GlobalReadData

var data_almanac: Dictionary = {}
const PATH_DATA_ALMANAC := "res://data/almanac/almanac_data.json"
@onready var character_registry: CharacterRegistry = %CharacterRegistry

## 图鉴「扩展植物」段的段名：**按植物 id 建键**，与 Plant / Zombie 段按 PlantName 建键不同 ——
## 这一页里的植物有一半是模组运行期注册的，本体只知道它的 id，拿不到稳定的 PlantName。
const SECTION_EXTRA_PLANT := "ExtraPlant"

## 运行期登记的扩展植物图鉴条目（键 = 植物 id）
##
## ★ 这是留给模组的口子：原版没有的植物（水盆之类）本体不该替它写图鉴文本 —— 本体不
##   认识任何一个模组（硬约束）。装载时 `register_extra_almanac_entry()` 登记一条，
##   卸载时 `clear_extra_almanac_entry()` 摘掉，关掉模组 = 条目跟着消失。
var extra_almanac: Dictionary = {}

## 僵尸行类型可以自然刷新的僵尸白名单
var whitelist_refresh_zombie_types_with_zombie_row_type: Dictionary[CharacterRegistry.ZombieRowType, Array] = {}

## 自然刷怪出现的僵尸黑名单类型
var blacklist_refresh_zombie_types: Array[StringName] = [
	ZombieIds.NULL,
	ZombieIds.FLAG,
	ZombieIds.DUCKYTUBE,
	ZombieIds.DANCER,
	ZombieIds.IMP,
	ZombieIds.BUNGI_DROP,
	ZombieIds.BOBSLED_SINGLE,
]

## 随机罐子刷新的植物白名单
var whitelist_plant_types_with_pot: Array[StringName] = []
## 罐子模式无冷却植物卡牌类型
var zero_cd_plnat_card_type_on_pot_mode: Array = [
	PlantIds.LILY_PAD,
	PlantIds.FLOWER_POT,
	PlantIds.COFFEE_BEAN,
]

## 随机罐子刷新的植物黑名单类型(null等)
var blacklist_plant_types_with_pot: Array[StringName] = [
	PlantIds.NULL,
	PlantIds.COFFEE_BEAN,
	PlantIds.IMITATER,
	PlantIds.SPROUT,
]
## 随机罐子刷新的僵尸黑名单,白名单使用自然刷怪白名单
var blacklist_zombie_types_with_pot: Array[StringName] = [
	ZombieIds.NULL,
	ZombieIds.DUCKYTUBE,
]

func _ready() -> void:
	update_whitelist_refresh_zombie_types_with_zombie_row_type()
	update_whitelist_plant_types_with_pot()

func ensure_almanac_loaded() -> void:
	if not data_almanac.is_empty():
		return
	data_almanac = _load_json(PATH_DATA_ALMANAC)


#region 扩展植物图鉴条目
## 登记一条扩展植物图鉴条目（模组用）：键 = 植物 id，值 = 与 `data_almanac["Plant"]` 那条同构的字典
## （`"名字" / "描述" / "参数" / "简介" / "背景"`；`"提示"` 可选，见 `AlmanacCharacterShowPanel`）。
## 重复登记同一 id = 覆盖。
func register_extra_almanac_entry(plant_type: StringName, entry: Dictionary) -> void:
	if plant_type == PlantIds.NULL or entry.is_empty():
		Log.error("GlobalReadData：登记扩展图鉴条目失败（植物 %s，条目 %s）" % [
			str(plant_type), "空" if entry.is_empty() else "非空"])
		return
	extra_almanac[plant_type] = entry.duplicate(true)


## 撤销一条运行期登记的扩展图鉴条目（关掉模组时用）
func clear_extra_almanac_entry(plant_type: StringName) -> void:
	extra_almanac.erase(plant_type)


## 取一条扩展植物的图鉴条目：**运行期登记的 > json 的 ExtraPlant 段 > 按注册表兜一条最简的**
##
## 兜底是必要的：模组可以不写图鉴文本就装一株植物（例如控制台临时注册的），
## 点开它的卡片时面板不能是一片空白甚至报错。
func get_extra_almanac_entry(plant_type: StringName) -> Dictionary:
	ensure_almanac_loaded()
	if extra_almanac.has(plant_type):
		return extra_almanac[plant_type]
	if data_almanac.has(SECTION_EXTRA_PLANT):
		var section: Dictionary = data_almanac[SECTION_EXTRA_PLANT]
		if section.has(plant_type):
			return section[plant_type]
	return _build_fallback_extra_almanac_entry(plant_type)


## 没人为这株植物写过图鉴文本时兜一条：名字取注册表，正文写明它是「扩展植物」
func _build_fallback_extra_almanac_entry(plant_type: StringName) -> Dictionary:
	var plant_name = character_registry.get_plant_info(plant_type,
		CharacterRegistry.PlantInfoAttribute.PlantName)
	return {
		## 注册表里查不到（还没登记 / 已撤销）时退回 id，别把 `<null>` 打到面板上
		"名字": str(plant_type) if plant_name == null else str(plant_name),
		"描述": "扩展植物：原版图鉴里没有它的条目",
		"参数": {},
		"简介": "由模组或调试模式加入的植物，暂时还没有图鉴文本。",
		"背景": "Day",
	}
#endregion

func update_whitelist_refresh_zombie_types_with_zombie_row_type() -> void:
	whitelist_refresh_zombie_types_with_zombie_row_type.clear()
	for curr_zombie_row_type in CharacterRegistry.ZombieRowType.values():
		whitelist_refresh_zombie_types_with_zombie_row_type[curr_zombie_row_type] = get_whitelist_refresh_zombie_types_on_zombie_row_type(curr_zombie_row_type)

func get_whitelist_refresh_zombie_types_on_zombie_row_type(curr_zombie_row_type: CharacterRegistry.ZombieRowType) -> Array[StringName]:
	var curr_whitelist_refresh_zombie_types: Array[StringName] = []
	for zombie_type in ZombieIds.ALL:
		if blacklist_refresh_zombie_types.has(zombie_type):
			continue

		if curr_zombie_row_type == CharacterRegistry.ZombieRowType.Both:
			curr_whitelist_refresh_zombie_types.append(zombie_type)
		else:
			var zombie_row_type: CharacterRegistry.ZombieRowType = character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType)
			if zombie_row_type == CharacterRegistry.ZombieRowType.Both:
				curr_whitelist_refresh_zombie_types.append(zombie_type)
			elif zombie_row_type == curr_zombie_row_type:
				curr_whitelist_refresh_zombie_types.append(zombie_type)

	return curr_whitelist_refresh_zombie_types

func update_whitelist_plant_types_with_pot() -> void:
	whitelist_plant_types_with_pot.clear()
	for plant_type in PlantIds.ALL:
		if blacklist_plant_types_with_pot.has(plant_type):
			continue
		whitelist_plant_types_with_pot.append(plant_type)

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json_text := file.get_as_text()
	file.close()
	var result: Dictionary = JSON.parse_string(json_text) as Dictionary
	if result == null:
		return {}
	return result
