extends Node
class_name SaveService

## 全局游戏存档服务：只负责持久化金币/花园/关卡进度
## 文件 IO 与自动保存逻辑放在这里，Global 只负责业务/运行态状态

@onready var user_manager: UserManager = %UserManager
## 与 Global 根下的 GlobalGameState 同级，用 % 引用，避免依赖 get_parent() 类型
@onready var global_game_state: GlobalGameState = %GlobalGameState

const SaveGameVersion := "20251130"
const SaveGameFileName := "GlobalSaveGame.json"
## 主游戏关卡等存档子目录名（单点定义）。其它脚本请用 `SaveService.MAIN_GAME_SAVE_DIR_NAME` 或 `Global.save_service.MAIN_GAME_SAVE_DIR_NAME`，勿复制字符串。
const MAIN_GAME_SAVE_DIR_NAME := "main_game_saves_data"

var _auto_save_timer: Timer

func _get_save_game_path() -> String:
	if user_manager == null or user_manager.curr_user_name.is_empty():
		return ""
	return "user://" + user_manager.curr_user_name + "/" + SaveGameFileName

## 启用自动保存存档
func start_autosave(interval_sec: float = 60.0) -> void:
	if _auto_save_timer != null:
		return

	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = interval_sec
	_auto_save_timer.one_shot = false
	_auto_save_timer.autostart = true
	add_child(_auto_save_timer)
	Log.debug("开始自动保存存档")
	_auto_save_timer.timeout.connect(_on_auto_save_timer_timeout)

func stop_autosave() -> void:
	if _auto_save_timer == null:
		return
	_auto_save_timer.stop()
	_auto_save_timer.queue_free()
	_auto_save_timer = null

func _on_auto_save_timer_timeout() -> void:
	Log.debug(str(GlobalUtils.get_curr_time()) + str(" 自动存档"))
	save_now()

func save_now() -> void:
	var path := _get_save_game_path()
	if path.is_empty():
		# 未选用户时常见，不算错误（用 verbose 避免自动存档定时刷屏）
		Log.debug("全局存档跳过：未登录用户或用户名为空")
		return

	if global_game_state == null:
		Log.error("❌ 全局存档失败：GlobalGameState 未就绪")
		return

	var data: Dictionary = {
		"version": SaveGameVersion,
		"coin_value": global_game_state.coin_value,
		"garden_data": global_game_state.garden_data,
		"curr_num_new_garden_plant": global_game_state.curr_num_new_garden_plant,
		"card_slot_upgrade_num": global_game_state.card_slot_upgrade_num,
		"is_pool_cleaner_bought": global_game_state.is_pool_cleaner_bought,
		"is_roof_cleaner_bought": global_game_state.is_roof_cleaner_bought,
		"rake_use_num": global_game_state.rake_use_num,
		"is_wall_nut_first_aid_bought": global_game_state.is_wall_nut_first_aid_bought,
		"is_first_coin_advice_shown": global_game_state.is_first_coin_advice_shown,
		"curr_all_level_state_data": global_game_state.curr_all_level_state_data,
		"selected_cards": global_game_state.selected_cards,
		"curr_plant": global_game_state.curr_plant,
		"curr_zombie": global_game_state.curr_zombie,
	}

	if not _save_json(data, path):
		return
	Log.debug(str(GlobalUtils.get_curr_time()) + str(" 存档全局数据成功, 存档路径:") + str(path))

