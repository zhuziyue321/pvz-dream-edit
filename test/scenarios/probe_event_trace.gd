extends RefCounted
## 探针 EVENT_TRACE：`EventBus` 的事件追踪开关是否真的跟随「调试模组」（对应 docs/TODO清单.md 的 U-48）
##
## 【为什么要有这一条】
##   原来 `EventBus` 上有一个 `@export var debug_mode`，全仓没有一处把它置真
##   ⇒ 恒 false ⇒ `get_never_pushed_subscribed_events()`（死事件检测）永远返回
##   「所有有订阅的事件」，等于没信息。2026-10-22 改成 `is_trace_pushed_events`，
##   调试模式做成模组（`ModIds.DEBUG`）后由模组的 `install()` / `uninstall()` 置位。
##   本探针钉住「跟随模组开关」这个语义，防止以后又被改回一个没人打开的开关。
##
## 【判定口径】
##   ① 初值 == 调试模组当前开关；
##   ② 打开模组后，push 一个事件会被记进 `_pushed_event_names`；
##   ③ 关掉模组后不再记录；
##   ④ 结束前把模组开关恢复成进来时的值（别污染同一进程里后续探针）。
##
## 【机器可读汇总】最后一行 `[EVENTTRACE] result=PASS|FAIL failed=<n>`

const TEST_EVENT := "probe_event_trace_only"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE EVENT_TRACE 事件追踪跟随调试模组 ==========")
	var origin := ModManager.is_mod_enabled(ModIds.DEBUG)
	_check(a, "初值跟随调试模组（%s）" % str(origin), EventBus.is_trace_pushed_events == origin,
		"is_trace_pushed_events=%s" % str(EventBus.is_trace_pushed_events))

	ModManager.set_mod_enabled(ModIds.DEBUG, true)
	_check(a, "开调试模组后开始追踪", EventBus.is_trace_pushed_events, "仍为 false")
	EventBus.push_event(TEST_EVENT, [], false)
	_check(a, "被 push 的事件名已记录", EventBus._pushed_event_names.has(TEST_EVENT),
		"未记录（追踪没生效）")

	ModManager.set_mod_enabled(ModIds.DEBUG, false)
	_check(a, "关调试模组后停止追踪", not EventBus.is_trace_pushed_events, "仍为 true")
	EventBus._pushed_event_names.erase(TEST_EVENT)
	EventBus.push_event(TEST_EVENT, [], false)
	_check(a, "关掉后不再记录", not EventBus._pushed_event_names.has(TEST_EVENT), "仍在记录")

	## 还原：同一进程里可能接着跑别的探针
	ModManager.set_mod_enabled(ModIds.DEBUG, origin)
	_finish(a)


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[EVENTTRACE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
