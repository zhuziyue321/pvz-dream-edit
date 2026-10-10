extends RefCounted
## 工具探针：把 `test/scenarios/` 下每一份脚本都 `load()` 一遍 —— 只为让 GDScript **解析器跑一次**
##
## ★ 为什么必须有这一份：`test/check_scripts.ps1` 走 Godot 的 `--import`，
## 而 `--import` 只编译**被别处引用到的**脚本。探针脚本是运行期按路径 `load()` 的，
## 没有任何东西引用它们 ⇒ **永远进不了门禁**。
##
## 后果很具体：实测连着两次「`var x :=` 推断不出类型」「引用了已删除的常量」这类
## **解析错误**都被门禁报成 `real compile errors = 0`，每次要等一整轮双进程实测
## （约 4 分钟）才由输出里的 `SCRIPT ERROR` 暴露出来。
##
## ⚠️ **本脚本不自己判 FAIL**：它只负责 `load()` 并打印条数，
## 有没有解析错误由 `check_scripts.ps1` 扫这次运行的 **stdout + stderr** 决定
## （判据与 `--import` 那道同一个 `RealPattern`）。
##
## 为什么不让脚本自己判断（两次踩坑的结论）：
##   1. `load() != null` **不行** —— 脚本有 Parse Error 时 Godot 返回的是
##      **占位 GDScript 对象**，不是 null，判空一律漏掉。
##   2. `has_method("run")` **也不行** —— 本目录下有一批命令行工具脚本
##      （`tool_*.gd`）根本没有 `run`，会被整片误报成"解析失败"。
##
## 机器可读汇总：`[COMPILE] scripts=..`（PASS / FAIL 由 PowerShell 那侧判定）

func run(a) -> void:
	var dir := "res://test/scenarios"
	var da := DirAccess.open(dir)
	if da == null:
		a.log("[COMPILE] result=FAIL 打不开 " + dir)
		a.quit_game()
		return
	var total := 0
	for f in da.get_files():
		if not f.ends_with(".gd"):
			continue
		total += 1
		## 只 load，不调用：解析错误会由 Godot 自己打到 stdout / stderr
		var script: Script = load(dir.path_join(f))
		if script == null:
			a.log("  [COMPILE] load 返回 null：" + f)
	a.log("[COMPILE] scripts=%d" % total)
	a.quit_game()
