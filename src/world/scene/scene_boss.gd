extends SceneSettingBase
## 夜屋顶（僵王关：冒险 5-10 / 迷你游戏 20）：与白天屋顶共用同一套几何（map_roof / map_boss），
## 只是夜色底图 + 僵王曲。数据来源：PVZ Wiki「Night Roof」
## 见 docs/参考存档/特殊关卡.md 与 test/scenarios/probe_boss_map.gd


func _init() -> void:
	display_name = "夜屋顶·僵王"
	game_sences = MainSceneRegistry.MainScenes.MainGameRoof
	game_BG = ConstLevelData.GameBg.Boss
	game_BGM = ConstLevelData.GameBGM.Boss
	is_day = false
	is_day_sun = false
