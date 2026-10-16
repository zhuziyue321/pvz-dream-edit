extends Plant000DownBase
## 水盆（战斗植物 `P050WaterBowl`）：**花盆的水生形态**
##
## ★ 动画是白拿的：本场景直接实例化花盆那份 `plant_flower_pot.tscn`，而花盆场景里的
##   AnimationTree 早就按 `is_water` 分了两支（`Pot_idle` / `Pot_waterplants`）——
##   战斗侧那只花盆从来没人给它设过 `is_water`（读的是个不存在的属性，所以永远播 `Pot_idle`）。
##   这里把 `is_water` 打开，同一套动画就切到水盆那一支，**一行动画都不用重写**。
##
## ★ 与花盆的差别只有一处（「盆里装的是水」这件事的两个后果）：
##   1. 上面只接水生植物（海蘑菇 / 缠绕海草）。
##   做法是自己在场景里声明地形位 `own_condition_bit`（本体留给模组的口子，
##   见 `Plant000DownBase.own_condition_bit`），值 = `PlantConditionBits.WATER_BOWL`（64）：
##     种下后格子地形 = 1 无 + 64 水盆 → 普通植物（条件 22：草地 / 花盆 / 睡莲）认不出这一位；
##     水生植物的条件被本模组换成「8 水 + 64 水盆」（见 `water_bowl_mod.gd`），于是它们能种进来。
##   结果就是：草地上也能种海蘑菇 / 缠绕海草 —— 原版没有这个组合，所以整件东西放在模组里。
##   2. 上层植物的**影子藏掉**：影子落在水面上看着别扭（见下面 `ready_norm()` 那一组）。
##
## ★ 其余与花盆完全相同：冷却、阳光、被啃、被铲、被蹦极偷、手套搬运、承载上层植物、
##   上层植物的位置抬升（`plant_up_position`）—— 全都在 `Plant000DownBase` 那一份里，
##   本脚本不复制任何一条。
##
## ⚠️ 本文件跑在 `user://mods/water_bowl/` 下：那里的 `class_name` 不会注册成全局类，
##    所以不写 class_name，由同目录的 `plant_water_bowl.tscn` 按路径引用本脚本。

## 花盆场景的 AnimationTree 靠这个属性切到 `Pot_waterplants`（水盆那套动画）
@export var is_water := true


## ★ 盆里装的是水：把种进来的上层植物的**影子藏掉**（影子落在水面上看着别扭）
##
## 做法：盯住本体的 `down_plant_container` —— 格子会把 Norm / Shell 两个容器收进来
## （见 `PlantCell._attach_down_plant_container`）：容器一进来就盯着容器，植物一进来就藏影子；
## 容器一出去（水盆被铲 / 被啃掉 / 被手套拿起）就把影子还回去，同时撤掉盯梢。
## 种下、模仿者变身、手套搬入走的都是「植物进容器」这一条路，一起盖住。
func ready_norm() -> void:
	super()
	down_plant_container.child_entered_tree.connect(_on_up_container_in)
	down_plant_container.child_exiting_tree.connect(_on_up_container_out)


## 上层容器被收进本体：盯着它，顺手处理它里面**已经有**的植物
## （自己种水盆时上层容器是空的，手套把水盆搬进新格子时里面可能已经带了植物）
func _on_up_container_in(container: Node) -> void:
	if not container.child_entered_tree.is_connected(_on_up_plant_in):
		container.child_entered_tree.connect(_on_up_plant_in)
	for up_plant in container.get_children():
		_set_up_plant_shadow_visible(up_plant, false)


## 上层容器被搬出本体：撤掉盯梢，影子还回去（上层植物回到格子的地面上，不该继续隐身）
func _on_up_container_out(container: Node) -> void:
	if container.child_entered_tree.is_connected(_on_up_plant_in):
		container.child_entered_tree.disconnect(_on_up_plant_in)
	for up_plant in container.get_children():
		_set_up_plant_shadow_visible(up_plant, true)


## 上层植物进入上层容器（种下 / 模仿者变身 / 手套搬入；容器重新入树也会走这里）
##
## ⚠️ 两个坑，都是「容器被搬回格子时会重新入树」和「`child_entered_tree` 早于 `_ready()`」惹的：
##   1. 撤盯梢只是其中一半：容器被 `remove_child` 后会 `add_child` 回格子，**整棵重新入树**，
##      于是容器里每株植物都会再发一次 `child_entered_tree` —— 所以这里先判
##      「它是不是真的还挂在本体的上下移动容器下」，不是就当没看见（否则刚还回去的影子又被藏掉）。
##   2. 此刻上层植物的 `@onready`（含 `shadow`）**还没赋值**（`_ready()` 在 `child_entered_tree`
##      之后才跑，实测取到的是 null），所以没 ready 的先挂 `ready` 信号，等它就绪再藏。
func _on_up_plant_in(up_plant: Node) -> void:
	if not down_plant_container.is_ancestor_of(up_plant):
		return
	if up_plant.is_node_ready():
		_set_up_plant_shadow_visible(up_plant, false)
	else:
		up_plant.ready.connect(
			_set_up_plant_shadow_visible.bind(up_plant, false), CONNECT_ONE_SHOT)


## [param is_visible] false = 藏掉（在水盆里），true = 还原（离开水盆）
func _set_up_plant_shadow_visible(node: Node, is_visible: bool) -> void:
	var up_plant := node as Plant000Base
	if up_plant == null or not is_instance_valid(up_plant.shadow):
		return
	up_plant.shadow.visible = is_visible
