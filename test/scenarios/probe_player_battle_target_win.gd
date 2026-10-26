extends RefCounted
## 探针：玩家对战「靶子僵尸」—— **受创三档换装** + **僵尸进家 = 僵尸方赢**
## （`mods_builtin/player_battle/targetzombie/` 与 `levels/player_battle_day.gd`）
##
## 覆盖：
##   0. 站位：靶子站在**第 10 列**（草坪 9 列之外那一列的正中）= 最后一列右边缘 + 半格，
##      再整体右移 `TARGET_ZOMBIE_STAND_EXTRA_OFFSET_X` 像素，身体骑在屏幕右边缘上
##      （一部分露在屏幕外、一部分还看得见）；
##      并且**第 9 列的植物还打得中它**（种一株豌豆射手看掉血，索敌带是否够长）；
##   1. 受创换装的配置：`HpStageChangeComponent` 的临界值 [140, 90, 40, 0]、
##      三张覆盖精灵挂在动画场景的 `Target` 底下、满血时全藏着；
##   2. 三档真的会换：`judge_body_change(130 / 80 / 30)` 之后只亮当前那一档；
##      同时完好的 `Target` 贴图**没被替换**（换的是覆盖精灵，见那份场景的注释）；
##   3. 僵尸方胜法：关卡声明 `is_zombie_can_home`（房子判定点开着）、订阅了 `zombie_go_home`；
##   4. 真推一条 `zombie_go_home` ⇒ 本体失败流程接管（`GAME_OVER` + 卡槽收起）、
##      关卡记下「僵尸方获胜」、**不**判胜（不会再弹奖杯）；
##   5. 两条收尾条件的先后：植物方先赢（已击破 3 只）时再来僵尸进家 → 不改判；
##      僵尸方先赢时靶子计数冻结。
##
## 无头可跑：`powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_player_battle_target_win`
##
## 机器可读汇总（最后一行）：[PBTARGET] result=PASS|FAIL failed=<n>

## 关卡脚本的两个加载根（内置源 / 玩家那份，`user://mods/` 优先）
const LEVEL_PATHS := [
	"res://mods_builtin/player_battle/levels/player_battle_day.gd",
	"user://mods/player_battle/levels/player_battle_day.gd",
]
## 模组共享常量的两个加载根（与关卡脚本同一套口径）
const SETTINGS_PATHS := [
	"res://mods_builtin/player_battle/player_battle_settings.gd",
	"user://mods/player_battle/player_battle_settings.gd",
]
## 靶子僵尸的 id（见 `player_battle_settings.gd`）
const TARGET_ID := &"pb_target_zombie"
## 三档受创的剩余血量临界值（与 `zombie_target.tscn` 的 `boundary_value_hp` 一致）
const BOUNDARY := [140, 90, 40, 0]
## 打到这些剩余血量时应当停在对应档位（0 起算：140 → 第 1 档，90 → 第 2 档，40 → 第 3 档）
const STAGE_TEST_HP := [130, 80, 30]
## 植物方的胜法：击破几只靶子
const DEFEAT_TO_WIN := 3
## 三张覆盖精灵在动画场景里的节点名（挂在 `Target` 底下）
const DAMAGE_SPRITES := ["TargetDamage1", "TargetDamage2", "TargetDamage3"]
## 靶子僵尸的动画场景根（相对角色根）
const ANIM_PATH := "Body/BodyCorrect/ZombieTargetAnim"
## 动画面里那块招牌（完好的那张贴图挂在它身上）
const TARGET_SPRITE := "Target"
## 动画播放器（一个库装全部段，见 target_zombie.gd）
const ANIM_LIB_PATH := "Body/BodyCorrect/ZombieTargetAnim/AnimLib"
## 受击段 / 待机段（带库名前缀）
const ANIM_HIT := &"Zombie_target/Zombie_target_hit"
const ANIM_IDLE := &"Zombie_target/Zombie_target_idle"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：玩家对战 靶子僵尸（受创换装 / 僵尸进家 = 僵尸方赢） ==========")

	var level_gd: GDScript = null
	for path in LEVEL_PATHS:
		if ResourceLoader.exists(path):
			level_gd = load(path) as GDScript
			break
	if level_gd == null:
		a.log("!! 关卡脚本加载失败（两个加载根都没有）")
		_finish(a)
		return

	_check_level_logic(a, level_gd)

	var para = level_gd.new()
	para.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelPlayerBattle, 0, "0001")
	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	var mg: MainGameManager = await _wait_main_game(a, 20.0)
	if mg == null:
		a.log("!! 进不了关卡（主游戏没起来）")
		_finish(a)
		return
	if not await _wait_cells(a, 20.0):
		a.log("!! 草坪格子没建出来")
		_finish(a)
		return

	## 无头点不了「开始战斗」：走主游戏自带的跳过选卡入口（调试通道同款）
	## —— 之后流程才会走到 `allow_operation()` → 接上 `zombie_go_home` → 摆靶子
	## ⚠️ 必须等时间轴**真的停在选卡事件上**再跳过（`is_timeline_waiting_choose_card`）：
	##   早了会走 `choosed_card_start_game()` 那条旁路，`signal_choose_card_finished`
	##   白白发射一次没人接，随后选卡事件才开始等 —— 一等等到看门狗收工。
	if not await _wait_choose_card_stage(a, mg, 40.0):
		a.log("!! 时间轴一直没停在选卡阶段（is_timeline_waiting_choose_card 没起来）")
		_finish(a)
		return
	await mg.skip_choose_card_start_game()
	var target: Zombie000Base = await _wait_target_zombie(a, 40.0)
	if target == null:
		a.log("!! 等不到靶子僵尸（关卡流程没走到摆靶子那一步？）")
		_finish(a)
		return

	_check_stand_position(a, mg, target)
	_check_appearance(a, target)
	await _check_hit_animation(a, target)
	await _check_reach(a, mg, target)
	await _check_zombie_win(a, mg, para, target)

	_finish(a)


