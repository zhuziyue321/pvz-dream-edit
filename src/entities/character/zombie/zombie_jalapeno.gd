extends Zombie001Norm
class_name Zombie034Jalapeno
## 火爆辣椒僵尸（原版 ZomBotany）：**走过一段固定时间后原地自爆**，烧掉整行植物，烧完自己也消失。
##
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Jalapeno_Zombie)
##          + 原版 `Zombie::UpdateZombieJalapenoHead`
##
## ⚠️ 原版**不是**「碰到植物才炸」：`ZombieInitialize()` 里按距离算初值
##    `mPhaseCounter = (275 + Rand(175)) / mVelX * ZOMBIE_LIMP_SPEED_FACTOR(2)`，
##    `Update()` 里每 tick 减 1，减到 0 就烧整行 + `DieNoLoot()`。
##    即它和前面有没有植物无关 —— 被植物挡住、边啃边走都会到点自爆；
##    只有被「定住」（冰冻陷阱 / 黄油，`IsImmobilizied()`）时计时才暂停。

## 烧毁伤害（原版火爆辣椒 1800）
@export var burn_attack_value: int = 1800
## 自爆前的时间（秒）
##
## 原版按「距离 / 速度 × 2」换算：275~450 px ÷ 0.3 px/tick（100 tick/s）× 2 ≈ 18~30 秒。
## **与是否碰到植物无关**；只有被冰冻陷阱 / 黄油定住时才停表。
@export var explode_time_range: Vector2 = Vector2(18.0, 30.0)

## 是否已经用过（一次性）
var is_used := false
## 自爆倒计时（秒）
var explode_counter := 0.0
## 是否已开始倒计时：只有正常出战（`ready_norm()`）才起算，图鉴 / 展示态不参与
var is_explode_armed := false


func ready_norm() -> void:
	super()
	explode_counter = randf_range(explode_time_range.x, explode_time_range.y)
	is_explode_armed = true


## 原版计时器每 tick 递减：这里按秒累计。
## **不因啃食停下** —— 原版 `mPhaseCounter` 与 `mIsEating` 无关，
## 所以它会在植物面前啃着啃着就自爆（这才是原版的表现）。
func _physics_process(delta: float) -> void:
	if not is_explode_armed or is_used or is_death:
		return
	## 被「定住」（冰冻陷阱 / 黄油）时停表 —— 对应原版 `IsImmobilizied()` 时 `mPhaseCounter` 不递减；
	## 冰豆 / 冰瓜那种**减速**不停表（原版同样只减速不减计时）
	if _is_immobilized():
		return
	explode_counter -= delta
	if explode_counter <= 0.0:
		_explode()


## 是否被完全定住（原版 `IsImmobilizied()` = 冰冻陷阱 or 黄油）：
## 只看这两档速度因子，减速档（`IceDecelerateSpeed` / `Slow`）不算 —— 那是「变慢」，不是「停住」
func _is_immobilized() -> bool:
	return is_zero_approx(influence_speed_factors.get(E_Influence_Speed_Factor.IceFreezeSpeed, 1.0)) \
		or is_zero_approx(influence_speed_factors.get(E_Influence_Speed_Factor.Butter, 1.0))


## 自爆：烧掉本行所有植物，自己也消失
func _explode() -> void:
	if is_used or is_death:
		return
	is_used = true
	_burn_lane()
	SoundManager.play_character_SFX(&"explosion")
	## 烧完自身消失（原版 DieNoLoot：不留战利品）
	character_death_disappear()


## 烧掉本行所有植物
## 读 `plant_in_cell` 一律走 `PlantCell.get_plant()`：槽位里可能是已释放对象的残留引用
func _burn_lane() -> void:
	var all_plant_cells: Array = get_main_game().plant_cell_manager.all_plant_cells
	if lane < 0 or lane >= all_plant_cells.size():
		Log.error("火爆辣椒僵尸的行号越界：" + str(lane))
		return
	for cell in all_plant_cells[lane]:
		var plant_cell := cell as PlantCell
		if not is_instance_valid(plant_cell):
			continue
		for place in plant_cell.plant_in_cell:
			var plant := plant_cell.get_plant(place)
			if is_instance_valid(plant) and not plant.is_death:
				plant.be_attacked_bullet(burn_attack_value, ConstDamage.E_DamageMode.Penetration, false, false)
