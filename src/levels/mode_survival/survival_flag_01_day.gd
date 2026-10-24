extends LevelScriptBase
## survival_flag_01_day —— 原版「生存模式：白天（普通）」
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序）。
## 原版普通生存 = 5 旗：每轮 10 波（一轮一旗），一轮打完重选一次卡。
## 出怪按原版生存规则**逐轮生成**（见 ZombieManager._update_survival_zombie_refresh_types），
## 所以这里不再写死出怪表，show_zombie / start_battle 都不带表
## —— 带上会把本轮生成的表顶掉，三档难度就又会出一模一样的僵尸。


func _init() -> void:
	save_key = "104_0_0001"
	max_wave = 10
	game_round = 5
	survival_difficulty = ConstLevelData.E_SurvivalDifficulty.Normal
	## 波次点数公式：原版生存分支（Board.cpp:638-641）——第 2 轮起 `(阶段*每阶段波数 + 波)*2/5+1`，
	## 本仓库波次下标跨轮累计，化简为 `波*2/5+1`；第 1 轮仍走默认 `波/3+1`（与原版一致）。
	## 此前全轮次都走默认公式，越往后越比原版松
	wave_points_formula = ConstLevelData.E_WavePointsFormula.Survival


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
	## 开战：普通档每轮 10 波，打满 5 轮判胜
	await start_battle(10)
