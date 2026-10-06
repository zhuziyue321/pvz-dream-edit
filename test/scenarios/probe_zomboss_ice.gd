extends RefCounted
## 探针：僵王博士的减速与冰冻（寒冰豌豆 / 寒冰菇）
## 覆盖：5-10 进关 → 等博士出场 → 逐条断言：
##      1. 寒冰豌豆命中僵王会施加减速 0.5 —— 僵王不是 Zombie000Base，没有二类防具门槛；
##      2. 寒冰菇全场冰冻能在受击窗口内冻住僵王：扣 20 血、动作倍率归零、冰块对齐影子；
##      3. 冻住期间状态机不再推进（动作计时器随角色倍率冻结）；
##      4. 解冻后转为减速 0.5。
## 每次结算前都重新打开受击窗口：状态机在各状态入口都会关掉它。
## 机器可读汇总：最后一行 [ZOMBOSSICE] result=PASS|FAIL failed=<n>

const LEVEL_05_10 := "res://src/levels/mode_adventure/adventure_05_10.gd"
## 冰冻附带的通用伤害，与 Character000Base.be_ice_freeze 一致
const ICE_FREEZE_DAMAGE := 20
## 本次冰冻时长 / 解冻后减速时长，单位为游戏秒
const FREEZE_TIME := 2.0
const DECELERATE_TIME := 1.5

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 僵王减速与冰冻 ==========")
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

	await _check_snow_pea_decelerate(a, mg, boss, hp)
	await _check_ice_shroom_freeze(a, mg, boss, hp)
	_check(a, "全程没有把博士打死", not boss.get("is_death"), "博士已死亡")
	_finish(a)


#region 各条断言
## 寒冰豌豆：僵王不吃普通僵尸的二类防具判定，命中即减速 0.5。
func _check_snow_pea_decelerate(a, mg, boss, hp) -> void:
	hp.curr_hp = hp.max_hp
	_cancel_ice(boss)
	var area := _get_first_hurt_area(boss)
	if area == null:
		_check(a, "取到僵王受击区域", false, "受击组件下没有 Area2D")
		return
	var scene: PackedScene = Global.bullet_registry.get_bullet_scenes(BulletRegistry.BulletType.Bullet002PeaSnow)
	if scene == null:
		_check(a, "注册表里有寒冰豌豆", false, "取不到 Bullet002PeaSnow")
		return
	var bullet: Bullet000Base = scene.instantiate()
	var paras := {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: true,
		Bullet000NormBase.E_InitParasAttr.BulletLane: 0,
		Bullet000NormBase.E_InitParasAttr.Position: Vector2(80, 80),
		Bullet000NormBase.E_InitParasAttr.Direction: Vector2.RIGHT,
		Bullet000NormBase.E_InitParasAttr.BulletCamp: CharacterRegistry.CharacterType.Plant,
	}
	bullet.init_bullet(paras)
	mg.bullets.add_child(bullet)
	## 同一帧内开关受击窗口并结算，避免状态机在两帧之间把它关掉。
	_open_hurt_window(boss)
	bullet._on_area_2d_attack_area_entered(area)
	await a.wait(0.3)
	var factor: float = _speed_factor(boss, Character000Base.E_Influence_Speed_Factor.IceDecelerateSpeed)
	a.log("  寒冰豌豆命中后减速倍率 = %s" % str(factor))
	_check(a, "寒冰豌豆让僵王减速 0.5", is_equal_approx(factor, 0.5), "倍率=%s" % str(factor))
	## 命中过的子弹自己会 queue_free，重复释放会报错；这里只收尾。
	if is_instance_valid(bullet):
		bullet.queue_free()


## 寒冰菇：受击窗口内冻住僵王，冻住期间动作计时器停摆、状态机不推进，解冻后转减速。
func _check_ice_shroom_freeze(a, mg, boss, hp) -> void:
	hp.curr_hp = hp.max_hp
	_cancel_ice(boss)
	await a.wait(0.2)
	var before: int = hp.curr_hp
	## 同一帧内开关受击窗口并结算，避免状态机在两帧之间把它关掉。
	_open_hurt_window(boss)
	mg.zombie_manager.ice_all_zombie(FREEZE_TIME, DECELERATE_TIME)
	await a.wait(0.3)
	var dealt: int = before - hp.curr_hp
	a.log("  寒冰菇 -> 掉血 %d（前/后=%d/%d）" % [dealt, before, hp.curr_hp])
	_check(a, "寒冰菇对僵王造成 %d 点" % ICE_FREEZE_DAMAGE, dealt == ICE_FREEZE_DAMAGE,
		"掉血=%d" % dealt)

	var freeze_factor: float = _speed_factor(boss, Character000Base.E_Influence_Speed_Factor.IceFreezeSpeed)
	a.log("  冰冻倍率 = %s" % str(freeze_factor))
	_check(a, "僵王被冻住（动作倍率 0）", is_equal_approx(freeze_factor, 0.0), "倍率=%s" % str(freeze_factor))

	var ice = boss.get("ice_effect")
	var shadow = boss.get("shadow")
	var ice_ok: bool = is_instance_valid(ice) and is_instance_valid(shadow) \
		and ice.global_position.is_equal_approx(shadow.global_position)
	_check(a, "冰块挂在僵王下并对齐影子", ice_ok,
		"冰块=%s 影子=%s" % [str(ice.global_position) if is_instance_valid(ice) else "无",
		str(shadow.global_position) if is_instance_valid(shadow) else "无"])

	var state_before: String = _state_name(boss)
	await a.wait(FREEZE_TIME * 0.6)
	_check(a, "冻住期间不出招（状态未推进）", _state_name(boss) == state_before,
		"%s -> %s" % [state_before, _state_name(boss)])

	await a.wait(0.6)
	var decelerate_factor: float = _speed_factor(boss, Character000Base.E_Influence_Speed_Factor.IceDecelerateSpeed)
	a.log("  解冻后减速倍率 = %s" % str(decelerate_factor))
	_check(a, "解冻后转减速 0.5", is_equal_approx(decelerate_factor, 0.5), "倍率=%s" % str(decelerate_factor))
	hp.curr_hp = hp.max_hp
#endregion


#region 辅助
## 打开僵王受击窗口：状态机每次进待机 / 技能都会关掉它，结算前重新开一次。
func _open_hurt_window(boss) -> void:
	var hurt = boss.get("hurt_box_component")
	if hurt == null:
		return
	hurt.enable_component(ComponentNormBase.E_IsEnableFactor.Character)


## 读僵王某个速度影响因素的当前倍率；未登记视为 1。
func _speed_factor(boss, factor) -> float:
	return float(boss.influence_speed_factors.get(factor, 1.0))


## 清掉上一次残留的冰冻 / 减速，避免干扰下一条断言。
func _cancel_ice(boss) -> void:
	if boss.has_method("cancel_ice"):
		boss.cancel_ice()


## 当前状态名；状态机未就绪时返回空串。
func _state_name(boss) -> String:
	var sm = boss.get("state_machine")
	if sm == null:
		return ""
	var current = sm.get("current_state")
	return current.name if is_instance_valid(current) else ""


## 取目标身上第一个受击 Area2D（伤害判定以它为单位，取哪个都一样）。
func _get_first_hurt_area(target) -> Area2D:
	var hurt = target.get("hurt_box_component")
	if hurt == null:
		return null
	for child in hurt.get_children():
		if child is Area2D:
			return child
	return null


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
	a.log("[ZOMBOSSICE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
