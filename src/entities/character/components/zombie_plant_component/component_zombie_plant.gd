extends ComponentNormBase
class_name ZombiePlantComponent
## 植物僵尸的「头顶植物」组件（原版 ZomBotany）
##
## 为什么继承 ComponentNormBase 而不是裸 Node2D（两者都是 Node2D，场景不用改）：
## 本组件此前是唯一一个「名字叫 Component、放在 components/ 下，却不进组件体系」的组件 ——
## 它自己重写 `_ready()`，于是拿不到框架统一的两件事：
##   ① `is_enable_default`（场景里关掉组件是否真的生效）—— 子类重写 `_ready()` 漏写 super 就会静默失效；
##   ② `component_ready()` 这个生命周期入口 —— 别处查「组件初始化写在哪」时它不在。
## 代价为零：ComponentNormBase 本身就是 Node2D，14 个僵尸场景里的 `type="Node2D"` 不用动。
##
## 只负责**拼出头顶那棵植物**这一件事，攻击行为由各自的攻击组件负责：
##   按 ZomBotanyConfig 在僵尸头顶（Body/BodyCorrect 下）拼出那棵植物。
##
## 那棵植物的**耐久**是挂在僵尸身上的 `ArmorComponentPlantHead`（一类防具）的血量，
## 打光了由那个防具组件把植物藏起来（见 `component_armor_plant_head.gd`）—— 本组件不碰耐久。
##
## 为什么耐久走防具而不是自己存一份：
##   伤害结算（先防具后本体）与血条显示都在 HpComponent 里，自己再存一份会和它各演化各的（K-01）。

## 头顶植物节点（运行时创建，挂在 Body/BodyCorrect 下）
var plant_head: Node2D
## 本只植物僵尸的数据（不是植物僵尸时为空）
var zom_botany_info: ZomBotanyConfig.ZomBotanyInfo


## 组件初始化入口（**不是** `_ready()` —— 见硬约束 §1-3 与 ComponentNormBase.component_ready）
func component_ready() -> void:
	super()
	if not (owner is Zombie000Base):
		Log.error("ZombiePlantComponent 只能挂在僵尸上，当前 owner：" + str(owner))
		return
	var zombie: Zombie000Base = owner
	zom_botany_info = ZomBotanyConfig.get_info(zombie.zombie_type)
	if zom_botany_info == null:
		Log.error("僵尸 " + str(zombie.zombie_type) + " 不是已配置的植物僵尸，头顶植物组件空转")
		return
	_create_plant_head()


## 在僵尸头顶拼出那棵植物
func _create_plant_head() -> void:
	var body_correct := owner.get_node_or_null(^"Body/BodyCorrect") as Node2D
	if not is_instance_valid(body_correct):
		Log.error("植物僵尸找不到 Body/BodyCorrect，头顶植物无法显示")
		return
	plant_head = Node2D.new()
	plant_head.name = &"PlantHead"
	plant_head.position = zom_botany_info.head_offset
	plant_head.scale = Vector2.ONE * zom_botany_info.head_scale
	body_correct.add_child(plant_head)
	for sprite_info: ZomBotanyConfig.PlantSprite in zom_botany_info.sprites:
		var sprite := Sprite2D.new()
		sprite.texture = sprite_info.texture
		sprite.position = sprite_info.offset
		sprite.scale = Vector2.ONE * sprite_info.scale
		plant_head.add_child(sprite)
