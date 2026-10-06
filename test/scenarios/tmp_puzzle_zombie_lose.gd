extends RefCounted
## 一次性探针：我是僵尸（解谜）对齐原版的两处改动
##
## 校验：
##   1. 僵尸卡的阳光费用 = 原版 I, Zombie 的价目（普僵 50 / 铁桶 125 / 橄榄球 175）
##   2. 开局 50 阳光（够放最便宜的僵尸）不判负
##   3. 场上无僵尸 + 阳光清零 → 1 秒内判负（main_game_progress == GAME_OVER）

const LEVEL_PATH := "res://src/levels/mode_puzzle/puzzle_zombie_01.gd"

var _failed := 0


func run(a) -> void:
	var para: Resource = (load(LEVEL_PATH) as GDScript).new()
	if para == null:
		a.log("[IZOMBIE] !! 关卡脚本加载失败")
		a.finish(true)
		return
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	await a.wait(3.0)
	if Global.main_game == null:
		a.log("[IZOMBIE] !! 主游戏未创建")
		a.finish(true)
		return
	if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		Global.main_game.main_game_start()
	await a.wait(3.0)

	var mg = Global.main_game
	_check(a, "已进入 MAIN_GAME", mg.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME)

	## 1. 僵尸卡阳光费用
	var slot = mg.card_manager.card_slot_battle
	var got := {}
	for card in slot.curr_cards:
		got[int(card.card_zombie_type)] = int(card.sun_cost)
	a.log("[IZOMBIE] 僵尸卡费用=%s" % str(got))
	_check(a, "普僵 = 50", got.get(1, -1) == 50)
	_check(a, "铁桶 = 125（原版）", got.get(5, -1) == 125)
	_check(a, "橄榄球 = 175（原版）", got.get(8, -1) == 175)

	## 2. 开局 50 阳光：够放最便宜的僵尸，不该判负
	await a.wait(2.0)
	_check(a, "开局阳光够放僵尸时不判负",
		mg.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME)

	## 3. 阳光清零 + 场上无僵尸 → 判负
	slot.sun_value = 0
	a.log("[IZOMBIE] 阳光已清零，等待判负")
	var over := false
	for _i in range(10):
		await a.wait(1.0)
		if mg.main_game_progress == MainGameManager.E_MainGameProgress.GAME_OVER:
			over = true
			break
	_check(a, "阳光不足且无僵尸时判负", over)

	a.log("")
	a.log("[IZOMBIE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _check(a, label: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	a.log("[IZOMBIE] %s %s" % ["PASS" if ok else "FAIL", label])
