extends "res://src/levels/core/level_script_base.gd"
## 玩家对战：白天 —— 卡槽已就位（对战逻辑还没做）
##
## 关卡 = 一个 .gd（属性 + 流程），见 LevelScriptBase。
## 这一关把双方的两条卡槽摆进主游戏：
##   - 左上：**植物卡槽**（本体那张，固定六格，选卡 / 种植那套全走本体流程）；
##   - 右上：**僵尸卡槽**（六格，反转 —— 脑子计数在右面）。
##     它由**僵尸卡模组**装（见 `mods_builtin/zombie_card/zombie_card_pvp_wiring.gd`，
##     本模组声明了对它的依赖）：本关的 `game_mode` 是 `ChooseLevelPlayerBattle`，
##     僵尸卡模组认这一条就在右上装槽，并在选卡阶段贴一条选僵尸卡面板
##     （植物待选区右面，一行五张）；一张都没选就发默认六张兜底。
##
## 还没做的（对战逻辑）：双方的胜负 / 脑子收入 / 放置限制 ——
## 现在两边都能点卡动手（植物种植、僵尸放到草坪任意格），打完没有结果。
##
## ⚠️ **胜利条件 = 关卡流程跑完**（见 LevelTimelineManager._run_level_script）：
## 流程一跑完就强制判胜弹奖杯。所以这一关的流程**不能跑完** ——
## 挂在一个轮询上：玩家从主菜单按钮退出本关时主游戏被释放，下一拍就自己收尾。

func _init() -> void:
	## 存档键：玩家对战（模式 106）+ 第 0 页 + 第 1 关 = "106_0_0001"
	save_key = "106_0_0001"
	## 白天的前院（默认值就是前院白天，这里写死是为了以后换地图好改）
	game_sences = MainSceneRegistry.MainScenes.MainGameFront
	game_BG = ConstLevelData.GameBg.FrontDay
	## 空关卡：不出怪、不预览僵尸（相机照样拉到预览位 —— 那里没有僵尸可看）
	monster_mode = ConstLevelData.E_MonsterMode.Null
	look_show_zombie = false
	## 出战卡槽：**一个 12 格的槽**（看似左右两条银行，存储是一份）——
	## 前 6 格植物卡（走正常选卡，花阳光）、后 6 格僵尸 / 僵王卡（僵尸卡模组装的
	## 选卡面板选进来，花脑子）；分块与分池的配置由僵尸卡模组的接线装
	## （见 zombie_card_pvp_wiring.gd）。不随存档卡槽数变。
	card_mode = ConstLevelData.E_CardMode.Norm
	can_choosed_card = true
	max_choosed_card_num = 12
	## 铲子先收掉：会顶进右边僵尸那半槽里（对战逻辑做完再定铲子归谁）
	is_shovel = false
	## 与正常关卡同一套开场红字
	is_show_ready_set_plant = true
	## 相机初始位不配（留 NAN 默认）：进关停在背景最左侧（拍到房子），
	## 由 run_flow 里的 show_zombie() 拉到预览位再归位


## 本关流程：与正常关卡同一套开场 → 放开玩家的手 → 提示一句 → 一直等着
##
## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## ⚠️ 结尾**不调 start_battle()**：本关 monster_mode = Null、没有波次，
##    开战事件可能当场判「打完了」→ 流程跑完就强制判胜弹奖杯 —— 所以停在轮询上等玩家退出。
func run_flow(mg: MainGameManager) -> void:
	## 展示（相机从最左拉到预览位）：本关没有出怪表，预览位只有相机平移、没有僵尸
	await show_zombie()
	## 选卡：等玩家点「开始战斗！」（相机归位在选卡收尾 choose_card_finish 里做）
	await choose_card()
	## 初始化小推车（正常关卡也是排在归位与红字之间）
	await init_lawn_mover()
	## 「准备…安放…植物」红字
	await ready_set_plant()
	## 放开玩家的手：推进到主游戏（卡槽挪进 HUD、能种植 / 放僵尸）——不开战、不出怪
	await allow_operation()
	## 屏幕下方提示一句：卡槽已就位，对战逻辑还在开发中
	await hint("玩家对战：白天 —— 左植物 / 右僵尸卡槽已就位，对战逻辑还在开发中")
	## 一直等着：这一关没有结束条件，流程不能跑完（跑完就强制判胜弹奖杯）
	while is_instance_valid(mg):
		await wait(1.0)
