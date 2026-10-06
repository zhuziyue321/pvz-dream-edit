extends LevelScriptBase
## minigame_04_seed_rain —— 原版迷你游戏**第 4 关**「种子雨」(It's Raining Seeds)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## ⚠️ 存档键沿用改名之前写死的值（102_0_0004），**不跟着序号改**：改了会让玩家已通关的记录错位。
##
## 天降种子卡（原版「种子雨」）是**本关专属玩法**：发卡器由本关自己建、自己起停
## （见 _start_seed_rain() / _pause_seed_rain()），通用卡牌管理器只提供
## `create_temp_card()` / `add_card_front_node()` 这类不带玩法判断的接口，不认识种子雨。

## 天降种子卡的发卡器：按定时器生成临时卡片（通用卡槽，参数由关卡数据喂进去）
const SEED_RAIN_SLOT := preload("res://src/ui/card/card_slot/card_slot_seed_rain.tscn")

## 运行期：本关的天降种子卡槽（多轮关卡每轮都跑一遍 run_flow，卡槽只建一次）
var seed_rain_slot: CardSlotSeedRain


func _init() -> void:
	save_key = "102_0_0004"
	## 场景：泳池·浓雾 —— 槽位 / 底图 / BGM / 雾 / 昼夜 / 天降阳光全由场景脚本给出
	scene_name = SceneSettingRegistry.SCENE_FOG
	## 覆盖场景默认：本关（种子雨）在原版是雨天
	is_rain = true
	can_choosed_card = false
	zombie_multy = 4
	card_mode = ConstLevelData.E_CardMode.Null
	is_seed_rain = true
	seed_rain_weights = ResourceCardWeight.create_plant_weights({
	1: 2,
	3: 1,
	4: 2,
	6: 2,
	8: 2,
	17: 8,
	18: 1,
	19: 2,
	21: 1,
	23: 2,
	26: 1,
	28: 2,
	44: 1
	})
	seed_rain_order = ResourceCardReference.create_plant_order({
	0: 17,
	5: 44
	})


func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z009Jackson,
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z004PoleVaulter,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z007ScreenDoor,
		CharacterRegistry.ZombieType.Z008Football,
		CharacterRegistry.ZombieType.Z016Jackbox,
		CharacterRegistry.ZombieType.Z015Dolphinrider,
		CharacterRegistry.ZombieType.Z004PoleVaulter,
	]

	## 展示僵尸
	await show_zombie(zombie_list)
	## 不选卡时相机停留
	await wait(3.0)
	## 相机归位
	await camera_back()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 天降种子卡：本关专属，开战起、打完停
	_start_seed_rain(mg)
	## 开战
	await start_battle(-1, zombie_list)
	_pause_seed_rain()


## 建好天降种子卡的发卡器并开始发卡
## 卡槽挂到卡片前景层（临时卡片也在那一层，见 CardManager.create_temp_card），
## 出卡节奏 / 出哪些卡全在卡槽自己身上：概率与固定顺序取自本关的关卡数据字段
func _start_seed_rain(mg: MainGameManager) -> void:
	if not is_instance_valid(seed_rain_slot):
		seed_rain_slot = SEED_RAIN_SLOT.instantiate()
		mg.card_manager.add_card_front_node(seed_rain_slot)
		seed_rain_slot.init_card_slot_seed_rain(mg.game_para)
	seed_rain_slot.start_seed_rain()


## 停发卡：一段打完（切轮摆场 / 结算）不再天降种子卡
func _pause_seed_rain() -> void:
	if is_instance_valid(seed_rain_slot):
		seed_rain_slot.pause_seed_rain()
