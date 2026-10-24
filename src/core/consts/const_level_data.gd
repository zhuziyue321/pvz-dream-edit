extends RefCounted
class_name ConstLevelData

#region 游戏背景
## 游戏场景
## 下标与 MainGameHome.door_downs / door_masks 的数组下标一一对应（新增背景必须同步扩那两个数组）
enum GameBg {
	FrontDay,
	FrontNight,
	Pool,
	Fog,
	Roof,
	Boss, ## 夜屋顶(僵王关 5-10：屋顶几何 + 夜色底图,原版第 6 个场景 Night Roof)
	MoonRoof, ## 月夜屋顶(DLC 版第 6 章 Moon：屋顶几何 + 月夜底图,见 docs/参考存档/地图实现.md §2.3.3)
	Woods, ## 郊外营地(DLC 版第 7 章 Woods：前院几何 + 森林营地底图,见 docs/参考存档/地图实现.md §2.3.3)
}

## 背景图**路径**（加载与缓存交给 AssetRegistry，见 get_game_bg_texture）
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Night_Roof —— 僵王关所在场景是独立的
## 「Night Roof(夜屋顶)」,与白天 Roof 是同一张屋顶、只是夜色底图,故单独一张 background6boss)
const GameBgTextureMap: Dictionary = {
	GameBg.FrontDay: "res://pak/images/background1.jpg",
	GameBg.FrontNight: "res://pak/images/background2.jpg",
	GameBg.Pool: "res://pak/images/background3.jpg",
	GameBg.Fog: "res://pak/images/background4.jpg",
	GameBg.Roof: "res://pak/images/background5.jpg",
	GameBg.Boss: "res://pak/images/background6boss.jpg",
	## 月夜屋顶（Moon）的**常驻**外观是月夜那幅，与僵王关同一张 —— DLC 的
	## `background6moon.png`（紫红夜空，id BACKGROUND_BLOODMOON）是**血月专用**的，
	## 由 `main_game_bg_moonroof.gd` 在血月期间换上来，平时不能拿它当底图
	## （否则玩家一进关就是紫红一片，视觉上像是血月已经开了）
	GameBg.MoonRoof: "res://pak/images/background6boss.jpg",
	GameBg.Woods: "res://pak/images/background7woods.png",
}

## 取某张背景的贴图（没登记返回 null，调用方判空）
static func get_game_bg_texture(bg: GameBg) -> Texture2D:
	var path: String = GameBgTextureMap.get(bg, "")
	if path == "":
		return null
	return AssetRegistry.get_texture(path)
#endregion

#region 音乐
## 音乐
## 曲目与原版关卡的对应关系见 https://plantsvszombies.wiki.gg/wiki/Music_(PvZ)?action=raw
enum GameBGM {
	FrontDay,	## Grasswalk(白天)
	FrontNight,	## Moongrains(夜晚)
	Pool,		## Watery Graves(泳池)
	Fog,		## Rigor Mormist(浓雾)
	Roof,		## Graze The Roof(屋顶)
	MiniGame,	## Loonboon(小游戏,以及冒险 1-5 / 2-5 / 3-5 / 5-5 特殊关)
	Boss,		## Brainiac Maniac(僵王关 5-10)
	Puzzle,		## Cerebrawl(解谜,以及冒险 4-5)
	UltimateBattle,	## Ultimate Battle(冒险 1-10 / 2-10 / 3-10 传送带关)
	NoBGM,			## 无背景音乐(冒险 4-10 不播 BGM,见 docs/参考存档/特殊关卡.md「特殊关音乐」)
	Moon,			## Harvest Moon(DLC 版月夜屋顶章曲,作者 MisterKaze;见 docs/参考存档/地图实现.md §2.3.3)
	Woods,			## Woody Tombstones(DLC 版郊外营地章曲,作者 Tamir Monteagudo & Andreko;见 docs/参考存档/地图实现.md §2.3.3)
}

