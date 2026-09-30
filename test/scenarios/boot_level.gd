extends RefCounted
## 场景脚本：启动 → 进入关卡 → 跳过选卡 → 观察波次
## 这是 autopilot 的「冒烟基线」，用来确认整套驱动链路可用。

func run(a) -> void:
	await a.wait(1.0)
	await a.dump("开始菜单就绪")

	var para: Resource = load("res://resources/level_date_resource/mode_adventure/adventure_01_01.tres")
	if para == null:
		a.log("!! 关卡资源加载失败")
		a.finish()
		return
	Global.game_para = para
	a.log("[场景] 切换到主游戏场景")
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	await a.wait(2.0)
	await a.dump("关卡场景已加载（此刻应在选卡阶段）")

	a.log("[场景] 跳过选卡: main_game_start()")
	Global.main_game.main_game_start()
	await a.wait(3.0)
	await a.dump("游戏已开始（应进入 MAIN_GAME）")

	await a.wait(8.0)
	await a.dump("运行 8 秒后（应有僵尸出场）")

	a.finish()
