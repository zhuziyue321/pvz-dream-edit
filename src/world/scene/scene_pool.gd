extends SceneSettingBase
## 泳池·白天（冒险 3-1 ~ 3-10、生存泳池）：草坪几何带中间两条水道
## （几何由 data/map/map_pool.tres 决定，这里只给场景信息）


func _init() -> void:
	display_name = "泳池·白天"
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_BG = ConstLevelData.GameBg.Pool
	game_BGM = ConstLevelData.GameBGM.Pool
	## 白天 + 掉阳光用基类默认
