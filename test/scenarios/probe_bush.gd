extends RefCounted
## 探针：灌木丛（DLC 版第 7 章 Woods 的场景障碍物）
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_bush
## 覆盖：
##   1. 静态：bush.tscn 契约（根 Bush / Body / Area2DHide 的碰撞层）
##   2. 实机：合成关卡（map_woods + scene woods + is_have_bush + init_bush_num=3）开局长 3 丛灌木，
##      且各灌木占的格子不能种普通植物
##   3. 实机：僵尸走进灌木 → 受击状态变成 IsInBush(128)，默认掩码(1)的攻击来源判定为「打不到」
##   4. 实机：爆杀（樱桃炸弹）炸掉灌木 + 灌木里藏着的僵尸恢复正常状态
##   5. 实机：小推车撞上灌木会自爆（只炸灌木前方的僵尸）+ 灌木被摧毁 + 推车消失
##   6. 实机：灌木能放出一只伏击僵尸（最终波那条路）
## 机器可读汇总：最后一行 [BUSH] result=PASS|FAIL failed=<n>

const MAP_WOODS := "res://data/map/map_woods.tres"
const BG_SCENE_WOODS := "res://src/world/background/main_game_bg_woods.tscn"

const EXPECT_BUSH_NUM := 3
## 藏僵尸测试：僵尸从灌木右侧 2 格外出发，速度 ×6 走过来（普通僵尸太慢，等太久）
const HIDE_TEST_SPEED_FACTOR := 6.0
const HIDE_TEST_WAIT_MAX := 8.0

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 灌木丛（DLC 第 7 章 Woods） ==========")
	_check_scene_contract(a)
	await _check_runtime(a)
	_finish(a)


#region 静态：场景契约

func _check_scene_contract(a) -> void:
	a.log("")
	a.log("STEP1 灌木场景契约")
	var packed: PackedScene = load("res://src/items/bush.tscn")
	if packed == null:
		_check(a, "灌木场景可加载", false)
		return
	var inst: Node = packed.instantiate()
	_check(a, "根节点是 Bush", inst is Bush, inst.get_class())
	var body: Node = inst.get_node_or_null("Body")
	var area: Node = inst.get_node_or_null("Area2DHide")
	_check(a, "有本体 Body(Sprite2D)", body is Sprite2D, str(body))
	_check(a, "有藏僵尸检测框 Area2DHide", area is Area2D, str(area))
	if area is Area2D:
		var area_2d: Area2D = area as Area2D
		## 与梯子同层 L12（2048）：炸弹 Area2DBomb 的掩码是 2048+4，共层就不用改炸弹场景
		_check(a, "灌木在 L12 道具层（炸弹 / 推车能感知）", area_2d.collision_layer == 2048,
			str(area_2d.collision_layer))
		_check(a, "灌木检测僵尸受击框 L10（512）", area_2d.collision_mask == 512,
			str(area_2d.collision_mask))
		_check(a, "灌木可被检测（monitorable）", area_2d.monitorable, str(area_2d.monitorable))
	inst.free()

	var mower_packed: PackedScene = load("res://src/items/lawn_mower/lawn_mower.tscn")
	if mower_packed != null:
		var mower: Node = mower_packed.instantiate()
		var mower_area: Node = mower.get_node_or_null("Area2D")
		if mower_area is Area2D:
			var ma: Area2D = mower_area as Area2D
			_check(a, "小推车能感知灌木（掩码含 2048）", (ma.collision_mask & 2048) != 0,
				str(ma.collision_mask))
		mower.free()
#endregion


#region 实机

