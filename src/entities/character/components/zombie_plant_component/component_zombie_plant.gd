extends ComponentNormBase
class_name ZombiePlantComponent
## 植物僵尸的「替代僵尸头的那颗植物」组件（原版 ZomBotany）
##
## 为什么继承 ComponentNormBase 而不是裸 Node2D（两者都是 Node2D，场景不用改）：
## 本组件此前是唯一一个「名字叫 Component、放在 components/ 下，却不进组件体系」的组件 ——
## 它自己重写 `_ready()`，于是拿不到框架统一的两件事：
##   ① `is_enable_default`（场景里关掉组件是否真的生效）—— 子类重写 `_ready()` 漏写 super 就会静默失效；
##   ② `component_ready()` 这个生命周期入口 —— 别处查「组件初始化写在哪」时它不在。
## 代价为零：ComponentNormBase 本身就是 Node2D，14 个僵尸场景里的 `type="Node2D"` 不用动。
##
## 只负责**用植物的头把僵尸自己的头换掉**这一件事，攻击行为由各自的攻击组件负责：
##   · 僵尸原本的头（`Anim_head1` 贴图 + 下巴 / 舌头 / 胡子 / 头发）不再绘制；
##   · 按 ZomBotanyConfig 在僵尸**头节点的位置**拼出那颗植物的头 —— 挂在僵尸头节点**下面**，
##     所以它跟着僵尸的走路 / 啃咬动画一起动，而不是钉死在身体上；
##   · 绘制层级沿用僵尸自己的头那一层（`Anim_head1` 在 `BodyCorrect` 里的兄弟次序），
##     不会被脖子 / 身体盖住，也不会盖住它们。
##
## 那颗植物的**耐久**是挂在僵尸身上的 `ArmorComponentPlantHead`（一类防具）的血量，
## 打光了由那个防具组件把植物藏起来（见 `component_armor_plant_head.gd`）—— 本组件不碰耐久。
##
## 为什么耐久走防具而不是自己存一份：
##   伤害结算（先防具后本体）与血条显示都在 HpComponent 里，自己再存一份会和它各演化各的（K-01）。

## 僵尸自己的头（被植物取代的就是它）
## 注意是 `Anim_head`（容器）/ `Anim_head1`（承头贴图的 Sprite2D）两层 ——
## `Anim_head` 本身不能隐藏（植物就挂在它下面），也不能只改 `Anim_head1.visible`（动画会还原）
const C_ZOMBIE_HEAD_PATH := ^"Anim_head/Anim_head1"
## 僵尸脸上跟着一起没的部件（**外层**容器：动画只驱动它们内层的 visible，
## 隐藏外层不会被动画还原 —— 见 `resource_body_change.gd` 里「掉头」用的同一套路径）
const C_ZOMBIE_FACE_PATHS: Array[NodePath] = [
	^"Anim_head2",			## 下巴
	^"Anim_tongue",			## 舌头
	^"Zombie_mustache",		## 胡子
	^"Anim_hair",			## 头发
]

## 植物头节点（运行时创建，挂在僵尸头节点下）
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
		Log.error("僵尸 " + str(zombie.zombie_type) + " 不是已配置的植物僵尸，换头组件空转")
		return
	## 组件比宿主先 `_ready()`（Godot 先子后父），而宿主的 `ready_norm()` 里还有一步随机外观
	## （`Zombie001Norm._random_sprit_appear()` 会把舌头 / 头发随机设成 visible）——
	## 在这里直接隐藏**会被它盖掉**。所以等宿主整个 `_ready()` 走完再换头。
	if owner.is_node_ready():
		_replace_zombie_head()
	else:
		owner.ready.connect(_replace_zombie_head, CONNECT_ONE_SHOT)


## 用植物的头把僵尸自己的头换掉
func _replace_zombie_head() -> void:
	var body_correct := owner.get_node_or_null(^"Body/BodyCorrect") as Node2D
	if not is_instance_valid(body_correct):
		Log.error("植物僵尸找不到 Body/BodyCorrect，换头无法进行")
		return
	var zombie_head := body_correct.get_node_or_null(C_ZOMBIE_HEAD_PATH) as Sprite2D
	if not is_instance_valid(zombie_head):
		Log.error("植物僵尸找不到僵尸头节点 Body/BodyCorrect/" + str(C_ZOMBIE_HEAD_PATH) + "，换头无法进行")
		return
	_hide_zombie_head(zombie_head, body_correct)
	_create_plant_head(zombie_head)


## 让僵尸自己的头不再绘制
##
## 头贴图用 `self_modulate` 的 alpha 关掉，**不是** `visible = false`，两个原因：
##   1. 动画里有 `Anim_head/Anim_head1:visible` 这条 track（死亡动画会把它设成 false），
##      改 `visible` 会被动画在下一帧还原；
##   2. `visible` 是**继承**的 —— 植物就挂在这个头节点下面，关掉它等于把植物一起关掉。
## `self_modulate` 只影响本节点自身的绘制，不牵连子节点，也没有动画 track 会覆盖它。
func _hide_zombie_head(zombie_head: Sprite2D, body_correct: Node2D) -> void:
	zombie_head.self_modulate.a = 0.0
	for face_path in C_ZOMBIE_FACE_PATHS:
		var face := body_correct.get_node_or_null(face_path) as Node2D
		if is_instance_valid(face):
			face.visible = false


## 在僵尸头的位置拼出那颗植物的头
##
## 挂点选 `Anim_head1`（僵尸头节点）而不是 `Body/BodyCorrect`：僵尸走路的摇头 / 啃咬的点头
## 都是这条 track 在驱动头节点的 transform，挂在它下面，植物才会跟着一起动（原版就是这么长的）。
func _create_plant_head(zombie_head: Sprite2D) -> void:
	plant_head = Node2D.new()
	plant_head.name = &"PlantHead"
	zombie_head.add_child(plant_head)
	## 头贴图是 `centered = false`：贴图从节点原点画到 size，所以节点原点就是「头的左上角」，
	## 植物原点要落在头贴图的**中心**上，再由配置表做最后几像素的微调
	var head_center := Vector2.ZERO
	if zombie_head.texture != null:
		head_center = zombie_head.texture.get_size() * 0.5
	plant_head.position = head_center + zom_botany_info.head_offset
	## 抵消僵尸头节点自身的缩放与倾斜：植物最终大小 = `head_scale`，静止时是正的。
	## 抵消的是**初始值**，动画随后在头节点上播的摆动照常传下来（头摇，植物跟着摇）。
	plant_head.rotation = -zombie_head.rotation
	plant_head.scale = Vector2.ONE * (zom_botany_info.head_scale / maxf(absf(zombie_head.scale.x), 0.0001))
	## 左右翻转：植物贴图一律朝右（植物的朝向），而僵尸朝左走（房子在左，豌豆也朝左飞），
	## 不翻的话植物是「背对着」僵尸行进方向长在头上的。翻的是 `plant_head` 的 x 缩放，
	## 各张贴图的 `offset` 会跟着一起镜像，整颗植物就是一张水平镜像图；
	## 位置参数都在上一层（僵尸头节点）坐标系里，不受这次翻转影响。
	plant_head.scale.x *= -1.0
	for sprite_info: ZomBotanyConfig.PlantSprite in zom_botany_info.sprites:
		var sprite := Sprite2D.new()
		sprite.texture = sprite_info.texture
		sprite.position = sprite_info.offset
		sprite.scale = Vector2.ONE * sprite_info.scale
		plant_head.add_child(sprite)
