extends RefCounted
## 探针：Ctrl+K 清场快捷键（`ShortcutKeys_KillAllZombie`，冒险 1-1）
## 校验：进 MAIN_GAME 且场上有僵尸 → 发一个带 Ctrl 的 K 键事件 → 僵尸数量归零。
## 无头可跑：僵尸出场、死亡信号、`curr_zombie_num` 递减都不依赖渲染。
##
## 注意：不要用 autopilot 的 `a.key()`，它走的是 `InputEventAction`，
## 不会进 `_unhandled_key_input()`，这里必须手工造一个带修饰键的物理按键事件。

const LEVEL_PATH := "res://src/levels/mode_adventure/adventure_01_01.gd"


func run(a) -> void:
	var para: Resource = (load(LEVEL_PATH) as GDScript).new()
	if para == null:
		a.log("[KILLALL] !! 关卡资源加载失败")
		a.finish(true)
		return
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	await a.wait(3.0)
	if Global.main_game == null:
		a.log("[KILLALL] !! 主游戏未创建")
		a.finish(true)
		return
	if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		Global.main_game.main_game_start()
	await a.wait(3.0)
	a.log("[KILLALL] 当前阶段=%d" % Global.main_game.main_game_progress)

	var zm = Global.main_game.zombie_manager
	## 1-1 是教程关，第一波由教程管理器「种下第一株植物后」才启动（见 ZombieManager.start_game()），
	## 干等永远不会出僵尸，这里直接调波次创建管理器摆 3 只普通僵尸上场。
	var creator = zm.zombie_wave_manager.zombie_wave_create_manager
	for lane in range(3):
		creator.wave_create_zombie(CharacterRegistry.ZombieType.Z001Norm, lane, 1)
	await a.wait(1.0)

	var before := 0
	for _i in range(10):
		before = zm.curr_zombie_num
		if before > 0:
			break
		await a.wait(1.0)
	if before <= 0:
		a.log("[KILLALL] !! 等到超时都没有僵尸出场，无法验证")
		a.finish(true)
		return

	var down := InputEventKey.new()
	down.keycode = KEY_K
	down.physical_keycode = KEY_K
	down.ctrl_pressed = true
	down.pressed = true
	Input.parse_input_event(down)
	await a.wait(0.2)
	var up := InputEventKey.new()
	up.keycode = KEY_K
	up.physical_keycode = KEY_K
	up.ctrl_pressed = true
	up.pressed = false
	Input.parse_input_event(up)
	await a.wait(1.5)

	var after := int(zm.curr_zombie_num)
	a.log("[KILLALL] 按键前僵尸=%d 按键后僵尸=%d" % [before, after])
	a.log("[KILLALL] result=%s" % ("PASS" if after == 0 else "FAIL"))
	a.finish(true)
