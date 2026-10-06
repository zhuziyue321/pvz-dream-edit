extends RefCounted
## 探针：冒险 3-5 与迷你游戏 10 的整关迷你僵尸规则。
## 覆盖关卡初始化参数、体型、血量，以及跳跃距离倍率和连续两次跳跃不衰减。

const LEVELS := [
	["冒险 3-5", "res://src/levels/mode_adventure/adventure_03_05.gd"],
	["迷你游戏 10", "res://src/levels/mode_minigame/minigame_10_mini_zombie.gd"],
]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 小僵尸（关卡下发 / 体型 / 血量 / 跳跃） ==========")
	for item: Array in LEVELS:
		await _run_level(a, item[0], item[1])
	_finish(a)


func _run_level(a, title: String, level_path: String) -> void:
	a.log("---- %s (%s)" % [title, level_path.get_file()])
	var para: ResourceLevelData = (load(level_path) as GDScript).new()
	if para == null:
		_check(a, title + ": 关卡脚本可实例化", false, level_path)
		return

	var extra := para.get_zombie_init_para_extra()
	_check(a, title + ": 关卡下发 IsMiniZombie",
		extra.get(Zombie000Base.E_ZInitAttr.IsMiniZombie, false) == true, str(extra))

	Global.game_para = para
	await a.frames(3)
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	await a.wait(3.0)

	var mg: MainGameManager = Global.main_game
	_check(a, title + ": 已进入主游戏", mg != null, "Global.main_game 为空")
	if mg == null:
		return
	var zm: ZombieManager = mg.zombie_manager
	_check(a, title + ": 僵尸行已初始化", not zm.all_zombie_rows.is_empty(), "没有僵尸行")
	if zm.all_zombie_rows.is_empty():
		return

	var norm := _spawn(zm, CharacterRegistry.ZombieType.Z001Norm, 0, 610.0)
	await a.wait(0.5)
	if not is_instance_valid(norm):
		_check(a, title + ": 普僵创建成功", false)
		return
	_check_mini_body_and_hp(a, title, norm)

	var jump_lane: int = mini(1, zm.all_zombie_rows.size() - 1)
	var pole := _spawn(zm, CharacterRegistry.ZombieType.Z004PoleVaulter, jump_lane, 700.0)
	await a.wait(0.5)
	if not is_instance_valid(pole):
		_check(a, title + ": 撑杆僵尸创建成功", false)
		norm.character_death_disappear()
		return
	_check(a, title + ": 撑杆僵尸体型为 0.5",
		is_equal_approx(absf(pole.scale.x), 0.5) and is_equal_approx(absf(pole.scale.y), 0.5),
		"scale=" + str(pole.scale))
	_check(a, title + ": 通用水平体型倍率为 0.5",
		is_equal_approx(absf(pole.scale.x), 0.5),
		"scale.x=" + str(pole.scale.x))
	await _check_jump_distance(a, title, pole)

	norm.character_death_disappear()
	pole.character_death_disappear()
	await a.wait(0.5)


func _spawn(zm: ZombieManager, zombie_type: CharacterRegistry.ZombieType, lane: int, x: float) -> Zombie000Base:
	var row: ZombieRow = zm.all_zombie_rows[lane]
	var init_para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType: row.zombie_row_type,
	}
	return zm.create_norm_zombie(zombie_type, row, init_para, Vector2(x, row.global_position.y))


func _check_mini_body_and_hp(a, title: String, zombie: Zombie000Base) -> void:
	_check(a, title + ": 普僵收到迷你规则", zombie.is_mini_zombie)
	_check(a, title + ": 普僵体型为 0.5",
		is_equal_approx(absf(zombie.scale.x), 0.5) and is_equal_approx(absf(zombie.scale.y), 0.5),
		"scale=" + str(zombie.scale))
	_check(a, title + ": 随机速度范围保持翻倍",
		zombie.random_speed_range.is_equal_approx(Vector2(1.8, 2.2)),
		"random_speed_range=" + str(zombie.random_speed_range))
	var hp := zombie.hp_component as HpComponentZombie
	_check(a, title + ": 普僵血量 270 → 135",
		hp.max_hp == 135 and hp.curr_hp == 135,
		"max_hp=%d curr_hp=%d" % [hp.max_hp, hp.curr_hp])


func _check_jump_distance(a, title: String, zombie: Zombie000Base) -> void:
	var jump := zombie.get_node_or_null(^"JumpComponent") as JumpComponent
	_check(a, title + ": 跳跃组件存在", jump != null)
	if jump == null:
		return
	var original_jump_x: float = jump.jump_x
	var moved: Array[float] = []
	for _i in range(2):
		jump.jump_start(false)
		var x_before: float = zombie.global_position.x
		await jump.jump_end()
		moved.append(x_before - zombie.global_position.x)
	_check(a, title + ": 两次跳跃均为 75px",
		is_equal_approx(moved[0], 75.0) and is_equal_approx(moved[1], 75.0),
		"moved=" + str(moved))
	_check(a, title + ": jump_x 未被累改",
		is_equal_approx(jump.jump_x, original_jump_x),
		"before=%s after=%s" % [original_jump_x, jump.jump_x])


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if not detail.is_empty() else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[MINIZOMBIE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
