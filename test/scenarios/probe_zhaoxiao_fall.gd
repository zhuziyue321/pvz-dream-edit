extends RefCounted
## 探针：模组「招笑版」的**摔倒机制**与**绊倒路障僵尸**（路障僵尸变种）
##
## ① 装上模组 → 绊倒路障僵尸热注册上（拿得到类型号）
## ② 摔倒机制本体：给一只普通僵尸挂上摔倒状态（`zhaoxiao_fall.gd`）→
##    · 身体倒平（|Body.rotation| ≈ 90°）、被抬到地面上（position.y 少一份 FALL_SINK_Y）
##    · 摔着的时候一步不挪（等 1 秒，x 不动）
##    · 到点自己站起来（rotation 回 0、position.y 还回去）并继续走（x 重新变小）
## ③ 绊倒路障僵尸：10 倍速 + 无视植物，走到从右侧数第 4 列摔倒 →
##    · 摔倒点就在第 4 列中心附近
##    · 头上的路障藏掉了、路障防具摘掉了（不再挡伤害）
##    · 摔倒点留下一根路障（位置对上、贴在本行地面上）
##    · 它自己也按摔倒机制的节奏爬起来继续走
## ④ 后来的僵尸被路障绊倒：在路障右边摆一只普通僵尸，任它自己走过去 →
##    · 走到路障身上被绊倒（摔倒状态挂上、就绊在路障那儿）
##    · 路障还在（永久存在，不淡出）
##    · 它爬起来继续走、越过路障，且**不会**被同一根路障绊第二次
##
## ⚠️ 踩过的坑（抄烟熏樱桃探针那三条）：
##   1. **别用 1-1**：教程关会推进教程流程、放教程僵尸，几秒内判负收摊。
##   2. **先把房子关掉**（`MainGameHome.disable_home()`）：探针要摆好几只僵尸，
##      任何一只走进房子都会把关卡收摊。房子在**背景子场景**里，要从场景根往下找。
##   3. 僵尸 spawn 完**立刻**用（出生点可能超出「僵尸可存在范围」被清掉）——
##      这里干脆自己指定 in-lawn 的 x，不等它自己走进来。
##   4. 用完的僵尸立刻 `character_death_disappear()` 清掉：10 倍速那只爬起来就往
##      小推车那边冲，别让它把小推车惹起来（会连带扫掉本行别的僵尸）。
##
## 机器可读汇总：最后一行 [ZHAOXIAO_FALL] result=PASS|FAIL failed=<n> checks=<n>

const Settings := preload("res://mods_builtin/zhaoxiao/zhaoxiao_settings.gd")
const FallStatus := preload("res://mods_builtin/zhaoxiao/zhaoxiao_fall.gd")
const ConeDrop := preload("res://mods_builtin/zhaoxiao/zhaoxiao_cone_drop.gd")

## 见文件头坑 1：不用教程关
const LEVEL := "res://src/levels/mode_adventure/adventure_01_10.gd"

