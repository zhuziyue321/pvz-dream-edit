extends LevelScriptBase
## survival_flag_08_pool —— 原版「生存模式：泳池（困难）」
##
## 困难生存 = 10 旗，每轮 20 波；出怪逐轮按原版生存规则生成（见 ZombieManager）。


func _init() -> void:
	save_key = "104_0_0008"
	max_wave = 20
	game_round = 5
	survival_difficulty = ConstLevelData.E_SurvivalDifficulty.Hard
	## 波次点数公式：原版生存分支（Board.cpp:638-641）——第 2 轮起 `(阶段*每阶段波数 + 波)*2/5+1`，
	## 本仓库波次下标跨轮累计，化简为 `波*2/5+1`；第 1 轮仍走默认 `波/3+1`（与原版一致）。
	## 此前全轮次都走默认公式，越往后越比原版松
	wave_points_formula = ConstLevelData.E_WavePointsFormula.Survival
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_BG = ConstLevelData.GameBg.Pool
	game_BGM = ConstLevelData.GameBGM.Pool


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 展示僵尸（空表 = 用僵尸管理器本轮生成的出怪表）
	await show_zombie()
	## 选卡
	await choose_card()
	## 初始化小推车
	await init_lawn_mover()
	## 准备安放植物
	await ready_set_plant()
	## 开战：困难档每轮 20 波，打满 5 轮判胜
	await start_battle(20)
