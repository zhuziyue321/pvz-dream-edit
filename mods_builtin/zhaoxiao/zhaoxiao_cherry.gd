extends Node
## 模组「招笑版」：挂在**每一株烟熏樱桃（原樱桃炸弹）**身上的观察者 —— 由入口脚本
## `zhaoxiao_mod.gd` 在**每一局主游戏**里现挂（本体场景里没有这个节点）。
##
## 它把樱桃炸弹改成「烟熏樱桃」，三件事（需求 2~3）：
##   1. **不造成伤害**：把炸弹组件的 `bomb_value` 压成 0 ——
##      伤害管线对 `amount <= 0` 直接取消（`DamageSystem`），所以爆炸表现 / 音效 / 动画一概照旧，
##      就是一滴血都不掉（也不会触发「炸死 → 灰烬 + 立即删除」那条路）；
##   2. **范围内的僵尸都吃到 30 秒烟熏**：接炸弹组件现成的 `signal_bomb_once`
##      （它在爆炸那一下发），此时按**同一个爆炸框**（`BombComponent/Area2DBomb`）找僵尸 ——
##      判据照抄本体 `BombComponentNorm._bomb_all_enemy()`：先过阵营（魅惑僵尸是植物方，
##      不吃植物方的炸弹），再过行范围 `bomb_lane`，最后过可攻击状态掩码；
##   3. 每只被炸到的僵尸挂一个 `zhaoxiao_smoke.gd`。
##
## ★ 为什么状态挂在**僵尸**身上而不是这株植物上：樱桃炸弹爆完**当场就死**
##   （动画方法轨道：`BombComponent.bomb_once()` → `character_death()`），
##   状态挂在它身上会跟着一起没。观察者本身也是它的子节点，所以两者分工很明确：
##   观察者只负责「在这一刻把状态派出去」，之后就随植物一起消失。
##
## ⚠️ 本类是普通 `Node`（不是 `Character000Base` / `ComponentNormBase` 的子类），
##    `_ready()` 按 Godot 常态写即可 —— 硬约束 §1-3 只管那两类角色 / 组件。

const Settings := preload("zhaoxiao_settings.gd")
const Smoke := preload("zhaoxiao_smoke.gd")

## 观察者节点的名字 / NodePath（入口脚本按它判「这株挂过没有」）
const NODE_NAME := &"SmokedCherryWatcher"
const NODE_PATH := ^"SmokedCherryWatcher"
## 炸弹组件的节点名（本体的爆炸组件）
const BOMB_COMPONENT_PATH := ^"BombComponent"

## 宿主（那株烟熏樱桃）
var _plant: Plant000Base
## 宿主的炸弹组件
var _bomb: BombComponentBase


#region 生命周期
func _ready() -> void:
	_plant = get_parent() as Plant000Base
	if _plant == null:
		Log.error("招笑版模组：烟熏樱桃观察者的父节点不是植物，本株不参与")
		return
	_bomb = _plant.get_node_or_null(BOMB_COMPONENT_PATH) as BombComponentBase
	if _bomb == null:
		Log.error("招笑版模组：烟熏樱桃身上找不到炸弹组件，本株不参与")
		return
	## 「不造成伤害」：压成 0。爆炸表现、音效、范围判定全都照旧，只是不掉血
	_bomb.bomb_value = 0
	if not _bomb.signal_bomb_once.is_connected(on_bomb_once):
		_bomb.signal_bomb_once.connect(on_bomb_once)
#endregion


#region 爆炸那一下：派发烟熏
## 「炸了」——本体每炸一次都会发这个信号（含死亡兜底那次）
##
## 公开方法（供信号连、也供探针直接调）。
func on_bomb_once() -> void:
	if not is_inside_tree() or not is_instance_valid(_plant):
		return
	for zombie in zombies_in_bomb_range():
		smoke_up(zombie)


## 爆炸框里的僵尸（判据照抄本体 `BombComponentNorm._bomb_all_enemy()` 的三道筛）
func zombies_in_bomb_range() -> Array:
	var result: Array = []
	if _bomb == null or not is_instance_valid(_bomb.area_2d_bomb):
		return result
	var bomb_camp := BulletCampConfig.get_owner_camp(_plant)
	var status := _bomb.can_attack_status_component
	for overlapped in _bomb.area_2d_bomb.get_overlapping_areas():
		var area_owner := overlapped.owner
		if not (area_owner is Zombie000Base):
			continue
		var zombie := area_owner as Zombie000Base
		if not is_instance_valid(zombie) or zombie.is_death:
			continue
		## 阵营：植物方的炸弹炸不到自己人（魅惑僵尸算植物方）
		if bomb_camp != CharacterRegistry.CharacterType.Null \
				and not BulletCampConfig.is_enemy(bomb_camp, zombie):
			continue
		## 可攻击状态（地下的矿工、空中的气球这类按掩码被排除）
		if is_instance_valid(status) and not status.can_attack(zombie):
			continue
		## 行范围（樱桃炸弹是 bomb_lane = 1：本行 + 上下各一行）
		if not _bomb.judge_lane(zombie):
			continue
		if not result.has(zombie):
			result.append(zombie)
	return result


## 给一只僵尸上烟熏；已经有烟熏状态就**只续时**（不重复挂第二个状态节点）
##
## 公开方法：`on_bomb_once()` 用它，探针也用它。
func smoke_up(zombie: Zombie000Base) -> void:
	if not is_instance_valid(zombie):
		return
	var existing := zombie.get_node_or_null(Smoke.NODE_PATH)
	if existing != null:
		existing.refresh()
		return
	var smoke := Smoke.new()
	smoke.name = Smoke.NODE_NAME
	zombie.add_child(smoke)
#endregion
