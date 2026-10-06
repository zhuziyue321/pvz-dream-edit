extends SceneSettingBase
## 泳池·浓雾（冒险 4-1 ~ 4-10、生存浓雾）：草坪几何与泳池关完全相同（仍是 map_pool.tres），
## 差别只在场景表现：后院夜晚 + 浓雾覆盖。
## 数据来源：docs/参考存档/关卡数据与出怪表.md「第四大关（浓雾 4-1 ~ 4-10）」
## 雨 / 闪电不是本场景的东西：冒险 4-10 的雷雨夜由关卡脚本自己加 is_rain / is_lightning


func _init() -> void:
	display_name = "泳池·浓雾"
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_BG = ConstLevelData.GameBg.Fog
	game_BGM = ConstLevelData.GameBGM.Fog
	is_fog = true
	is_day = false
	is_day_sun = false
