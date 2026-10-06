extends SceneTree
## 迁移工具的命令行入口：**不启动游戏主场景**，直接跑 .tres → .gd（几秒就完事）
##
## 为什么单独开一个入口：run_autopilot.ps1 会把整个游戏（开始菜单 + 4 个选关场景）跑起来，
## 首次还要做资源导入，一次要好几分钟；而本工具只做文本解析，压根不需要游戏。
##
## 跑法（PowerShell）：
##   & "C:\Users\a a\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path "c:/Users/a a/Desktop/Dream" --script res://test/scenarios/tool_tres2gd_cli.gd
##
## 结果写到 test/out_tres2gd.txt（离线工具没有 Log autoload，所以落文件而不是裸 print）

const OUT := "res://test/out_tres2gd.txt"


func _initialize() -> void:
	var logger := CliLogger.new()
	var tool: RefCounted = (load("res://test/scenarios/tool_level_tres_to_script.gd") as GDScript).new()
	tool.run(logger)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f != null:
		var text := ""
		for l in logger.lines:
			text += l + "\n"
		f.store_string(text)
		f.close()
	quit()


## 顶替 run_autopilot 的 a：只把日志攒起来，最后落文件
class CliLogger extends RefCounted:
	var lines: Array[String] = []

	func log(msg: String) -> void:
		lines.append(msg)

	func finish() -> void:
		pass

	func quit_game() -> void:
		pass
