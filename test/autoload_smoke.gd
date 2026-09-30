extends Node
## 自动加载冒烟测试（会加载全部 autoload，因此必须用场景方式运行）
## 用法（务必重定向 APPDATA 以隔离存档）:
##   godot --headless --path <项目> res://test/autoload_smoke.tscn
##
## 校验点：所有单例都成功注册、日志可用、工具函数可用。
## 注意：本项目 autoload 含 SoundManager/AllCards，初始化较重，故只等几帧就退出。

const EXPECTED_AUTOLOADS: Array[String] = [
	"Log", "Global", "SoundManager", "SceneRegistry",
	"AllCards", "GlobalUtils", "EventBus", "TreePauseManager", "DebugChannel",
]

var _fail: Array[String] = []


func _ready() -> void:
	## 等几帧，让 autoload 的 _ready 全部执行完
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	for name in EXPECTED_AUTOLOADS:
		if get_node_or_null("/root/" + name) == null:
			_fail.append("自动加载单例缺失: " + name)

	## 日志可用（这条正是当年爆栈的位置）
	if Log != null:
		Log.debug("[冒烟] 自动加载环境下的 debug")
		Log.info("[冒烟] 自动加载环境下的 info")

	## 关键单例的公开属性可访问
	if Global != null:
		if not ("config_service" in Global):
			_fail.append("Global.config_service 不存在")

	if get_tree().root != null and get_tree().current_scene != null:
		pass

	print("")
	print("[自动加载冒烟] 失败 %d 项" % _fail.size())
	for f in _fail:
		print("    [失败] " + f)
	print("[自动加载冒烟] 结果: " + ("通过" if _fail.is_empty() else "存在问题"))
	## 机器可读汇总行（纯 ASCII，供 test/verify.ps1 解析）
	print("[AUTOLOAD-SMOKE] failed=%d result=%s" % [_fail.size(), "PASS" if _fail.is_empty() else "FAIL"])
	get_tree().quit(0 if _fail.is_empty() else 1)