#region 纯逻辑：两条收尾条件的先后（不依赖关卡实例）
## 用两份「空壳」关卡实例验 `_on_zombie_go_home` / `_on_target_defeated` 的判据 ——
## 这两条只用计数字段，不碰主游戏，可以脱离关卡直接调
func _check_level_logic(a, level_gd: GDScript) -> void:
	a.log("STEP0 收尾条件先后（关卡脚本自己的判据）")

	## 僵尸方先赢：记下结果
	var zombie_win = level_gd.new()
	zombie_win._on_zombie_go_home(null)
	_check(a, "僵尸进家 → 关卡记下「僵尸方获胜」", zombie_win._zombie_side_won)

	## 僵尸方已经赢了：靶子再被打掉也不算数（结果不再变）
	var frozen_before: int = zombie_win._targets_defeated
	zombie_win._on_target_defeated()
	_check(a, "僵尸方赢了之后靶子计数冻结",
		zombie_win._targets_defeated == frozen_before,
		"%d → %d" % [frozen_before, zombie_win._targets_defeated])

	## 植物方先赢：已经击破 3 只时再来僵尸进家，不该把结果改判成僵尸赢
	var plant_win = level_gd.new()
	plant_win._targets_defeated = DEFEAT_TO_WIN
	plant_win._on_zombie_go_home(null)
	_check(a, "植物方先赢（已击破 %d 只）后僵尸进家不改判" % DEFEAT_TO_WIN,
		not plant_win._zombie_side_won)
#endregion


