class_name DetectTargetStrategy
## 检测组件的「目标选择策略」：从 DetectComponent 里抽出来的纯选择逻辑
## （见 docs/参考存档/重构拆分方案.md 的 B4）
##
## 为什么单独放一个文件：
##   DetectComponent 本体负责「区域 / 层 / 信号 / 开关」，这几段只负责「从候选里挑谁」，
##   挑谁的规则与检测组件的运行状态无关，做成 static 后组件本体只管接线与转发。
##
## 约定：
##   · 全部是 static，不持有状态、不碰 owner、不发信号 —— 只吃参数、吐结果
##   · **不要**拿这里的实现去「统一」子弹里的同名函数：bullet_000_parabola_base /
##     bullet_000_linear_base 的优先级顺序与这里不同（抛物线先 Norm，直线先 Shell），
##     合并会改行为，先确认是不是有意为之再动

## 格子内应该被击中的植物：Shell > Norm > Imitater > Down > Float
## （原 DetectComponent.get_first_be_hit_plant_in_cell）
##
## 注意：必须用 Dictionary.get() 取值。植物格子默认只登记 Norm/Shell/Down/Float 四个位置，
## Imitater 键历史上是缺的（见 plant_cell.gd），直接下标会在「格子里只有花盆/睡莲/漂浮植物」时
## 越界崩溃（Out of bounds get index '4'）。
## 一律走 PlantCell.get_plant()：它会过滤掉槽位里已释放对象的残留引用，
## 直接读字典再用类型化局部变量接会报 "previously freed instance"。
static func get_first_be_hit_plant_in_cell(plant: Plant000Base, can_attack_plant_status: int) -> Plant000Base:
	var plant_cell: PlantCell = plant.plant_cell
	## shell
	var shell: Plant000Base = plant_cell.get_plant(CharacterRegistry.PlacePlantInCell.Shell)
	if is_instance_valid(shell):
		return shell
	var norm: Plant000Base = plant_cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm)
	if is_instance_valid(norm):
		return norm
	var imitater: Plant000Base = plant_cell.get_plant(CharacterRegistry.PlacePlantInCell.Imitater)
	if is_instance_valid(imitater):
		return imitater
	var down: Plant000Base = plant_cell.get_plant(CharacterRegistry.PlacePlantInCell.Down)
	if is_instance_valid(down):
		return down
	var floating: Plant000Base = plant_cell.get_plant(CharacterRegistry.PlacePlantInCell.Float)
	if is_instance_valid(floating):
		if can_attack_plant_status & 2:
			return floating
		else:
			Log.error("当前位置有悬浮植物，但角色不攻击悬浮植物")
			return null
	Log.error("当前植物格子没有植物")
	return null


## 从所有检测区域里找在空中的僵尸（仙人掌专用，原 DetectComponent.judge_zombie_in_sky）
## 找不到返回 null
static func find_zombie_in_sky(
	all_ray_area: Array[Area2D],
	lane: int,
	is_lane: bool,
	can_attack_status_component: CanAttackStatusComponent
) -> Character000Base:
	for ray_area in all_ray_area:
		var all_enemy_area = ray_area.get_overlapping_areas()
		for enemy_area in all_enemy_area:
			if enemy_area.owner is Character000Base:
				var enemy: Character000Base = enemy_area.owner
				## 先判断行属性
				if is_lane and lane != enemy.lane:
					continue
				## 检测到僵尸 and 可以攻击状态 and 在空中
				if enemy is Zombie000Base \
				and can_attack_status_component.can_attack(enemy) \
				and enemy.curr_be_attack_status == Zombie000Base.E_BeAttackStatusZombie.IsSky:
					return enemy
	return null


## 追踪子弹选敌（原 DetectComponent.update_enemy_track_bullet）
## 规则：第一次索敌直接锁定；之后空中敌人优先，其余按「更靠近本方推进方向」优先
##   · 植物方子弹（打僵尸）：x 更小（更靠近房子）优先
##   · 僵尸方子弹（打植物）：x 更大（更靠近僵尸出生侧）优先，见 BulletCampConfig.is_nearer
## [all_enemy] 当前所有可攻击敌人 [curr_enemy] 当前锁定的敌人（可能已失效 / 为 null）
## [camp] 索敌方的阵营，只挑敌对阵营的候选（植物原来是被直接跳过的，植物僵尸需要它）
##
## 注意：curr_enemy **不能**声明成 Character000Base ——
##   追踪子弹锁定的目标死亡后被 queue_free，全局检测组件（DetectComponentGlobal）里
##   会残留一个已释放引用（它不连目标的死亡信号），用类型化形参接它会在**调用时**直接报
##   "Invalid type in function 'pick_enemy_for_track_bullet' ... (previously freed) is not a
##   subclass of the expected argument class"，函数体里的 is_instance_valid() 根本轮不到执行
##   —— 与本文件 get_first_be_hit_plant_in_cell 同一个坑，形参必须保持无类型。
static func pick_enemy_for_track_bullet(
	all_enemy: Array[Character000Base],
	curr_enemy,
	camp: CharacterRegistry.CharacterType = CharacterRegistry.CharacterType.Plant
) -> Character000Base:
	var is_have_sky_enemy := false
	## 已释放 / 非角色的残留引用一律当作「没有锁定过敌人」
	if not (curr_enemy is Character000Base):
		curr_enemy = null
	for enemy: Character000Base in all_enemy:
		## 只考虑敌对阵营：植物方子弹跳过植物，僵尸方子弹跳过僵尸
		if not BulletCampConfig.is_enemy(camp, enemy):
			continue
		## 空中优先只对僵尸目标有意义（植物没有空中受击状态）
		var is_sky_enemy: bool = enemy is Zombie000Base \
			and enemy.curr_be_attack_status == Zombie000Base.E_BeAttackStatusZombie.IsSky
		## 还没有锁定的敌人，直接锁定
		if not is_instance_valid(curr_enemy):
			curr_enemy = enemy
			if is_sky_enemy:
				is_have_sky_enemy = true
			continue
		## 如果有在空中的敌人,只对空中敌人进行判定
		if is_have_sky_enemy:
			if is_sky_enemy and BulletCampConfig.is_nearer(camp, enemy.global_position.x, curr_enemy.global_position.x):
				curr_enemy = enemy
		elif is_sky_enemy:
			is_have_sky_enemy = true
			curr_enemy = enemy
		elif BulletCampConfig.is_nearer(camp, enemy.global_position.x, curr_enemy.global_position.x):
			curr_enemy = enemy
	## 候选全空时可能还留着上一轮已释放的锁定目标，返回前再兜一次
	return curr_enemy if is_instance_valid(curr_enemy) else null
