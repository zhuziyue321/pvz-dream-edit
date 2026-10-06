extends LevelScriptBase
## minigame_06_invisi_ghoul —— 原版迷你游戏**第 6 关**「隐形战争」(Invisi-ghoul，又译隐形食脑者)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## 玩法：传送带关，所有出战僵尸**本体隐形**。玩家要靠间接线索判断僵尸的位置 / 种类 / 状态：
##   现形手段：寒冰菇的冰冻（ Character000Base.be_ice_freeze ）、玉米投手的黄油（ ZombieButterUtil.be_butter ）
##   行踪线索：僵尸入池的水花（ SwimBoxComponent.appear_splash ，挂在僵尸行上，不受隐形影响）
##             洗冰车的冰道（ IceRoad 挂在背景层）+ 开车音效、海豚骑士 / 玩偶匣的入场音效
##             掉落的防具（ ZombieDropBase 掉落后 reparent 到僵尸行，仍然可见）
##             植物被啃的受伤动画、小推车被触发
## 实现链路：本关 hook `get_zombie_init_para_extra()` → ZombieManager.create_norm_zombie 并进 zombie_init_para
##         → Zombie000Base.init_zombie → ready_norm → Character000Base.update_invisible_show
##         → BodyCharacter.set_invisible
##         （隐形合成进 body.modulate，与受击闪白 / 冰冻染色相乘；不能改 Sprite2D 的 self_modulate，
##           动画资源里每个部件都带 self_modulate 轨道，逐帧写回会被动画盖掉）


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0007"
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_BG = ConstLevelData.GameBg.Pool
	## 场景曲：本关是泳池 → 泳池曲 Watery Graves
	game_BGM = ConstLevelData.GameBGM.Pool
	is_day_sun = false
	## 底图是白天泳池，但要让寒冰菇能直接用（蘑菇不在白天睡觉），故按夜晚处理
	is_day = false
	zombie_multy = 2
	## 传送带：植物由传送带送上来，玩家不选卡（card_mode 会自己把 can_choosed_card 压成 false）
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	## 原版本关传送带只给这 6 种：豌豆射手 / 坚果墙 / 冰蘑菇 / 荷叶 / 窝瓜 / 玉米投手
	## 冰蘑菇和玉米投手是玩家唯一能主动让僵尸现形的两张牌，权重给低一点
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	1: 3,	## 豌豆射手
	4: 3,	## 坚果墙
	15: 1,	## 冰蘑菇：冰冻现形
	17: 2,	## 荷叶：水路才能种
	18: 2,	## 窝瓜
	35: 2,	## 玉米投手：黄油现形
	})


## 本关核心：出战僵尸本体隐形
## 走「僵尸初始化参数」下发（ E_ZInitAttr.IsInvisible 是角色的通用外观项）：
## 一关专属的设定留在关卡脚本里，游戏本体不认识「隐形战争」；
## 预览 / 图鉴的展示僵尸走 IsShow 初始化，不隐形（玩家能看到本关有哪些僵尸）
func get_zombie_init_para_extra() -> Dictionary:
	return {
		Zombie000Base.E_ZInitAttr.IsInvisible: true,
	}


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	## 原版本关的僵尸：普僵 / 路障 / 铁桶 / 铁门 / 潜水 / 洗冰车 / 海豚骑士 / 玩偶匣
	## （洗冰车的冰道与音效、海豚骑士与玩偶匣的入场音效是原版留给玩家的行踪线索）
	## 不写 Z011Duckytube：它在自然刷怪黑名单里（写了也只会被 init_para 滤掉并打 warning），
	## 水面行的鸭子泳圈由两栖僵尸（普僵等）入水时自动套上，见 docs/参考存档/植物僵尸.md §4 坑 2
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z007ScreenDoor,
		CharacterRegistry.ZombieType.Z012Snorkle,
		CharacterRegistry.ZombieType.Z013Zamboni,
		CharacterRegistry.ZombieType.Z015Dolphinrider,
		CharacterRegistry.ZombieType.Z016Jackbox,
	]

	## 展示僵尸（展示僵尸走 IsShow 初始化，不隐形，玩家能看到本关有哪些僵尸）
	await show_zombie(zombie_list)
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(20, zombie_list)
