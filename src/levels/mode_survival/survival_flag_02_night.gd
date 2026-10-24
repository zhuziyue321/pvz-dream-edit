extends LevelScriptBase
## survival_flag_02_night —— 原版「生存模式：黑夜（普通）」
##
## 普通生存 = 5 旗，每轮 10 波；出怪逐轮按原版生存规则生成（见 ZombieManager）。


func _init() -> void:
	save_key = "104_0_0002"
	max_wave = 10
	game_round = 5
	survival_difficulty = ConstLevelData.E_SurvivalDifficulty.Normal
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.FrontNight
	is_day = false
	is_day_sun = false
	is_have_tombston = true
	init_tombstone_num = 5
	## 生存夜晚:每个大波(本轮最终波)前补墓碑,再由全部墓碑放伏击僵尸
	is_tombstone_respawn = true


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
