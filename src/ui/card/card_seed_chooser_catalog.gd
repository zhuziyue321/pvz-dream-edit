extends RefCounted
class_name CardSeedChooserCatalog
## 选卡候选卡池快照（数据层）
##
## ★ 只在卡池变化时重建一次（见 `AllCards.get_seed_chooser_catalog()`），之后**跨关卡复用同一个对象**：
##   换关不再重排顺序、不再逐张查表。进入选卡阶段之前它就已经存在（第一次查询时建好并常驻在 autoload 里）。
##
## 这里只固化「有哪些卡位、按什么顺序排、要不要敌方页」；
## 玩家实际能不能选到哪一张仍由已解锁名单（`GlobalGameState.curr_plant` / `curr_zombie`）
## 在消费侧（`CardSlotCandidate`）点亮时决定 —— 数据层不掺解锁状态。
##
## 存的是 `AllCards` 源目录里的**源卡节点**（autoload 常驻、跨关卡有效），不是副本：
## 副本与待选容器由 `SceneRegistry` 的候选容器池跨关卡复用，见 `docs/参考存档/卡片与选卡流程.md`。

## 植物候选，顺序 = `AllCards.get_plant_types_in_choose_order()`
var plants: Array[Card] = []
## 敌方候选（普通僵尸在前、僵王紧接其后）；没有敌方页时为空
var enemies: Array[Card] = []
## 本快照是否包含敌方页（= 生成时 `GlobalGameState.is_zombie_card_enabled()`）
var has_enemy_page := false
## 生成时的卡池版本；与 `AllCards` 内部版本不一致就整份重建
var version := 0


## 每页能放 [param page_size] 张卡时，[param num_card] 张卡需要几页
func get_page_count(num_card: int, page_size: int) -> int:
	if num_card <= 0 or page_size <= 0:
		return 0
	return ceili(float(num_card) / float(page_size))
