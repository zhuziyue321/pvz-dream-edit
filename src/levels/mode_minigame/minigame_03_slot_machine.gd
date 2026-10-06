extends LevelScriptBase
## minigame_03_slot_machine —— 原版迷你游戏**第 3 关**「拉霸」(Slot Machine)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## ⚠️ 存档键沿用改名之前写死的值（102_1_0021），**不跟着序号改**：改了会让玩家已通关的记录错位。

## 过关目标：累计从拉杆/植物中收集到的阳光数量
const TARGET_SUN := 2000

func _init() -> void:
	save_key = "102_1_0021"
	## 场景曲：本关是白天前院 → 白天曲 Grasswalk
	game_BGM = ConstLevelData.GameBGM.FrontDay
	game_BG = ConstLevelData.GameBg.FrontDay
	is_day_sun = false
	look_show_zombie = false
	can_choosed_card = false
	monster_mode = ConstLevelData.E_MonsterMode.Null
	card_mode = ConstLevelData.E_CardMode.Null
	is_shovel = false
	is_lawn_mover = false
	start_sun = 2000
	camera_init_x = MainGameCamera.CAM_POS_ORI.x


func run_flow(mg: MainGameManager) -> void:
	## 本关不出怪（monster_mode = Null），走不了 start_battle() 那条路，
	## 但**开战入口同时负责切主游戏 BGM**（开战一秒后播 game_BGM）—— 少了这一句，
	## 整关都停在进关时的选卡曲「Choose Your Seeds」上，本关的 Loonboon 永远不会响。
	## 与水族馆 / 观星同一套写法（见 minigame_08_zombie_aquarium.run_flow）：
	## 本关 monster_mode = Null，zombie_manager.start_game() 会直接返回，不会刷出僵尸。
	## 阶段切到 MAIN_GAME 也由它负责（不再手动赋值 main_game_progress）
	await mg.main_game_start()

	var slot_ui: SlotMachineUI = preload("res://src/levels/mode_minigame/minigame_03_slot_machine_ui.gd").new()
	mg.canvas_layer_ui.add_child(slot_ui)
	slot_ui.init(mg, start_sun, TARGET_SUN)
	await slot_ui.game_finished

	if is_instance_valid(slot_ui):
		slot_ui.queue_free()

	EventBus.push_event("create_trophy", [Vector2(400, 300)])
