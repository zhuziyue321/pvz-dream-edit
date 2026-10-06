extends RefCounted
## 探针：迷你游戏第 16 关「坚不可摧」(Last Stand)
## 覆盖：
##   ① 选卡界面禁掉阳光生产类（向日葵 / 阳光菇 / 双子向日葵）与免费植物（小喷菇 / 海蘑菇），
##      模仿者页里的同款也一起禁
##   ② 布阵阶段：玩家能操作（MAIN_GAME）、**不出怪**、右下角有「开始战斗！」按钮
##   ③ 点了按钮才开打（布阵期间一波都没有，点完第一波进场）
##   ④ 每过一波补 250 阳光（第 1 波是开局那一波，不补）
## 机器可读汇总：最后一行 [LASTSTAND] result=PASS|FAIL failed=<n>

const LEVEL := "res://src/levels/mode_minigame/minigame_16_last_stand.gd"
## 布阵阶段的阳光 = 关卡脚本里的 SUN_START
const SUN_START := 5000
const SUN_EVERY_WAVE := 250

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 坚不可摧（Last Stand） ==========")

	## 玩家拥有这些卡：里面有本关禁掉的（向日葵 / 小喷菇），也有不禁的（豌豆射手 / 坚果墙）
	var state = Global.global_game_state
	state.curr_plant.assign([
		CharacterRegistry.PlantType.P001PeaShooterSingle,
		CharacterRegistry.PlantType.P002SunFlower,
		CharacterRegistry.PlantType.P004WallNut,
		CharacterRegistry.PlantType.P009PuffShroom,
	])
	state.unlock_plant(CharacterRegistry.PlantType.P999Imitater)

	var para: Resource = (load(LEVEL) as GDScript).new()
	if para == null:
		_check(a, "关卡脚本可实例化", false, LEVEL)
		_finish(a)
		return
	Global.game_para = para
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	await a.wait(3.0)

	var mg := Global.main_game
	if mg == null:
		_check(a, "已进入主游戏", false, "Global.main_game 为空")
		_finish(a)
		return

	# ------------------------------------------------ STEP1 禁选卡
	a.log("STEP1 选卡界面禁选阳光生产 / 免费植物")
	var cand = mg.card_manager.card_slot_norm.card_slot_candidate
	if cand == null:
		_check(a, "找到待选卡槽", false, "null")
		_finish(a)
		return
	_check(a, "向日葵不出现（普通页）", not _candidate_visible(cand, false, CharacterRegistry.PlantType.P002SunFlower))
	_check(a, "小喷菇不出现（普通页）", not _candidate_visible(cand, false, CharacterRegistry.PlantType.P009PuffShroom))
	_check(a, "豌豆射手正常出现（普通页）", _candidate_visible(cand, false, CharacterRegistry.PlantType.P001PeaShooterSingle))
	_check(a, "坚果墙正常出现（普通页）", _candidate_visible(cand, false, CharacterRegistry.PlantType.P004WallNut))
	_check(a, "向日葵的模仿者也不出现", not _candidate_visible(cand, true, CharacterRegistry.PlantType.P002SunFlower))
	_check(a, "豌豆射手的模仿者正常出现", _candidate_visible(cand, true, CharacterRegistry.PlantType.P001PeaShooterSingle))

	# ------------------------------------------------ STEP2 走到选卡阶段并点「开始游戏」
	a.log("STEP2 等选卡阶段")
	if not await _wait_progress(a, mg, MainGameManager.E_MainGameProgress.CHOOSE_CARD, 30.0):
		_finish(a)
		return
	mg.card_manager.card_slot_norm._on_texture_button_pressed()

	# ------------------------------------------------ STEP3 布阵阶段
	a.log("STEP3 布阵阶段：能操作、不出怪、有「开始战斗！」按钮")
	var button = null
	for i in range(80):
		await a.wait(0.5)
		button = _find_lets_rock_button(mg)
		if button != null:
			break
	if button == null:
		_check(a, "布阵阶段出现「开始战斗！」按钮", false, "canvas_layer_ui 下没找到 LetsRockButton")
		_finish(a)
		return
	_check(a, "布阵阶段出现「开始战斗！」按钮", true)
	var wave_manager = mg.zombie_manager.zombie_wave_manager
	_check(a, "布阵阶段已进入 MAIN_GAME（玩家能种）",
		mg.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME, str(mg.main_game_progress))
	_check(a, "布阵阶段还没出过一波", wave_manager.curr_wave == -1, str(wave_manager.curr_wave))
	_check(a, "布阵阶段场上没有僵尸", mg.zombie_manager.curr_zombie_num == 0, str(mg.zombie_manager.curr_zombie_num))
	_check(a, "开局阳光 = " + str(SUN_START), _sun(mg) == SUN_START, str(_sun(mg)))
	_check(a, "本关没有天降阳光", mg.game_para.is_day_sun == false, str(mg.game_para.is_day_sun))

	# ------------------------------------------------ STEP4 点按钮开战
	a.log("STEP4 点「开始战斗！」")
	button.pressed.emit()
	await a.wait(9.0)
	_check(a, "点完按钮按钮已收起", not is_instance_valid(button) or button.is_queued_for_deletion(), "")
	_check(a, "开打后刷出了第一波", wave_manager.curr_wave >= 0, str(wave_manager.curr_wave))
	_check(a, "开打后场上有僵尸", mg.zombie_manager.curr_zombie_num > 0, str(mg.zombie_manager.curr_zombie_num))
	_check(a, "第一波不补阳光", _sun(mg) == SUN_START, str(_sun(mg)))
	## 波数是「开战」事件带进去的（LevelTimelineEventStartBattle._apply_battle_para），布阵阶段还没生效
	_check(a, "总波数 = 50（5 面旗帜）", mg.game_para.max_wave == 50, str(mg.game_para.max_wave))
	_check(a, "波次管理器总波数 = 50", wave_manager.max_wave_one_round == 50, str(wave_manager.max_wave_one_round))

	# ------------------------------------------------ STEP5 每波补 250 阳光
	a.log("STEP5 推进下一波，应补 " + str(SUN_EVERY_WAVE) + " 阳光")
	var sun_before: int = _sun(mg)
	wave_manager.start_next_wave()
	await a.wait(1.0)
	_check(a, "过一波后阳光 +" + str(SUN_EVERY_WAVE), _sun(mg) == sun_before + SUN_EVERY_WAVE,
		str(sun_before) + " -> " + str(_sun(mg)))

	_finish(a)


#region 工具
## 待选区里某张卡是否出现（imitater = true 查模仿者页）
func _candidate_visible(cand, imitater: bool, plant_type: CharacterRegistry.PlantType) -> bool:
	var containers = cand.all_card_candidate_containers_plant_imitater if imitater \
		else cand.all_card_candidate_containers_plant
	if not AllCards.plant_card_ids.has(plant_type):
		return false
	var card_id: int = AllCards.plant_card_ids[plant_type]
	if not containers.has(card_id):
		return false
	return containers[card_id].visible


func _find_lets_rock_button(mg):
	for child in mg.canvas_layer_ui.get_children():
		if child is LetsRockButton:
			return child
	return null


func _sun(mg) -> int:
	return mg.card_manager.card_slot_battle.sun_value


## 等主游戏推进到某个阶段
func _wait_progress(a, mg, progress, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if mg.main_game_progress == progress:
			return true
		await a.wait(0.5)
		waited += 0.5
	_check(a, "等到阶段 " + str(progress), false, "当前阶段=" + str(mg.main_game_progress))
	return false


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[LASTSTAND] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
