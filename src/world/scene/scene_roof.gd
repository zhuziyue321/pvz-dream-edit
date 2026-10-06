extends SceneSettingBase
## 屋顶·白天（冒险 5-1 ~ 5-9、生存屋顶）：斜面地形，裸屋顶上没有花盆就种不下植物
## （花盆由关卡脚本在 run_flow() 开头整列铺，见 docs/工作记录/2026-10-06_屋顶花盆改成run_flow里整列种植.md）


func _init() -> void:
	display_name = "屋顶·白天"
	game_sences = MainSceneRegistry.MainScenes.MainGameRoof
	game_BG = ConstLevelData.GameBg.Roof
	game_BGM = ConstLevelData.GameBGM.Roof
	## 白天 + 掉阳光用基类默认
