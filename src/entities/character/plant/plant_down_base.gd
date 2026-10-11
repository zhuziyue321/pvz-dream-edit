extends Plant000Base
class_name Plant000DownBase
## 底部类植物基类

## 底部类植物
## 底部植物容器节点，作为中间植物容器的父节点
## 底部植物容器节点会上下移动，带动中间植物上下移动
## 荷叶与花盆的起伏**统一由动画控制**：花盆写在角色动画里（pot_idle 的 DownPlantContainer:position 轨道），
## 荷叶走下面的 is_float_anim（脚本构建循环动画，作用于本体的 position:y）
@onready var down_plant_container: Node2D = $DownPlantContainer

## 底部类植物放置后，norm和shell植物位置变化
@export var plant_up_position :Vector2

## 本体是否随水面上下起伏（荷叶开，花盆关）
@export var is_float_anim := false
## 起伏幅度（像素，向上为负）
@export var float_anim_height := 5.0
## 起伏一个完整来回的时长（秒）
@export var float_anim_duration := 4.5
## 起伏动画播放器（与角色动画播放器分开，避免和 AnimationTree 抢同一批轨道）
@onready var float_animation_player: AnimationPlayer = $FloatAnimationPlayer

## 起伏动画名
const FLOAT_ANIM_NAME := &"down_plant_float"
## 起伏动画的采样点数：越多越接近余弦曲线
const FLOAT_ANIM_SAMPLE_COUNT := 12

## 植物初始化相关
func init_plant(plant_init_para:Dictionary) -> void:
	super(plant_init_para)
	if plant_init_para[E_PInitAttr.CharacterInitType] != E_CharacterInitType.IsNorm:
		return
	plant_cell.down_plant_change_condition(plant_cell.plant_cell_type == PlantCell.PlantCellType.Pool)

## 角色初始化完成（项目规范 K-04：角色子类不重写 _ready()）
func ready_norm() -> void:
	super()
	if is_float_anim:
		_start_float_anim()

## 构建并播放本体上下起伏的循环动画
##
## 为什么不新建 animation/ 下的 .tres：那批资源由 R2Ga_PVZ 转换工具生成、不建议手改
## （见 animation/AGENTS.md），而且起伏要基于植物当前 position.y 才能不覆盖种植位置，
## 所以这里在运行时按当前位置构建，动画仍然由 AnimationPlayer 驱动，和花盆同一套机制。
func _start_float_anim() -> void:
	var base_y := position.y
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = float_anim_duration
	var track_index := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_index, NodePath(".:position:y"))
	## 余弦采样：首尾都回到 base_y，保证循环处不跳变
	for i in range(FLOAT_ANIM_SAMPLE_COUNT + 1):
		var ratio := float(i) / FLOAT_ANIM_SAMPLE_COUNT
		anim.track_insert_key(track_index, ratio * float_anim_duration,
				base_y - float_anim_height * 0.5 * (1.0 - cos(TAU * ratio)))
	var library := AnimationLibrary.new()
	library.add_animation(FLOAT_ANIM_NAME, anim)
	float_animation_player.add_animation_library("", library)
	float_animation_player.play(FLOAT_ANIM_NAME)
	## 随机起始播放位置：避免同一水面的荷叶整齐地一起起伏
	float_animation_player.seek(randf() * float_anim_duration)

## 角色死亡时切换地形
func character_death():
	plant_cell.down_plant_change_condition(plant_cell.plant_cell_type == PlantCell.PlantCellType.Pool)
	super()
