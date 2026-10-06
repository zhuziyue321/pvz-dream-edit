extends Zombie021Bungi
## 蹦极空投僵尸（蹦极闪电战专用）
class_name Zombie026BungiDrop

"""
与偷植物的蹦极僵尸（Z021Bungi）共用外形与降落 / 起飞流程，区别有五点：
	1. 没有靶子（靶子只给偷植物用，空投的落点是随机的植物格子）
	2. 每帧画面都相同：降落 / 落地等 / 起飞分别放 Zombie_bungi_drop_static
	   与 Zombie_bungi_raise_static——两者都是原版 Zombie_bungi_raise 的最后一帧
	   （抱着东西的姿态）抽出来的单帧动画，看不出松手之类的过渡；
	   起飞那一个额外保留了 raise_start 方法轨，靠它把投放完的蹦极僵尸撤走
	3. 没有前后摇：进场就开始降落、落地就开始起飞（drop_start_delay / grab_start_delay = 0）
	4. 落地后不是把植物偷走，而是把吊在绳子上的那只僵尸放到场上
	5. 它更像一段投放动画而不是僵尸：受击框全程禁用，不参与任何索敌
	6. 怀里僵尸的运动（这条是核心，其余都围着它转）：把它当成「t=0 时刻凭空生成」的僵尸，
	   空投只是让这次生成看起来合理，所以降落过程（t<0）必须是直上直下的正比例直线，
	   t=0 时横纵坐标都跟「凭空生成」完全重合，落地才不会跳：
	   —— 横向：容器在本体偏右，整体左挪让它对准落点，x 在整段空投里恒定不变
	   —— 纵向：降落终点抬高容器那点高度（landing_offset_y），本体停在半空、
	      绳子末端正好停在地面上，僵尸的脚才落在地面而不是陷进地里
	   —— 没有缓冲：降落 / 起飞的补间都是匀速直线（绝对值函数那样的 V 形）
	7. 本体还要再往上抬 perch_offset_y：同一张静态图压在被吊的僵尸身上不好看，
	   抬高后像是从上方吊下来的；这只挪本体，僵尸的路径完全不受影响
	   还差一点就用导出变量 carry_offset 微调

被吊着的僵尸在落地前禁用受击 / 移动 / 攻击组件、并把速度系数压到 0，落地时才恢复，
这样它不会在半空中被植物打到，也不会站在场上等着，更不会在绳子上迈腿——
下落过程里它应该是一动不动地被吊下来的，只有整只僵尸跟着绳子往下走。

图层：怀里的僵尸要夹在蹦极「身体」与「抱着的手 / 小臂」之间，看着才是被抱住的——
身体留在行内 z（lane*50+30），僵尸 +1，手 / 小臂单独用绝对 z 抬到 +2
（手 / 小臂的节点不挪位置，只改 z；挪了动画轨道就取不到节点了）。
被偷的植物走 BungiContainer（本体最后一个子节点），本来就压在所有部位之上，不动它。

贴图：蹦极自己的贴图（含挂在身上的绳子）整体下移 body_texture_offset_y 像素（默认 10）。
只改 Sprite2D 的贴图偏移，不挪节点——挂点 / 落点都挂在 BungiContainer 上，
挪节点会把怀里的僵尸一起带走，落点也跟着偏 10px。

注意：携带的僵尸本体只跟着绳子改坐标，不改父子关系——
僵尸的动画轨道是按 Body/BodyCorrect/... 取节点的，把 Body 挪走会让它的移动动画失效。
"""

