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
## 损坏存档的隔离后缀（原档改名保留，改名后不会被后续写档覆盖）
const CORRUPT_SUFFIX := ".corrupt"

## 读一个 JSON 文件的三种结果（见 _read_json_file）
const ReadOk := "ok"
const ReadMissing := "missing"
const ReadBroken := "broken"

## 存档保护开关：本局一旦判定「损坏且无法恢复」就锁死写入，直到下次读档重新判定。
##
## 为什么必须锁：读档失败时 state 仍是默认值，而自动存档每 60 s 跑一次 ——
## 不锁的话，60 s 后 save_now() 就把这份空档写回去，原档被挪成 .bak 后
## 再被下一次写档顶掉，**一次损坏变成永久丢档**。
## 锁住之后本局照常能玩，只是不再落盘；原档已隔离成 .corrupt，可人工恢复。
var _save_locked := false

var _auto_save_timer: Timer

## 本局是否处于「存档损坏保护中」（true = 不再写档，原档已隔离）。
## UI 想提示玩家时读这个，不要在别处自己判。
func is_save_locked() -> bool:
	return _save_locked

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

	## 存档损坏保护：读档失败后 state 全是默认值，此时写入等于把空档固化。
	## 宁可本局不落盘，也不能让玩家丢档（见 _save_locked 的注释）。
	if _save_locked:
		Log.error("❌ 全局存档拒绝写入：本局存档已判定损坏（原档已隔离为 %s，可人工恢复）" % CORRUPT_SUFFIX)
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

	## 每读一次档就重新判定一次：上一个用户的档坏了，不代表这个用户的档也坏，
	## 所以读取前先把保护开关清掉，由 _load_json 按本次结果重新置位。
	_save_locked = false

	var loaded: Variant = _load_json(path)
	## null = 没有可用档：新用户保持默认值即可；损坏档同样保持默认值，
	## 但已由 _load_json 隔离原档并锁住写入，这里直接返回，不动 state。
	if loaded == null:
		return
	var data := loaded as Dictionary

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
		## 本关给哪一株写在那一关的脚本上（level_complete_loot 那个战利品名字），不查表
		var reward_plant := LevelRegistry.get_adventure_level_reward_plant(adventure_level)
		if reward_plant != CharacterRegistry.PlantType.Null and not result.has(reward_plant):
			result.append(reward_plant)

	## 存档中已记录的植物(购买类解锁)
	for plant_type in data.get("curr_plant", []):
		var curr: CharacterRegistry.PlantType = int(plant_type) as CharacterRegistry.PlantType
		if curr != CharacterRegistry.PlantType.Null and not result.has(curr):
			result.append(curr)
	return result


## 保存上次选卡结果
##
## 为什么不走「读档 → 改 selected_cards 一个键 → 写回」：
## 那样写回的字典**只剩 selected_cards 一个键**，金币 / 关卡进度 / 花园 / 已解锁植物
## 会被整体抹掉（一次损坏 → 整档丢失）。直接写全量：`save_now()` 的字段表里已经包含
## selected_cards。损坏档现在由 `_load_json` 隔离 + `_save_locked` 挡住写入（见那两处注释）。
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
	var loaded: Variant = _load_json(path)
	## null = 没有可用档（新用户，或已损坏并被 _load_json 隔离）：保持当前值，不落空数组
	if loaded == null:
		return
	global_game_state.selected_cards = _normalize_selected_cards((loaded as Dictionary).get("selected_cards", []))

## 写存档：先写 .tmp，再原子替换，全程留一份 .bak 兜底
##
## 为什么不直接 `FileAccess.open(path, WRITE)` 覆盖：
## 写入中途崩溃 / 断电会留下**截断的坏档**；也正因为这里每次都把旧档留成 .bak，
## 读档侧才有一条「主档坏了就回退 .bak」的退路（见 _load_json）。
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

## 读单个 JSON 文件，返回 `{"state": ReadOk|ReadMissing|ReadBroken, "data": Dictionary}`。
##
## 为什么要把「不存在」和「读不出来」分开：前者是「这个用户还没存过」，正常；
## 后者是「存过但坏了」，异常。混成一个空字典，调用方就只能一律按空档处理，
## 而自动存档会立刻把这份空档写回去 —— 那才是一档丢失的真正起点。
func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"state": ReadMissing, "data": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.error("❌ 存档读取失败：无法打开文件 %s" % path)
		return {"state": ReadBroken, "data": {}}
	var json_text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not parsed is Dictionary:
		Log.error("❌ 存档已损坏：JSON 解析失败 %s" % path)
		return {"state": ReadBroken, "data": {}}
	return {"state": ReadOk, "data": parsed}


