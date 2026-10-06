extends RefCounted
## 探针:验证雷雨关(原版 4-10)的表现链路 —— 关卡开关、雨场景实例化、压暗与闪电。
## 用法: powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_rain_lightning

const LEVEL_4_10 := "res://src/levels/mode_adventure/adventure_04_10.gd"
const RAIN_SCENE := "res://src/world/background/rain.tscn"


func run(a) -> void:
	var para: Resource = (load(LEVEL_4_10) as GDScript).new()
	a.log("[RAIN] 4-10 rain=%s lightning=%s fog=%s BGM=%s" % [
		str(para.is_rain), str(para.is_lightning), str(para.is_fog), str(para.game_BGM)])

	var scn: PackedScene = load(RAIN_SCENE)
	var rain: MainGameRain = scn.instantiate()
	a.get_tree().root.add_child(rain)
	await a.wait(0.2)
	a.log("[RAIN] 节点 darkness=%s flash=%s timer=%s" % [
		str(rain.darkness != null), str(rain.flash != null), str(rain.lightning_timer != null)])
	a.log("[RAIN] 未开闪电 darkness.a=%s" % str(rain.darkness.color.a))

	rain.set_lightning(true)
	a.log("[RAIN] 开闪电后 darkness.a=%s 间隔=%s" % [
		str(rain.darkness.color.a), str(rain.lightning_timer.wait_time)])

	rain.strike()
	await a.wait(0.15)
	a.log("[RAIN] 闪电中 flash.a=%s darkness.a=%s" % [
		str(rain.flash.color.a), str(rain.darkness.color.a)])
	await a.wait(1.2)
	a.log("[RAIN] 闪电后 flash.a=%s darkness.a=%s" % [
		str(rain.flash.color.a), str(rain.darkness.color.a)])

	rain.set_lightning(false)
	rain.queue_free()
	a.quit_game()
