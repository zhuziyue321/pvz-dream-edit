extends RefCounted
## 探针：防具组件（`ArmorComponent`）的结构与结算回归
##
## 为什么有这个探针：
##   防具原先是 `HpComponentZombie` 上的两个固定槽位（`max_hp_armor1/2`），
##   改成"挂几个节点就有几层防具、同类可叠加"之后，场景里那个节点的
##   `armor_class` / `max_hp` / `body_change` 写错**在编辑器里看不出来**，
##   只有跑起来才发现「路障打不掉」或者「报纸掉了不暴走」。
##   这里锁死四件事：
##     1. 各僵尸场景的防具节点能被血量组件收集到，类别与血量对得上；
##     2. 伤害按「二类 → 一类 → 本体」逐层走，六种模式的分配没被改坏；
##     3. 同类防具可以叠加（`absorb_priority` 决定谁先挨打）；
##     4. 防具在 ② 加工阶段**先于本体**拿到包，且能整包取消（`process_damage()`）。
##
## 只做静态 + 单次结算检查：进一个普通白天关（只为拿到 `zombie_manager` ——
## 防具破损掉落的掉落物要挂到它下面，关卡之外会报 Nil），不出怪、不打完一整关。

const C_LEVEL := "res://src/levels/mode_adventure/adventure_01_day_test.gd"

const C_ARMOR_SCENES := [
	["路障", "res://src/entities/character/zombie/zombie_cone.tscn", ConstArmor.E_ArmorClass.Armor1, 370],
	["铁桶", "res://src/entities/character/zombie/zombie_bucket.tscn", ConstArmor.E_ArmorClass.Armor1, 1100],
	["橄榄球", "res://src/entities/character/zombie/zombie_football.tscn", ConstArmor.E_ArmorClass.Armor1, 1400],
	["铁门", "res://src/entities/character/zombie/zombie_screendoor.tscn", ConstArmor.E_ArmorClass.Armor2, 1100],
	["报纸", "res://src/entities/character/zombie/zombie_paper.tscn", ConstArmor.E_ArmorClass.Armor2, 150],
	["梯子", "res://src/entities/character/zombie/zombie_ladder.tscn", ConstArmor.E_ArmorClass.Armor2, 500],
	["气球", "res://src/entities/character/zombie/zombie_balloon.tscn", ConstArmor.E_ArmorClass.Armor1, 20],
	["矿工镐", "res://src/entities/character/zombie/zombie_digger.tscn", ConstArmor.E_ArmorClass.Armor1, 100],
	["坚果僵尸", "res://src/entities/character/zombie/zombie_wall_nut.tscn", ConstArmor.E_ArmorClass.Armor1, 1100],
	["高坚果僵尸", "res://src/entities/character/zombie/zombie_tall_nut.tscn", ConstArmor.E_ArmorClass.Armor1, 2200],
	["豌豆僵尸", "res://src/entities/character/zombie/zombie_pea_shooter.tscn", ConstArmor.E_ArmorClass.Armor1, 300],
]

## 探针自用：一层"只对爆炸免疫"的防具 —— 证明防具能在 ② 加工阶段**先于本体**整包取消。
##
## ⚠️ 吸收已经并入 `process_damage()`，所以放行时必须 `return super(info)` 让本层照常吃伤害；
## 不能像旧实现那样只 `return true`（那样这层就永远不掉血了）。
class _ArmorImmuneBomb extends ArmorComponent:
	func process_damage(info: DamageInfo) -> bool:
		if info.cause == ConstDamage.E_DamageCause.Bomb:
			return false
		return super(info)


var _failed := 0


func run(a) -> void:
	a.log("PROBE 防具组件 启动")
	await _enter_level(a)
	_check_scenes(a)
	await _check_damage_modes(a)
	await _check_all_modes_do_damage(a)
	await _check_stack_same_class(a)
	await _check_armor_process_first(a)
	await _check_cancel_keeps_absorbed_hp(a)
	_check_effects(a)
	a.log("")
	a.log("[ARMOR] result=%s failed=%d" % [("PASS" if _failed == 0 else "FAIL"), _failed])
	a.quit_game()