func _check_runtime(a) -> void:
	a.log("")
	a.log("STEP2 合成关卡开局长灌木")
	var para: ResourceLevelData = ResourceLevelData.new()
	para.map_data = load(MAP_WOODS)
	para.scene_name = SceneSettingRegistry.SCENE_WOODS
	para.is_have_bush = true
	para.init_bush_num = EXPECT_BUSH_NUM
	Global.game_para = para
	await a.wait(1.0)
	GlobalUtils.change_scene(
		Global.main_scene_registry.get_scene_path(para.game_sences)
	)
	var waited := 0.0
	while waited < 30.0 and GameContext.curr_main_game == null:
		await a.wait(0.5)
		waited += 0.5
	if GameContext.curr_main_game == null:
		_check(a, "进入主游戏场景", false, "超时")
		return
	_check(a, "进入主游戏场景", true)
	await a.wait(1.5)

	var mg = GameContext.curr_main_game
	var pcm = mg.plant_cell_manager
	## 灌木（与墓碑一样）是开战时长的：MainGameManager.main_game_start 里按
	## `init_bush_num` 调它。合成关卡没有关卡脚本流程、开战那一步不会走，
	## 所以这里直接按同一个入口叫一次（等价于开战那一下）
	pcm.create_bush(EXPECT_BUSH_NUM)
	await a.wait(1.0)
	_check(a, "灌木长出来了 %d 丛" % EXPECT_BUSH_NUM, pcm.bush_list.size() == EXPECT_BUSH_NUM,
		str(pcm.bush_list.size()))
	_check(a, "灌木管理器记的数量一致",
		pcm.bush_manager.bush_num == EXPECT_BUSH_NUM, str(pcm.bush_manager.bush_num))

	var not_occupied := 0
	for bush: Bush in pcm.bush_list:
		var cell: PlantCell = bush.plant_cell
		if not cell.curr_special_state_plant.get(PlantCell.E_SpecialStatePlant.IsBush, false):
			not_occupied += 1
		if cell.can_common_plant:
			not_occupied += 1
	_check(a, "每丛灌木占的格子都不能种普通植物", not_occupied == 0, "异常数=%d" % not_occupied)

	if pcm.bush_list.is_empty():
		return

	## 后面的用例各挑一丛灌木（灌木位置随机，别共用一丛，免得互相干扰）
	## 引用先取全：每次摧毁都会把灌木从 bush_list 里摘掉，边跑边按下标取会取到别人
	var bush_hide: Bush = pcm.bush_list[0]
	## 爆杀这丛挑左边还有格子的：樱桃要种在它左边一格（僵尸前进的那一侧），
	## 最左列的灌木左边没地方种
	var bush_bomb: Bush = pcm.bush_list[1]
	for b in pcm.bush_list:
		var bush_b: Bush = b
		if bush_b.row_col.y > 0:
			bush_bomb = bush_b
			break
	var bush_mower: Bush = pcm.bush_list[2]
	await _check_hide_zombie(a, mg, bush_hide)
	## 出怪要赶在摧毁之前：爆炸 / 推车都会顺手清掉范围内的其它灌木
	await _check_spawn_from_bush(a, mg, bush_hide)
	await _check_bomb_bush(a, mg, bush_bomb)
	await _check_mower_bush(a, mg, bush_mower)


