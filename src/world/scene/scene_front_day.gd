extends SceneSettingBase
## 前院·白天（冒险 1-1 ~ 1-10 的白天关、大部分迷你游戏 / 生存白天关）
## 数据来源：PVZ 原版前院白天场景（底图 background1，曲子 Grasswalk）


func _init() -> void:
	display_name = "前院·白天"
	game_sences = MainSceneRegistry.MainScenes.MainGameFront
	game_BG = ConstLevelData.GameBg.FrontDay
	game_BGM = ConstLevelData.GameBGM.FrontDay
	## 白天 + 有雾 / 昼夜 / 天降阳光三项用基类默认（无雾 / 白天 / 掉阳光）