## BGM 资源路径
const GameBGMMap: Dictionary[GameBGM, String] = {
	GameBGM.FrontDay: "res://assets_custom/audio/BGM/grasswalk.mp3",
	GameBGM.FrontNight: "res://assets_custom/audio/BGM/moongrains.mp3",
	GameBGM.Pool: "res://assets_custom/audio/BGM/watery_graves.mp3",
	GameBGM.Fog: "res://assets_custom/audio/BGM/rigor_mormist.mp3",
	GameBGM.Roof: "res://assets_custom/audio/BGM/graze_the_roof.mp3",
	GameBGM.MiniGame: "res://assets_custom/audio/BGM/loonboon.mp3",
	GameBGM.Boss: "res://assets_custom/audio/BGM/brainiac_maniac.mp3",
	GameBGM.Puzzle: "res://assets_custom/audio/BGM/cerebrawl.mp3",
	GameBGM.UltimateBattle: "res://assets_custom/audio/BGM/ultimate_battle.mp3",
	GameBGM.NoBGM: "",
	GameBGM.Moon: "res://assets_custom/audio/BGM/harvest_moon.ogg",
	GameBGM.Woods: "res://assets_custom/audio/BGM/woody_tombstones.ogg",
}
#endregion

#region 出怪
## 出怪模式
enum E_MonsterMode {
	Null, ## 不出怪，测试使用
	Norm, ## 正常出怪模式
	HammerZombie, ## 锤僵尸出怪模式
}

## 生存模式难度（原版 Challenge::InitZombieWaves 的生存分支按档位决定出怪与旗数）
## ⚠️ 只描述「出怪规则」，旗数/轮次仍由关卡脚本的 game_round + 每轮波数给出：
##   Normal  = 5 旗（每 stage 10 波，一 stage 一旗）
##   Hard    = 10 旗（每 stage 20 波，一 stage 两旗）
##   Endless = 无限 stage（game_round 写 -1）
enum E_SurvivalDifficulty {
	None, ## 不是生存模式
	Normal, ## 普通：5 旗
	Hard, ## 困难：10 旗
	Endless, ## 无尽：泳池地图，轮次无上限
}

## 波次「基础点数」公式（原版 `Board::PickZombieWaves()` 的四条分支，Board.cpp:633-649）
## 波次战力上限 = 基础点数 × zombie_multy（大波再 ×2.5）。
## 本仓库 `curr_wave` 是**跨阶段累计**的下标且每阶段波数固定，原版按阶段展开的两条
## 公式可化简（推导见 `ZombieWaveCreateManager.calculate_base_wave_points()`）：
##   Norm      —— `波/3+1`（默认）；二周目冒险自动升档 `波*2/5+1`（1-5 例外）
##   LastStand —— 坚不可摧：原版 `(阶段*10 + 波 + 10)*2/5+1` → 化简 `(波+10)*2/5+1`
##   Survival  —— 生存：原版只有 `mSurvivalStage > 0` 才走 `(阶段*每阶段波数 + 波)*2/5+1`
##                → 化简 `波*2/5+1`；第 1 轮落 Norm 分支（与原版一致）
enum E_WavePointsFormula {
	Norm,
	LastStand,
	Survival,
}
#endregion

#region 卡槽
## 卡槽模式
enum E_CardMode {
	Null, ## 没有卡槽（罐子模式：卡片全从罐子里开出）
	Norm, ## 常规卡槽：出战卡由选卡决定
	ConveyorBelt, ## 只有传送带：出战卡由传送带按权重发，玩家不选卡
	Both, ## 卡槽 + 传送带同时出现（卡槽在上、传送带在下）：卡槽走选卡，传送带按权重补卡
}
#endregion

#region 罐子
## 罐子的生成模式（**关卡级**：这一关的罐子怎么摆）
## ⚠️ 名字和 `ScaryPot.E_PotType` 撞车，但**两者不是一回事**（U-11）：
## 本枚举是说「罐子里装什么由谁决定」（写死在关卡资源 / 随机），
## `E_PotType` 是说「某一个罐子里装的是植物还是僵尸」。改名前先看清你在改哪一个。
enum E_PotMode {
	Null, ## 无
	Fixd, ## 固定生成，随机位置（罐子里装什么写死在关卡资源里）
}
#endregion

#region 关卡流程
## **关卡流程 = 关卡脚本的 run_flow()**（见 LevelScriptBase）：一段顺序结构的程序，
## `await` 一个流程方法（`show_zombie` / `choose_card` / `start_battle` …）才走下一步。
## 流程方法的实现是**一种步骤 = 一个脚本**（见 ResourceLevelTimelineEvent，脚本都在
## `level/script/timeline_event/`）：脚本自己 `@export` 的字段就是这一步的参数。
## 这里不维护「步骤类型」枚举：加一种步骤 = 新建一个脚本，参数只属于它自己。
#endregion