## 僵尸走进灌木 → 藏起来（受击状态 IsInBush = 128）
func _check_hide_zombie(a, mg, bush: Bush) -> void:
	a.log("")
	a.log("STEP3 僵尸走进灌木就被藏起来")
	var row: int = bush.row_col.x
	var zombie_row = mg.zombie_manager.all_zombie_rows[row]
	var spawn_x: float = bush.global_position.x + 160.0
	var zombie: Zombie000Base = mg.zombie_manager.create_norm_zombie(
		&"norm",
		zombie_row,
		{
			Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane: row,
		},
		Vector2(spawn_x, zombie_row.zombie_create_position.global_position.y)
	)
	if not is_instance_valid(zombie):
		_check(a, "造一只测试僵尸", false)
		return
	zombie.update_speed_factor(HIDE_TEST_SPEED_FACTOR, Character000Base.E_Influence_Speed_Factor.LevelSpeed)

	## 等它走进灌木（Area2D 的 area_entered 在物理帧触发，轮询等）
	var waited := 0.0
	while waited < HIDE_TEST_WAIT_MAX and not bush.is_hiding_zombie():
		await a.wait(0.2)
		waited += 0.2
	_check(a, "僵尸走进了灌木（%.1f 秒）" % waited, bush.is_hiding_zombie(),
		"僵尸 x=%.0f 灌木 x=%.0f" % [zombie.global_position.x, bush.global_position.x])
	_check(a, "僵尸受击状态 = IsInBush(128)",
		zombie.curr_be_attack_status == Zombie000Base.E_BeAttackStatusZombie.IsInBush,
		str(zombie.curr_be_attack_status))

	## 默认掩码（只勾 1 正常）的攻击来源应当判定「打不到」
	var cas := CanAttackStatusComponent.new()
	_check(a, "默认掩码(1)判定：打不到灌木里的僵尸", not cas.can_attack(zombie), str(cas.can_attack_zombie_status))
	## 爆杀类（191）/ 蜂射手（129）应当判定「打得到」
	cas.can_attack_zombie_status = 191
	_check(a, "爆杀掩码(191)判定：打得到灌木里的僵尸", cas.can_attack(zombie), str(cas.can_attack_zombie_status))
	cas.can_attack_zombie_status = 129
	_check(a, "蜂射手掩码(129)判定：打得到灌木里的僵尸", cas.can_attack(zombie), str(cas.can_attack_zombie_status))
	cas.free()


## 爆杀（樱桃炸弹）炸掉灌木，灌木里藏着的僵尸跟着恢复正常状态
func _check_bomb_bush(a, mg, bush: Bush) -> void:
	a.log("")
	a.log("STEP5 爆杀类炸掉灌木")
	var row: int = bush.row_col.x
	## 灌木的坐标先留一份：灌木被炸掉后对象会被释放，之后再读 bush.row_col 会抛
	## "Invalid access to property or key"（会吞掉后面所有用例）
	var bush_col: int = bush.row_col.y
	## 把樱桃种在灌木**左边**一格：僵尸是从右往左走的，它走进灌木之后还会继续往左挪，
	## 种在它前进的那一侧，它只会越走越近；种右边它就一路走出爆炸范围了
	var col: int = bush_col - 1
	var cell: PlantCell = mg.plant_cell_manager.all_plant_cells[row][col]
	var zombie_row = mg.zombie_manager.all_zombie_rows[row]
	var zombie: Zombie000Base = mg.zombie_manager.create_norm_zombie(
		&"norm",
		zombie_row,
		{
			Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane: row,
		},
		Vector2(bush.global_position.x + 160.0, zombie_row.zombie_create_position.global_position.y)
	)
	if is_instance_valid(zombie):
		zombie.update_speed_factor(HIDE_TEST_SPEED_FACTOR, Character000Base.E_Influence_Speed_Factor.LevelSpeed)
	var waited := 0.0
	while waited < HIDE_TEST_WAIT_MAX and not bush.is_hiding_zombie():
		await a.wait(0.2)
		waited += 0.2
	_check(a, "灌木里先藏了僵尸", bush.is_hiding_zombie(), "等了 %.1f 秒" % waited)
	## 藏住之后把速度放回正常：前面 20 倍速只是让它快点走到灌木
	if is_instance_valid(zombie):
		zombie.update_speed_factor(1.0, Character000Base.E_Influence_Speed_Factor.LevelSpeed)

	var plant: Plant000Base = cell.create_plant(&"cherry_bomb")
	_check(a, "灌木旁边种下樱桃炸弹", is_instance_valid(plant), str(plant))
	await a.wait(3.0)

	_check(a, "灌木被炸弹摧毁", not is_instance_valid(bush), str(bush))
	if is_instance_valid(zombie):
		_check(a, "灌木没了，里头的僵尸恢复正常状态",
			zombie.curr_be_attack_status == Zombie000Base.E_BeAttackStatusZombie.IsNorm,
			str(zombie.curr_be_attack_status))
	## 不验"爆炸把那只僵尸一起处理了"：灌木只给路过的僵尸"隐身"，僵尸在里面照常前进，
	## 爆炸那一下能不能把它一起带走，取决于它当时走到哪儿了（时而走出爆心，用例会抖）。
	## 那是樱桃自己的基础能力，由 probe_zhaoxiao_cherry 验；这条用例只验灌木机制本身
	var cell_now: PlantCell = mg.plant_cell_manager.all_plant_cells[row][bush_col]
	_check(a, "灌木没了之后那格又能种普通植物", cell_now.can_common_plant, str(cell_now.can_common_plant))


