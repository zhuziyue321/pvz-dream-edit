extends Node2D
class_name SwimBoxComponent
## 僵尸游泳组件基类
##
## ⚠️ 本类**没有继承 `ComponentNormBase`**，但用法上确实是组件（挂在僵尸场景里、
## 有 `component_swim_box_norm` / `component_swim_box_snorkle` 两个子类）。
## 不接入的两条理由（2026-10-11 复核后维持现状，接入属行为变更、要开游戏确认）：
##   1. `ComponentNormBase` 的 `_ready()` 会把初始化统一转给 `component_ready()`，
##      并按 `is_enable_default` / 各路「启用因素」禁用组件；本类的 `_on_area_2d_area_entered`
##      等回调是**场景里连的信号**，接入后「组件被禁用」时这些信号回调仍在不在、要重判一遍。
##   2. 本类依赖 `visible` 与子节点（`%Shadow` / `%Body`），而 `ComponentNormBase` 本身
##      也是 `Node2D`（不是 `Node`），所以「因为要 Node2D 才不能接入」这个理由**不成立** ——
##      真正的差别只有启用/禁用框架。接入的收益（死亡时自动停）需要实测才敢要。

@onready var shadow: Sprite2D = %Shadow
@onready var body: BodyCharacter = %Body

## 游泳时body变化
@export var body_change_swim:ResourceBodyChange

## 特殊水花位置(普通水花位置跟影子重叠,海豚僵尸使用)
@export var special_splash_pos_node:Node2D

var owner_is_death:=false

## 改变游泳状态信号
signal signal_change_is_swimming(is_swimming:bool)

func _on_owner_is_death():
	owner_is_death = true

## 检测到泳池
func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.owner is Pool:
		signal_change_is_swimming.emit(true)

## 离开泳池
func _on_area_2d_area_exited(area: Area2D) -> void:
	if area.owner is Pool:
		signal_change_is_swimming.emit(false)

## 出现水花（位置跟影子重叠）
func appear_splash():
	appear_splash_at(shadow)

## 特殊位置水花（海豚僵尸用，位置取 `special_splash_pos_node`）
func appear_splash_special_pos():
	appear_splash_at(special_splash_pos_node)

## 在 [param pos_node] 的全局位置冒一朵水花：上面两个函数只差"位置取哪个节点"，实现共用这一份
func appear_splash_at(pos_node: Node2D) -> void:
	var splash = SceneRegistry.SPLASH.instantiate()
	splash.position = pos_node.global_position - owner.get_sibling_layer().global_position + Vector2(0, 15)
	owner.get_sibling_layer().add_child.call_deferred(splash)
