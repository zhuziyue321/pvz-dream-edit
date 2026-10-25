extends RefCounted
## 探针：僵王血量按关卡配置（5-10 = 40000 / 僵尸博士的复仇 = 60000）+ 原版技能调度
## 覆盖：逐关进僵王关 → 断言僵王 max_hp / 破损阈值（80% / 50% 两档，随血量等比缩放）；
##      在 5-10 断言原版四计数器初值、select_skill 优先级、破损阶段强制招式、
##      砸车落地重置、放置间隔随阶段递减、放置类型按存活时长分段（Zombie.cpp Boss* 系列）。
## 机器可读汇总：最后一行 [ZOMBOSSHP] result=PASS|FAIL failed=<n>

const LEVELS: Array[Dictionary] = [
	{
		"name": "冒险 5-10",
		"path": "res://src/levels/mode_adventure/adventure_05_10.gd",
		"hp": 40000,
		"stages": [32000, 20000, 0],
	},
	{
		"name": "僵尸博士的复仇",
		"path": "res://src/levels/mode_minigame/minigame_20_zomboss_revenge.gd",
		"hp": 60000,
		"stages": [48000, 30000, 0],
	},
]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 僵王血量 / 原版技能调度 ==========")
	for level: Dictionary in LEVELS:
		await _check_level(a, level)
	_finish(a)


## 进一关僵王关，断言僵王的血量与机甲破损阈值。[br]
## [param level] 关卡名、脚本路径、期望血量与期望破损阈值。
func _check_level(a, level: Dictionary) -> void:
	a.log("")
	a.log("---------- " + str(level["name"]) + " ----------")
	var para: Resource = (load(level["path"]) as GDScript).new()
	Global.game_para = para
	GlobalUtils.change_scene(
		Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.MainGameRoof)
	)
	await a.wait(3.0)

	var mg := GameContext.curr_main_game
	_check(a, "已进入主游戏", mg != null, "GameContext.curr_main_game 为空")
	if mg == null:
		return
	if mg.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		mg.main_game_start()
	await a.wait(2.0)

	## 等博士出场（boss_spawn_wave = 0，开战即自动出场）
	var boss: Node2D = null
	for _i in 40:
		var bosses := mg.zombie_manager.get_living_bosses()
		if not bosses.is_empty():
			boss = bosses[0]
			break
		await a.wait(0.5)
	_check(a, "博士已出场", boss != null, "20 秒内没有僵王实例")
	if boss == null:
		return

	var hp_component = boss.get("hp_component")
	var stage_component = boss.get_node_or_null("%HpStageChangeComponent")
	var expect_hp: int = int(level["hp"])
	a.log("  max_hp=%d curr_hp=%d 破损阈值=%s"
		% [hp_component.max_hp, hp_component.curr_hp, str(stage_component.boundary_value_hp)])
	_check(a, "僵王 max_hp = %d" % expect_hp, hp_component.max_hp == expect_hp, str(hp_component.max_hp))
	_check(a, "开局满血", hp_component.curr_hp == hp_component.max_hp,
		"curr_hp=%d max_hp=%d" % [hp_component.curr_hp, hp_component.max_hp])
	var expect_stages: Array[int] = []
	expect_stages.assign(level["stages"])
	_check(a, "破损阈值按比例缩放为 %s" % str(expect_stages),
		stage_component.boundary_value_hp == expect_stages, str(stage_component.boundary_value_hp))

	if level["path"] == LEVELS[0]["path"]:
		_check_scheduler(a, boss, mg)


