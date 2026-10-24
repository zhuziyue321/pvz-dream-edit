extends RefCounted
## 探针 ZOM_BOTANY_PEA_SHOOT：豌豆僵尸发射点口径回归（2026-10-24 魅惑 / 定身修复）
##
## 【为什么要有这一条】
##   豌豆僵尸的发射点不在场景里摆死，而是运行时按原版公式算
##   （`ZombiePlantComponent.get_head_shoot_global_position()`）。这类「算出来的坐标」
##   改常量 / 改分支时不会有任何编译错误，表现只是「豌豆从奇怪的位置飞出去」——
##   2026-10-24 修魅惑态（原版 `DO_FIX_BUGS` 分支：发射点前移 90、豌豆改朝右飞）与
##   定身停表（原版 `IsImmobilizied()` 时 `mPhaseCounter` 不递减）后，需要一条机器断言锁住。
##
## 【锁四件事】
##   1. 普通态：发射点 = 头轨道世界坐标 + C_SHOOT_OFFSET（原版 `mPos + mTrans + (-9,+6)` 的换算值）
##   2. 魅惑态：发射点 = 头轨道世界坐标 + C_SHOOT_OFFSET_HYPNO（= 普通偏移 + 90，原版前移量）
##   3. 子弹方向：普通态朝左（原版 MOTION_BACKWARDS）；魅惑态朝右（原版植物方豌豆默认朝向）
##   4. 停表：speed_product == 0（冰冻停滞 / 黄油）时发射计时器 paused，恢复即解除
##
## 【自证拦得住】把 C_SHOOT_OFFSET_HYPNO 改回普通偏移、删掉 `_get_bullet_direction()` 的魅惑分支、
##   或删掉 `owner_update_speed()` 覆写，本探针必须 FAIL。
##
## 【边界】只实例化一只豌豆僵尸挂在树根下读坐标，不进关卡、不发真子弹；
##   头轨道节点本身的存在由 probe_zom_botany 的结构断言负责，这里只算坐标。

const C_ZOMBIE_TYPE := ZombieIds.PEA_SHOOTER_ZOMBIE
## 原版 `UpdateZombiePeaHead()` 魅惑分支的前移量：`aOriginX += 90.0f * mScaleZombie`
## （豌豆僵尸是普通僵尸，s = 1），两个参照项目口径一致
const C_ORIGINAL_HYPNO_SHIFT_X := 90.0

var _failed := 0


func run(a) -> void:
	a.log("PROBE 豌豆僵尸发射点 启动")
	var zombie := _spawn_zombie(a)
	if zombie == null:
		_finish(a)
		return
	## 等 _ready 链跑完、变换传播一帧（关卡外创建的僵尸见 ZombieBase.ready_norm 的挡板注释）
	await a.frames(3)
	_check_constants(a)
	_check_normal(a, zombie)
	await _check_hypno(a, zombie)
	await _check_mirror_fallback(a, zombie)
	_check_direction(a, zombie)
	_check_timer_pause(a, zombie)
	zombie.free()
	_finish(a)


func _finish(a) -> void:
	a.log("")
	a.log("[ZOMBOTANY_PEA_SHOOT] result=%s failed=%d" % [("PASS" if _failed == 0 else "FAIL"), _failed])
	a.quit_game()


#region 检查

## 常量锁：魅惑偏移必须正好是「普通偏移 + 原版前移量」，不许手拍一个新数字
func _check_constants(a) -> void:
	_expect(a, "普通态发射点偏移 = 原版公式换算值 (-24, +14)",
		ZombiePlantComponent.C_SHOOT_OFFSET, Vector2(-24, 14))
	_expect(a, "魅惑态偏移 = 普通偏移 + 原版前移 90",
		ZombiePlantComponent.C_SHOOT_OFFSET_HYPNO,
		ZombiePlantComponent.C_SHOOT_OFFSET + Vector2(C_ORIGINAL_HYPNO_SHIFT_X, 0))


## 普通态：发射点贴着晃动中的头轨道，偏移是 (-24, +14)
func _check_normal(a, zombie: Zombie000Base) -> void:
	_expect(a, "豌豆僵尸未魅惑", zombie.is_hypno, false)
	var head := _head_track(zombie)
	_expect(a, "头轨道节点存在", head != null, true)
	if head == null:
		return
	_expect_vec(a, "普通态发射点 = 头轨道 + (-24, +14)",
		_shoot_pos(zombie), head.global_position + ZombiePlantComponent.C_SHOOT_OFFSET)


