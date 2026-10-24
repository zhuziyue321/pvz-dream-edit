extends LevelScriptBase
## ★ 二周目版（adventure_02_09_round2）—— 二周目及以后进这一关时加载的就是本文件：
##   进关方按周目取脚本（LevelRegistry.get_adventure_level_id(关卡序号, 周目)），
##   正本 adventure_02_09.gd 与它是**同一关的两套脚本**，存档键仍是同一份（二周目的进度靠记录里的 Round 区分）。
##   本文件与正本的差异（见 docs/参考存档/二周目.md）：
##     · 波数：20 → 30 波（普通关二周目多 10 波）
##     · 开局锁定前 3 个随机卡槽：从本关能用的植物里随机挑 3 株占住前 3 槽，玩家只能改后面的槽
## adventure_02_09 —— 由同目录的 adventure_02_09.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	save_key = "101_1_0019"
	## 二周目差异：开局锁定前 3 个随机卡槽 —— 从本关能用的植物里随机挑 3 株占住前 3 槽，
	## 玩家只能编辑第 4 个槽起的部分（机制与边界见 docs/参考存档/二周目.md）
	locked_random_card_num = 3
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.FrontNight
	is_day = false
	is_day_sun = false
	is_have_tombston = true
	init_tombstone_num = 11


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[StringName] = [
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.SCREEN_DOOR,
		ZombieIds.JACKSON,
	]

	## 戴夫推销卡槽扩充（2-2 ~ 3-4 这几关都有；钱不够时戴夫不来，见 LevelScriptBase.dave_sell_card_slot）
	await dave_sell_card_slot()
	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(30, zombie_list)
	## 本关没有通关奖励（全 50 关里就这 6 关没有：x-9 / 5-10，原版也不给东西），
	## 所以本关没写 level_complete_loot —— 掉奖杯兜底
	if is_curr_level_success():
		win_with_trophy_only()
	else:
		await gain(LootRegistry.TROPHY)