## 只在 5-10 断言原版技能调度；全部为同步断言，中间不留 await，避免计数器被物理帧推进。
func _check_scheduler(a, boss: Node2D, mg) -> void:
	var sm = boss.get("state_machine")
	_check(a, "取到博士状态机", sm != null, "state_machine 缺失")
	if sm == null:
		return
	var hp_component = boss.get("hp_component")
	var stage_component = boss.get_node_or_null("%HpStageChangeComponent")

	## 初值：原版入场 mSummonCounter=500、mBossHeadCounter=5000、踩踏/蹦极 -1 锁定
	sm._reset_skill_counters()
	a.log("  计数器初值 summon=%s head=%s stomp=%s bungee=%s 阶段=%d"
		% [str(sm.summon_counter), str(sm.head_counter), str(sm.stomp_counter), str(sm.bungee_counter), sm.boss_damage_stage])
	_check(a, "首次放置等待 5 秒", sm.summon_counter == 5.0, str(sm.summon_counter))
	_check(a, "首次吐球等待 50 秒", sm.head_counter == 50.0, str(sm.head_counter))
	_check(a, "脚踩计数锁定为 -1", sm.stomp_counter == -1.0, str(sm.stomp_counter))
	_check(a, "蹦极计数锁定为 -1", sm.bungee_counter == -1.0, str(sm.bungee_counter))
	_check(a, "初始破损阶段为 0", sm.boss_damage_stage == 0, str(sm.boss_damage_stage))

	## ⑤ 放置计数到 0 → 召唤；计数器由技能开跑回调重置到阶段区间内
	sm.summon_counter = 0.0
	var selected = sm.select_skill()
	_check(a, "放置计数到 0 选中 Spawn", selected != null and selected.name == "Spawn", str(selected))
	_check(a, "召唤开始后放置计数重置为正数", sm.summon_counter > 0.0, str(sm.summon_counter))

	## ④ 吐球优先于放置：两个计数同时到 0 时先吐球
	sm.summon_counter = 0.0
	sm.head_counter = 0.0
	selected = sm.select_skill()
	_check(a, "吐球优先于放置", selected != null and selected.name == "HeadSkill", str(selected))
	_check(a, "吐球开始后计数重置为 40~50 秒",
		sm.head_counter > 40.0 and sm.head_counter <= 50.0, str(sm.head_counter))

	## ② 脚踩计数到 0：无目标时消耗本轮并重置，不发招
	sm.stomp_counter = 0.0
	selected = sm.select_skill()
	_check(a, "无目标脚踩不发招", selected == null, str(selected))
	_check(a, "无目标脚踩计数仍重置为 55~65 秒",
		sm.stomp_counter > 55.0 and sm.stomp_counter <= 65.0, str(sm.stomp_counter))

	## 摆花盆给蹦极提供目标（每行最左格摆一个，共 5 个）
	for row_cells in mg.plant_cell_manager.all_plant_cells:
		var cell = row_cells[0]
		if is_instance_valid(cell):
			cell.create_plant(PlantIds.FLOWER_POT)

	## ③ 蹦极计数到 0：冒险模式概率置 0 后必出蹦极
	sm.rv_chance_adventure = 0.0
	sm.bungee_counter = 0.0
	selected = sm.select_skill()
	_check(a, "蹦极计数到 0 选中 Bungee（有目标）", selected != null and selected.name == "Bungee", str(selected))
	_check(a, "蹦极开始后计数重置为 40~50 秒",
		sm.bungee_counter > 40.0 and sm.bungee_counter <= 50.0, str(sm.bungee_counter))

	## ① 破损阶段 1（血量 < 80%）：立即蹦极一次，优先于一切计数器
	hp_component.curr_hp = 30000
	stage_component.judge_body_change(30000, true)
	_check(a, "血量 30000 进入破损阶段 1", sm._get_damage_stage() == 1, str(sm._get_damage_stage()))
	selected = sm.select_skill()
	_check(a, "进入阶段 1 立即蹦极", selected != null and selected.name == "Bungee", str(selected))

	## ① 破损阶段 2（血量 < 50%）：立即砸车一次
	hp_component.curr_hp = 15000
	stage_component.judge_body_change(15000, true)
	_check(a, "血量 15000 进入破损阶段 2", sm._get_damage_stage() == 2, str(sm._get_damage_stage()))
	selected = sm.select_skill()
	_check(a, "进入阶段 2 立即砸车", selected != null and selected.name == "ThrowRV", str(selected))

	## 原版 BossRVLanding：砸车落地统一重置四条技能线
	sm.on_rv_landed()
	a.log("  砸车落地重置 summon=%s head=%s stomp=%s bungee=%s"
		% [str(sm.summon_counter), str(sm.head_counter), str(sm.stomp_counter), str(sm.bungee_counter)])
	_check(a, "落地后放置计数 5 秒", sm.summon_counter == 5.0, str(sm.summon_counter))
	_check(a, "落地后吐球计数 50 秒", sm.head_counter == 50.0, str(sm.head_counter))
	_check(a, "落地后脚踩计数 40 秒", sm.stomp_counter == 40.0, str(sm.stomp_counter))
	_check(a, "落地后蹦极计数 65 秒", sm.bungee_counter == 65.0, str(sm.bungee_counter))

	## 放置间隔随破损阶段递减：原版 450~550 / 350~450 / 150~250 tick
	sm.boss_damage_stage = 0
	var interval: float = sm._get_summon_interval()
	_check(a, "阶段 0 放置间隔 4.5~5.5 秒", interval > 4.5 and interval <= 5.5, str(interval))
	sm.boss_damage_stage = 1
	interval = sm._get_summon_interval()
	_check(a, "阶段 1 放置间隔 3.5~4.5 秒", interval > 3.5 and interval <= 4.5, str(interval))
	sm.boss_damage_stage = 2
	interval = sm._get_summon_interval()
	_check(a, "阶段 2 放置间隔 1.5~2.5 秒", interval > 1.5 and interval <= 2.5, str(interval))

	## 放置类型按存活时长分段（原版 mZombieAge 3500 / 8000 / 12500 tick）
	var spawn_skill = sm.get_node_or_null("Spawn").get("effect_component")
	_check(a, "取到放置技能组件", spawn_skill != null, "SpawnSkill 缺失")
	if spawn_skill != null:
		sm.battle_age = 0.0
		_check(a, "35 秒内只放普僵", spawn_skill._pick_zombie_type(mg.zombie_manager, 2) == "norm", "age=0")
		sm.battle_age = 50.0
		_check(a, "35~80 秒只放路障", spawn_skill._pick_zombie_type(mg.zombie_manager, 2) == "cone", "age=50")
		sm.battle_age = 100.0
		_check(a, "80~125 秒只放铁桶", spawn_skill._pick_zombie_type(mg.zombie_manager, 2) == "bucket", "age=100")
		sm.battle_age = 200.0
		var late_type: StringName = spawn_skill._pick_zombie_type(mg.zombie_manager, 2)
		_check(a, "125 秒后从原版 gBossZombieList 抽取", late_type in spawn_skill.late_pool, str(late_type))
		var top_type: StringName = spawn_skill._pick_zombie_type(mg.zombie_manager, 0)
		_check(a, "最上行不放巨人（原版特判）", top_type != "gargantuar", str(top_type))


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[ZOMBOSSHP] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
