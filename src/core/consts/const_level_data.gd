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
}

## 背景图
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Night_Roof —— 僵王关所在场景是独立的
## 「Night Roof(夜屋顶)」,与白天 Roof 是同一张屋顶、只是夜色底图,故单独一张 background6boss)
const GameBgTextureMap: Dictionary = {
	GameBg.FrontDay: preload("res://assets/image/background/background1.jpg"),
	GameBg.FrontNight: preload("res://assets/image/background/background2.jpg"),
	GameBg.Pool: preload("res://assets/image/background/background3.jpg"),
	GameBg.Fog: preload("res://assets/image/background/background4.jpg"),
	GameBg.Roof: preload("res://assets/image/background/background5.jpg"),
	GameBg.Boss: preload("res://assets/image/background/background6boss.jpg"),
}
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
}

## BGM 资源路径
const GameBGMMap: Dictionary[GameBGM, String] = {
	GameBGM.FrontDay: "res://assets/audio/BGM/grasswalk.mp3",
	GameBGM.FrontNight: "res://assets/audio/BGM/moongrains.mp3",
	GameBGM.Pool: "res://assets/audio/BGM/watery_graves.mp3",
	GameBGM.Fog: "res://assets/audio/BGM/rigor_mormist.mp3",
	GameBGM.Roof: "res://assets/audio/BGM/graze_the_roof.mp3",
	GameBGM.MiniGame: "res://assets/audio/BGM/loonboon.mp3",
	GameBGM.Boss: "res://assets/audio/BGM/brainiac_maniac.mp3",
	GameBGM.Puzzle: "res://assets/audio/BGM/cerebrawl.mp3",
	GameBGM.UltimateBattle: "res://assets/audio/BGM/ultimate_battle.mp3",
	GameBGM.NoBGM: "",
}
#endregion

#region 出怪
## 出怪模式
enum E_MonsterMode {
	Null, ## 不出怪，测试使用
	Norm, ## 正常出怪模式
	HammerZombie, ## 锤僵尸出怪模式
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
## 罐子的生成模式
enum E_PotMode {
	Null, ## 无
	Fixd, ## 固定生成，随机位置（罐子里装什么写死在关卡资源里）
}
#endregion

#region 关卡时间轴
## 关卡时间轴的事件类型（见 ResourceLevelTimelineData / LevelTimelineManager）
## 关卡流程 = 一条时间轴：按数组顺序执行，**上一个事件结束才开下一个**。
## 关卡资源 ResourceLevelData.timeline 留空时，按关卡现有开关生成等价默认时间轴，
## 所以老关卡不改数据也照旧跑；要改流程就配一条自己的时间轴。
## 关卡时间轴的「事件类型」这里不再维护：一种事件 = 一个脚本（见 ResourceLevelTimelineEvent），
## 事件是什么、叫什么由那个脚本自己决定，调试看脚本类名 / 事件上的 note。
#endregion
