extends ArmorComponent
class_name ArmorComponentPlantHead
## 植物僵尸头上那棵植物（它取代了僵尸自己的头）：它的耐久就是本防具的血量（先于本体被扣），
## 打光了就把那棵植物藏起来 —— 僵尸变回一只普通僵尸（原版 ZomBotany 行为）。
##
## 为什么耐久走防具而不是 `ZombiePlantComponent` 自己存一份：
##   伤害结算顺序（先防具后本体）与血条都在 `HpComponentZombie` 里，自己再存一份
##   会和它各演化各的（K-01）。这里只负责"掉了之后把植物藏起来"这一件事。


## 那棵植物被打掉：隐藏它（血量已经在防具里结算完）
func on_armor_break() -> void:
	var plant_component := owner.get_node_or_null(^"ZombiePlantComponent") as ZombiePlantComponent
	if plant_component == null or not is_instance_valid(plant_component.plant_head):
		return
	plant_component.plant_head.visible = false