#region 站位：第 10 列再右移（草坪外，半截身体在屏幕外）
func _check_stand_position(a, mg: MainGameManager, target: Zombie000Base) -> void:
	a.log("STEP1a 站位：草坪 9 列之外的第 10 列（再整体右移）")
	var cells: Array = mg.plant_cell_manager.all_plant_cells[target.lane]
	_check(a, "第 %d 行有格子" % target.lane, not cells.is_empty())
	if cells.is_empty():
		return
	var last := cells[cells.size() - 1] as PlantCell
	## 第 10 列正中 = 最后一列右边缘再往右半格（草坪 9 列 ⇒ 跨 1 列）
	var column_center_x: float = last.global_position.x + last.size.x * 1.5
	## 站位列之外的整体右移量（见 `player_battle_settings.gd`）
	var extra_offset_x: float = float(_mod_const(&"TARGET_ZOMBIE_STAND_EXTRA_OFFSET_X", 30.0))
	var expect_x: float = column_center_x - float(_mod_const(&"TARGET_ZOMBIE_BODY_VISUAL_OFFSET_X", -19.5)) \
		+ extra_offset_x
	_check(a, "靶子原点 = 第 10 列正中 + 身体视觉偏移 + 右移 %.0fpx（身体才落在该列中间）" % extra_offset_x,
		absf(target.global_position.x - expect_x) < 1.0,
		"x=%.1f 期望=%.1f（草坪右边缘=%.1f，第 10 列正中=%.1f）"
			% [target.global_position.x, expect_x, last.global_position.x + last.size.x, column_center_x])
	## 屏幕坐标：拿**视觉包围盒**（所有可见 Sprite2D 的外接矩形）判，
	## 不用坐标点 —— 僵尸的身体画在原点左边，只看原点会以为「整只都在屏幕里」
	var canvas := mg.get_viewport().get_canvas_transform()
	var view_width := mg.get_viewport_rect().size.x
	var visual := _visual_screen_rect(mg, target)
	var visual_center_x := visual.position.x + visual.size.x * 0.5
	var column_center_screen_x := (canvas * Vector2(column_center_x + extra_offset_x, 0)).x
	var detail := "视觉 x=%.0f~%.0f 中心=%.0f / 第 10 列正中+右移=%.0f / 视口宽=%.0f（露在屏幕外 %.0f%%）" % [
		visual.position.x, visual.end.x, visual_center_x, column_center_screen_x, view_width,
		clampf((visual.end.x - view_width) / maxf(visual.size.x, 1.0), 0.0, 1.0) * 100.0]
	_check(a, "身体视觉中心落在第 10 列正中再右移 %.0fpx 处（不是第 9 列）" % extra_offset_x,
		absf(visual_center_x - column_center_screen_x) <= 8.0, detail)
	_check(a, "靶子有一部分身体露在屏幕外", visual.end.x > view_width, detail)
	_check(a, "靶子还有一部分身体在屏幕内（看得见它在）", visual.position.x < view_width, detail)


## 读模组共享常量（`player_battle_settings.gd`）：内置源优先，玩家那份兜底
func _mod_const(const_name: StringName, default_value):
	for path in SETTINGS_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var script: GDScript = load(path) as GDScript
		if script == null:
			continue
		var map: Dictionary = script.get_script_constant_map()
		if map.has(const_name):
			return map[const_name]
	return default_value


## 角色在**屏幕坐标**下的视觉包围盒：所有可见 Sprite2D 的矩形并集
## （只算几何，不需要渲染 —— 无头也能测）
func _visual_screen_rect(mg: MainGameManager, character: Node2D) -> Rect2:
	var canvas := mg.get_viewport().get_canvas_transform()
	var result := Rect2()
	var has_any := false
	for node in character.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite == null or sprite.texture == null or not sprite.is_visible_in_tree():
			continue
		var local_rect := sprite.get_rect()
		var corners := [
			sprite.global_transform * local_rect.position,
			sprite.global_transform * (local_rect.position + Vector2(local_rect.size.x, 0)),
			sprite.global_transform * (local_rect.position + Vector2(0, local_rect.size.y)),
			sprite.global_transform * (local_rect.position + local_rect.size),
		]
		for corner in corners:
			var p: Vector2 = canvas * corner
			if not has_any:
				result = Rect2(p, Vector2.ZERO)
				has_any = true
			else:
				result = result.expand(p)
	return result


## 受击动画：DLC reanim 的 hit 段（0.83 s）必须在掉血当帧切出来，播完回 idle。
## 1 点伤害只为触发 `signal_hp_loss`，不把血量打过受创档（150 → 149）——
## 所以这一步必须排在受创换装的手工档位断言之后、豌豆射手实伤之前。
func _check_hit_animation(a, target: Zombie000Base) -> void:
	a.log("STEP1b 受击动画（Zombie_target_hit）")
	var anim: AnimationPlayer = target.get_node_or_null(ANIM_LIB_PATH) as AnimationPlayer
	_check(a, "动画播放器上挂着 hit 段", anim != null and anim.get_animation(ANIM_HIT) != null)
	if anim == null:
		return
	target.be_attacked_bullet(1, ConstDamage.E_DamageMode.Norm, true, false)
	_check(a, "掉血当帧切到受击段", anim.current_animation == ANIM_HIT, str(anim.current_animation))
	await a.wait(1.1)
	_check(a, "受击段播完回待机", anim.current_animation == ANIM_IDLE or not anim.is_playing(),
		str(anim.current_animation))


