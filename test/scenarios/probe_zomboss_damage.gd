extends RefCounted
## 探针：僵王受击入口的伤害结算（普通子弹 / 火爆辣椒）
## 覆盖：5-10 进关 → 等博士出场 → 打开受击窗口后逐条断言：
##      1. 第一行（lane 0）的普通豌豆能直接命中僵王 —— 僵王不加入普通僵尸行列表（lane 恒为 -1），
##         它豁免子弹的同号限制，能否命中只由受击框的空间重叠决定；
##      2. 跨行的普通僵尸仍然不被其它行的子弹打到（同行限制没有跟着被放开）；
##      3. 任意行的火爆辣椒都能炸到僵王。
## 每次扣血前都重新打开受击窗口：状态机会在各技能小人 / 待机入口关掉它。
## 机器可读汇总：最后一行 [ZOMBOSSDAMAGE] result=PASS|FAIL failed=<n>

const LEVEL_05_10 := "res://src/levels/mode_adventure/adventure_05_10.gd"
## 豌豆的单发伤害，与 bullet_pea.tscn 的 attack_value 一致
const PEA_DAMAGE := 20
## 火爆辣椒对僵王的伤害，与 ZombieManager.jalapeno_bomb_lane_zombie 一致
const JALAPENO_DAMAGE := 1800

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 僵王受击伤害 ==========")
	if not await _boot(a):
		_finish(a)
		return

	var mg := Global.main_game
	var boss = await _wait_boss(a)
	if boss == null:
		_finish(a)
		return
	await a.wait(1.0)

	var hp = boss.get("hp_component")
	_check(a, "取到僵王血量组件", hp != null, "hp_component 为空")
	if hp == null:
		_finish(a)
		return

	await _check_pea_hits_boss(a, mg, boss, hp)
	await _check_lane_still_matters(a, mg, boss)
	await _check_jalapeno_hits_boss(a, mg, boss, hp)
	_check(a, "全程没有把博士打死", not boss.get("is_death"), "博士已死亡")
	_finish(a)


#region 各条断言
## 第 0 行的豌豆：僵王豁免同行限制，应直接吃到满额伤害。
func _check_pea_hits_boss(a, mg, boss, hp) -> void:
	var before: int = hp.curr_hp
	var dealt: int = await _deal_pea(a, mg, boss, 0)
	a.log("  第 0 行豌豆 -> 掉血 %d（boss.lane=%s）" % [dealt, str(boss.get("lane"))])
	_check(a, "第 0 行豌豆命中僵王 %d 点" % PEA_DAMAGE, dealt == PEA_DAMAGE, "掉血=%d 前/后=%d/%d"
		% [dealt, before, hp.curr_hp])
	hp.curr_hp = hp.max_hp


## 同行限制只对普通角色生效：其它行的豌豆仍打不到这一行的普通僵尸。
func _check_lane_still_matters(a, mg, boss) -> void:
	var zombie = _spawn_zombie_for_probe(mg, 2)
	if zombie == null:
		a.log("  [INFO] 造不出第 2 行的僵尸，跳过跨行回归（不算失败）")
		return
	await a.wait(1.0)
	if zombie.is_death or not is_instance_valid(zombie):
		a.log("  [INFO] 探针僵尸已被打死，跳过跨行回归（不算失败）")
		return
	var zhp = zombie.get("hp_component")
	var before: int = zhp.curr_hp
	var dealt: int = await _deal_pea(a, mg, zombie, 0)
	a.log("  第 0 行豌豆 -> 第 2 行僵尸掉血 %d" % dealt)
	_check(a, "跨行豌豆打不到普通僵尸", dealt == 0, "掉血=%d 前/后=%d/%d"
		% [dealt, before, zhp.curr_hp])
	zombie.character_death_disappear()


## 火爆辣椒：任意行都能炸到僵王，且按 1800 结算。
func _check_jalapeno_hits_boss(a, mg, boss, hp) -> void:
	hp.curr_hp = hp.max_hp
	_open_hurt_window(boss)
	var before: int = hp.curr_hp
	mg.zombie_manager.jalapeno_bomb_lane_zombie(0)
	await a.wait(0.3)
	var dealt: int = before - hp.curr_hp
	a.log("  第 0 行辣椒 -> 掉血 %d" % dealt)
	_check(a, "火爆辣椒对僵王造成 %d 点" % JALAPENO_DAMAGE, dealt == JALAPENO_DAMAGE,
		"掉血=%d 前/后=%d/%d" % [dealt, before, hp.curr_hp])
