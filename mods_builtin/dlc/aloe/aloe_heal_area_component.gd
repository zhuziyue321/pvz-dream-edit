extends Node2D
## 芦荟的治疗范围组件（由模组「DLC植物」提供，供芦荟专用）
##
## ★ 干什么：罩住宿主周围 3×3 的 Area2D，每帧发现自己范围内**血量未满**的植物，
##   通过两个信号告诉宿主「有得治 / 没得治」（与本体 `DetectComponent` 的两个
##   `signal_can_attack` / `signal_not_can_attack` 同一套节奏，宿主照射手的接法接即可），
##   另提供 `get_all_can_be_heal()` 供宿主取全部目标。
##
## ★ 为什么不直接用本体 `DetectComponent`：那是「索敌」组件 —— 层由
##   `update_curr_collision_lay()` 按宿主阵营定死（植物只看僵尸的层 4），
##   并且会连 `CanAttackStatusComponent` 判"能不能攻击"。治疗要看的恰好是
##   **植物的受击框检测层（layer 2）**、且不判定"能不能被打"。
##
## ★ 碰撞：`Area2D.collision_mask = 2`（layer 2 = PlantHurtBoxDetection），
##   `collision_layer = 0` —— 自己不被任何检测看到，不会被僵尸 / 子弹误判。
##   受击框那侧 `monitorable` 由 `HurtBoxComponent` 维护，植物死了自然退出范围。
##
## ★ 形状 / 位置写在场景里（`plant_aloe.tscn` 的 `Area2D` + `CollisionShape2D`），
##   与本体检测组件「形状进场景」的习惯一致；本脚本不再自己造形状。
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_aloe.tscn` 按路径引用。

## 范围内出现可治疗的植物（受伤且存活）
signal signal_can_heal
## 范围内没有可治疗的植物
signal signal_not_can_heal

## 监听层：植物受击框检测层（见 project.godot 的 layer_names）
const PLANT_HURT_BOX_LAYER := 2

@onready var _area_2d: Area2D = $Area2D

## 宿主（芦荟本体）：由 `aloe_plant.gd` 的 `ready_norm_signal_connect()` 注入。
## 组件不自己 `get_parent()` 抓宿主（硬约束：组件只通过 owner / 信号 / 场景配置通信）。
## 用途只有一个：把宿主从「可治疗目标」里排掉（芦荟不治自己）。
var host_character: Plant000Base = null

## 上一帧是否「有得治」—— 只在状态变化时发信号，避免每帧刷
var _had_target := false


func _ready() -> void:
	_area_2d.collision_mask = PLANT_HURT_BOX_LAYER
	_area_2d.collision_layer = 0
	_area_2d.monitoring = true


func _physics_process(_delta: float) -> void:
	judge_is_can_heal()


## 重新判定范围内有没有可治疗的植物，按变化发信号
## [return] 当前是否有可治疗目标
func judge_is_can_heal() -> bool:
	var has_target := not get_all_can_be_heal().is_empty()
	if has_target == _had_target:
		return has_target
	_had_target = has_target
	if has_target:
		signal_can_heal.emit()
	else:
		signal_not_can_heal.emit()
	return has_target


## 取范围内所有「受伤且存活」的植物
##
## 按 layer 2 的受击框取：同一格里的壳（南瓜头）/ 底下植物各自有独立受击框，
## 所以一格里叠着的植物会被分别收集；宿主自己不在结果里（芦荟不治自己）。
func get_all_can_be_heal() -> Array[Plant000Base]:
	var result: Array[Plant000Base] = []
	if not is_instance_valid(_area_2d):
		return result
	for area: Area2D in _area_2d.get_overlapping_areas():
		var area_owner := area.get_owner()
		if not area_owner is Plant000Base:
			continue
		var plant := area_owner as Plant000Base
		if plant == null or plant == host_character:
			continue
		if plant.is_death or plant.is_queued_for_deletion():
			continue
		var hp := plant.hp_component
		if hp == null or hp.is_death or hp.get_all_hp() >= hp.max_hp:
			continue
		if result.has(plant):
			continue
		result.append(plant)
	return result