var _failed := 0
var _checks := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：模组「招笑版」· 摔倒机制与绊倒路障僵尸 ==========")

	# ------------------------------------------------ STEP1 装模组 + 注册
	a.log("STEP1 装上模组 → 绊倒路障僵尸热注册上")
	ModManager.set_mod_enabled(ModIds.ZHAOXIAO, true)
	var cone_type: StringName = _cone_zombie_type()
	_check(a, "绊倒路障僵尸已热注册（拿得到类型号）", cone_type != ZombieIds.NULL, str(cone_type))
	if cone_type == ZombieIds.NULL:
		_finish(a)
		return

	# ------------------------------------------------ STEP2 进关
	a.log("STEP2 进一个白天关（不用教程关），先把房子关掉")
	var para = (load(LEVEL) as GDScript).new()
	if para == null:
		_check(a, "关卡脚本可实例化", false, LEVEL)
		_finish(a)
		return
	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	await a.wait(3.0)
	var mg = GameContext.curr_main_game
	if mg == null:
		_check(a, "已进入主游戏", false, "GameContext.curr_main_game 为空")
		_finish(a)
		return
	var home := _find_home(mg.get_tree().current_scene)
	_check(a, "找得到房子并把它关掉（探针不跑失败流程）", home != null, "没找到 MainGameHome")
	if home != null:
		home.disable_home()
	var lane := _first_land_lane(mg)
	_check(a, "找得到一行陆地行（探针在这一行摆僵尸）", lane >= 0, "lane=%d" % lane)
	if lane < 0:
		_finish(a)
		return
	## 先清一次场：自然出怪 / 关卡预置的僵尸别来捣乱
	_clear_zombies(mg)

	# ------------------------------------------------ STEP3 摔倒机制本体
	a.log("STEP3 摔倒机制：挂上摔倒状态 → 趴平、不动、到点自己站起来继续走")
	var walker := _spawn(mg, ZombieIds.NORM, lane, 500.0)
	await a.wait(0.8)
	if not is_instance_valid(walker):
		_check(a, "普通僵尸摆得下", false, "引用已释放")
	else:
		await _check_fall_mechanism(a, walker)
		if is_instance_valid(walker):
			walker.character_death_disappear()

	# ------------------------------------------------ STEP4 绊倒路障僵尸
	a.log("STEP4 绊倒路障僵尸：10 倍速走到第 4 列摔倒，路障掉在草坪上")
	_clear_zombies(mg)
	var fall_x := _fall_column_x(mg, lane)
	_check(a, "算得出第 4 列的中心 x", fall_x > 0.0, str(fall_x))
	var cone := _spawn(mg, cone_type, lane, _right_edge_x(mg, lane))
	var fell := await _poll(a, func():
		return is_instance_valid(cone) and cone.get_node_or_null(FallStatus.NODE_PATH) != null, 15.0)
	_check(a, "绊倒路障僵尸走到第 4 列摔倒了", fell)
	var drop: Node2D = null
	if fell and is_instance_valid(cone):
		_check(a, "摔倒点就在第 4 列中心附近",
			absf(cone.global_position.x - fall_x) < 15.0,
			"x=%.1f 期望≈%.1f" % [cone.global_position.x, fall_x])
		var cone_sprite := cone.get_node_or_null(^"Body/BodyCorrect/Anim_cone") as Node2D
		_check(a, "头上的路障藏掉了",
			cone_sprite != null and not cone_sprite.visible,
			"sprite=%s" % str(cone_sprite))
		_check(a, "路障防具摘掉了（不再挡伤害）",
			cone.get_armor(ConstArmor.E_ArmorType.Cone) == null,
			"防具=%s" % str(cone.get_armor(ConstArmor.E_ArmorType.Cone)))
		drop = _find_cone_drop_near(mg, fall_x)
		_check(a, "摔倒点留下一根路障", drop != null)
		if drop != null:
			_check(a, "路障就躺在摔倒点（x 对上）",
				absf(drop.global_position.x - cone.global_position.x) < 15.0,
				"路障 x=%.1f 僵尸 x=%.1f" % [drop.global_position.x, cone.global_position.x])
			_check(a, "路障贴在本行地面上（y 对上行地面）",
				absf(drop.global_position.y - mg.get_row_base_global_y(lane)) < 8.0,
				"路障 y=%.1f 地面 y=%.1f" % [drop.global_position.y, mg.get_row_base_global_y(lane)])
		## 它自己也按摔倒机制的节奏爬起来继续走（10 倍速，别让它往小推车冲太久）
		var got_up := await _poll(a, func():
			return not is_instance_valid(cone) \
				or cone.get_node_or_null(FallStatus.NODE_PATH) == null,
			Settings.FALL_TIME + 3.0)
		_check(a, "路障僵尸自己也爬起来站了起来", got_up and is_instance_valid(cone))
		if got_up and is_instance_valid(cone):
			_check(a, "爬起来时身体转回站姿", is_zero_approx(cone.body.rotation),
				str(cone.body.rotation))
			var x_up := cone.global_position.x
			await a.wait(0.6)
			_check(a, "爬起来继续走了（10 倍速，x 明显变小）",
				is_instance_valid(cone) and cone.global_position.x < x_up - 20.0,
				"x %.1f → %.1f" % [x_up, cone.global_position.x if is_instance_valid(cone) else -1.0])
	if is_instance_valid(cone):
		cone.character_death_disappear()

	# ------------------------------------------------ STEP5 后来的僵尸被路障绊倒
	a.log("STEP5 后来的僵尸走到路障上被绊倒；路障永久留着")
	_clear_zombies(mg)
	if drop == null or not is_instance_valid(drop):
		_check(a, "上一帧留下的路障还在（不然没得绊）", false, "引用已释放")
	else:
		var victim := _spawn(mg, ZombieIds.NORM, lane, drop.global_position.x + 70.0)
		var tripped := await _poll(a, func():
			return is_instance_valid(victim) and victim.get_node_or_null(FallStatus.NODE_PATH) != null, 15.0)
		_check(a, "后来的僵尸走到路障上被绊倒了", tripped)
		if tripped and is_instance_valid(victim):
			_check(a, "就绊在路障那儿（|x 差| ≤ 绊倒范围 %.0f）" % Settings.CONE_TRIP_RANGE,
				absf(victim.global_position.x - drop.global_position.x) <= Settings.CONE_TRIP_RANGE + 8.0,
				"差 %.1f 像素" % absf(victim.global_position.x - drop.global_position.x))
			_check(a, "路障还留在草坪上（绊完也没消失）", is_instance_valid(drop))
			## 等它自己站起来（摔倒状态的正常节奏）
			var stood := await _poll(a, func():
				return not is_instance_valid(victim) \
					or victim.get_node_or_null(FallStatus.NODE_PATH) == null,
				Settings.FALL_TIME + 3.0)
			_check(a, "被绊的僵尸自己站起来继续走了",
				stood and is_instance_valid(victim) \
					and victim.get_node_or_null(FallStatus.NODE_PATH) == null)
			if stood and is_instance_valid(victim):
				## 走路动画是「爆发式」位移（本体移动组件跟着地面标记走，见 component_move.gd），
				## 固定等 1 秒不一定越过路障 —— 这里轮询等它走过去
				var passed := await _poll(a, func():
					return not is_instance_valid(victim) \
						or victim.global_position.x < drop.global_position.x, 10.0)
				_check(a, "站起来后走过去了（x 继续变小、越过路障）",
					passed and is_instance_valid(victim) \
						and victim.global_position.x < drop.global_position.x,
					"x=%.1f（路障 %.1f）" % [
						victim.global_position.x if is_instance_valid(victim) else -1.0,
						drop.global_position.x])
				_check(a, "没有被同一根路障绊第二次",
					is_instance_valid(victim) \
						and victim.get_node_or_null(FallStatus.NODE_PATH) == null)
				_check(a, "路障仍然留在草坪上（永久存在）", is_instance_valid(drop))
		if is_instance_valid(victim):
			victim.character_death_disappear()

	# ------------------------------------------------ STEP6 关掉模组
	a.log("STEP6 关掉模组")
	ModManager.set_mod_enabled(ModIds.ZHAOXIAO, false)
	_check(a, "绊倒路障僵尸的类型号还回去了（已注销）",
		_cone_zombie_type() == ZombieIds.NULL, str(_cone_zombie_type()))
	## 开关是**持久化**的，跑完必须存回去，别把后面的探针带歪
	ModManager.save_mods()
	_finish(a)


