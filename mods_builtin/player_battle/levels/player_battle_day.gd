extends "res://src/levels/core/level_script_base.gd"
## 玩家对战：白天 —— **空关卡**（对战逻辑还没做）
##
## 关卡 = 一个 .gd（属性 + 流程），见 LevelScriptBase。
## 这一关现在只做一件事：把玩家放进白天的前院草坪，然后一直等着 ——
## 没有僵尸、没有波次、也没有结束条件（双方各守一半、互相出怪那套还没写）。
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
	## 空关卡：不出怪、不预览僵尸
	monster_mode = ConstLevelData.E_MonsterMode.Null
	look_show_zombie = false
	## 没有卡槽（这一关还没有对战逻辑，玩家手上没牌可出）
	card_mode = ConstLevelData.E_CardMode.Null
	can_choosed_card = false
	## 不播「准备…安放…植物」红字
	is_show_ready_set_plant = false
	## 进关就停在相机归位位（一进来就看得见整块草坪）
	camera_init_x = MainGameCamera.CAM_POS_ORI.x


## 本关流程：放开玩家的手 → 提示一句 → 一直等着
##
## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
func run_flow(mg: MainGameManager) -> void:
	## 允许操作：推进到主游戏阶段（这一关没有卡也没有僵尸，玩家只能在草坪上走动）
	await allow_operation()
	## 屏幕下方提示一句：这一关还是空的
	await hint("玩家对战：白天 —— 空关卡，对战逻辑还在开发中")
	## 一直等着：这一关没有结束条件，流程不能跑完（跑完就强制判胜弹奖杯）
	while is_instance_valid(mg):
		await wait(1.0)