## 把损坏的存档**改名**隔离（不删除），返回隔离后的系统路径，失败返回 ""。
##
## 保留现场而不是删掉：坏档里往往还有能救回来的字段，玩家也可能想自己看一眼。
## 改名（而不是留在原位）是为了让后续写档不会把它当旧档挪进 .bak 里顶掉。
func _quarantine_corrupt_file(path: String, reason: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var abs_path := ProjectSettings.globalize_path(path)
	## 用毫秒而不是秒：同一秒内连续隔离两次（主档坏 + 备份也坏就会走到）时，
	## 秒级时间戳会算出同一个名字，后一次把前一次的现场顶掉 —— 隔离就白做了。
	## 再叠一层顺延，彻底排除同一毫秒内重名的可能。
	var stamp := Time.get_ticks_msec()
	var target := "%s%s_%d" % [abs_path, CORRUPT_SUFFIX, stamp]
	var seq := 0
	while FileAccess.file_exists(target):
		seq += 1
		target = "%s%s_%d_%d" % [abs_path, CORRUPT_SUFFIX, stamp, seq]
	if DirAccess.rename_absolute(abs_path, target) != OK:
		Log.error("❌ 损坏存档隔离失败：无法把 %s 改名为 %s" % [path, target])
		return ""
	Log.error("❌ 存档已损坏（%s）：原文件已隔离为 %s，本局不会自动覆写，可人工恢复" % [reason, target])
	return target


## 存档版本迁移链。当前只有一档、链是空的，但形状先立起来：
## 以后每次改存档结构，就在下面加一级 `if v == "<旧版本号>": ...`，
## 而不是在各处散落 `data.get(k, default)` 的兼容补丁 —— 后者会越积越多且看不出版本历史。
##
## 无版本号（v == ""）= 本功能上线前的老档，字段级兜底已经覆盖，不额外处理。
func _migrate_save_data(data: Dictionary) -> Dictionary:
	var v := str(data.get("version", ""))
	if v == SaveGameVersion:
		return data
	if v == "":
		Log.warn("⚠️ 存档无版本号（本功能上线前的老档），按字段级兜底读取")
		return data
	## 比当前版本更新的档（玩家用新版本存过、又退回旧版）同样走字段级兜底，但不静默
	Log.warn("⚠️ 存档版本 %s 与当前 %s 不一致，按字段级兜底读取（未知字段将被忽略）" % [v, SaveGameVersion])
	return data


## 读取全局存档，返回可用字典；**没有可用档时返回 null**（不是空字典）。
##
## 返回 null 有两种情况，调用方不必区分，但内部处理不同：
##   ① 文件不存在 —— 新用户，正常：state 保持默认值，允许写入；
##   ② 主档与 .bak 都损坏 —— 异常：原档已隔离为 .corrupt，并置 `_save_locked`
##      锁死本局写入，避免自动存档把空档固化成永久丢档。
##
## **不要改回「损坏就返回 {}」**：那样调用方会把 state 全量设成默认值，
## 60 s 后 save_now() 写回的就是一份空档，而原档已经变成 .bak 再被顶掉。
func _load_json(path: String) -> Variant:
	var read := _read_json_file(path)
	if read["state"] == ReadOk:
		return _migrate_save_data(read["data"])

	if read["state"] == ReadMissing:
		return null

	## 主档坏了：先试上一份好档（_save_json 每次写档都会把旧档留成 .bak）
	var bak_path := path + ".bak"
	if FileAccess.file_exists(bak_path):
		var bak_read := _read_json_file(bak_path)
		if bak_read["state"] == ReadOk:
			Log.warn("⚠️ 主存档损坏，已回退到上一份备份 %s" % bak_path)
			_quarantine_corrupt_file(path, "JSON 解析失败")
			## 把备份复制回主档位置，下次写档就有干净的底子（复制而非改名：备份继续保留）
			if DirAccess.copy_absolute(
				ProjectSettings.globalize_path(bak_path), ProjectSettings.globalize_path(path)
			) != OK:
				Log.warn("⚠️ 备份回写主档失败，不影响本次读取（下次写档会重新生成）")
			return _migrate_save_data(bak_read["data"])

	## 主档和备份都不可用：隔离现场 + 锁写，绝不按空档继续
	_save_locked = true
	_quarantine_corrupt_file(path, "JSON 解析失败且 .bak 不可用")
	return null
