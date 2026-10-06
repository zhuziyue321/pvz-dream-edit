class_name ZombieMowerRunUtil
## 僵尸「被小推车碾压」的完整表现（原 Zombie000Base.be_mowered_run / be_mowered_run_anim_norm）
## （见 docs/参考存档/重构拆分方案.md 的 B5）
##
## 为什么单独放一个文件：
##   50 行里全是「掉防具 → 收集掉落物 → 压扁 → 逐个掉出去」的表现编排，
##   和僵尸基类的其它职责没有交集，抽走后基类只留一行转发。
##
## 约定：
##   · 全部 static，不持有状态；需要改僵尸自身的字段时显式传 zombie 进来
##   · **不要 await**：流程串在一条 Tween 上（tween_callback + tween_interval），
##     这样这里不需要写成协程，僵尸被 queue_free 时整条 Tween 一起被杀，
##     不会像原来的 SceneTreeTimer 那样在僵尸已经释放后还去动它的节点

## 被小推车碾压：结算死亡 → 播放表现 → 删除节点
static func run(zombie: Zombie000Base, lawn_mover: LawnMover) -> void:
	## 取消亡语
	zombie.is_can_death_language = false
	## 首先死亡无掉落
	zombie.hp_component.Hp_loss_death(false)
	## 禁用移动组件 停止移动
	zombie.move_component.disable_component(ComponentNormBase.E_IsEnableFactor.Death)
	## 停止动画
	zombie.anim_component.stop_anim()

	var zombie_death_bomb: ZombieDeathBomb = zombie.get_node_or_null("Body/ZombieDeathBomb")
	if zombie_death_bomb != null:
		zombie_death_bomb.activate_it()
		zombie.queue_free()
		return
	## 没有自爆节点时走通用碾压表现，播完再删节点
	start_anim_norm(zombie, lawn_mover).finished.connect(zombie.queue_free)

## 通用碾压表现：压扁 + 逐个掉落本体掉落物（手和头）
## 返回串好整条流程的 Tween，调用方接 finished 即可
static func start_anim_norm(zombie: Zombie000Base, lawn_mover: LawnMover) -> Tween:
	## 先掉落防具
	var hp_component := zombie.hp_component as HpComponentZombie
	if hp_component.curr_hp_armor1 != 0:
		zombie.hp_stage_change_component.judge_body_change_armor(0, 0, true, true)
	if hp_component.curr_hp_armor2 != 0:
		zombie.hp_stage_change_component.judge_body_change_armor(0, 0, true, false)

	## 收集本体掉落物（手和头），先藏起来
	var all_node_drop: Array[ZombieDropBase] = zombie.hp_stage_change_component.get_all_body_change()
	for node_drop in all_node_drop:
		node_drop.visible = false
		node_drop.reparent(zombie)

	## 身体被压扁
	var tween := zombie.create_tween()
	tween.set_parallel()
	tween.tween_property(zombie.body, "rotation_degrees", 90, 0.25)
	tween.tween_property(zombie.body, "scale", Vector2(0.5, 1), 0.25)
	tween.set_parallel(false)
	tween.tween_callback(func(): zombie.body.visible = false)

	## 掉落本体掉落物，每个间隔 0.1 秒
	## 这里刻意不用 for node_drop in ... + lambda：GDScript 的循环变量会被 lambda 捕获成同一个，
	## 结果是所有掉落物都掉到最后一个身上，必须 bind 把值拷进去
	for i in all_node_drop.size():
		tween.tween_callback(
			drop_one_body_part.bind(all_node_drop[i], lawn_mover.global_position.x)
		)
		tween.tween_interval(0.1)
	return tween

## 掉出一个本体掉落物（手 / 头）
static func drop_one_body_part(node_drop: ZombieDropBase, ground_x: float) -> void:
	node_drop.visible = true
	node_drop.acitvate_it_on_ground(ground_x)
	SoundManager.play_character_SFX("limbs_pop")
