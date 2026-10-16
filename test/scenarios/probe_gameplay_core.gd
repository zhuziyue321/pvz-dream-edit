extends RefCounted
## 探针 GAMEPLAY_CORE：玩法主链路回归（对应 docs/TODO清单.md 的 H-10）
##
## 【为什么要有这一条】
##   `test/scenarios/` 下已有的 100+ 个探针几乎都是**结构 / 流程探针** —— 它们证明「对象按预期建出来了」，
##   但**没有一条**能证明「打起来了」：唯一真的种下植物的 `probe_plant`，种植环节判 `plant_result=SKIP`
##   （合成鼠标输入的限制）；而编译门禁 `check_scripts.ps1` 自己写明连「方法在基类上不存在」都抓不到。
##   于是「改动触达角色 / 子弹 / 伤害管线」这类改动的唯一防线，长期是**人的记忆**。
##   本探针补的就是这一段：**种下去 → 索敌开火 → 子弹命中 → 掉血 → 死亡**，四段全落成机器可读断言。
##
## 【覆盖的链路】（`架构总览.md` §12.2「一帧内的典型链路」的机器化版本）
##   PlantCell.create_plant → DetectComponent 索敌 → AttackComponent 四因素全真
##   → bullet_registry.create_bullet → 子弹飞行 → Area2DAttack 命中 ZombieHurtBoxReal
##   → HpComponent.curr_hp 下降 → hp_loss_to_death → character_death / signal_character_death
##
## 【机器可读汇总】最后一行 `[GAMEPLAY] result=PASS|FAIL failed=<n>`（`run_all_scenarios.ps1` 只认这行）
##
## 【⚠️ 写了检查必须自证它拦得住】改坏一次再重跑，本探针**必须** FAIL，否则等于没写（H-10 的验收口径）：
##   · 把 `data/character/registry_data/plant_info_data.gd` 里豌豆射手的攻击力改成 0，或
##   · 让 `bullet_registry.create_bullet()` 直接 `return null`
##   → 两种改法都应让「子弹命中：僵尸掉血」这组断言变红。
##
## 【已知边界】（写清是为了后人不必重新判定一遍，见规范细则存档 E-07）
##   · 只覆盖「普通僵尸 × 豌豆射手」这一条**最常用**的链路；投手 / 穿透 / 追踪 / 溅射子弹各有分支，未覆盖。
##   · 种植走**代码路径**（`PlantCell.create_plant()`，与游戏内种植同一个入口），**不碰 UI 点击** ——
##     合成鼠标事件在本仓库实测不可靠（见 `probe_plant.gd` 文件头）。
##   · 掉落物（金币 / 阳光）的出现带随机性，只打印不判定；判定只认「掉血」与「死亡信号」这类确定性事实。

const LEVEL := "res://src/levels/mode_adventure/adventure_01_01.gd"
## 僵尸行（植物也种在这一行）：0 = 最上行
const LANE := 0
## 等「僵尸走进射程 → 开火 → 子弹飞到 → 命中」的上限（秒）；实测正常在 3~6 秒内掉血
const HIT_WAIT_MAX := 20.0
## 等尸体离场的上限（秒）；正常死亡动画播完 1~4 秒
const GONE_WAIT_MAX := 6.0

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE GAMEPLAY_CORE 玩法主链路 ==========")
	if not await _boot(a):
		_finish(a)
		return
	var cell := _pick_cell(a, LANE)
	if cell == null:
		_finish(a)
		return
	if not await _plant_pea_shooter(a, cell):
		_finish(a)
		return
	var zombie := await _spawn_zombie(a, LANE)
	if zombie == null:
		_finish(a)
		return
	await _check_fire_and_hit(a, zombie)
	await _check_death(a, zombie)
	_finish(a)


#region 关卡准备

