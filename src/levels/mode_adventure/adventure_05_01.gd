extends LevelScriptBase
## adventure_05_01 —— 由同目录的 adventure_05_01.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


## 本关开场戴夫对话：台词在数据层，见 res://data/dave/dialog/adventure_05_01_opening.tres
const DAVE_OPENING := preload("res://data/dave/dialog/adventure_05_01_opening.tres")


func _init() -> void:
	save_key = "101_4_0041"
	game_sences = MainSceneRegistry.MainScenes.MainGameRoof
	game_BG = ConstLevelData.GameBg.Roof
	game_BGM = ConstLevelData.GameBGM.Roof
	dave_dialog_only_first_playthrough = true
	is_bungi = true
	## 本关通关掉落：花盆（种子包）
	level_complete_loot = "flower_pot_seed_packet"


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	await plant_flower_pot_columns(4)
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[StringName] = [
		ZombieIds.NORM,
		ZombieIds.CONE,
	]

	## 关卡戴夫对话
	await dave_dialog(DAVE_OPENING)
	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(10, zombie_list)
	## 通关掉落：首次通关掉本关奖励（见 _init 里的 level_complete_loot），已通关过只出奖杯
	if is_curr_level_success():
		win_with_trophy_only()
	else:
		await gain(level_complete_loot)
