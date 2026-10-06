extends Node
class_name UserManager

signal signal_users_update

## 当前用户名
var curr_user_name: String = ""
## 所有用户名
var all_user_name: Array[String] = []

## 当前用户配置文件路径（单独存储用户名）
const CURRENT_USER_CONFIG_PATH := "user://current_user.ini"

## 没有任何账号时静默创建的默认账号名
const DEFAULT_USER_NAME := "default user"

## 从单独文件加载当前用户名和用户列表
func load_current_user() -> bool:
	var config := ConfigFile.new()
	var err := config.load(CURRENT_USER_CONFIG_PATH)
	if err == OK:
		curr_user_name = config.get_value("user", "current_user", "")
		all_user_name = config.get_value("user", "all_user", [])
		Log.debug(str("✅ 成功加载当前用户: ") + str(curr_user_name))
		Log.debug(str("✅ 已加载用户列表: ") + str(all_user_name))
		return true

	Log.debug("⚠️ 用户配置文件不存在")
	curr_user_name = ""
	all_user_name.clear()
	return false

## 保存当前用户名到单独文件
func save_user_names() -> void:
	var config := ConfigFile.new()
	config.set_value("user", "current_user", curr_user_name)
	config.set_value("user", "all_user", all_user_name)
	var err := config.save(CURRENT_USER_CONFIG_PATH)
	if err == OK:
		Log.debug(str("✅ 当前用户已保存: ") + str(curr_user_name))
	else:
		Log.error("❌ 保存当前用户失败: %s" % err)

## 保证启动时至少有一个可用账号（在 load_current_user() 之后调用）：
## 没有任何账号时静默创建 DEFAULT_USER_NAME 并设为当前账号，跳过开始菜单的「创建用户」流程。
## 返回 true 表示本次新创建了默认账号（首次启动）。
func ensure_default_user() -> bool:
	if not all_user_name.is_empty():
		## 有账号但未选中时静默选中第一个，避免存档 / 配置路径为空
		if curr_user_name.is_empty():
			set_current_user(all_user_name[0])
		return false

	var err_msg := add_user(DEFAULT_USER_NAME)
	if not err_msg.is_empty():
		Log.error(str("❌ 创建默认账号失败: ") + err_msg)
		return false
	set_current_user(DEFAULT_USER_NAME)
	Log.debug(str("✅ 无账号，已静默创建默认账号: ") + DEFAULT_USER_NAME)
	return true

## 设定当前用户（只修改内存 + 写入 CURRENT_USER_CONFIG；不负责读写游戏存档）
func set_current_user(user_name: String) -> void:
	curr_user_name = user_name
	save_user_names()
	signal_users_update.emit()

## 验证并创建存档文件夹，创建用户名时调用
func ensure_save_directory_exists(user_name: String) -> void:
	var save_dir_path := "user://%s/%s" % [user_name, SaveService.MAIN_GAME_SAVE_DIR_NAME]
	if not DirAccess.dir_exists_absolute(save_dir_path):
		var err := DirAccess.make_dir_recursive_absolute(save_dir_path)
		if err == OK:
			Log.debug(str("✅ 创建存档文件夹成功：") + str(save_dir_path))
		else:
			Log.error("❌ 创建存档文件夹失败，错误码：%s" % err)
	else:
		Log.debug("存在存档文件")

## 增加新用户接口
func add_user(new_user_name: String) -> String:
	new_user_name = new_user_name.strip_edges()
	if new_user_name == "":
		Log.debug("❌ 用户名不能为空")
		return "用户名不能为空"
	if all_user_name.has(new_user_name):
		Log.debug(str("❌ 用户已存在: ") + str(new_user_name))
		return "用户已存在"

	all_user_name.append(new_user_name)
	save_user_names()
	## 创建用户存档文件夹
	ensure_save_directory_exists(new_user_name)
	Log.debug(str("✅ 成功添加用户: ") + str(new_user_name))
	signal_users_update.emit()
	return ""

## 删除用户接口（不允许删除当前登录用户）
func delete_user(user_name: String) -> String:
	if not all_user_name.has(user_name):
		Log.debug(str("❌ 用户不存在: ") + str(user_name))
		return "用户不存在"
	if user_name == curr_user_name:
		Log.debug("❌ 不能删除当前登录用户")
		return "不能删除当前登录用户"

	# 删除用户存档目录
	var user_dir_path := "user://%s" % user_name
	if DirAccess.dir_exists_absolute(user_dir_path):
		delete_folder(user_dir_path)
		Log.debug(str("✅ 已删除用户存档目录: ") + str(user_dir_path))

	# 从用户列表移除
	all_user_name.erase(user_name)
	save_user_names()
	signal_users_update.emit()
	Log.debug(str("✅ 成功删除用户: ") + str(user_name))
	return ""

## 重命名用户接口（负责目录迁移 + 列表更新；不负责读写游戏存档）
func rename_user(old_name: String, new_name: String) -> String:
	old_name = old_name.strip_edges()
	new_name = new_name.strip_edges()
	if new_name == "":
		Log.debug("❌ 新用户名不能为空")
		return "新用户名不能为空"
	if old_name == new_name:
		Log.debug("❌ 新用户名不能与原用户名相同")
		return "新用户名不能与原用户名相同"
	if not all_user_name.has(old_name):
		Log.debug(str("❌ 原用户不存在: ") + str(old_name))
		return "原用户不存在"
	if all_user_name.has(new_name):
		Log.debug(str("❌ 新用户名已存在: ") + str(new_name))
		return "新用户名已存在"

	# 迁移存档目录
	var old_dir_path := "user://%s" % old_name
	var new_dir_path := "user://%s" % new_name

	if DirAccess.dir_exists_absolute(old_dir_path):
		var err := DirAccess.rename_absolute(old_dir_path, new_dir_path)
		if err != OK:
			Log.debug(str("❌ 迁移存档目录失败，错误码: ") + str(err))
			return "迁移存档目录失败，错误码"
		Log.debug(str("✅ 存档目录已从 ") + str(old_dir_path) + str(" 迁移到 ") + str(new_dir_path))

	# 更新用户列表
	var old_index := all_user_name.find(old_name)
	if old_index != -1:
		all_user_name[old_index] = new_name

	# 如果重命名的是当前用户，更新当前用户名
	if old_name == curr_user_name:
		curr_user_name = new_name

	# 保存配置
	save_user_names()

	Log.debug(str("✅ 用户已从重命名: ") + str(old_name) + str(" -> ") + str(new_name))
	signal_users_update.emit()
	return ""

func delete_folder(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		Log.error("无法打开目录: " + path)
		return

	# 删除所有文件
	for file in dir.get_files():
		var file_path := path.path_join(file)
		var err := dir.remove(file_path)
		if err != OK:
			Log.error("删除文件失败: " + file_path)

	# 删除所有子目录（递归）
	for sub in dir.get_directories():
		delete_folder(path.path_join(sub))

	# 删除自身目录
	var parent_dir := DirAccess.open(path.get_base_dir())
	if parent_dir:
		parent_dir.remove(path)