func load_global_game_data() -> void:
	var path := _get_save_game_path()
	if path.is_empty():
		return

	if global_game_state == null:
		return

	var data := _load_json(path) as Dictionary

	var state := global_game_state
	state.coin_value = data.get("coin_value", state.DEFAULT_COIN_VALUE)
	state.curr_num_new_garden_plant = data.get("curr_num_new_garden_plant", state.DEFAULT_CURR_NUM_NEW_GARDEN_PLANT)
	state.card_slot_upgrade_num = data.get("card_slot_upgrade_num", state.DEFAULT_CARD_SLOT_UPGRADE_NUM)
	state.is_pool_cleaner_bought = data.get("is_pool_cleaner_bought", state.DEFAULT_IS_POOL_CLEANER_BOUGHT)
	state.is_roof_cleaner_bought = data.get("is_roof_cleaner_bought", state.DEFAULT_IS_ROOF_CLEANER_BOUGHT)
	state.rake_use_num = data.get("rake_use_num", state.DEFAULT_RAKE_USE_NUM)
	state.is_wall_nut_first_aid_bought = data.get(
		"is_wall_nut_first_aid_bought", state.DEFAULT_IS_WALL_NUT_FIRST_AID_BOUGHT
	)
	state.is_first_coin_advice_shown = data.get(
		"is_first_coin_advice_shown", state.DEFAULT_IS_FIRST_COIN_ADVICE_SHOWN
	)
	state.garden_data = data.get("garden_data", state.DEFAULT_GARDEN_DATA).duplicate(true)
	## JSON 读回来的数字都是 float:转回 int,免得花园工具记录越存越"浮点"
	state.normalize_garden_data_numbers()
	state.curr_all_level_state_data = data.get("curr_all_level_state_data", state.DEFAULT_CURR_ALL_LEVEL_STATE_DATA).duplicate(true)
	state.selected_cards = _normalize_selected_cards(data.get("selected_cards", []))
	## 已解锁植物: 存档里的解锁记录 + 按已通关冒险关卡重新推导(兼容旧档与手动改档),取并集
	state.curr_plant = _build_curr_plant(data, state)

	var loaded_curr_zombie_raw: Array = data.get("curr_zombie", state.curr_zombie)
	var loaded_curr_zombie: Array[CharacterRegistry.ZombieType] = []
	for zombie_type in loaded_curr_zombie_raw:
		loaded_curr_zombie.append(int(zombie_type) as CharacterRegistry.ZombieType)
	state.curr_zombie = loaded_curr_zombie


## 上次选卡结果做归一化:
## 与 curr_zombie / curr_plant 同一个坑 —— JSON 读回来的枚举是 float,
## 下游 AllCards.plant_card_ids[plant_type] 这类按枚举取值的写法会因此对不上。
## 当前格式是 Dictionary({card_type, content_id, is_imitater})（见 ResourceCardReference.to_dict）；
## 旧档的 {plant_type / zombie_type / is_imitater} 在这里就地升级成新格式,避免玩家重新选卡。
func _normalize_selected_cards(raw: Variant) -> Array:
	var result: Array = []
	if not raw is Array:
		return result
	for item in raw:
		if not item is Dictionary:
			continue
		var card_data: Dictionary = (item as Dictionary).duplicate()
		# 已经是新格式：只需把 JSON 的 float 转回 int,并确认模仿修饰是布尔值。
		if card_data.has("card_type") and card_data.has("content_id"):
			card_data["card_type"] = int(card_data["card_type"])
			card_data["content_id"] = int(card_data["content_id"])
			card_data["is_imitater"] = bool(card_data.get("is_imitater", false))
			result.append(card_data)
			continue
		# 旧格式：植物条目
		if card_data.has("plant_type"):
			result.append({"card_type": ResourceCardReference.CardType.Plant,
				"content_id": int(card_data["plant_type"]),
				"is_imitater": bool(card_data.get("is_imitater", false))})
			continue
		# 旧格式：普通僵尸条目
		if card_data.has("zombie_type"):
			result.append({"card_type": ResourceCardReference.CardType.Zombie,
				"content_id": int(card_data["zombie_type"]),
				"is_imitater": false})
	return result