## 场景落地：防具节点挂上了、类别与血量对得上
func _check_scenes(a) -> void:
	for item: Array in C_ARMOR_SCENES:
		var title: String = item[0]
		var path: String = item[1]
		var scene: PackedScene = load(path)
		if scene == null:
			_failed += 1
			a.log("  [NG] " + title + " 场景加载失败 " + path)
			continue
		var zombie: Zombie000Base = scene.instantiate()
		Engine.get_main_loop().root.add_child(zombie)
		var hp := zombie.hp_component as HpComponentZombie
		var armors := hp.get_all_armors()
		_expect(a, title + " 防具层数", armors.size(), 1)
		if armors.is_empty():
			zombie.queue_free()
			continue
		_expect(a, title + " 防具类别", armors[0].armor_class, item[2])
		_expect(a, title + " 防具血量", armors[0].max_hp, item[3])
		_expect(a, title + " 防具满血", armors[0].curr_hp, item[3])
		zombie.queue_free()
	await a.frames(2)


## 四种典型伤害模式的分配（与原版口径一致）
func _check_damage_modes(a) -> void:
	## Norm：二类 / 一类防具扣光后溢出到本体
	var cone := _spawn("res://src/entities/character/zombie/zombie_cone.tscn")
	if cone == null:
		return
	var cone_hp := cone.hp_component as HpComponentZombie
	var cone_body_before := cone_hp.curr_hp
	_apply(cone, 400, ConstDamage.E_DamageMode.Norm)
	_expect(a, "Norm 打路障 400：一类防具扣光", cone_hp.get_all_armors()[0].curr_hp, 0)
	_expect(a, "Norm 打路障 400：溢出 30 到本体", cone_body_before - cone_hp.curr_hp, 30)
	cone.queue_free()

	## Penetration：二类防具照扣但不消耗伤害，伤害继续打本体
	var door := _spawn("res://src/entities/character/zombie/zombie_screendoor.tscn")
	if door == null:
		return
	var door_hp := door.hp_component as HpComponentZombie
	var door_body_before := door_hp.curr_hp
	_apply(door, 100, ConstDamage.E_DamageMode.Penetration)
	_expect(a, "穿透打铁门 100：二类防具照扣", door_hp.get_all_armors()[0].curr_hp, 1000)
	_expect(a, "穿透打铁门 100：本体也扣 100", door_body_before - door_hp.curr_hp, 100)
	door.queue_free()

	## Real：跳过二类防具，直接打本体
	var door2 := _spawn("res://src/entities/character/zombie/zombie_screendoor.tscn")
	if door2 == null:
		return
	var door2_hp := door2.hp_component as HpComponentZombie
	var door2_body_before := door2_hp.curr_hp
	_apply(door2, 100, ConstDamage.E_DamageMode.Real)
	_expect(a, "真实伤害打铁门 100：二类防具不掉血", door2_hp.get_all_armors()[0].curr_hp, 1100)
	_expect(a, "真实伤害打铁门 100：本体扣 100", door2_body_before - door2_hp.curr_hp, 100)
	door2.queue_free()

	## Hammer：无视二类防具，一类防具 900 且不溢出
	var cone2 := _spawn("res://src/entities/character/zombie/zombie_cone.tscn")
	if cone2 == null:
		return
	var cone2_hp := cone2.hp_component as HpComponentZombie
	var cone2_body_before := cone2_hp.curr_hp
	_apply(cone2, 100, ConstDamage.E_DamageMode.Hammer)
	_expect(a, "锤子打路障：一类防具 -900 直接破", cone2_hp.get_all_armors()[0].is_broken, true)
	_expect(a, "锤子打路障：不溢出到本体", cone2_body_before - cone2_hp.curr_hp, 0)
	cone2.queue_free()
	await a.frames(2)


## U-33 护栏：遍历**全部** `E_DamageMode` —— 每种模式都必须真的掉血
##
## 为什么要它：模式的分配写在**两处 `match`**（`ArmorComponent.get_absorb_rule()` 负责防具吃多少，
## `HpComponentZombie.get_body_damage()` 负责本体吃多少）。新增一种模式漏改任一处，症状是
## **静默不掉血** —— 编译能过、别的探针也都绿。这里对每种模式打一笔足以破防的伤害，
## 断言「防具 + 本体」总血确实减少，漏改的模式会当场变红。
func _check_all_modes_do_damage(a) -> void:
	for mode: ConstDamage.E_DamageMode in ConstDamage.E_DamageMode.values():
		var zombie := _spawn("res://src/entities/character/zombie/zombie_cone.tscn")
		if zombie == null:
			return
		var hp := zombie.hp_component as HpComponentZombie
		var before: int = hp.get_all_hp()
		var mode_name := str(ConstDamage.E_DamageMode.find_key(mode))
		## 400 足以打穿路障那 370 点；保龄球 / 锤子走固定值一样要掉血
		var result := _apply(zombie, 400, mode)
		var real_loss := before - hp.get_all_hp()
		_expect(a, "模式 %s 打下去有掉血（防具或本体）" % mode_name, real_loss > 0, true)
		## `hp_loss` = 防具 + 本体一起算的掉血，必须与实测一致
		_expect(a, "模式 %s 的结果 hp_loss 与实测一致" % mode_name, result.hp_loss, real_loss)
		zombie.queue_free()
	await a.frames(2)


