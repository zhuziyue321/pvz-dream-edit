extends ZB001DoctorSkillState
class_name ZB001DoctorStateSpawn
## 按技能组件提前准备的清单逐只放置，两次放置之间播放待机动画。
## 常态下两次放置之间的等待时间，单位为正常动作速度下的秒；首轮前与最后一轮后不等待。
@export_range(0.1, 60.0, 0.1) var spawn_interval_duration: float = 6.0
## 残血阶段两次放置之间的等待时间；剩余血量比例低于阈值后启用，通常不大于常态间隔。
@export_range(0.1, 60.0, 0.1) var spawn_interval_duration_low_hp: float = 4.0
## 进入残血阶段的剩余血量比例；低于该比例后改用残血间隔，0 表示只有空血才切换。
@export_range(0.0, 1.0, 0.01) var spawn_low_hp_ratio: float = 0.5


## 返回本次等待使用的放置间隔；剩余血量比例低于阈值时使用残血间隔。[br]
## 每两次放置之间重新读取血量，跨过阈值后本批剩余僵尸立即改用更短的间隔。
func get_spawn_interval_duration() -> float:
	if not is_instance_valid(boss) or not is_instance_valid(boss.hp_component):
		return spawn_interval_duration
	# 最大血量非正时无法计算比例，保留常态间隔，避免误判成残血。
	var max_hp: int = boss.hp_component.max_hp
	if max_hp <= 0 or boss.hp_component.curr_hp >= max_hp * spawn_low_hp_ratio:
		return spawn_interval_duration
	return spawn_interval_duration_low_hp


## 错误由检测分支就地输出；返回值供上层中止初始化，转发时不重复报错。
func get_configuration_error() -> String:
	if not effect_component is ZB001DoctorSkillSpawn:
		Log.error("%s：必须绑定 ZB001DoctorSkillSpawn 效果组件。" % get_path())
		return "技能效果组件类型错误。"
	# 本函数发现的配置错误；下层返回的错误已经由下层报告。
	var detected_error: String = ""
	# 父类技能配置检查的结果；非空时直接返回，不继续验证放置专属参数。
	var error := super.get_configuration_error()
	if not error.is_empty():
		return error
	if not is_finite(spawn_interval_duration) or spawn_interval_duration <= 0.0:
		detected_error = "放置间隔必须为有限正数。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	if not is_finite(spawn_interval_duration_low_hp) or spawn_interval_duration_low_hp <= 0.0:
		detected_error = "残血放置间隔必须为有限正数。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	if not is_finite(spawn_low_hp_ratio) or spawn_low_hp_ratio < 0.0 or spawn_low_hp_ratio > 1.0:
		detected_error = "残血阈值必须位于 0 到 1 之间。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	# 本技能的通用准备入口；所属技能和首条阶段连线在复合状态内统一检查。
	var prepare_state: ZB001DoctorStateSkillPrepare = child_state_machine.initial_state as ZB001DoctorStateSkillPrepare
	if prepare_state == null or prepare_state.skill_state != self:
		detected_error = "放置技能入口必须使用自身的通用 Prepare，处理无可用目标的情况。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	if not prepare_state.next_state is ZB001DoctorStateSpawnPlace:
		detected_error = "放置准备入口必须连接放置动作 Place。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	return ""
