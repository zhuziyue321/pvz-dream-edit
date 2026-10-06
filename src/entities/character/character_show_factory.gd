extends RefCounted
class_name CharacterShowFactory
## 展示态（IsShow）角色的统一创建入口
##
## 图鉴、关卡开局预览、种子包、僵尸水族馆里的角色只用来「看」，不参与战斗，
## 创建流程完全一致：注册表取场景 -> instantiate -> init_plant/init_zombie -> add_child -> 摆位置。
## 这段原本在 5 个脚本里各写一份（图鉴植物 / 图鉴僵尸 / 开局预览僵尸 / 种子包 / 水族馆），
## 其中种子包还漏掉了 init_plant、直接改字段靠 _ready 兜底，与其余四处口径不一致。
## 现在一律走这里。
##
## 注意：本文件只管「展示态」。出战角色仍走
##   PlantCell.create_plant()             植物，见 src/items/plant_cell.gd
##   ZombieManager.create_norm_zombie()   僵尸，见 src/managers/zombie_manager/zombie_manager.gd
## 两条路子的差别不在「怎么创建」，而在创建完之后要不要登记到战场（连信号 / 进数组 / 计数量）。

## 创建展示态植物
## [parent] 挂靠的父节点
## [pos] 挂上去之后的局部坐标，Vector2.ZERO = 交给父节点布局（种子包这类由容器决定）
## [extra_para] 额外初始化参数，会覆盖默认的 CharacterInitType
static func create_show_plant(
	plant_type:CharacterRegistry.PlantType,
	parent:Node,
	pos:Vector2 = Vector2.ZERO,
	extra_para:Dictionary = {}
) -> Plant000Base:
	var plant_scene:PackedScene = Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	if plant_scene == null:
		Log.error("展示态植物：取不到 [%s] 的植物场景" % str(plant_type))
		return null
	var plant:Plant000Base = plant_scene.instantiate()
	var init_para:Dictionary = {
		Plant000Base.E_PInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsShow
	}
	init_para.merge(extra_para, true)
	## 必须在 add_child 之前初始化：init 参数决定 _ready 走哪条分支（见 Plant000Base.init_plant）
	plant.init_plant(init_para)
	parent.add_child(plant)
	plant.position = pos
	return plant


## 创建展示态僵尸（参数含义同 create_show_plant）
static func create_show_zombie(
	zombie_type:CharacterRegistry.ZombieType,
	parent:Node,
	pos:Vector2 = Vector2.ZERO,
	extra_para:Dictionary = {}
) -> Zombie000Base:
	var zombie_scene:PackedScene = Global.character_registry.get_zombie_info(
		zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieScenes)
	if zombie_scene == null:
		Log.error("展示态僵尸：取不到 [%s] 的僵尸场景" % str(zombie_type))
		return null
	var zombie:Zombie000Base = zombie_scene.instantiate()
	var init_para:Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsShow
	}
	init_para.merge(extra_para, true)
	zombie.init_zombie(init_para)
	parent.add_child(zombie)
	zombie.position = pos
	return zombie