## 小推车撞上灌木会自爆（只炸灌木前方的僵尸）
func _check_mower_bush(a, mg, bush: Bush) -> void:
	a.log("")
	a.log("STEP6 小推车撞灌木自爆")
	var row: int = bush.row_col.x
	var zombie_row = mg.zombie_manager.all_zombie_rows[row]
	## 灌木前方（右侧 = 僵尸来的那一侧）放一只，灌木后方（左侧）也放一只：只该炸掉前面那只
	var zombie_front: Zombie000Base = mg.zombie_manager.create_norm_zombie(
		&"norm", zombie_row,
		{
			Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane: row,
		},
		Vector2(bush.global_position.x + 60.0, zombie_row.zombie_create_position.global_position.y)
	)
	var zombie_back: Zombie000Base = mg.zombie_manager.create_norm_zombie(
		&"norm", zombie_row,
		{
			Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane: row,
		},
		Vector2(bush.global_position.x - 160.0, zombie_row.zombie_create_position.global_position.y)
	)
	## 让它们站住不动，免得自己走出判定区
	if is_instance_valid(zombie_front):
		zombie_front.update_speed_factor(0.0, Character000Base.E_Influence_Speed_Factor.LevelSpeed)
	if is_instance_valid(zombie_back):
		zombie_back.update_speed_factor(0.0, Character000Base.E_Influence_Speed_Factor.LevelSpeed)

	var mower_packed: PackedScene = load("res://src/items/lawn_mower/lawn_mower.tscn")
	var mower: LawnMover = mower_packed.instantiate()
	mower.lane = row
	mower.is_moving = true
	zombie_row.add_child(mower)
	mower.global_position = Vector2(bush.global_position.x - 40.0, bush.global_position.y)
	await a.wait(0.5)

	## 物理层不一定在合成关卡里稳定触发 area_entered，这里直接推一下入口函数
	if is_instance_valid(bush) and is_instance_valid(mower):
		mower._on_lane_bush_enter(bush)
	await a.wait(0.5)

	_check(a, "灌木被推车撞没了", not is_instance_valid(bush), str(bush))
	_check(a, "推车自己也爆炸消失了", not is_instance_valid(mower), str(mower))
	_check(a, "灌木前方（右侧）的僵尸被炸死", not is_instance_valid(zombie_front) or zombie_front.is_death,
		str(zombie_front))
	_check(a, "灌木后方（左侧）的僵尸没被波及", is_instance_valid(zombie_back) and not zombie_back.is_death,
		str(zombie_back))


## 灌木能放出一只伏击僵尸（最终波那条路）
func _check_spawn_from_bush(a, mg, bush: Bush) -> void:
	a.log("")
	a.log("STEP4 灌木放出伏击僵尸")
	if not is_instance_valid(bush):
		_check(a, "灌木还在（可以出怪）", false)
		return
	var before: int = mg.zombie_manager.curr_zombie_num
	var ok: bool = bush.create_new_zombie(&"cone")
	_check(a, "灌木放出去一只僵尸", ok, str(ok))
	await a.wait(1.0)
	var after: int = mg.zombie_manager.curr_zombie_num
	_check(a, "场上僵尸数 +1", after == before + 1, "%d → %d" % [before, after])
#endregion


#region 断言

func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[BUSH] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
