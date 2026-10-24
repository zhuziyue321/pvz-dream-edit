extends Zombie000Base
## 会「跳过去」的僵尸基类（撑杆僵尸 / 海豚骑士僵尸共用）
##
## 这两个僵尸原本各抄一份 `ready_norm` / `ready_norm_signal_connect` / `jump_start` /
## `jump_end` / `jump_end_end` / `jump_be_stop`，差异只有两处（见下方两个钩子）。
## 公共部分收在这里，子类只写钩子。
##
## ⚠️ `is_jumping` 是 AnimationTree 的 `advance_expression` 绑定属性
## （`zombie_pole_vaulter.tscn` / `zombie_dolphinrider.tscn` 的 `"is_jumping"` / `"not is_jumping"`），
## **不能**挪进 `JumpComponent`：挪了动画机就取不到值。逻辑侧的状态在
## `JumpComponent.is_jumping`，两边靠 `signal_jump_start` / `signal_jump_end` 同步。
class_name ZombieJumpBase

@onready var jump_component: JumpComponent = $JumpComponent
@onready var detect_component: DetectComponent = %DetectComponent

## 跳跃中（动画表达式绑定，见文件头）
@export var is_jumping := false


func ready_norm() -> void:
	super()
	detect_component.disable_component(ComponentNormBase.E_IsEnableFactor.Jump)


## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	jump_component.signal_jump_start.connect(jump_start)
	jump_component.signal_jump_end.connect(jump_end)
	jump_component.signal_jump_end_end.connect(jump_end_end)

	jump_component.signal_jump_end_end.connect(detect_component.enable_component.bind(ComponentNormBase.E_IsEnableFactor.Jump))
	## 跳跃对移动影响
	jump_component.signal_jump_start.connect(move_component.update_move_factor.bind(true, MoveComponent.E_MoveFactor.IsJump))
	jump_component.signal_jump_end_end.connect(move_component.update_move_factor.bind(false, MoveComponent.E_MoveFactor.IsJump))


## 开始跳跃,跳跃组件信号发射调用
func jump_start():
	is_jumping = true
	curr_be_attack_status = E_BeAttackStatusZombie.IsJump
	signal_status_update.emit()
	_on_jump_start_extra()


## 僵尸跳跃结束,跳跃组件信号发射调用
func jump_end():
	is_jumping = false
	jump_component.disable_component(ComponentNormBase.E_IsEnableFactor.Jump)


## 僵尸跳跃后摇结束
func jump_end_end():
	curr_be_attack_status = E_BeAttackStatusZombie.IsNorm
	is_trigger_squash_pos_judge = false
	is_trigger_tall_nut_stop_jump = false
	_on_jump_end_extra()


## 跳跃被强行停止,高坚果调用
func jump_be_stop(plant:Plant000Base):
	jump_component.jump_be_stop(plant)


## 开始跳跃时子类的补充动作（默认不做）
func _on_jump_start_extra() -> void:
	pass


## 跳跃后摇结束时子类的补充动作（默认不做）。
## 撑杆僵尸在这里补 `signal_status_update`（它原本就把这句放在后摇结束而不是开始）；
## 海豚骑士在这里把移动模式切回 `Ground`。
func _on_jump_end_extra() -> void:
	pass