#region 摔倒机制本体
## 给一只僵尸挂上摔倒状态，把「趴平 / 不动 / 自己起来 / 继续走」四件事都量一遍
func _check_fall_mechanism(a, zombie: Zombie000Base) -> void:
	var body_y_before := zombie.body.position.y
	var fall := FallStatus.new()
	fall.name = FallStatus.NODE_NAME
	zombie.add_child(fall)
	## 等倒下去那一下走完（FALL_TIPPING_TIME + 余量）
	await a.wait(Settings.FALL_TIPPING_TIME + 0.3)
	_check(a, "挂上了摔倒状态", zombie.get_node_or_null(FallStatus.NODE_PATH) != null)
	_check(a, "身体倒平了（|rotation| ≈ 90°）",
		absf(absf(zombie.body.rotation) - Settings.FALL_LIE_ANGLE) < 0.2,
		"rotation=%.3f" % zombie.body.rotation)
	_check(a, "身体被抬到地面上（position.y 少一份 FALL_SINK_Y）",
		absf(zombie.body.position.y - (body_y_before - Settings.FALL_SINK_Y)) < 2.0,
		"y %.1f → %.1f（期望 %.1f）" % [body_y_before, zombie.body.position.y,
			body_y_before - Settings.FALL_SINK_Y])
	var x_fallen := zombie.global_position.x
	await a.wait(1.0)
	_check(a, "摔着的那 1 秒里一步没挪", absf(zombie.global_position.x - x_fallen) < 1.0,
		"x %.1f → %.1f" % [x_fallen, zombie.global_position.x])
	## 到点自己站起来（FALL_TIME 从挂上算起，这会儿已经过了 ~1.6 秒）
	await a.wait(Settings.FALL_TIME - 1.6 + 0.6)
	_check(a, "到点自己站回来了（rotation 回 0）", is_zero_approx(zombie.body.rotation),
		"rotation=%.3f" % zombie.body.rotation)
	_check(a, "身体的 y 还回去了", absf(zombie.body.position.y - body_y_before) < 0.5,
		"y=%.1f（原来 %.1f）" % [zombie.body.position.y, body_y_before])
	## 走路动画是「爆发式」位移（本体移动组件跟着地面标记走，见 component_move.gd），
	## 固定等 0.6 秒不一定挪够 5 像素 —— 轮询等它重新走起来
	var resumed := await _poll(a, func():
		return not is_instance_valid(zombie) or zombie.global_position.x < x_fallen - 5.0, 5.0)
	_check(a, "站起来继续走了（x 重新变小）",
		resumed and is_instance_valid(zombie) and zombie.global_position.x < x_fallen - 5.0,
		"x %.1f → %.1f" % [x_fallen,
			zombie.global_position.x if is_instance_valid(zombie) else -1.0])
