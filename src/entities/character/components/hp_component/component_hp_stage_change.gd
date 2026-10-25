extends ComponentNormBase
class_name HpStageChangeComponent
## 血量阶段变化组件（掉手 / 掉头这类按血量阈值换皮的表现）
## 血量阶段变化组件,坚果和南瓜头使用
## 血量到达临界值时变化
##
## 已接入组件体系（`ComponentNormBase`），初始化写在 `component_ready()` 里。
## 禁用机制不会误伤本类：全仓无代码对 hp / anim 组件调 `disable_component()`，
## 详见 HpComponent 的类注释。

## 宿主角色走基类 ComponentNormBase.owner_character（U-06 统一后的唯一写法）
@onready var hp_component: HpComponent = %HpComponent

@export_group("血量临界值(两者个数必须对应)")
@export_subgroup("本体血量临界值(血量临界值数组默认为空（2个）即可)")
## 血量临界值数组，从满血到死亡顺序,默认为空即可
@export var boundary_value_hp:Array[int]
## 每阶段血量改变的精灵节点（默认有两个阶段：掉手、掉头）
@export var body_change:Array[ResourceBodyChange]
## 当前血量阶段(-1 = 未受损)
var curr_hp_stage := -1:
	set(value):
		curr_hp_stage = value
		signal_hp_stage_change.emit(curr_hp_stage)

signal signal_hp_stage_change(curr_hp_stage:int)

## 满血外观快照(坚果包扎术回血时用来把裂纹 / 掉手的外观复原,见 reset_hp_stage)
## 为什么要在 _ready 里先存一份: body_change 只能单向改外观(换纹理 / 显隐精灵),
## 没有反向操作,不存快照就退不回满血的样子
var _full_hp_sprite_nodes: Array[Sprite2D] = []
var _full_hp_sprite_textures: Array[Texture2D] = []
## 满血时应当隐藏的精灵(掉手 / 裂纹阶段才出现)
var _full_hp_hidden_nodes: Array[Node2D] = []
## 满血时应当显示的精灵(掉手 / 裂纹阶段才消失)
var _full_hp_shown_nodes: Array[Node2D] = []

func component_ready() -> void:
	## 初始化参数
	if boundary_value_hp.is_empty():
		@warning_ignore("integer_division")
		@warning_ignore("integer_division")
		boundary_value_hp.append(hp_component.max_hp * 2 / 3 - 1)	## 掉手
		@warning_ignore("integer_division")
		@warning_ignore("integer_division")
		boundary_value_hp.append(hp_component.max_hp * 1 / 3 - 1)	## 掉头
		if owner is Plant000Base:
			Log.error("植物使用血量阶段变化组件需对对`boundary_value_hp`赋值")

	## 修改死亡临界值
	if boundary_value_hp[-1] != 0:
		hp_component.set_death_hp(boundary_value_hp[-1])

	## 快照必须在任何掉手 / 裂纹发生之前取,放在 _ready 末尾即可
	_record_full_hp_body()

#region 本体body变化
## 判断body是否需要变化
## curr_hp: 当前剩余血量
func judge_body_change(curr_hp:int, is_drop:=true):
	## 角色不存在 or 最后血量状态 or 不掉落
	if not is_instance_valid(owner_character) or curr_hp_stage == boundary_value_hp.size() - 1 or not is_drop:
		return
	## 循环数组
	for i in range(boundary_value_hp.size()):
		if curr_hp_stage < i and curr_hp <= boundary_value_hp[i]:
			curr_hp_stage = i
			if body_change[i] == null:
				continue

			body_change[i].update_body(self)

## 记录满血外观(坚果包扎术复原用),见 _full_hp_sprite_nodes 的注释
func _record_full_hp_body() -> void:
	for body in body_change:
		if body == null:
			continue
		for i in range(body.sprite_change.size()):
			var sprite := get_node_or_null(body.sprite_change[i]) as Sprite2D
			if sprite == null:
				continue
			_full_hp_sprite_nodes.append(sprite)
			_full_hp_sprite_textures.append(sprite.texture)
		for path in body.sprite_appear:
			var node := get_node_or_null(path) as Node2D
			if node != null:
				_full_hp_hidden_nodes.append(node)
		for path in body.sprite_disappear:
			var node := get_node_or_null(path) as Node2D
			if node != null:
				_full_hp_shown_nodes.append(node)


## 复原满血外观(坚果包扎术):血量阶段与 body 外观一起退回未受损状态
## 只复原本体;防具的破损外观由 `ArmorComponent` 自己管,不在这里处理
func reset_hp_stage() -> void:
	if curr_hp_stage < 0:
		return
	curr_hp_stage = -1
	for i in range(_full_hp_sprite_nodes.size()):
		_full_hp_sprite_nodes[i].texture = _full_hp_sprite_textures[i]
	for node in _full_hp_hidden_nodes:
		node.visible = false
	for node in _full_hp_shown_nodes:
		node.visible = true


## 获取所有的本体body掉落物
func get_all_body_change()->Array[ZombieDropBase]:
	var all_node_drop :Array[ZombieDropBase] = []

	for i in range(body_change.size()):
		if body_change[i] == null:
			continue
		var body_drop:ZombieDropBase = body_change[i].get_drop_node(self)
		if body_drop != null:
			all_node_drop.append(body_drop)
	return all_node_drop

#endregion

## 小僵尸大麻烦更新僵尸血量变化临界值
## 只管本体;防具那几层由 `HpComponentZombie.update_mini_zombie_hp()` 转给各自的防具组件
func update_mini_zombie_hp_stage_change():
	for i in range(boundary_value_hp.size()):
		boundary_value_hp[i] /= 2
	## 修改死亡临界值
	if boundary_value_hp[-1] != 0:
		hp_component.set_death_hp(boundary_value_hp[-1])