func _boot(a) -> bool:
	var para: Resource = (load(LEVEL) as GDScript).new()
	if para == null:
		a.log("!! 关卡资源加载失败: " + LEVEL)
		_check(a, "关卡资源可加载", false, LEVEL)
		return false
	Global.game_para = para
	GlobalUtils.change_scene(
		Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.MainGameFront)
	)
	await a.wait(2.0)
	if GameContext.curr_main_game == null:
		a.log("!! GameContext.curr_main_game 为空")
		_check(a, "主游戏已就绪", false, "curr_main_game 为空")
		return false
	## 卡槽被系统自动填满时关卡会跳过选卡，这里不要重复触发开始流程
	if GameContext.curr_main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		GameContext.curr_main_game.main_game_start()
	## 等真正进入游戏阶段：1-1 会自动开局，但阶段推进要几拍
	var waited := 0.0
	while GameContext.curr_main_game.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME \
			and waited < 30.0:
		await a.wait(1.0)
		waited += 1.0
	var mg: MainGameManager = GameContext.curr_main_game
	var ok: bool = mg.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME
	_check(a, "进入主游戏阶段", ok, "progress=%d 等待=%.1fs" % [mg.main_game_progress, waited])
	return ok


## 本探针只种一格：挑该行**最靠右**的空格子 —— 僵尸从右侧入场，这样它一进场就进射程，等待时间最短
func _pick_cell(a, lane: int) -> PlantCell:
	var mgr := GameContext.curr_main_game.plant_cell_manager
	if mgr == null:
		_check(a, "植物格子管理器可用", false, "plant_cell_manager 为空")
		return null
	var all: Array = mgr.all_plant_cells
	if all.size() <= lane:
		_check(a, "植物格子管理器可用", false, "行数=%d 取不到第 %d 行" % [all.size(), lane])
		return null
	var row: Array = all[lane]
	var best: PlantCell = null
	var invalid_n := 0
	var occupied_n := 0
	for cell in row:
		if not is_instance_valid(cell):
			invalid_n += 1
			continue
		## 已有植物的格子跳过（本探针不改关卡自带布局）
		if not _is_cell_free(cell):
			occupied_n += 1
			continue
		if best == null or (cell as PlantCell).row_col.y > best.row_col.y:
			best = cell
	_check(a, "找到空的植物格子", best != null,
		"行=%d 该行格数=%d 无效=%d 已占=%d" % [lane, row.size(), invalid_n, occupied_n]
		+ (" 选中 col=%d" % best.row_col.y if best != null else ""))
	return best


## 格子是不是空的：⚠️ **不能**用 `plant_in_cell.is_empty()` 判 —— 那个字典在场景里就预置了全部槽位键
## （值恒为 null），任何格子都不是 empty。按槽位走安全读取口 `PlantCell.get_plant()`（见规范细则 S-06）
func _is_cell_free(cell: PlantCell) -> bool:
	for place in [
		CharacterRegistry.PlacePlantInCell.Norm,
		CharacterRegistry.PlacePlantInCell.Shell,
		CharacterRegistry.PlacePlantInCell.Down,
		CharacterRegistry.PlacePlantInCell.Float,
		CharacterRegistry.PlacePlantInCell.Imitater,
	]:
		if is_instance_valid(cell.get_plant(place)):
			return false
	return true

#endregion


#region 主链路四段

## 第 1 段：种下去（走游戏内同一个种植入口 PlantCell.create_plant）
func _plant_pea_shooter(a, cell: PlantCell) -> bool:
	var plant: Plant000Base = cell.create_plant(PlantIds.PEA_SHOOTER_SINGLE)
	if plant == null or not is_instance_valid(plant):
		_check(a, "豌豆射手种下成功", false, "create_plant 返回空（槽位被占或注册表缺条目）")
		return false
	_check(a, "豌豆射手种下成功", true, "%s row_col=%s" % [plant.get_class(), str(plant.row_col)])
	await a.wait(0.5)
	## 种下后本体与行号必须稳定存活（_ready → ready_norm 链完整跑过）
	_check(a, "种植后本体仍有效", is_instance_valid(plant))
	_check(a, "植物落在探针指定的行", plant.lane == LANE, "实际 lane=%d 期望=%d" % [plant.lane, LANE])
	return true