## 被吊着、还没落地的僵尸
var carry_zombie: Zombie000Base
## 携带僵尸本体的原始 transform，落地时原样还原
var carry_body_position := Vector2.ZERO
var carry_body_scale := Vector2.ONE
## 本次空投是否已经放下（防止放下两次）
var is_drop_finish := false
## 怀里僵尸原本的图层，放下后还原
var carry_z_index := 0
## 抱着姿态里被抬到怀里僵尸之上的部位（手 / 小臂），放下后还原
var carry_front_parts: Array[CanvasItem] = []
## 抱姿里要压在怀里僵尸之上的部位：只有「手 + 小臂」，
## 身体 / 大臂 / 腿留在下层，僵尸夹在中间才是被抱住而不是被整只挡住。
## 路径与动画轨道取节点的写法一致（Body/BodyCorrect/...），只改 z，不挪节点
const CARRY_FRONT_PART_PATHS: Array[NodePath] = [
	"Body/BodyCorrect/Zombie_bungi_rightarm_lower2",
	"Body/BodyCorrect/Zombie_bungi_rightarm_hand2",
	"Body/BodyCorrect/Zombie_bungi_leftarm_lower2",
	"Body/BodyCorrect/Zombie_bungi_leftarm_hand2",
]
## 行内 z 偏移（见 docs/参考存档/渲染层级.md「主游戏 z_index」）：僵尸行本体 lane*50+30、
## 怀里僵尸 +1、抱着的「手 / 小臂」+2
const CARRY_Z_OFFSET := 1
const CARRY_FRONT_Z_OFFSET := 2
## 怀里僵尸相对绳子末端的微调偏移（默认 0，看画面觉得偏了就在这里调）
@export var carry_offset := Vector2.ZERO
## 蹦极自己的贴图整体往下挪多少像素（抱着看觉得偏上就调这里）
## 只挪贴图，不挪节点：挂在绳子上的位置 / 落点都挂在 BungiContainer 上，
## 挪节点会把怀里的僵尸一起带走，落点也跟着偏
@export var body_texture_offset_y := 10.0
## 本体在「怀里的僵尸正好落在落点上」这个基准上再偏多少：x 正 = 往右，y 正 = 往下。
## 这只挪本体，被吊的僵尸路径完全不受影响（走位时会反向补回来）
@export var perch_offset := Vector2(-17.0, -60.0)


func ready_norm():
	## 空投没有靶子（落点本来就随机，不需要给玩家提示）
	bungee_target.visible = false
	## 蹦极自己的贴图整体下移（含绳子），挂点与落点都不动
	offset_body_texture(body_texture_offset_y)
	## 反着推本来站在地面上的那只僵尸的位置：t=0（凭空生成）时它在 (落点x, 地面y)，
	## t<0（降落过程）要是一条直上直下的正比例直线，绳子末端就必须落在这同一个点上
	## —— 横向：容器在本体偏右（42），整体左挪让它对准落点，之后 x 恒定不变
	global_position.x -= bungi_container.global_position.x - global_position.x
	## —— 纵向：降落终点抬高容器的那点高度（73），本体停在半空、绳子末端正好停在地面，
	##    否则僵尸的脚会落在地面下方 73，落地那一帧又要往下补一段
	landing_offset_y = -(bungi_container.global_position.y - global_position.y)
	## 本体整体再偏一点，僵尸则不跟着偏（走位在下式里反向补回来）
	global_position += perch_offset
	## 进场全程是抱着姿态（body2 可见、普通身体隐藏），绳子要挂到 body2 上才看得见
	update_bungee_cords_parent()
	## 先把携带的僵尸挂到绳子上（此时各 @onready 节点已就绪），再走父类的降落流程
	hold_carry_zombie()
	super()


func _process(_delta: float) -> void:
	## 吊着的僵尸本体跟着绳子走（本体在上文被挪了 perch_offset，这里补回来，
	## 好让它在 t<0 是一条直上直下的正比例直线、t=0 正好落在落点上）
	if is_instance_valid(carry_zombie):
		carry_zombie.body.global_position = bungi_container.global_position - perch_offset + carry_offset


## 蹦极自己的贴图整体下移 offset_y 像素（含挂在身上的绳子）
## 只改 Sprite2D 的贴图偏移：动画轨道不打 offset，改了不会被覆盖；
## 而 BungiContainer 是 Node2D（没有贴图），挂点与落点自然跟着不动
func offset_body_texture(offset_y: float) -> void:
	if is_zero_approx(offset_y):
		return
	for child in body_correct.find_children("*", "Sprite2D", true, false):
		var sprite := child as Sprite2D
		if sprite == null:
			continue
		sprite.offset.y += offset_y