## 站到第 10 列之后**还打不打得到**（这一改动最容易弄坏的一条）：
## 在第 9 列种一株豌豆射手，看靶子掉不掉血 —— 掉血说明植物的索敌带还盖得住那一列。
## ⚠️ 必须排在受创换装的断言之后：这株植物一直在打，实伤会不停触发 `judge_body_change`，
##   把手工设定的档位改回去。
func _check_reach(a, mg: MainGameManager, target: Zombie000Base) -> void:
	a.log("STEP1c 第 10 列还打不打得到")
	var cells: Array = mg.plant_cell_manager.all_plant_cells[target.lane]
	if cells.is_empty():
		return
	var last := cells[cells.size() - 1] as PlantCell
	var plant := last.create_plant(PlantIds.PEA_SHOOTER_SINGLE)
	_check(a, "第 9 列种得下豌豆射手", plant != null and is_instance_valid(plant))
	if plant == null or not is_instance_valid(plant):
		return
	var hp_before: int = target.hp_component.curr_hp
	var waited := 0.0
	while waited < 8.0 and target.hp_component.curr_hp >= hp_before:
		await a.wait(0.5)
		waited += 0.5
	_check(a, "第 9 列的植物打得中第 10 列的靶子（掉血 = 索敌带够长）",
		target.hp_component.curr_hp < hp_before,
		"%d → %d（等了 %.1f 秒）" % [hp_before, target.hp_component.curr_hp, waited])
#endregion


#region 受创三档换装
func _check_appearance(a, target: Zombie000Base) -> void:
	a.log("STEP1 受创换装的配置")
	var comp: HpStageChangeComponent = target.hp_stage_change_component
	_check(a, "靶子僵尸挂着 HpStageChangeComponent", comp != null)
	if comp == null:
		return
	var same := comp.boundary_value_hp.size() == BOUNDARY.size()
	if same:
		for i in BOUNDARY.size():
			if comp.boundary_value_hp[i] != BOUNDARY[i]:
				same = false
	_check(a, "临界值 = 剩余血量 140 / 90 / 40 / 0（末项 0 = 死亡线）", same,
		str(comp.boundary_value_hp))

	var target_sprite := target.get_node_or_null("%s/%s" % [ANIM_PATH, TARGET_SPRITE]) as Sprite2D
	_check(a, "动画面里有那块招牌（Target）", target_sprite != null)
	var overlays: Array[Sprite2D] = []
	for sprite_name in DAMAGE_SPRITES:
		var node := target.get_node_or_null("%s/%s/%s" % [ANIM_PATH, TARGET_SPRITE, sprite_name]) as Sprite2D
		overlays.append(node)
		_check(a, "招牌底下挂着覆盖精灵 %s（且有贴图）" % sprite_name,
			node != null and node.texture != null)
	if overlays.has(null):
		return
	var all_hidden := true
	for ov in overlays:
		if ov.visible:
			all_hidden = false
	_check(a, "满血时三张覆盖精灵都藏着", all_hidden)
	var intact_tex := "" if target_sprite == null or target_sprite.texture == null \
		else target_sprite.texture.resource_path
	_check(a, "完好的招牌贴图还在 Target 上（换的是覆盖精灵，不是这张）",
		intact_tex.ends_with("Zombie_target.png"), intact_tex)

	a.log("STEP2 三档真的会换（按剩余血量逐档亮一张）")
	for stage in STAGE_TEST_HP.size():
		comp.judge_body_change(STAGE_TEST_HP[stage])
		var only_this := true
		for i in overlays.size():
			if overlays[i].visible != (i == stage):
				only_this = false
		_check(a, "剩余 %d 血 → 只亮第 %d 档招牌" % [STAGE_TEST_HP[stage], stage + 1],
			comp.curr_hp_stage == stage and only_this,
			"stage=%d 可见=%s" % [comp.curr_hp_stage,
				str(overlays[0].visible) + "/" + str(overlays[1].visible) + "/" + str(overlays[2].visible)])
