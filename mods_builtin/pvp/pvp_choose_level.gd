extends "res://src/menus/choose_level/choose_level.gd"
## 多人游戏(PVP)选关界面：**页里一个关卡都没有**（对战逻辑还没做）
##
## 界面由 pvp 模组在 install() 时注入 `MainSceneRegistry.MainScenes.ChooseLevelPvp` 槽位，
## 主菜单木牌上的「MULTIPLAYER」牌按下即进这里。
## 复用本体的选关页基类：返回主菜单、翻页、选关 BGM 都照旧，只是页里不挂任何关卡按钮。
##
## 以后加对局：把「一场对局」当成关卡条目挂进 `AllPage/GridContainer` 即可
## （关卡脚本由 pvp 模组自己提供，本体不认识它们）。

## 本模式没有关卡，也就没有「解锁名额」这回事：一律按全开放算
## （不去查冒险模式的解锁表 —— 这个模式与冒险模式进度无关）
func calc_open_level_num() -> int:
	return -1
