extends Node2D
class_name Rake
## 钉耙(Garden Rake)
##
## 原版一代 PC: 关卡开局自动放在草坪上,踩到它的僵尸吃 1800 点穿透伤害
## (除巨人 / 红眼巨人 / 高坚果僵尸外当场击杀);触发时把手像卡通里那样翘起来砸中僵尸,
## 砸完钉耙就消失,一关只放一个。
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Garden_Rake)
##
## 生成与消耗见 GIM_Rake(剩余关数存在 GlobalGameState.rake_use_num)。

## 命中伤害(穿透),原版 1800,与倭瓜同级
@export var attack_value: int = ConstShop.RAKE_ATTACK_VALUE

## 钉耙所在行(从 0 开始),由 GIM_Rake 在生成时赋值
var lane: int = -1
## 是否已经触发过(一关只触发一次)
var is_triggered: bool = false

@onready var area_2d: Area2D = $Area2D
@onready var rake_head: Sprite2D = $Body/RakeHead
@onready var rake_head_hit: Sprite2D = $Body/RakeHeadHit
@onready var handle: Node2D = $Body/Handle

## 把手平放时的位置 / 角度(原版 reanim 的静止帧: 柄横躺在钉耙头左下方)
const HANDLE_DOWN_POS := Vector2(-47, 7)
const HANDLE_DOWN_ROTATION := deg_to_rad(-90.0)
## 触发后把手立起来的位置 / 角度(原版 reanim: 柄弹到钉耙头正上方)
const HANDLE_UP_POS := Vector2(-1, -47)
const HANDLE_UP_ROTATION := 0.0
## 把手立起来后停留的时间(秒)
const HANDLE_UP_KEEP_TIME := 0.8
## 消失前的淡出时间(秒)
const FADE_OUT_TIME := 0.4


func _ready() -> void:
	## 把手初始姿态以脚本常量为准,场景里的值只作编辑器预览
	handle.position = HANDLE_DOWN_POS
	handle.rotation = HANDLE_DOWN_ROTATION


func _on_area_entered(area: Area2D) -> void:
	if is_triggered:
		return
	var area_owner := area.owner
	if area_owner is Zombie000Base:
		var zombie: Zombie000Base = area_owner
		if lane == zombie.lane:
			_try_trigger(zombie)


## 触发判定:已经进入死亡流程 / 本体血量已在临界值以下的僵尸不触发
## (与小推车同一套过滤,见 LawnMover.start_trigger_filter)
func _try_trigger(zombie: Zombie000Base) -> void:
	if is_triggered or zombie.is_death:
		return
	if zombie.is_below_critical_value:
		return
	## 掘土状态的矿工踩不到钉耙,等它出土再说
	if zombie is Zombie018Digger and not zombie.is_can_trigger_mower:
		var callback := _try_trigger.bind(zombie)
		if not zombie.signal_can_trigger_mower.is_connected(callback):
			zombie.signal_can_trigger_mower.connect(callback)
		return
	_trigger(zombie)


## 真正触发:先结算伤害再播表现,免得死亡流程把动画打断
func _trigger(zombie: Zombie000Base) -> void:
	is_triggered = true
	zombie.be_rake_attack(attack_value)
	_play_trigger_anim()


## 把手弹起 → 停留 → 淡出消失
func _play_trigger_anim() -> void:
	SoundManager.play_other_SFX("bonk")
	## 弹起瞬间抬到僵尸上面(行内 z_index:僵尸 30、小推车 40),否则会被僵尸挡住
	z_index = lane * 50 + 45
	rake_head.visible = false
	rake_head_hit.visible = true
	var up_tween := create_tween().set_parallel()
	up_tween.tween_property(handle, "position", HANDLE_UP_POS, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up_tween.tween_property(handle, "rotation", HANDLE_UP_ROTATION, 0.12)
	await up_tween.finished
	await get_tree().create_timer(HANDLE_UP_KEEP_TIME).timeout
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
	await fade_tween.finished
	queue_free()
