extends SceneSettingBase
## 郊外营地（DLC 版《植物大战僵尸 DLC Edition》第 7 章「Woods / 郊外」）：
## 与白天前院共用同一套网格几何（map_front / map_woods），只是森林营地底图 + Woody Tombstones 曲。
## 机制口径（DLC 官方维基 pvz-dlc-edition.fandom.com/wiki/Woods）：
## 地点是玩家的营地（Player's Camp），在远离房子的郊外野外；白天、天降正常阳光
## （早期版本掉小阳光，Update 2.5 已移除）。特色机制 = 灌木丛（Bush）藏僵尸、
## 割草机撞灌木会爆炸（需商店买 Wood Chipper）、大波时僵尸从灌木里伏击 ——
## 属**关卡级玩法**，暂未移植（见 docs/参考存档/地图实现.md §2.3.3 的待办）。
## 注意：场景只管背景 / BGM / 昼夜；要用郊外几何的关卡还需自己指定
## `map_data = preload("res://data/map/map_woods.tres")`（底图与房门遮罩在那张图的背景子场景里）。


func _init() -> void:
	display_name = "郊外营地"
	game_sences = MainSceneRegistry.MainScenes.MainGameFront
	game_BG = ConstLevelData.GameBg.Woods
	game_BGM = ConstLevelData.GameBGM.Woods
	is_day = true
	is_day_sun = true