#endregion


#region 僵尸方胜法
func _check_zombie_win(a, mg: MainGameManager, para, target: Zombie000Base) -> void:
	a.log("STEP3 僵尸方胜法的接线")
	_check(a, "关卡声明「僵尸能进家」（is_zombie_can_home）", para.is_zombie_can_home,
		str(para.is_zombie_can_home))
	var home: MainGameHome = mg.background_manager.home if mg.background_manager != null else null
	_check(a, "背景房子在", home != null)
	_check(a, "房子判定区开着（没被 disable_home 关掉）",
		home != null and home.area_2d_home != null and home.area_2d_home.monitoring)
	_check(a, "关卡订阅了 zombie_go_home（" + ConstEventName.ZOMBIE_GO_HOME + "）",
		_is_level_subscribed(para))

	a.log("STEP4 真推一条 zombie_go_home ⇒ 僵尸方赢")
	var before_count: int = para._targets_defeated
	EventBus.push_event(ConstEventName.ZOMBIE_GO_HOME, [target])
	_check(a, "关卡记下「僵尸方获胜」", para._zombie_side_won)
	_check(a, "主游戏切到 GAME_OVER（本体失败流程接管）",
		mg.main_game_progress == MainGameManager.E_MainGameProgress.GAME_OVER,
		str(mg.main_game_progress))
	_check(a, "卡槽收起（失败流程照常收场）", not mg.card_slot_root.visible)
	_check(a, "这一局没有判胜（失败之后不会再弹奖杯）", not mg.reward_manager.is_win_started)
	para._on_target_defeated()
	_check(a, "僵尸方赢了之后靶子计数冻结",
		para._targets_defeated == before_count,
		"%d → %d" % [before_count, para._targets_defeated])
	_check(a, "关卡仍然订阅着（收尾退订是流程返回时的事，这一局已结束）",
		_is_level_subscribed(para) or not is_instance_valid(mg))


## 关卡脚本自己有没有挂在 `zombie_go_home` 上
## （本体 `MgmLoseManager` 也挂在这条事件上，所以按「回调对象是不是这份关卡脚本」认）
func _is_level_subscribed(para) -> bool:
	if not EventBus.has_signal(ConstEventName.ZOMBIE_GO_HOME):
		return false
	for conn in EventBus.get_signal_connection_list(ConstEventName.ZOMBIE_GO_HOME):
		if conn["callable"].get_object() == para:
			return true
	return false
#endregion


#region 工具
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[PBTARGET] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	## 直接退出进程：这一局已经被「失败流程」收掉了（场景树暂停），不必再走回主菜单
	a.quit_game()


func _wait_main_game(a, timeout: float) -> MainGameManager:
	var waited := 0.0
	while waited < timeout:
		var mg: MainGameManager = GameContext.curr_main_game
		if mg != null and is_instance_valid(mg):
			return mg
		await a.wait(0.25)
		waited += 0.25
	return null


func _wait_cells(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		var mg: MainGameManager = GameContext.curr_main_game
		if mg != null and mg.plant_cell_manager != null:
			var rows: Array = mg.plant_cell_manager.all_plant_cells
			if not rows.is_empty() and not (rows[0] as Array).is_empty():
				return true
		await a.wait(0.25)
		waited += 0.25
	return false


## 等时间轴停在「选卡」事件上（`LevelTimelineEventChooseCard.run()` 置位、等玩家点开始）
func _wait_choose_card_stage(a, mg: MainGameManager, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if not is_instance_valid(mg):
			return false
		if mg.is_timeline_waiting_choose_card:
			return true
		await a.wait(0.25)
		waited += 0.25
	return false


## 等关卡流程走到「摆靶子」（`allow_operation()` 之后），返回第一只靶子僵尸
func _wait_target_zombie(a, timeout: float) -> Zombie000Base:
	var waited := 0.0
	while waited < timeout:
		var mg: MainGameManager = GameContext.curr_main_game
		if mg == null or not is_instance_valid(mg):
			return null
		var zm = mg.zombie_manager
		if zm != null:
			for z in zm.all_zombies_1d:
				if z != null and is_instance_valid(z) and z.zombie_type == TARGET_ID:
					return z
		await a.wait(0.25)
		waited += 0.25
	return null
#endregion
