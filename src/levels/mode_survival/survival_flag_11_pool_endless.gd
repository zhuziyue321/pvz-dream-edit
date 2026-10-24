extends LevelScriptBase
## survival_flag_11_pool_endless —— 原版「生存模式：泳池（无尽）」
##
## 原版无尽就是**泳池地图**的生存（ChallengeScreen 里 `SURVIVAL_ENDLESS_STAGE_3`，
## 图标对应 Survival_Thumbnails 的第 11 格），一轮 20 波（两旗），轮次无上限。
## 出怪按原版生存规则逐轮生成（见 ZombieManager._update_survival_zombie_refresh_types）：
## 第 1 轮普僵 + 路障 + 铁桶，之后每轮随机补 min(轮次, 9) 种，蹦极只在屋顶 / 无尽出现。
##
## save_key 沿用原「无尽 白天」的 104_0_0011：老存档里的无尽进度不丢
## （关卡 id 变了不影响，存档键是写死的那个）。


func _init() -> void:
	save_key = "104_0_0011"
	max_wave = 20
	## -1 = 无尽（约定见 ResourceLevelData.game_round）
	game_round = -1
	survival_difficulty = ConstLevelData.E_SurvivalDifficulty.Endless
	## 波次点数公式：原版生存分支（Board.cpp:638-641）——第 2 轮起 `(阶段*每阶段波数 + 波)*2/5+1`，
	## 本仓库波次下标跨轮累计，化简为 `波*2/5+1`；第 1 轮仍走默认 `波/3+1`（与原版一致）。
	## 无尽轮次无上限，这条公式正是「越打越猛」的来源；此前全轮次走默认公式，涨不上去
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
	## 开战：无尽档每轮 20 波，轮次没有上限
	await start_battle(20)
