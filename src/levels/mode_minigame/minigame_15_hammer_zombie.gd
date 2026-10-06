extends LevelScriptBase
## minigame_15_hammer_zombie —— 原版迷你游戏**第 15 关**「打僵尸」(Whack-a-Zombie)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## ⚠️ 存档键沿用改名之前写死的值（102_0_0002），**不跟着序号改**：改了会让玩家已通关的记录错位。
##
## 玩法（原版口径：本关是冒险 2-5「打地鼠」的加强版）：
##   · 草坪上只有 3 张固定出战卡（寒冰菇 / 墓碑吞噬者 / 土豆地雷），玩家不选卡；
##   · 夜不掉阳光，阳光全靠**锤僵尸**掉落：一只僵尸偶尔掉 3 颗 25 阳光（= 75，正好一张寒冰菇 / 墓碑吞噬者）；
##   · 僵尸从**草坪右侧的墓碑**里冒头（不是一个劲儿从右边走进来的那种出怪），越往后冒得越快；
##   · 锤子按防具算数：普通僵尸 1 下、路障 2 下、铁桶 3 下（伤害换算见 component_hp_zombie 的 Hammer 分支）；
##
## **本关的「锤僵尸」玩法由共用规则装配**：见 LevelRuleHammerZombie.install() —— 锤子光标与
## 出怪器都由那条规则装进主游戏，本体不为这个玩法留任何分支（硬约束 §1-8）。
##   · 墓碑吞噬者啃掉墓碑会掉一枚银币（见 tombstone.gd::tombstone_death）；
##   · 前面啃掉的墓碑会长回来，原版撑不到最后一大波就把墓碑清空是不可能的；
##     补到几座由锤僵尸管理器按阶段补（`zm_hammer_zombie_manager.gd`）。
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Whack_a_Zombie)


func _init() -> void:
	save_key = "102_0_0002"
	game_BG = ConstLevelData.GameBg.FrontNight
	## 例外：本关是夜晚场地，原版却播通用小游戏曲 Loonboon（与冒险 2-5 打地鼠同源；用户实机确认）
	game_BGM = ConstLevelData.GameBGM.MiniGame
	is_day = false
	is_day_sun = false
	look_show_zombie = false
	can_choosed_card = false
	## 进关就停在相机归位位（与冒险 2-5 同口径：本关没有预览僵尸 / 选卡，不该先拍房子）
	camera_init_x = MainGameCamera.CAM_POS_ORI.x
	monster_mode = ConstLevelData.E_MonsterMode.HammerZombie
	is_have_tombston = true
	init_tombstone_num = 10
	start_sun = 0
	## 打地鼠小游戏（原版）：出战卡固定 3 张，卡槽数 = 固定卡数
	max_choosed_card_num = 3
	prechosen_cards = ResourceCardReference.create_plant_list([15, 12, 5])
	## 难度参数不在本关另立一套：原版口径是「2-5 的加强版」，而锤僵尸模式只认自己那三个僵尸转速字段
	## （不读普通出怪的 zombie_multy / max_wave），本关沿用 2-5 的默认值：
	##   speed_zombie_init —— 第 1 波僵尸的起身倍率（默认 1.0）
	##   speed_zombie_add —— 每大波加多少（默认 0.15）
	##   speed_zombie_max —— 倍率上限（默认 2.0）
	## 要调更狠就在本关这里给值（或抬 zombie_multy_hammer），别跑去改管理器，免得把 2-5 一起改了。


## 进关时装上「锤僵尸」玩法（与冒险 2-5 共用同一条规则，见 LevelRuleHammerZombie）
func init_level_items(mg: MainGameManager, _item_root: Node2D) -> void:
	LevelRuleHammerZombie.install(mg)


func run_flow(_mg: MainGameManager) -> void:
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	## ⚠️ 这里**不要**给出怪表：锤僵尸出怪模式（`HammerZombieManager`）走自己的僵尸候选
	## （普通 → 第 4 波起加路障 → 第 6 波起加铁桶），正好是原版「1 下 / 2 下 / 3 下」那三种，
	## 关卡数据上的 zombie_refresh_types 在本模式下**不会被读**，写了也只是摆着。
	await start_battle()