## 把携带的僵尸吊到蹦极僵尸下面
func hold_carry_zombie() -> void:
	if not is_instance_valid(carry_zombie):
		return
	carry_body_position = carry_zombie.body.position
	carry_body_scale = carry_zombie.body.scale
	## 落地前不参与战斗：不被植物打到、不走、不吃
	carry_zombie.hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	carry_zombie.move_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	carry_zombie.attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	## 整只僵尸定住：只禁用移动组件它只是不平移，走路动画还在播，看着像自己在半空里走下来。
	## 速度系数压到 0 后动画停在当帧（黄油 / 冰冻用的是同一套口径），落地再还原。
	carry_zombie.update_speed_factor(0.0, Character000Base.E_Influence_Speed_Factor.BungiCarry)
	carry_zombie.shadow.visible = false
	## 怀里的僵尸要盖在蹦极的身体之上（不然会被身体挡住）
	carry_z_index = carry_zombie.z_index
	carry_zombie.z_index = z_index + CARRY_Z_OFFSET
	## 再把抱着的手 / 小臂抬到僵尸之上：僵尸夹在身体与手之间
	raise_carry_front_parts()


## 把抱着姿态的「手 / 小臂」抬到怀里僵尸之上
## 这几处是本体内部的节点，用相对 z 永远压不住同行的另一只僵尸，
## 所以用绝对 z（z_as_relative=false，与火爆辣椒火焰同源的写法），节点本身不挪
func raise_carry_front_parts() -> void:
	var front_z := lane * 50 + 30 + CARRY_FRONT_Z_OFFSET
	for part_path in CARRY_FRONT_PART_PATHS:
		var part: CanvasItem = get_node_or_null(part_path) as CanvasItem
		if part == null:
			Log.error("空投蹦极缺少抱姿部位节点：" + str(part_path))
			continue
		carry_front_parts.append(part)
		part.z_as_relative = false
		part.z_index = front_z


## 放下后把手 / 小臂的图层还原
func restore_carry_front_parts() -> void:
	for part in carry_front_parts:
		if not is_instance_valid(part):
			continue
		part.z_as_relative = true
		part.z_index = 0
	carry_front_parts.clear()


## 空投蹦极更像一段投放动画而不是僵尸：受击框全程禁用，不参与任何索敌
func enable_hurt_box_on_drop() -> void:
	pass


## 空投：把携带的僵尸放下来，替代父类的偷植物
func bungi_plant_cell(_p_c: PlantCell) -> void:
	drop_carry_zombie()


## 被保护伞摊开时也要把携带的僵尸放下来，否则它会一直挂在半空
func raise_start():
	if is_umbrella_raise:
		drop_carry_zombie()
	super()


## 放下携带的僵尸
func drop_carry_zombie() -> void:
	if is_drop_finish:
		return
	is_drop_finish = true
	if not is_instance_valid(carry_zombie):
		carry_zombie = null
		return
	carry_zombie.body.position = carry_body_position
	carry_zombie.body.scale = carry_body_scale
	carry_zombie.shadow.visible = true
	carry_zombie.z_index = carry_z_index
	## 手 / 小臂回到本体里（蹦极自己马上就要起飞离场，还原只为不留脏状态）
	restore_carry_front_parts()
	## 先解冻再恢复组件：落地那一帧起就是正常速度，不会先定住再动
	carry_zombie.update_speed_factor(1.0, Character000Base.E_Influence_Speed_Factor.BungiCarry)
	carry_zombie.hurt_box_component.enable_component(ComponentNormBase.E_IsEnableFactor.Character)
	carry_zombie.move_component.enable_component(ComponentNormBase.E_IsEnableFactor.Character)
	carry_zombie.attack_component.enable_component(ComponentNormBase.E_IsEnableFactor.Character)
	carry_zombie = null


## 空投蹦极僵尸被打下来时，先把携带的僵尸丢下去，保证本波僵尸不会凭空消失
func character_death():
	drop_carry_zombie()
	super()
