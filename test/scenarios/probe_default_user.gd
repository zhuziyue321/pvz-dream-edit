extends RefCounted
## 探针：首次启动（没有任何账号）时应静默创建默认账号 "default user" 并设为当前账号
## 校验（无头可跑）：
##   1. curr_user_name == "default user"
##   2. all_user_name 含 "default user"
##   3. 该账号的存档目录已创建（存档 / 配置路径不会为空）
##   4. current_user.ini 已落盘（下次启动仍是同一账号）
##   5. 再次 ensure_default_user() 幂等：不重复创建、不重复追加


func run(a) -> void:
	var um := Global.user_manager
	a.log("[default-user] curr=%s all=%s" % [um.curr_user_name, str(um.all_user_name)])

	var ok := true
	if um.curr_user_name != um.DEFAULT_USER_NAME:
		ok = false
		a.log("[default-user] !! 当前账号不是默认账号，实际=%s" % um.curr_user_name)
	if not um.all_user_name.has(um.DEFAULT_USER_NAME):
		ok = false
		a.log("[default-user] !! 用户列表不含默认账号")

	var save_dir := "user://%s/%s" % [um.DEFAULT_USER_NAME, Global.save_service.MAIN_GAME_SAVE_DIR_NAME]
	if not DirAccess.dir_exists_absolute(save_dir):
		ok = false
		a.log("[default-user] !! 存档目录未创建: %s" % save_dir)

	if not FileAccess.file_exists(um.CURRENT_USER_CONFIG_PATH):
		ok = false
		a.log("[default-user] !! 用户配置文件未落盘: %s" % um.CURRENT_USER_CONFIG_PATH)

	## 幂等：已有账号时不应再新建
	var created_again := um.ensure_default_user()
	if created_again or um.all_user_name.count(um.DEFAULT_USER_NAME) != 1:
		ok = false
		a.log("[default-user] !! 重复创建默认账号 created_again=%s 数量=%d" % [
			str(created_again), um.all_user_name.count(um.DEFAULT_USER_NAME)])

	a.log("[default-user] 结果=%s" % ("PASS" if ok else "FAIL"))
	a.finish(true)
