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
		push_error("❌ 全局存档失败：GlobalGameState 未就绪")
		return

	var data: Dictionary = {
		"version": SaveGameVersion,
		"coin_value": global_game_state.coin_value,
		"garden_data": global_game_state.garden_data,
		"curr_num_new_garden_plant": global_game_state.curr_num_new_garden_plant,
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
	state.garden_data = data.get("garden_data", state.DEFAULT_GARDEN_DATA).duplicate(true)
	state.curr_all_level_state_data = data.get("curr_all_level_state_data", state.DEFAULT_CURR_ALL_LEVEL_STATE_DATA).duplicate(true)
	state.selected_cards = data.get("selected_cards", [])
	## 已解锁植物: 存档里的解锁记录 + 按已通关冒险关卡重新推导(兼容旧档与手动改档),取并集
	state.curr_plant = _build_curr_plant(data, state)

	var loaded_curr_zombie_raw: Array = data.get("curr_zombie", state.curr_zombie)
	var loaded_curr_zombie: Array[CharacterRegistry.ZombieType] = []
	for zombie_type in loaded_curr_zombie_raw:
		loaded_curr_zombie.append(int(zombie_type) as CharacterRegistry.ZombieType)
	state.curr_zombie = loaded_curr_zombie


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


func save_selected_cards() -> void:
	var path := _get_save_game_path()
	if path.is_empty():
		Log.debug("选卡存档跳过：未登录用户或用户名为空")
		return
	if global_game_state == null:
		push_error("❌ 选卡存档失败：GlobalGameState 未就绪")
		return
	var data := _load_json(path)
	data["selected_cards"] = global_game_state.selected_cards
	if not _save_json(data, path):
		return

func load_selected_cards() -> void:
	var path := _get_save_game_path()
	if path.is_empty():
		return
	if global_game_state == null:
		return
	var data := _load_json(path)
	global_game_state.selected_cards = data.get("selected_cards", [])

func _save_json(data: Dictionary, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		push_error("❌ 存档写入失败：无法打开文件 %s（错误码 %d）" % [path, err])
		return false

	var json_text := JSON.stringify(data, "\t") # 可读性更强
	file.store_string(json_text)
	file.close()
	return true

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
