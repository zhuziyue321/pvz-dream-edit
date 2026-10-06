extends RefCounted
## 探针：迷你游戏第 6 关「隐形战争」的**僵尸隐形**
## 覆盖：
##   ① 关卡脚本下发的僵尸初始化参数里真的带 IsInvisible（本体上没有 is_invisible_zombie 字段）
##   ② 出战僵尸本体 / 影子 alpha = 0（隐形），对照组 1-1 的僵尸 alpha 仍是 1
##   ③ 被冰冻（寒冰菇）时现形，解冻后重新隐形
##   ④ 被黄油（玉米投手）糊脸时现形，黄油掉落后重新隐形
## 机器可读汇总：最后一行 [INVISIGHOUL] result=PASS|FAIL failed=<n>

const LEVEL_INVISI := "res://src/levels/mode_minigame/minigame_06_invisi_ghoul.gd"
const LEVEL_1_1 := "res://src/levels/mode_adventure/adventure_01_01.gd"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 隐形战争（僵尸隐形 / 冰冻·黄油现形） ==========")
	await _run_one(a, "隐形战争", LEVEL_INVISI, true)
	await _run_one(a, "1-1对照", LEVEL_1_1, false)
	_finish(a)


func _run_one(a, title: String, level_path: String, expect_invisible: bool) -> void:
	a.log("---- " + title + " (" + level_path.get_file() + ") 期望隐形=" + str(expect_invisible))
	var para = (load(level_path) as GDScript).new()
	if para == null:
		_check(a, title + ": 关卡脚本可实例化", false, level_path)
		return
	Global.game_para = para
	## 让上一关的收尾（僵尸移除、节点增删）走完再切场景，否则 remove_child 会撞上 busy
	await a.frames(3)
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	await a.wait(3.0)

	var mg := Global.main_game
	_check(a, title + ": 已进入主游戏", mg != null, "Global.main_game 为空")
	if mg == null:
		return
	## 卡槽被系统自动填满时关卡已自己开了，重复触发会跑两遍开始流程
	if mg.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		mg.choosed_card_start_game()
	await a.wait(1.5)

	## ① 关卡下发的僵尸初始化参数（隐形是关卡脚本自己的设定，本体上没有 is_invisible_zombie 字段）
	var extra: Dictionary = para.get_zombie_init_para_extra()
	var extra_invisible: bool = extra.get(Zombie000Base.E_ZInitAttr.IsInvisible, false)
	_check(a, title + ": 初始化参数 IsInvisible=" + str(extra_invisible),
		extra_invisible == expect_invisible, "期望=" + str(expect_invisible))

	## 造一只普僵，直接看它的渲染状态
	var zm: ZombieManager = mg.zombie_manager
	if zm.zombies_root.get_child_count() == 0:
		_check(a, title + ": 有僵尸行", false, "zombies_root 没有子节点")
		return
	var row_node: Node = zm.zombies_root.get_child(0)
	var init_para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: 0,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType: CharacterRegistry.ZombieRowType.Land,
	}
	var z: Zombie000Base = zm.create_norm_zombie(
		CharacterRegistry.ZombieType.Z001Norm, row_node, init_para, Vector2(900, 100))
	await a.wait(0.5)
	if not is_instance_valid(z):
		_check(a, title + ": 僵尸创建成功", false, "实例无效")
		return

	## ② 隐形设定下发 + 本体 / 影子透明度
	_check(a, title + ": 僵尸 is_invisible=" + str(z.is_invisible),
		z.is_invisible == expect_invisible, "期望=" + str(expect_invisible))
	_expect_alpha(a, title + " 出场时", z, 0.0 if expect_invisible else 1.0)

	## ②' 隐形不影响被攻击（受击走受击框，与 alpha 无关）
	var hp_before: int = z.hp_component.get_all_hp()
	z.be_attacked_bullet(10)
	await a.frames(2)
	_check(a, title + ": 可被攻击（受击掉血）", z.hp_component.get_all_hp() < hp_before,
		"打前=" + str(hp_before) + " 打后=" + str(z.hp_component.get_all_hp()))

	## ③ 冰冻现形 → 解冻重新隐形
	z.be_ice_freeze(1.0, 1.0)
	await a.frames(3)
	_expect_alpha(a, title + " 冰冻中", z, 1.0)
	await a.wait(1.6)
	_expect_alpha(a, title + " 解冻后", z, 0.0 if expect_invisible else 1.0)

	## 等减速也走完，避免和黄油的状态叠在一起
	await a.wait(1.6)

	## ④ 黄油现形 → 黄油掉落后重新隐形
	z.be_butter(1.0)
	await a.frames(3)
	_expect_alpha(a, title + " 黄油中", z, 1.0)
	await a.wait(1.6)
	_expect_alpha(a, title + " 黄油掉落后", z, 0.0 if expect_invisible else 1.0)

	z.character_death_disappear()


#region 断言
## 本体与影子的 alpha 都要对得上
func _expect_alpha(a, label: String, z: Zombie000Base, expect: float) -> void:
	var body_a: float = z.body.modulate.a
	var shadow_a: float = z.shadow.modulate.a
	_check(a, label + ": body.modulate.a=" + str(snappedf(body_a, 0.01)),
		is_equal_approx(body_a, expect), "期望=" + str(expect))
	_check(a, label + ": shadow.modulate.a=" + str(snappedf(shadow_a, 0.01)),
		is_equal_approx(shadow_a, expect), "期望=" + str(expect))


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[INVISIGHOUL] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
