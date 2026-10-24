extends LevelScriptBase
## adventure_03_pool_test —— 由同目录的 adventure_03_pool_test.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_BG = ConstLevelData.GameBg.Pool
	game_BGM = ConstLevelData.GameBGM.Pool
	monster_mode = ConstLevelData.E_MonsterMode.Null
	## 出怪倍率：本关 monster_mode = Null（不自然出怪），此值不生效；写 1 与默认一致。
	## 此前是 10（无依据，与植物僵尸两关的历史问题同值）
	zombie_multy = 1
	start_sun = 6460


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[StringName] = [ZombieIds.SNORKLE]

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
	## 通关掉落：测试关没有奖励，掉奖杯兜底
	if is_curr_level_success():
		win_with_trophy_only()
	else:
		await gain(LootRegistry.TROPHY)
