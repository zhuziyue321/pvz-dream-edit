extends Node2D
class_name Bullet000Base

## 子弹影子
@onready var bullet_shadow: Sprite2D = $BulletShadow
## 子弹本体节点
@onready var body: Node2D = $Body
## 子弹类型
@export var bullet_type:BulletRegistry.BulletType

## 实体编号（与角色 / 阳光 / 金币共用同一个分配器，全场唯一）
##
## 为什么要有：联机要说清"飞的是哪一颗" —— 客户端不自己造子弹（那一颗由主机随快照下发），
## 两端必须对得上同一颗，否则会按编号重复造一遍。单机不涉及，行为不变。
##
## ⚠️ 领号在 `BulletRegistry.create_bullet()` 里做，**不要**挪到 `_ready()`：
## 本类**自己没有 `_ready()`**，而 **8 个子类各写了一份**（bowling / cactus / cob_cannon /
## norm_base / parabola_base / pea_fire / track_base / winter_melon）。
## 领号放在唯一的创建口上，子类怎么重写都不会漏号、也不必记得调 `super()`；
## 这与"闸门装了但没人读"是同一种坑（见 `GlobalUtils.sun_spawn_gate` 的注释）。
var entity_id:int = 0

## 指定实体编号：客户端收到主机的快照后、入树**之前**调用（覆盖自动领到的那个号）
func assign_entity_id(new_id: int) -> void:
	entity_id = new_id

## 子弹阵营
## 场景里的值只是默认值，**发射方**通过 init_bullet 的 E_InitParasAttr.BulletCamp 覆盖它：
## 植物发射时是植物方子弹（打僵尸），植物僵尸 / 投石车僵尸发射时是僵尸方子弹（打植物），
## 这样同一份子弹场景可以被双方复用，不必为僵尸方再复制一套场景
@export var bullet_camp:CharacterRegistry.CharacterType = CharacterRegistry.CharacterType.Plant

## 阵营变化（init_bullet 应用阵营时发出；溅射组件等子节点据此同步自己的碰撞层）
signal signal_bullet_camp_changed(camp:CharacterRegistry.CharacterType)


## 设置子弹阵营
## 改字段 → 应用阵营（子类重写 apply_bullet_camp 同步碰撞层）→ 发信号通知子节点
## [camp] 新阵营
## [is_force] 为 true 时即使阵营没变也重新应用一次（init_bullet 初始化时用）
func set_bullet_camp(camp:CharacterRegistry.CharacterType, is_force:=false) -> void:
	if bullet_camp == camp and not is_force:
		return
	bullet_camp = camp
	apply_bullet_camp()
	signal_bullet_camp_changed.emit(bullet_camp)


## 应用阵营到自身（子类重写：把阵营对应的碰撞层写进自己的攻击框）
## 基类没有攻击框，什么都不做
func apply_bullet_camp() -> void:
	pass


## 主场景访问器：子弹需要的主场景能力一律走这里，**不要**直接取 GameContext.curr_main_game（旧称 Global.main_game，已删除）。
##
## 为什么：直接取全局单例等于让子弹隐式依赖「当前一定有一局主游戏」。收进本方法之后，
## 子弹代码里不再出现全局单例名，将来主场景改成注入式上下文只改这一处
## （角色侧对应 Character000Base.get_main_game，组件侧见 ComponentNormBase）。
## 「当前这一局」的真相源在 GameContext（见 global.gd 里那段「当前局上下文不在 Global 里」的说明）。
func get_main_game() -> MainGameManager:
	return GameContext.curr_main_game


## **子弹组件取「子弹身上某个节点」的统一入口**（替代在组件里拼 `$"../XXX"`）
##
## 与 `Character000Base.host_node_of()` 是同一套约定，只是宿主换成了子弹：
## 相对路径等于让组件假设「子弹是我的父节点、目标在第几层」，
## 子弹结构调整时组件会静默取到 null。改由子弹自己回答自己的结构。
##
## 用法（子弹组件里的 @onready）：
##[codeblock]
##	@onready var body: Node2D = Bullet000Base.host_node_of(owner, ^"Body")
##[/codeblock]
static func host_node_of(bullet_owner: Node, bullet_path: NodePath) -> Node:
	var host := bullet_owner as Bullet000Base
	if host == null:
		return null
	return host.get_node_or_null(bullet_path)
