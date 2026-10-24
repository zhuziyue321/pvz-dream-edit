extends ZombieJumpBase
class_name Zombie004PoleVaulter
## 撑杆僵尸：跳跃流程全部继承 `ZombieJumpBase`，本类只保留「跳过之后通知别人重判」与
## 「我是僵尸模式检测到脑子」两处差异（见 U-52）。

## 监测到脑子
var is_detect_brain:=false


## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	## 我是僵尸模式检测到脑子
	jump_component.signal_detect_brain.connect(_on_jump_detect_brain)


## 跳跃后摇结束：撑杆僵尸要在这一刻通知敌人重新索敌
func _on_jump_end_extra():
	signal_status_update.emit()


## 跳跃之前检测到脑子
func _on_jump_detect_brain():
	is_detect_brain=true
	detect_component.enable_component(ComponentNormBase.E_IsEnableFactor.Jump)
