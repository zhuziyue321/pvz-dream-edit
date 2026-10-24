extends RefCounted
## 探针：冰瓜的减速判据与寒冰豌豆一致（二类防具还在举着时不吃减速）
##
## 原版依据（`Zombie.cpp`）：`TakeShieldDamage()` 里**不调** `ApplyChill()`，
## 只有打在本体（`TakeBodyDamage`）或一类防具（`TakeHelmDamage`）上才上减速。
## 本作由防具组件回答 `is_slow_immune`，冰瓜的**直击 + 溅射**都要问它（对齐 `bullet_pea_snow.gd`）。
##
## 断言：
##   ① 铁门还举着：冰瓜砸过去不上减速
##   ② 铁门被打掉后再砸：上减速
##
## 机器可读汇总：最后一行 [WM_SLOW] result=PASS|FAIL failed=<n>

const MAP_FRONT := "res://data/map/map_front.tres"
const BULLET_SCENE := "res://src/entities/bullet/bullet_winter_melon.tscn"
const DOOR_ZOMBIE := &"screen_door"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 冰瓜减速 vs 二类防具 ==========")
	var mg = await _enter_level(a)
	if mg == null:
		_finish(a)
		return

	var zombie: Zombie000Base = _spawn_zombie(mg, DOOR_ZOMBIE, 1)
	if zombie == null:
		_check(a, "生成铁门僵尸", false)
		_finish(a)
		return
	await a.wait(0.8)
	_check(a, "铁门算二类防具（免疫减速）", zombie.is_slow_immune,
		"is_slow_immune=" + str(zombie.is_slow_immune))

	await _hit_with_winter_melon(a, mg, zombie)
	_check(a, "铁门还在：冰瓜不上减速", not _is_decelerated(zombie),
		"减速中=" + str(_is_decelerated(zombie)))

	## 把二类防具打光（走血量 setter，与真实破门同一条路径）
	var door_broken := false
	for armor in zombie.hp_component.armor_list:
		if armor.armor_class == ConstArmor.E_ArmorClass.Armor2:
			armor.curr_hp = 0
			door_broken = true
	_check(a, "找到并打掉铁门", door_broken, "armor_list=" + str(zombie.hp_component.armor_list.size()))
	await a.wait(0.5)

	await _hit_with_winter_melon(a, mg, zombie)
	_check(a, "铁门没了：冰瓜照常上减速", _is_decelerated(zombie),
		"减速中=" + str(_is_decelerated(zombie)))
	_finish(a)


## 直接让一颗冰瓜砸中目标（只借它的攻击入口，不走飞行 / 命中流程）
func _hit_with_winter_melon(a, mg, zombie: Zombie000Base) -> void:
	var bullet = load(BULLET_SCENE).instantiate()
	mg.add_child(bullet)
	bullet.lane = zombie.lane
	bullet.attack_once(zombie)
	await a.wait(0.2)
	if is_instance_valid(bullet):
		bullet.queue_free()


func _is_decelerated(zombie: Zombie000Base) -> bool:
	var timer = zombie.all_timer.get(Character000Base.E_TimerType.IceDecelerate)
	return timer != null and is_instance_valid(timer) and timer.time_left > 0.0


func _spawn_zombie(mg, zombie_type: StringName, row: int) -> Zombie000Base:
	var zm = mg.zombie_manager
	var row_node = zm.all_zombie_rows[row]
	return zm.create_norm_zombie(
		zombie_type,
		row_node,
		{
			Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane: row,
		},
		Vector2(620.0, row_node.zombie_create_position.global_position.y)
	)


func _enter_level(a):
	var para: ResourceLevelData = ResourceLevelData.new()
	para.map_data = load(MAP_FRONT)
	para.scene_name = SceneSettingRegistry.SCENE_FRONT_DAY
	Global.game_para = para
	await a.wait(1.0)
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	var waited := 0.0
	while waited < 30.0 and GameContext.curr_main_game == null:
		await a.wait(0.5)
		waited += 0.5
	if GameContext.curr_main_game == null:
		_check(a, "进入主游戏场景", false, "超时")
		return null
	_check(a, "进入主游戏场景", true)
	await a.wait(1.5)
	return GameContext.curr_main_game


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[WM_SLOW] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
