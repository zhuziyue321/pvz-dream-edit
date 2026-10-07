extends LevelScriptBase
## adventure_04_06 —— 由同目录的 adventure_04_06.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


## 本关开场戴夫对话（戴夫送手套）：台词与手持物在数据层，
## 见 res://data/dave/dialog/adventure_04_06_glove.tres
const DAVE_GLOVE := preload("res://data/dave/dialog/adventure_04_06_glove.tres")


func _init() -> void:
	## 场景：泳池·浓雾 —— 槽位 / 底图 / BGM / 雾 / 昼夜 / 天降阳光全由场景脚本给出
	scene_name = SceneSettingRegistry.SCENE_FOG
	dave_dialog_only_first_playthrough = true
	drop_unlock_wave = 5
	drop_unlock_tip = "解谜模式解锁！可以从主菜单中进入该模式！"


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z018Digger,
	]

	## 关卡戴夫对话：整段是「戴夫送手套」的赠礼演出，手套功能隐藏时不播
	## （见 ConstFeatureSwitch.GLOVE_ENABLED）
	if ConstFeatureSwitch.GLOVE_ENABLED:
		await dave_dialog(DAVE_GLOVE)
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