## L-16 护栏：**靠里的防具取消整包时，外层已经吸收掉的血要反映到结果里**
##
## 吸收在 ②-a 就地发生（见 `ArmorComponent.process_damage()`），所以靠里的取消挡不住
## 外层已经扣掉的血。若 `DamageSystem.apply()` 的取消分支只报「没生效」而不填血量快照，
## 调用方拿到的 `hp_loss` 就是 0 —— 与真实掉血不符（`DAMAGE_APPLIED` 也会漏广播）。
func _check_cancel_keeps_absorbed_hp(a) -> void:
	var zombie := _spawn_raw("res://src/entities/character/zombie/zombie_cone.tscn")
	if zombie == null:
		return
	## 外层：普通防具，priority 大 ⇒ 先挨打、先吸收
	var outer := ArmorComponent.new()
	outer.name = &"ArmorComponentOuter"
	outer.armor_type = ConstArmor.E_ArmorType.Cone
	outer.armor_class = ConstArmor.E_ArmorClass.Armor2
	outer.absorb_priority = 9
	outer.max_hp = 100
	zombie.add_child(outer)
	## 内层：免疫爆炸 ⇒ 轮到它时整包取消（但外层那 30 点已经扣掉了）
	var inner := _ArmorImmuneBomb.new()
	inner.name = &"ArmorComponentImmuneBombInner"
	inner.armor_type = ConstArmor.E_ArmorType.Cone
	inner.armor_class = ConstArmor.E_ArmorClass.Armor2
	inner.absorb_priority = 0
	inner.max_hp = 100
	zombie.add_child(inner)
	Engine.get_main_loop().root.add_child(zombie)

	var hp := zombie.hp_component as HpComponentZombie
	var before: int = hp.get_all_hp()
	var result := _apply(zombie, 30, ConstDamage.E_DamageMode.Norm, ConstDamage.E_DamageCause.Bomb)
	_expect(a, "靠里的防具取消整包：原因 = Armor", result.cancel_reason,
		ConstDamage.E_CancelReason.Armor)
	_expect(a, "靠里的防具取消整包：外层仍吸收了 30", outer.curr_hp, 70)
	_expect(a, "靠里的防具取消整包：内层完好", inner.curr_hp, 100)
	_expect(a, "靠里的防具取消整包：结果 hp_loss 反映外层掉血", result.hp_loss, 30)
	_expect(a, "靠里的防具取消整包：总血实测也少 30", before - hp.get_all_hp(), 30)
	zombie.queue_free()
	await a.frames(2)


## 同类防具叠加：`absorb_priority` 大的在外层、先挨打
func _check_stack_same_class(a) -> void:
	var zombie := _spawn_raw("res://src/entities/character/zombie/zombie_cone.tscn")
	if zombie == null:
		return
	## 再挂一层同类防具，优先级更高 ⇒ 排在场景里那层（路障）外面
	var outer := ArmorComponent.new()
	outer.name = &"ArmorComponentOuter"
	outer.armor_type = ConstArmor.E_ArmorType.Cone
	outer.armor_class = ConstArmor.E_ArmorClass.Armor1
	outer.absorb_priority = 1
	outer.max_hp = 100
	zombie.add_child(outer)
	Engine.get_main_loop().root.add_child(zombie)

	var hp := zombie.hp_component as HpComponentZombie
	var armors := hp.get_all_armors()
	_expect(a, "叠一层同类防具后的层数", armors.size(), 2)
	if armors.size() < 2:
		zombie.queue_free()
		await a.frames(2)
		return
	_expect(a, "优先级高的排在外层", armors[0] == outer, true)
	_expect(a, "两层防具都进总血", hp.get_all_hp() - hp.curr_hp, 470)

	## 打 150：外层 100 扣光，剩下 50 溢到内层路障
	_apply(zombie, 150, ConstDamage.E_DamageMode.Norm)
	_expect(a, "外层同类防具先扣光", outer.curr_hp, 0)
	_expect(a, "溢出 50 打到内层路障", armors[1].curr_hp, 320)
	zombie.queue_free()
	await a.frames(2)