#endregion


#region 小工具
## 轮询等到某个条件成立（或超时）；返回是否等到
func _poll(a, condition: Callable, timeout: float, step: float = 0.2) -> bool:
	var waited := 0.0
	while waited < timeout:
		if condition.call():
			return true
		await a.wait(step)
		waited += step
	return condition.call()


## 绊倒路障僵尸的类型号（模组关着 / 没注册上时是 NULL）
func _cone_zombie_type() -> StringName:
	var mod = ModManager.get_mod(ModIds.ZHAOXIAO)
	if mod == null:
		return ZombieIds.NULL
	return mod.get_cone_zombie_type()


## 摆一只僵尸到指定行、指定世界 x（y 用该行的地面线）
##
## ⚠️ y 必须取 `zombie_create_position` 的世界 y（= `get_row_base_global_y()`）：
##    僵尸行节点本身在原点（见 `zombie_manager.gd` 的 `create_zombie_rows_from_map_data()`），
##    取行节点自己的 y 会把僵尸飘到半空。
func _spawn(mg, zombie_type: StringName, lane: int, x: float) -> Zombie000Base:
	var zm: ZombieManager = mg.zombie_manager
	var row: ZombieRow = zm.all_zombie_rows[lane]
	var init_para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType: row.zombie_row_type,
	}
	return zm.create_norm_zombie(zombie_type, row, init_para,
		Vector2(x, mg.get_row_base_global_y(lane)))


## 从右侧数第 4 列的中心 x（与 `zhaoxiao_cone_zombie.gd` 同一个口径）
func _fall_column_x(mg, lane: int) -> float:
	var row_cells: Array = mg.plant_cell_manager.all_plant_cells[lane]
	var col := clampi(row_cells.size() - Settings.CONE_ZOMBIE_FALL_COLUMN_FROM_RIGHT, 0,
		row_cells.size() - 1)
	var cell: PlantCell = row_cells[col] as PlantCell
	if cell == null:
		return -1.0
	return cell.global_position.x + cell.size.x * 0.5


## 本行最右一列的中心 x 再往右 40 像素（绊倒路障僵尸的出生点：让它自己走进来）
func _right_edge_x(mg, lane: int) -> float:
	var row_cells: Array = mg.plant_cell_manager.all_plant_cells[lane]
	var cell: PlantCell = row_cells[row_cells.size() - 1] as PlantCell
	if cell == null:
		return -1.0
	return cell.global_position.x + cell.size.x * 0.5 + 40.0


## 第一行陆地行（探针在这一行摆僵尸；水池行不摆）
func _first_land_lane(mg) -> int:
	var rows: Array = mg.zombie_manager.all_zombie_rows
	for i in range(rows.size()):
		if rows[i].zombie_row_type == CharacterRegistry.ZombieRowType.Land:
			return i
	return -1


## 找掉在 x 附近的那根路障（按组名扫全场，再按 x 就近）
func _find_cone_drop_near(mg, x: float, range_px: float = 40.0) -> Node2D:
	for node in mg.get_tree().get_nodes_in_group(ConeDrop.GROUP):
		if not is_instance_valid(node):
			continue
		if absf(node.global_position.x - x) <= range_px:
			return node as Node2D
	return null


## 清场（自然出怪的僵尸别来捣乱）；最后一波时清场会直接结算关卡，那样就别清
func _clear_zombies(mg) -> void:
	if mg.zombie_manager != null and not mg.zombie_manager.is_end_wave:
		mg.zombie_manager.death_all_zombie()
		await mg.get_tree().create_timer(0.3).timeout


## 场景树里那扇「房子」（按类型找，不猜路径）
func _find_home(node) -> MainGameHome:
	if node is MainGameHome:
		return node
	for child in node.get_children():
		var found := _find_home(child)
		if found != null:
			return found
	return null


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	_checks += 1
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[ZHAOXIAO_FALL] result=%s failed=%d checks=%d"
		% ["PASS" if _failed == 0 else "FAIL", _failed, _checks])
	a.finish(true)
#endregion
