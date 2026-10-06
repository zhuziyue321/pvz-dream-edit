extends Node2D
class_name ZombiePlantComponent
## 植物僵尸的「头顶植物」组件（原版 ZomBotany）
##
## 只负责**表现与耐久反馈**两件事，攻击行为由各自的攻击组件负责：
##   1. 按 ZomBotanyConfig 在僵尸头顶（Body/BodyCorrect 下）拼出那棵植物；
##   2. 头顶植物的耐久挂在僵尸的**一类防具血量**上（场景里配 `HpComponent.max_hp_armor1`），
##      防具被打掉 = 植物被打掉，这时把植物节点隐藏 —— 僵尸变回普通僵尸（原版行为）。
##
## 为什么耐久走一类防具而不是自己存一份：
##   伤害结算（先防具后本体）与血条显示都在 HpComponent 里，自己再存一份会和它各演化各的（K-01）。

## 头顶植物节点（运行时创建，挂在 Body/BodyCorrect 下）
var plant_head: Node2D
## 本只植物僵尸的数据（不是植物僵尸时为空）
var zom_botany_info: ZomBotanyConfig.ZomBotanyInfo


func _ready() -> void:
	if not (owner is Zombie000Base):
		Log.error("ZombiePlantComponent 只能挂在僵尸上，当前 owner：" + str(owner))
		return
	var zombie: Zombie000Base = owner
	zom_botany_info = ZomBotanyConfig.get_info(zombie.zombie_type)
	if zom_botany_info == null:
		Log.error("僵尸 " + str(zombie.zombie_type) + " 不是已配置的植物僵尸，头顶植物组件空转")
		return
	_create_plant_head()
	## 头顶植物被打掉（一类防具血量归零）后隐藏植物
	## ⚠️ 不能在这里直接连：owner 的 @onready（hp_component）在本组件之后才赋值
	## （Godot 先跑子节点 _ready 再跑父节点），此刻它是 null，`is_instance_valid` 判空直接跳过，
	## 连接**静默失败** —— 表现是「头顶植物怎么打都打不掉，僵尸到死都顶着它」
	## （静态探针查不出来，只有进关卡打一下才发现）
	if owner.is_node_ready():
		_connect_plant_head_broken()
	else:
		owner.ready.connect(_connect_plant_head_broken)


## 连「头顶植物被打掉」的信号（必须等 owner ready 完，hp_component 才已赋值）
func _connect_plant_head_broken() -> void:
	var zombie := owner as Zombie000Base
	if zombie == null:
		return
	if not is_instance_valid(zombie.hp_component):
		Log.error("植物僵尸拿不到 HpComponent，头顶植物不会在打掉后消失")
		return
	if zombie.hp_component.signal_armor1_death.is_connected(_on_plant_head_broken):
		return
	zombie.hp_component.signal_armor1_death.connect(_on_plant_head_broken)


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


## 头顶植物被打掉：僵尸变回普通僵尸（只影响外观，血量已经在 HpComponent 里结算完）
func _on_plant_head_broken() -> void:
	if not is_instance_valid(plant_head):
		return
	plant_head.visible = false