#endregion


#region 辅助
## 打开僵王受击窗口：状态机每次进 duty / 技能都会关掉它，扣血前重新开一次。
func _open_hurt_window(boss) -> void:
	var hurt = boss.get("hurt_box_component")
	if hurt == null:
		return
	hurt.enable_component(ComponentNormBase.E_IsEnableFactor.Character)


## 造一颗指定行的豌豆，手工把「僵王/僵尸的受击区域」喂给它的碰撞回调，返回实际掉血量。
func _deal_pea(a, mg, target, bullet_lane: int) -> int:
	var area := _get_first_hurt_area(target)
	if area == null:
		_check(a, "取到目标的受击区域", false, "受击组件下没有 Area2D")
		return 0
	var scene: PackedScene = Global.bullet_registry.get_bullet_scenes(BulletRegistry.BulletType.Bullet001Pea)
	if scene == null:
		_check(a, "注册表里有豌豆", false, "取不到 Bullet001Pea")
		return 0
	var bullet: Bullet000Base = scene.instantiate()
	var paras := {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: true,
		Bullet000NormBase.E_InitParasAttr.BulletLane: bullet_lane,
		Bullet000NormBase.E_InitParasAttr.Position: Vector2(80, 80),
		Bullet000NormBase.E_InitParasAttr.Direction: Vector2.RIGHT,
		Bullet000NormBase.E_InitParasAttr.BulletCamp: CharacterRegistry.CharacterType.Plant,
	}
	bullet.init_bullet(paras)
	mg.bullets.add_child(bullet)

	var target_hp = target.get("hp_component")
	var before: int = target_hp.curr_hp
	## 同一帧内开关受击窗口并结算，避免状态机在两帧之间把它关掉。
	_open_hurt_window(target)
	bullet._on_area_2d_attack_area_entered(area)
	var after_call: int = target_hp.curr_hp
	await a.wait(0.3)
	var dealt: int = before - target_hp.curr_hp
	## 命中过的子弹自己会 queue_free，重复释放会报错；这里只收尾。
	if is_instance_valid(bullet):
		bullet.queue_free()
	return dealt


## 取目标身上第一个受击 Area2D（伤害判定以它为单位，取哪个都一样）。
func _get_first_hurt_area(target) -> Area2D:
	var hurt = target.get("hurt_box_component")
	if hurt == null:
		return null
	for child in hurt.get_children():
		if child is Area2D:
			return child
	return null


## 在第 2 行造一只普通僵尸，只为验证同行限制没有被误放开。
func _spawn_zombie_for_probe(mg, lane: int):
	var zm = mg.zombie_manager
	var row = zm.all_zombie_rows[lane]
	var init_para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrWave: 1,
	}
	return zm.create_norm_zombie(
		CharacterRegistry.ZombieType.Z001Norm,
		row,
		init_para,
		row.zombie_create_position.global_position)


## 进入 5-10 并跳过选卡，返回主游戏是否可用。
func _boot(a) -> bool:
	var para: Resource = (load(LEVEL_05_10) as GDScript).new()
	if para == null:
		a.log("!! 关卡资源加载失败: " + LEVEL_05_10)
		return false
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameRoof]
	)
	await a.wait(3.0)
	var mg := Global.main_game
	_check(a, "已进入主游戏", mg != null, "Global.main_game 为空")
	if mg == null:
		return false
	if mg.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		mg.main_game_start()
	await a.wait(2.0)
	return Global.main_game != null


## 等博士出场（boss_spawn_wave = 0，开战即自动出场）。
func _wait_boss(a):
	var mg := Global.main_game
	for _i in 40:
		var bosses := mg.zombie_manager.get_living_bosses()
		if not bosses.is_empty():
			return bosses[0]
		await a.wait(0.5)
	_check(a, "博士已出场", false, "20 秒内没有僵王实例")
	return null
#endregion


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[ZOMBOSSDAMAGE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
