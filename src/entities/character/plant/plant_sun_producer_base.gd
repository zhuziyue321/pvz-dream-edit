extends Plant000Base
class_name PlantSunProducerBase
## 产阳光植物的公共基类（向日葵 / 双子向日葵）
##
## 为什么要有这一层：`plant_sun_flower.gd` 与 `plant_twin_sun_flower.gd` 原本是
## **两个逐字相同的脚本**（除 `class_name` 外 27 行完全一致），两者真正的差异
## （产阳光节奏 / 单次产量）全在各自场景里 `CreateSunComponent` 的参数上。
## 复制粘贴的代价是「改一处忘另一处」，且新增产阳光植物要再抄一遍。
##
## 新增产阳光植物：`extends PlantSunProducerBase` + 场景里配 `CreateSunComponent` 参数即可。

@onready var create_sun_component: CreateSunComponent = $CreateSunComponent


func ready_norm() -> void:
	super()
	if is_zombie_mode:
		create_sun_component.disable_component(ComponentNormBase.E_IsEnableFactor.GameMode)


## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(create_sun_component.owner_update_speed)


## 被僵尸啃食一次特殊效果,魅惑\大蒜\我是僵尸生产阳光
func _be_zombie_eat_once_special(_attack_zombie:Zombie000Base):
	if is_zombie_mode:
		create_sun_component._on_be_eat_once()


## 植物死亡
func character_death():
	if is_zombie_mode:
		create_sun_component._on_character_death()
	super()
