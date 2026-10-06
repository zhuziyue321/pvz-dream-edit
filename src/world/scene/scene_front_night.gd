extends SceneSettingBase
## 前院·夜晚（冒险 2-1 ~ 2-10、生存夜晚、解谜我是僵尸夜晚关）
## 与原版一致：夜晚有墓碑、蘑菇不睡觉、没有天降阳光（阳光靠阳光菇）


func _init() -> void:
	display_name = "前院·夜晚"
	game_sences = MainSceneRegistry.MainScenes.MainGameFront
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.FrontNight
	is_day = false
	is_day_sun = false
