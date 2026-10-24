extends LevelScriptBase
## adventure_05_05 —— 由同目录的 adventure_05_05.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。
##
## 本关专属玩法「蹦极闪电战」见同目录 adventure_05_05_bungi_blitz.gd：
## 管理器由本脚本在 init_level_items() 里创建，波次进场方式由 create_wave_zombies() 换掉。


## 本关开场戴夫对话：台词在数据层，见 res://data/dave/dialog/adventure_05_05_opening.tres
const DAVE_OPENING := preload("res://data/dave/dialog/adventure_05_05_opening.tres")


#region 蹦极闪电战（本关专属）
## 本关的蹦极闪电战：僵尸全部由蹦极僵尸空投进场，只有 5-5 用得到，所以挂在关卡脚本这一侧
var bungi_blitz: Adventure0505BungiBlitz


## 进关时把空投管理器建起来（格子已建好、玩家还动手不了，见 LevelScriptBase.init_level_items）
func init_level_items(mg: MainGameManager, item_root: Node2D) -> void:
	bungi_blitz = Adventure0505BungiBlitz.new()
	bungi_blitz.name = "BungiBlitz"
	item_root.add_child(bungi_blitz)
	bungi_blitz.init_bungi_blitz(mg.zombie_manager)


## 本波僵尸不从场地边缘走进来，改由空投蹦极僵尸吊进场（清单仍由通用波次按战力算）
func create_wave_zombies(
	create_manager: ZombieWaveCreateManager,
	wave_spawn: Array[StringName],
	wave: int
) -> Array[Zombie000Base]:
	if bungi_blitz == null:
		return create_manager.create_norm_wave_zombies(wave_spawn, wave)
	return bungi_blitz.create_drop_wave_zombies(create_manager, wave_spawn, wave)
#endregion


func _init() -> void:
	save_key = "101_4_0045"
	game_sences = MainSceneRegistry.MainScenes.MainGameRoof
	game_BG = ConstLevelData.GameBg.Roof
	game_BGM = ConstLevelData.GameBGM.Roof
	## 蹦极闪电战:不直接出怪,僵尸全部由蹦极僵尸空投进场;大波另外来偷植物的蹦极僵尸
	## 空投本身是本关专属玩法,写在同目录的 adventure_05_05_bungi_blitz.gd 里,由本脚本创建
	## 传送带补种 花盆/南瓜头/大嘴花/樱桃炸弹
	is_bungi = true
	## 出怪倍率 = 2：原版蹦极闪电战（冒险 5-5，LawnApp::IsBungeeBlitzLevel）的倍率
	## （Board.cpp:683-686）。本关僵尸由蹦极空投进场，但清单仍按战力上限算
	## → 每波空投只数也翻倍。此前漏配 = 默认 1
	zombie_multy = 2
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	&"cherry_bomb": 2,
	&"chomper": 2,
	&"pumpkin": 2,
	&"flower_pot": 2
	})
	## 本关通关掉落：大蒜（种子包）
	level_complete_loot = "garlic_seed_packet"


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	await plant_flower_pot_columns(4)
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[StringName] = [
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.BUCKET,
		ZombieIds.LADDER,
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
	## 首波 2 秒：原版蹦极闪电战 `mZombieCountDown = 200` tick
	await start_battle(20, zombie_list, 0.0, 2.0)
	## 通关掉落：首次通关掉本关奖励（见 _init 里的 level_complete_loot），已通关过只出奖杯
	if is_curr_level_success():
		win_with_trophy_only()
	else:
		await gain(level_complete_loot)
