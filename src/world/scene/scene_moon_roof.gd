extends SceneSettingBase
## 月夜屋顶（DLC 版《植物大战僵尸 DLC Edition》第 6 章 Moon）：与屋顶共用同一套几何
## （map_roof / map_moonroof），只是月夜底图 + Harvest Moon 曲。
## 机制口径（DLC 官方维基 pvz-dlc-edition.fandom.com/wiki/Moon）：
## 是「Night + Roof」的混合场景 —— 夜晚不掉阳光（Moon 章五项难点之一就是 lack of sun）、
## 屋顶斜面、必须用花盆种植；旗间会触发血月事件（僵尸大幅加速，属关卡级玩法，暂未移植）。
## 注意：场景只管背景 / BGM / 昼夜；要用月夜屋顶几何的关卡还需自己指定
## `map_data = preload("res://data/map/map_moonroof.tres")`（月夜底图与房门遮罩在那张图的背景子场景里）。


func _init() -> void:
	display_name = "月夜屋顶"
	game_sences = MainSceneRegistry.MainScenes.MainGameRoof
	game_BG = ConstLevelData.GameBg.MoonRoof
	game_BGM = ConstLevelData.GameBGM.Moon
	is_day = false
	is_day_sun = false
	is_blood_moon = true
