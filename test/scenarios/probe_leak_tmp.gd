extends RefCounted
## 临时探针：进入关卡 → 跑几秒 → 退出，用来抓退出时的 RID / 对象泄漏明细（配合 --verbose）

func run(a) -> void:
	await a.wait(1.0)
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	await a.wait(3.0)
	if Global.main_game != null and Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		Global.main_game.main_game_start()
	await a.wait(6.0)
	a.finish(true)
