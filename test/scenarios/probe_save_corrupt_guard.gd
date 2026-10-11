extends RefCounted
## 探针：存档损坏的三条兜底行为
## 覆盖（对应 SaveService 的损坏保护）：
##   1. 主档写坏、.bak 完好 —— 回退到备份，主档隔离成 .corrupt，且**不**锁写
##   2. 主档与 .bak 都写坏 —— 锁死写入（_save_locked），save_now() 不再产档，坏档隔离保留
##   3. 重新读档后解锁，能正常写档（保证保护是一次性的，不会永久废掉存档）
##
## 为什么必须有这个探针：丢档链是「解析失败 → 按空档处理 → 下一次 save_now() 把空档写回」，
## 三处改动任何一处被回退都会让整条链复活，而这条链平时跑不出来（要人为造坏档）。
## 机器可读汇总：最后一行 [SAVEGUARD] result=PASS|FAIL failed=<n>

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 存档损坏兜底 ==========")
	await a.wait(2.0)

	var save_service = Global.save_service
	var state = Global.global_game_state
	var path := _save_path()
	_check(a, "已有登录用户（存档路径非空）", not path.is_empty(), path)

	a.log("STEP0 先落两份正常档，制造出 .bak（第一次 777，第二次 888）")
	state.coin_value = 777
	save_service.save_now()
	_check(a, "正常档写入成功", FileAccess.file_exists(path))
	state.coin_value = 888
	save_service.save_now()
	_check(a, "备份文件 .bak 已生成", FileAccess.file_exists(path + ".bak"))

	a.log("STEP1 主档写坏 → 应回退到 .bak（金币回到 777）")
	state.coin_value = 0
	_write_text(a, path, "{ 这不是合法 JSON")
	save_service.load_global_game_data()
	_check(a, "金币回退到备份里的 777", state.coin_value == 777, str(state.coin_value))
	_check(a, "有备份可回退时不锁写", not save_service.is_save_locked())
	_check(a, "坏档被隔离成 .corrupt（现场保留）", _corrupt_count(path) >= 1,
		str(_corrupt_count(path)))

	a.log("STEP2 主档与 .bak 都写坏 → 应锁死写入")
	_write_text(a, path, "{ 主档又坏了")
	_write_text(a, path + ".bak", "{ 备份也坏了")
	save_service.load_global_game_data()
	_check(a, "两档皆损坏时锁死写入", save_service.is_save_locked())
	_check(a, "第二次坏档也被隔离", _corrupt_count(path) >= 2, str(_corrupt_count(path)))
	save_service.save_now()
	_check(a, "锁写后 save_now() 不再生成主档", not FileAccess.file_exists(path))

	a.log("STEP3 重新读档后解锁，存档功能恢复")
	save_service.load_global_game_data()
	_check(a, "重新读档后解除保护（保护是一次性的）", not save_service.is_save_locked())
	save_service.save_now()
	_check(a, "解锁后可以正常写档", FileAccess.file_exists(path))

	_finish(a)


#region 工具与断言

func _save_path() -> String:
	var user_name: String = Global.user_manager.curr_user_name
	if user_name.is_empty():
		return ""
	return "user://" + user_name + "/" + Global.save_service.SaveGameFileName


## 直接往盘上写文本（用来造坏档）
func _write_text(a, path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failed += 1
		a.log("  [NG] 无法写入文件（造坏档失败，本轮结论不可信）: " + path)
		return
	file.store_string(text)
	file.close()


## 数一下存档目录里被隔离的坏档有几个（文件名含 .corrupt）
func _corrupt_count(path: String) -> int:
	var abs_path := ProjectSettings.globalize_path(path)
	var dir := abs_path.get_base_dir()
	var count := 0
	for file_name in DirAccess.get_files_at(dir):
		if file_name.begins_with(path.get_file() + Global.save_service.CORRUPT_SUFFIX):
			count += 1
	return count


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[SAVEGUARD] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()

#endregion
