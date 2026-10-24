extends LevelScriptBase
## minigame_03_slot_machine —— 原版迷你游戏**第 3 关**「拉霸」(Slot Machine)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## ⚠️ 存档键沿用改名之前写死的值（102_1_0021），**不跟着序号改**：改了会让玩家已通关的记录错位。
##
## 玩法（从原版 C++ 参照移植，口径见 minigame_03_slot_machine_ui.gd 头部）：
##   没有僵尸、没有选卡，屏幕左上是拉霸机（阳光银行 + 3 个种子包转轮 + 拉杆）；
##   花 25 阳光拉一次杆，三个转轮按权重随机转出图案，凑对拿阳光 / 钻石 / 免费植物，
##   当前阳光达到 2000 过关掉奖杯（原版 Challenge::UpdateSlotMachine）。
## 界面与机制本体都在同目录的 `minigame_03_slot_machine_ui.gd`（本关专属，硬约束 §1-8）。

## 过关目标：当前阳光达到 2000（原版 SLOT_MACHINE_WINNING_SCORE）
const TARGET_SUN := 2000
## 奖杯掉落格子：原版 SpawnLevelAward(4, 2) = 第 5 列第 3 行（0 起算）
const AWARD_COL := 4
const AWARD_ROW := 2

## 本关的进度条数据源：进度 = 当前阳光 / 2000（见 create_progress_provider）
var progress_provider := SlotMachineProgressProvider.new()


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
	## 原版起始阳光 = 50（Board.cpp InitLevel 的 else 分支）
	start_sun = 50
	camera_init_x = MainGameCamera.CAM_POS_ORI.x


## 本关的进度条口径：**当前阳光 / 2000**（拉霸没有波次，进度条就是「离过关还差多少阳光」）
## 数据源是本脚本自己的实例，拉霸 UI 挂上之后由它 bind_ui()
func create_progress_provider() -> LevelProgressProvider:
	return progress_provider


func run_flow(mg: MainGameManager) -> void:
	## 本关不出怪（monster_mode = Null），走不了 start_battle() 那条路，
	## 但**开战入口同时负责切主游戏 BGM**（开战一秒后播 game_BGM）—— 少了这一句，
	## 整关都停在进关时的选卡曲「Choose Your Seeds」上，本关的 Grasswalk 永远不会响。
	## 与水族馆 / 观星同一套写法（见 minigame_08_zombie_aquarium.run_flow）：
	## 本关 monster_mode = Null，zombie_manager.start_game() 会直接返回，不会刷出僵尸。
	## 阶段切到 MAIN_GAME 也由它负责（不再手动赋值 main_game_progress）
	await mg.main_game_start()

	var slot_ui: SlotMachineUI = preload("res://src/levels/mode_minigame/minigame_03_slot_machine_ui.gd").new()
	mg.canvas_layer_ui.add_child(slot_ui)
	slot_ui.init(mg, start_sun, TARGET_SUN)
	## 进度条这时才拿得到拉霸 UI：之后每帧向它问一次阳光，算出「阳光 / 2000」
	progress_provider.bind_ui(slot_ui)

	await slot_ui.game_finished

	if is_instance_valid(slot_ui):
		slot_ui.queue_free()

	## 奖杯掉在原版那个格子（第 5 列第 3 行）的中心；拿不到格子就退到屏幕中央
	EventBus.push_event(ConstEventName.CREATE_TROPHY, [_get_award_position(mg)])


## 奖杯掉落位置：原版 SpawnLevelAward(4, 2)，按格子中心算全局坐标
func _get_award_position(mg: MainGameManager) -> Vector2:
	if mg != null and mg.plant_cell_manager != null:
		var all_rows: Array = mg.plant_cell_manager.all_plant_cells
		if all_rows.size() > AWARD_ROW:
			var award_row: Array = all_rows[AWARD_ROW]
			if award_row.size() > AWARD_COL:
				var cell = award_row[AWARD_COL]
				return cell.global_position + cell.size * 0.5
	return mg.get_viewport_rect().size * 0.5
