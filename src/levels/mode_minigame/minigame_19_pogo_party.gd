extends LevelScriptBase
## minigame_19_pogo_party —— 原版迷你游戏**第 19 关**「蹦蹦舞会」(Pogo Party)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## 原版口径（**三面旗帜的屋顶关，除旗帜波外全是蹦蹦僵尸**）：Roof / Three flags / Choice
##   数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Pogo_Party)
##
## 本关的「原版味」全在下表这五条，逐条对应下面的字段：
##   ① 三面旗帜 = 30 波 → start_battle(30, ...)
##   ② 除旗帜波以外，出怪**只有蹦蹦僵尸** → zombie_list 里只写 Z019Pogo
##      （旗帜波由 ZombieWaveCreateManager 自己补旗帜僵尸 + 普僵，与原版一致）
##   ③ 屋顶 → 先给左侧 1~4 列摆好花盆（"Levels with pre-placed plants"，与其它屋顶关同一套写法）
##   ④ 原版本关播屋顶曲「Graze the Roof」（原版仅它与被取消的 High Gravity 用）→ game_BGM = Roof
##      「哪几关迷你游戏不播通用小游戏曲」见 docs/参考存档/特殊关卡.md「迷你游戏音乐」
##   ⑤ 开局到第一波有**约 55 秒**的超长准备期（原版 Trivia，与「全面冻结」同源）
##
## zombie_multy = 4 不是随便取的数：波次战力上限 = int(波数/3 + 1) * zombie_multy，
## 而蹦蹦僵尸的战力正好是 4 → 非旗帜波的战力预算刚好是**整数只**蹦蹦僵尸，
## 凑不出不足 4 点的「余额」去补普僵，于是非旗帜波真能做到「一只别的僵尸都没有」。


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0017"
	game_sences = MainSceneRegistry.MainScenes.MainGameRoof
	game_BG = ConstLevelData.GameBg.Roof
	## 原版本关播屋顶曲 Graze the Roof，不是通用小游戏曲
	game_BGM = ConstLevelData.GameBGM.Roof
	zombie_multy = 4
	## 原版「蹦蹦舞会 / 全面冻结」共有的超长开场：摆完植物要等约 55 秒才来第一波
	first_wave_delay = 55.0


func run_flow(_mg: MainGameManager) -> void:
	## 屋顶要花盆才能种：先给左侧 4 列铺上（与 survival_flag_05_roof 同一套写法）
	await plant_flower_pot_columns(4)
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	## 原版除旗帜波外**全是蹦蹦僵尸**，所以这里只有一种 —— 预览僵尸也是清一色蹦蹦
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z019Pogo,
	]

	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战（原版 3 面旗帜 = 30 波）
	await start_battle(30, zombie_list)
