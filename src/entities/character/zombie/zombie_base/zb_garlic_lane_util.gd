class_name ZombieGarlicLaneUtil
## 僵尸「啃到大蒜后换行」（原 Zombie000Base.update_lane_on_eat_garlic / update_lane）
## （见 docs/参考存档/重构拆分方案.md 的 B5）
##
## 为什么单独放一个文件：
##   换行要读 zombie_manager 的行列表、改自己的行、换父节点、再补一段位移 Tween，
##   是一段自己就能讲完的小流程，基类里只留一行转发。
##
## 约定：
##   · 全部 static，不持有状态；需要改僵尸自身的字段时显式传 zombie 进来
##   · 愣神的那 0.5 秒用 Tween 而不是 SceneTreeTimer：僵尸在这期间死了的话
##     Tween 会随节点一起被杀，不会在节点释放后再去换行

## 啃到大蒜：愣 0.5 秒，然后换行
static func on_eat_garlic(zombie: Zombie000Base) -> void:
	SoundManager.play_character_SFX("yuck")
	zombie.update_speed_factor(0.0, Character000Base.E_Influence_Speed_Factor.EatGarlic)
	var tween := zombie.create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		zombie.update_speed_factor(1.0, Character000Base.E_Influence_Speed_Factor.EatGarlic)
		update_lane(zombie)
	)

## 换到相邻的同类型行（陆换陆、水换水）
## 选不到可换的行就直接返回（例如 陆/水/陆 布局里水行僵尸上下都不是水）
static func update_lane(zombie: Zombie000Base) -> void:
	var all_zombie_rows = Global.main_game.zombie_manager.all_zombie_rows
	## 可以换的行索引
	var can_update_zombie_row_i: Array[int] = []
	if zombie.lane != 0 and all_zombie_rows[zombie.lane - 1].zombie_row_type == zombie.curr_zombie_row_type:
		can_update_zombie_row_i.append(zombie.lane - 1)
	if zombie.lane != all_zombie_rows.size() - 1 and all_zombie_rows[zombie.lane + 1].zombie_row_type == zombie.curr_zombie_row_type:
		can_update_zombie_row_i.append(zombie.lane + 1)

	## 上下相邻行的行类型都与当前行不同时数组为空，
	## pick_random() 返回 null 再赋给 lane:int 会报错且换行失效
	if can_update_zombie_row_i.is_empty():
		Log.warn("僵尸换行失败：上下相邻行的行类型都与当前行不同")
		return

	var new_lane_i: int = can_update_zombie_row_i.pick_random()
	zombie.lane = new_lane_i
	zombie.signal_lane_update.emit()

	## 换行过程中禁用攻击组件，落地（位移结束）后再启用
	zombie.attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Garlic)
	zombie.reparent(all_zombie_rows[zombie.lane])
	var tween := zombie.create_tween()
	tween.tween_property(
		zombie,
		^"position:y",
		all_zombie_rows[zombie.lane].zombie_create_position.position.y,
		1
	)
	tween.tween_callback(zombie.attack_component.enable_component.bind(ComponentNormBase.E_IsEnableFactor.Garlic))