## 防具在 ② 加工阶段**先于本体**拿到包，且能整包取消（见 `ArmorComponent.process_damage()`）
func _check_armor_process_first(a) -> void:
	var zombie := _spawn_raw("res://src/entities/character/zombie/zombie_cone.tscn")
	if zombie == null:
		return
	## 挂一层"免疫爆炸"的防具，排在最外面（absorb_priority 最大）
	var armor := _ArmorImmuneBomb.new()
	armor.name = &"ArmorComponentImmuneBomb"
	armor.armor_type = ConstArmor.E_ArmorType.Cone
	armor.armor_class = ConstArmor.E_ArmorClass.Armor2
	armor.absorb_priority = 9
	armor.max_hp = 100
	zombie.add_child(armor)
	Engine.get_main_loop().root.add_child(zombie)

	var hp := zombie.hp_component as HpComponentZombie
	var before: int = hp.get_all_hp()

	## 爆炸：最外层防具在 ② 取消了整包 —— 连它自己那 100 点血都不掉
	var bomb_result := _apply(zombie, 999, ConstDamage.E_DamageMode.Norm,
		ConstDamage.E_DamageCause.Bomb)
	_expect(a, "防具在 ② 取消整包：总血不变", hp.get_all_hp(), before)
	_expect(a, "防具在 ② 取消整包：原因 = Armor", bomb_result.cancel_reason,
		ConstDamage.E_CancelReason.Armor)
	_expect(a, "防具在 ② 取消整包：防具也完好", armor.curr_hp, 100)

	## 子弹：同一层防具放行，伤害照常按防具链结算
	_apply(zombie, 30, ConstDamage.E_DamageMode.Norm, ConstDamage.E_DamageCause.Bullet)
	_expect(a, "防具放行时照常结算", before - hp.get_all_hp(), 30)
	_expect(a, "防具放行时由最外层先吃", armor.curr_hp, 70)
	zombie.queue_free()
	await a.frames(2)


## 防具存在时的特殊效果由防具组件自己回答
func _check_effects(a) -> void:
	var door := _spawn("res://src/entities/character/zombie/zombie_screendoor.tscn")
	if door != null:
		_expect(a, "举着二类防具（铁门）免疫减速", door.is_slow_immune, true)
		door.queue_free()
	var cone := _spawn("res://src/entities/character/zombie/zombie_cone.tscn")
	if cone != null:
		_expect(a, "只戴一类防具（路障）不免疫减速", cone.is_slow_immune, false)
		cone.queue_free()
	await a.frames(2)


#region 工具
## 进一个普通白天关，只为拿到 zombie_manager（见文件头的说明）
func _enter_level(a) -> void:
	var para: ResourceLevelData = (load(C_LEVEL) as GDScript).new()
	if para == null:
		_failed += 1
		a.log("  [NG] 关卡脚本实例化失败 " + C_LEVEL)
		return
	Global.game_para = para
	await a.frames(3)
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	await a.wait(3.0)
	if GameContext.curr_main_game == null:
		_failed += 1
		a.log("  [NG] 未能进入主游戏，防具掉落没有 zombie_manager 可挂")


## 实例化并立即入树（`add_child` 会同步跑完所有子节点的 `_ready()`）
func _spawn(path: String) -> Zombie000Base:
	var zombie := _spawn_raw(path)
	if zombie != null:
		Engine.get_main_loop().root.add_child(zombie)
	return zombie


## 只实例化、不入树（给要在 `_ready()` 之前改节点结构的用例用）
func _spawn_raw(path: String) -> Zombie000Base:
	var scene: PackedScene = load(path)
	if scene == null:
		return null
	return scene.instantiate() as Zombie000Base


func _apply(zombie: Zombie000Base, amount: int, mode: ConstDamage.E_DamageMode,
		cause: ConstDamage.E_DamageCause = ConstDamage.E_DamageCause.Bullet) -> DamageResult:
	var info := DamageInfo.create(zombie, amount, mode, cause)
	return DamageSystem.apply(info)


func _expect(a, name: String, got, want) -> void:
	if got == want:
		a.log("  [OK] " + name + " = " + str(got))
	else:
		_failed += 1
		a.log("  [NG] " + name + " = " + str(got) + "（期望 " + str(want) + "）")
#endregion