## 魅惑态：原版 `DO_FIX_BUGS` 分支 —— 发射点前移 90（相对头轨道即 (66, +14)）
func _check_hypno(a, zombie: Zombie000Base) -> void:
	zombie.is_hypno = true
	var head := _head_track(zombie)
	if head == null:
		_expect(a, "头轨道节点存在", false, true)
		return
	_expect_vec(a, "魅惑态发射点 = 头轨道 + (66, +14)",
		_shoot_pos(zombie), head.global_position + ZombiePlantComponent.C_SHOOT_OFFSET_HYPNO)
	## 清掉魅惑标记，还给后面的检查
	zombie.is_hypno = false


## 非魅惑原因被水平镜像（模组自定义朝向）时偏移取反 —— 镜像分支不能被魅惑分支吃掉后失效
func _check_mirror_fallback(a, zombie: Zombie000Base) -> void:
	zombie.scale.x = -1.0
	## 变换传播要等一帧：改完 scale 立刻读子节点 global_position 拿到的是旧值
	await a.frames(2)
	var head := _head_track(zombie)
	if head == null:
		_expect(a, "头轨道节点存在", false, true)
		return
	_expect_vec(a, "镜像态发射点 = 头轨道 + (+24, +14)",
		_shoot_pos(zombie), head.global_position + Vector2(24, 14))
	zombie.scale.x = 1.0
	await a.frames(2)


## 子弹方向：普通态朝左飞（原版 MOTION_BACKWARDS），魅惑态朝右飞（原版植物方豌豆）
func _check_direction(a, zombie: Zombie000Base) -> void:
	var atk := _attack_component(zombie)
	if atk == null:
		_expect(a, "攻击组件存在", false, true)
		return
	zombie.is_hypno = false
	_expect(a, "普通态子弹方向朝左", atk._get_bullet_direction(), Vector2.LEFT)
	zombie.is_hypno = true
	_expect(a, "魅惑态子弹方向朝右", atk._get_bullet_direction(), Vector2.RIGHT)
	zombie.is_hypno = false


## 停表：speed_product == 0（冰冻停滞 / 黄油）暂停发射计时器并保留剩余时间，
## 对应原版 `IsImmobilizied()` 时 `mPhaseCounter` 不递减；减速档（0 < p < 1）不停表
func _check_timer_pause(a, zombie: Zombie000Base) -> void:
	var atk := _attack_component(zombie)
	if atk == null:
		_expect(a, "攻击组件存在", false, true)
		return
	atk.owner_update_speed(0.0)
	_expect(a, "定身（speed=0）时发射计时器停表", atk.bullet_attack_cd_timer.paused, true)
	atk.owner_update_speed(0.5)
	_expect(a, "减速（speed=0.5）时发射计时器不停表", atk.bullet_attack_cd_timer.paused, false)
	atk.owner_update_speed(1.0)
	_expect(a, "恢复（speed=1）时发射计时器不停表", atk.bullet_attack_cd_timer.paused, false)

#endregion


#region 工具

func _spawn_zombie(a) -> Zombie000Base:
	var scene: PackedScene = Global.character_registry.get_zombie_info(
		C_ZOMBIE_TYPE, CharacterRegistry.ZombieInfoAttribute.ZombieScenes)
	if scene == null:
		_expect(a, "注册表里有豌豆僵尸场景", false, null)
		return null
	var zombie := scene.instantiate() as Zombie000Base
	if zombie == null:
		_expect(a, "豌豆僵尸场景可实例化", false, null)
		return null
	var tree := Engine.get_main_loop() as SceneTree
	zombie.position = Vector2(600, 300)
	tree.root.add_child(zombie)
	return zombie


func _head_track(zombie: Zombie000Base) -> Node2D:
	return zombie.get_node_or_null(ZombiePlantComponent.C_HEAD_TRACK_PATH) as Node2D


## 走组件自己的取点入口（探针断言点 = 游戏实际用的那一个），
## 兜底值给一个不可能等于正常结果的数：走到兜底说明头轨道丢了，必须 FAIL
func _shoot_pos(zombie: Zombie000Base) -> Vector2:
	var comp := zombie.get_node_or_null(^"ZombiePlantComponent") as ZombiePlantComponent
	if comp == null:
		return Vector2(-99999.0, -99999.0)
	return comp.get_head_shoot_global_position(Vector2(-99999.0, -99999.0))


func _attack_component(zombie: Zombie000Base) -> AttackComponentZomBotanyPea:
	return zombie.get_node_or_null(^"AttackComponent") as AttackComponentZomBotanyPea

#endregion


func _expect(a, name: String, got, want) -> void:
	if got == want:
		a.log("  OK   " + name + " = " + str(got))
	else:
		_failed += 1
		a.log("  FAIL " + name + " = " + str(got) + "（期望 " + str(want) + "）")


func _expect_vec(a, name: String, got: Vector2, want: Vector2) -> void:
	if got.is_equal_approx(want):
		a.log("  OK   " + name + " = " + str(got))
	else:
		_failed += 1
		a.log("  FAIL " + name + " = " + str(got) + "（期望 " + str(want) + "）")