## 构建已解锁植物列表:
## 初始植物 + 已通关冒险关卡对应的植物 + 存档中已记录的植物(紫卡/模仿者等购买所得)
## 取并集,保证旧档不丢植物、通关进度也能自愈
func _build_curr_plant(data: Dictionary, state: GlobalGameState) -> Array[CharacterRegistry.PlantType]:
	## 不基于 state.curr_plant 累加,避免切换用户时把上一个用户的解锁带过来
	var result: Array[CharacterRegistry.PlantType] = []
	for plant_type in ConstPlantUnlock.INIT_PLANT_TYPES:
		if not result.has(plant_type):
			result.append(plant_type)

	## 已通关的冒险关卡对应的植物
	for save_game_name in state.curr_all_level_state_data:
		var curr_level_state_data: Dictionary = state.curr_all_level_state_data[save_game_name]
		if not curr_level_state_data.get("IsSuccess", false):
			continue
		var adventure_level: int = state.get_adventure_level_on_save_game_name(str(save_game_name))
		if adventure_level <= 0:
			continue
		for plant_type in ConstPlantUnlock.get_unlock_plant_on_adventure_level(adventure_level):
			if not result.has(plant_type):
				result.append(plant_type)

	## 存档中已记录的植物(购买类解锁)
	for plant_type in data.get("curr_plant", []):
		var curr: CharacterRegistry.PlantType = int(plant_type) as CharacterRegistry.PlantType
		if curr != CharacterRegistry.PlantType.Null and not result.has(curr):
			result.append(curr)
	return result


## 保存上次选卡结果
##
## 为什么不走「读档 → 改 selected_cards 一个键 → 写回」：
## `_load_json` 在文件损坏 / JSON 解析失败时返回 `{}`，那样写回的字典**只剩 selected_cards 一个键**，
## 金币 / 关卡进度 / 花园 / 已解锁植物会被整体抹掉（一次损坏 → 整档丢失）。
## 直接写全量：`save_now()` 的字段表里已经包含 selected_cards。
func save_selected_cards() -> void:
	save_now()

## 读上次选卡结果（「重选上次卡片」按钮走这条）
## 注意：读档路径有两条（本函数与 load_global_game_data），**两条都要过 _normalize_selected_cards**，
## 否则 JSON 的 float 枚举会漏到下游的 AllCards.plant_card_ids[plant_type]
func load_selected_cards() -> void:
	var path := _get_save_game_path()
	if path.is_empty():
		return
	if global_game_state == null:
		return
	var data := _load_json(path)
	global_game_state.selected_cards = _normalize_selected_cards(data.get("selected_cards", []))

## 写存档：先写 .tmp，再原子替换，全程留一份 .bak 兜底
##
## 为什么不直接 `FileAccess.open(path, WRITE)` 覆盖：
## 写入中途崩溃 / 断电会留下**截断的坏档**，下次 `_load_json` 解析失败返回 `{}`，
## 任何「读档 → 改键 → 写回」的调用都会把残档固化 —— 这是丢档链的第一环。
func _save_json(data: Dictionary, path: String) -> bool:
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		var open_err := FileAccess.get_open_error()
		Log.error("❌ 存档写入失败：无法打开临时文件 %s（错误码 %d）" % [tmp_path, open_err])
		return false

	file.store_string(JSON.stringify(data, "\t")) # 可读性更强
	file.close()

	## user:// 是虚拟路径，rename 前要转成系统绝对路径
	var abs_path := ProjectSettings.globalize_path(path)
	var abs_tmp := ProjectSettings.globalize_path(tmp_path)
	var abs_bak := abs_path + ".bak"

	## Windows 的 rename 不允许覆盖已存在的文件：先把上一份好档挪成 .bak
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_bak)
		DirAccess.rename_absolute(abs_path, abs_bak)

	if DirAccess.rename_absolute(abs_tmp, abs_path) != OK:
		Log.error("❌ 存档写入失败：临时文件替换失败 %s" % path)
		## 兜底：把 .bak 还原回去，别让玩家连上一份好档都没了
		if not FileAccess.file_exists(path) and FileAccess.file_exists(abs_bak):
			DirAccess.rename_absolute(abs_bak, abs_path)
		DirAccess.remove_absolute(abs_tmp)
		return false
	return true

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.error("❌ 存档读取失败：无法打开文件 %s" % path)
		return {}
	var json_text := file.get_as_text()
	file.close()
	var result: Dictionary = JSON.parse_string(json_text) as Dictionary
	if result == null:
		## 解析失败必须出声：静默返回 {} 会让调用方把整档写成残档
		Log.error("❌ 存档已损坏：JSON 解析失败 %s（本次按空档处理，不会覆写原文件）" % path)
		return {}
	return result