## 第 2 段：索敌 → 开火 → 子弹命中 → 掉血。判定只认「血量真的下降」，
## 因为它是**整条攻击链路都通**的唯一证据（索敌 / 建子弹 / 碰撞 / 伤害管线任一环断掉都不会掉血）
func _check_fire_and_hit(a, zombie: Zombie000Base) -> void:
	var hp := zombie.hp_component
	if hp == null:
		_check(a, "僵尸血量组件可用", false, "hp_component 为空")
		return
	var hp_before: int = hp.curr_hp
	var max_hp: int = hp.max_hp
	a.log("  僵尸初始血量=%d/%d，等开火与命中（上限 %.0fs）..." % [hp_before, max_hp, HIT_WAIT_MAX])
	var waited := 0.0
	while is_instance_valid(zombie) and hp.curr_hp >= hp_before and waited < HIT_WAIT_MAX:
		await a.wait(0.5)
		waited += 0.5
	if not is_instance_valid(zombie):
		_check(a, "子弹命中：僵尸掉血", false, "僵尸在掉血前就失效了（%.1fs）" % waited)
		return
	var lost: int = hp_before - hp.curr_hp
	_check(a, "子弹命中：僵尸掉血", lost > 0,
		"血量 %d -> %d（掉 %d）耗时=%.1fs" % [hp_before, hp.curr_hp, lost, waited])


## 第 3 段：死亡链。`hp_loss_to_death()` 是游戏内的「直接打死」入口，
## 判定用**死亡信号 + is_death**（确定性），尸体是否离场只打印（走死亡动画，时长受动画影响）
func _check_death(a, zombie: Zombie000Base) -> void:
	if not is_instance_valid(zombie):
		_check(a, "死亡链：信号与状态位", false, "僵尸已失效，无法判定")
		return
	var flag := {"emitted": false}
	zombie.signal_character_death.connect(func() -> void: flag["emitted"] = true)
	zombie.hp_component.hp_loss_to_death(true)
	await a.wait(0.5)
	_check(a, "死亡链：信号已发出", flag["emitted"], "signal_character_death")
	_check(a, "死亡链：is_death 已置位", zombie.is_death if is_instance_valid(zombie) else false,
		"is_death=%s" % (str(zombie.is_death) if is_instance_valid(zombie) else "对象已释放"))
	## 诊断输出：尸体离场（不计入 result）
	var gone_wait := 0.0
	while is_instance_valid(zombie) and gone_wait < GONE_WAIT_MAX:
		await a.wait(0.5)
		gone_wait += 0.5
	a.log("  [诊断] 尸体离场=%s（等了 %.1fs，不计入判定）" % [
		("是" if not is_instance_valid(zombie) else "否"), gone_wait])

#endregion


#region 造物与断言

## 造一只僵尸：走与 probe_init 相同的路径（出怪器的直接创建口，不依赖波次节奏）
func _spawn_zombie(a, lane: int) -> Zombie000Base:
	var mgr := GameContext.curr_main_game.zombie_manager
	if mgr == null or mgr.zombie_wave_manager == null:
		_check(a, "僵尸管理器可用", false, "zombie_wave_manager 为空")
		return null
	var z: Zombie000Base = mgr.zombie_wave_manager.zombie_wave_create_manager.wave_create_zombie(
		ZombieIds.NORM, lane, 0
	)
	await a.wait(0.5)
	if z == null or not is_instance_valid(z):
		_check(a, "普通僵尸创建成功", false, "wave_create_zombie 返回空")
		return null
	_check(a, "普通僵尸创建成功", true, "%s lane=%d 血量=%d" % [z.get_class(), z.lane, z.hp_component.curr_hp])
	return z


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[GAMEPLAY] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()

#endregion
