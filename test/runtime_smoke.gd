extends MainLoop
## 运行期冒烟测试（不加载 autoload，因此可以在 --script 模式下跑）
## 用法: godot --headless --path <项目> --script res://test/runtime_smoke.gd
##
## 为什么需要它：静态扫描只能证明「能编译」，证明不了「跑起来不炸」。
## 曾经 logger.gd 的 _write() 里误用了 Log.debug()，造成
## _write → debug() → _write 无限递归爆栈 —— 编译完全正常，
## 编辑器全量扫描 PROBLEMS=0，只有真正执行才暴露。

var _pass := 0
var _fail: Array[String] = []


func _initialize() -> void:
	print("[运行期冒烟] 开始")

	_test_logger()
	_test_logger_level_filter()
	_test_global_utils()
	_test_random_picker()

	print("")
	print("[运行期冒烟] 通过 %d 项，失败 %d 项" % [_pass, _fail.size()])
	for f in _fail:
		print("    [失败] " + f)
	print("[运行期冒烟] 结果: " + ("通过" if _fail.is_empty() else "存在问题"))
	## 机器可读汇总行（纯 ASCII，供 test/verify.ps1 解析）
	print("[RUNTIME-SMOKE] passed=%d failed=%d result=%s" % [
		_pass, _fail.size(), "PASS" if _fail.is_empty() else "FAIL"
	])


func _process(_delta: float) -> bool:
	return true


func _ok(check_name: String, condition: bool) -> void:
	if condition:
		_pass += 1
		print("    ok   " + check_name)
	else:
		_fail.append(check_name)
		print("    FAIL " + check_name)


## 核心用例：日志工具自己不能递归调用自己
func _test_logger() -> void:
	var logger_script: GDScript = load("res://scripts/autoload/util/logger.gd")
	if logger_script == null:
		_fail.append("logger.gd 加载失败")
		return
	var log: Node = logger_script.new()
	_ok("logger 实例化", log != null)
	if log == null:
		return
	## 只要这四行里任意一行发生递归，整个进程就会爆栈，后面都执行不到
	log.debug("[冒烟] debug")
	log.info("[冒烟] info")
	log.warn("[冒烟] warn")
	log.error("[冒烟] error")
	_ok("logger 四个级别调用不爆栈", true)
	_ok("logger 多参数拼接", log._join("a", "b", null, null, null) == "ab")
	_ok("logger null 参数被跳过", log._join("a", null, null, null, null) == "a")
	log.free()


## 级别过滤：level 设为 OFF 后不应产生任何输出
func _test_logger_level_filter() -> void:
	var logger_script: GDScript = load("res://scripts/autoload/util/logger.gd")
	var log: Node = logger_script.new()
	log.level = logger_script.Level.OFF
	log.debug("这一行不应该出现")
	log.error("这一行也不应该出现")
	_ok("level=OFF 时不输出", true)
	log.free()


func _test_global_utils() -> void:
	var script: GDScript = load("res://scripts/autoload/util/global_utils.gd")
	if script == null:
		_fail.append("global_utils.gd 加载失败")
		return
	var utils: Node = script.new()
	var padded: Array = utils.pad_array([1], 4, 0)
	_ok("global_utils.pad_array 补全长度", padded.size() == 4)
	_ok("global_utils.pad_array 保留原值", padded[0] == 1)
	_ok("global_utils.pad_array 填充值正确", padded[3] == 0)
	utils.free()


func _test_random_picker() -> void:
	var script: GDScript = load("res://scripts/autoload/util/random_picker.gd")
	if script == null:
		_fail.append("random_picker.gd 加载失败")
		return
	var picker = script.new([["a", 1], ["b", 1]])
	_ok("random_picker 构造", picker != null)
	if picker == null:
		return
	_ok("random_picker 非空判断", not picker.is_empty())
	var picked: Variant = picker.get_random_item()
	_ok("random_picker 取到的项来自输入集合", picked == "a" or picked == "b")
