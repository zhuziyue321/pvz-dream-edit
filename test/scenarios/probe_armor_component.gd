extends RefCounted
## 探针：防具组件（`ArmorComponent`）的结构与结算回归
##
## 为什么有这个探针：
##   防具原先是 `HpComponentZombie` 上的两个固定槽位（`max_hp_armor1/2`），
##   改成"挂几个节点就有几层防具、同类可叠加"之后，场景里那个节点的
##   `armor_class` / `max_hp` / `body_change` 写错**在编辑器里看不出来**，
##   只有跑起来才发现「路障打不掉」或者「报纸掉了不暴走」。
##   这里锁死三件事：
##     1. 各僵尸场景的防具节点能被血量组件收集到，类别与血量对得上；
##     2. 伤害按「二类 → 一类 → 本体」逐层走，六种模式的分配没被改坏；
##     3. 同类防具可以叠加（`absorb_priority` 决定谁先挨打）。
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

var _failed := 0


func run(a) -> void:
	a.log("PROBE 防具组件 启动")
	await _enter_level(a)
	_check_scenes(a)
	await _check_damage_modes(a)
	await _check_stack_same_class(a)
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


func _apply(zombie: Zombie000Base, amount: int, mode: ConstDamage.E_DamageMode) -> void:
	var info := DamageInfo.create(zombie, amount, mode, ConstDamage.E_DamageCause.Bullet)
	DamageSystem.apply(info)


func _expect(a, name: String, got, want) -> void:
	if got == want:
		a.log("  [OK] " + name + " = " + str(got))
	else:
		_failed += 1
		a.log("  [NG] " + name + " = " + str(got) + "（期望 " + str(want) + "）")
#endregion
