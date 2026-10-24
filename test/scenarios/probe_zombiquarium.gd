extends RefCounted
## 探针：迷你游戏第 8 关「僵尸水族馆」（Zombiquarium）的关键玩法闭环
## 覆盖（口径全部按原版源码，见 src/core/consts/const_zombiquarium.gd）：
##   ① 关卡字段：开局 50 阳光、不出怪（monster_mode = Null）、不走选卡
##   ② 进关后水族馆挂上：开局 2 只宠物僵尸、阳光 50
##   ③ 宠物的血量模型：原版初始 200 血、每 100 tick 掉 10 血，血量 ≤150 才找脑子
##   ④ 造脑子：扣 5 阳光、水缸里最多同时 3 个脑子（第 4 个被拒，不扣阳光）
##   ⑤ 僵尸游过来把脑子吃掉（吃完回 200 血，封顶 300）
##   ⑥ 僵尸定时产阳光（首次 200~400 tick，之后 1000~1500 tick）
##   ⑦ 花 100 阳光买一只潜水僵尸（点出战卡槽里那张 100 的种子包）
##   ⑧ 攒够 1000 阳光点奖杯种子包：关卡结束（signal_finished(true)）+ 奖杯真的抛出来
##   ⑧b 右下角进度条口径 = 阳光 / 1000
##   ⑨ 第二轮：所有宠物饿死 -> 主游戏进入 GAME_OVER（判负）
## 机器可读汇总：最后一行 [ZOMBAQ] result=PASS|FAIL failed=<n>

const LEVEL_AQUARIUM := "res://src/levels/mode_minigame/minigame_08_zombie_aquarium.gd"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 僵尸水族馆（养僵尸） ==========")
	await _run_win(a, "通关线")
	await _run_lose(a, "判负线")
	_finish(a)


#region 第一轮：投食 / 买僵尸 / 买奖杯通关
func _run_win(a, title: String) -> void:
	a.log("---- " + title)
	var para: Resource = (load(LEVEL_AQUARIUM) as GDScript).new()
	if para == null:
		_check(a, title + ": 关卡脚本可实例化", false, LEVEL_AQUARIUM)
		return
	## ① 关卡字段
	_check(a, title + ": 开局阳光 = 50", para.start_sun == 50, "实际=" + str(para.start_sun))
	_check(a, title + ": 不出怪 = Null", para.monster_mode == ConstLevelData.E_MonsterMode.Null,
		"实际=" + str(para.monster_mode))
	_check(a, title + ": 不选卡", para.can_choosed_card == false, "实际=" + str(para.can_choosed_card))

	Global.game_para = para
	await a.frames(3)
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	await a.wait(4.0)

	var mg := GameContext.curr_main_game
	_check(a, title + ": 已进入主游戏", mg != null, "GameContext.curr_main_game 为空")
	if mg == null:
		return
	var scene: ZombiquariumScene = _find_aquarium(mg)
	_check(a, title + ": 水族馆入口场景已挂上", scene != null, "主游戏下没有 ZombiquariumScene")
	if scene == null:
		return
	var aquarium: ZombiquariumManager = scene.get_manager()
	_check(a, title + ": 壳里拿得到玩法本体", aquarium != null, "入口场景里没有 ZombiquariumManager")
	if aquarium == null:
		return
	_check(a, title + ": 关卡模式不显示独立预览 HUD", scene.standalone_hud.visible == false,
		"HUD 不该跟着关卡出现")
	## ② 开局状态
	_check(a, title + ": 开局 2 只宠物僵尸", aquarium.get_pets().size() == 2,
		"实际=" + str(aquarium.get_pets().size()))
	_check(a, title + ": 开局 50 阳光", aquarium.get_sun_value() == 50,
		"实际=" + str(aquarium.get_sun_value()))
	_check(a, title + ": 主游戏阶段 = MAIN_GAME",
		mg.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME,
		"实际=" + str(mg.main_game_progress))

	## ③ 宠物的初始状态
	var first_pet: ZombiquariumPet = aquarium.get_pets()[0]
	_check(a, title + ": 宠物在播游泳动画",
		first_pet.get_curr_anim_name() == &"Zombie_snorkle_aquarium_swim",
		"实际=" + str(first_pet.get_curr_anim_name()))
	_check(a, title + ": 宠物血量从 200 起掉（原版 Zombie.cpp:867）",
		first_pet.get_health() <= ConstZombiquarium.PET_HEALTH_INIT \
				and first_pet.get_health() > ConstZombiquarium.PET_SEEK_HEALTH,
		"实际=" + str(first_pet.get_health()))
	## 产阳光用「事件计数」验：阳光掉在场上会被捡走 / 超时消失，数场上个数不稳
	var sun_spawned := [0]
	var on_sun_spawned := func(_sun) -> void: sun_spawned[0] += 1
	EventBus.subscribe(ConstEventName.SUN_SPAWNED, on_sun_spawned)

	## ③b 血量模型：原版每 100 tick 掉 10 血，血量 ≤150 才找脑子
	## （200 血 → 掉到 150 要 500 tick ≈ 8.3 秒）
	var waited := 0.0
	while first_pet.get_health() > ConstZombiquarium.PET_SEEK_HEALTH and waited < 15.0:
		await a.wait(0.5)
		waited += 0.5
	_check(a, title + ": 血量掉到 150（原版 PET_SEEK_HEALTH）",
		first_pet.get_health() <= ConstZombiquarium.PET_SEEK_HEALTH,
		"实际=" + str(first_pet.get_health()))

	## ④ 造脑子：扣 5 阳光（投在宠物的嘴部锚点上，原版判定半径 50）
	aquarium.create_brain(first_pet.get_mouth_pos())
	_check(a, title + ": 造脑子扣 5 阳光", aquarium.get_sun_value() == 45,
		"实际=" + str(aquarium.get_sun_value()))
	## ④b 僵尸会游过来把脑子吃掉（落地 15 tick 后才吃得掉）
	await a.wait(3.0)
	_check(a, title + ": 僵尸把脑子吃了", aquarium.get_brains().is_empty(),
		"还剩 " + str(aquarium.get_brains().size()) + " 个脑子")
	_check(a, title + ": 吃完脑子回血（封顶 300）", first_pet.get_health() > 150,
		"实际=" + str(first_pet.get_health()))

	## ④c 上限 3 个：连着造 3 个（同一帧内断言，僵尸来不及吃），第 4 个被拒
	aquarium.create_brain(Vector2(300, 200))
	aquarium.create_brain(Vector2(500, 250))
	aquarium.create_brain(Vector2(600, 300))
	_check(a, title + ": 水缸里最多 3 个脑子", aquarium.get_brains().size() == 3,
		"实际=" + str(aquarium.get_brains().size()))
	aquarium.create_brain(Vector2(250, 350))
	_check(a, title + ": 第 4 个脑子被拒（不扣阳光）",
		aquarium.get_brains().size() == 3 and aquarium.get_sun_value() == 30,
		"脑子=" + str(aquarium.get_brains().size()) + " 阳光=" + str(aquarium.get_sun_value()))

	## ④d 僵尸定时产阳光（原版首次 200~400 tick，之后 1000~1500 tick）
	await a.wait(8.0)
	EventBus.unsubscribe(ConstEventName.SUN_SPAWNED, on_sun_spawned)
	_check(a, title + ": 僵尸产了阳光", sun_spawned[0] > 0,
		"本关产阳光次数=" + str(sun_spawned[0]))

	## ④ 买僵尸：玩家现在是在出战卡槽里点的（100 阳光那张种子包），右下角那排按钮已经不参与主游戏
	mg.card_manager.card_slot_battle.sun_value = 100
	await a.frames(2)
	var pet_packet := _find_packet(ConstZombiquarium.PET_SUN_COST)
	_check(a, title + ": 卡槽里有 100 阳光的买僵尸种子包", pet_packet != null, "卡槽里没有这张卡")
	if pet_packet == null:
		return
	pet_packet.button.pressed.emit()
	await a.frames(2)
	_check(a, title + ": 花 100 阳光买到一只僵尸",
		aquarium.get_pets().size() == 3 and aquarium.get_sun_value() == 0,
		"僵尸=" + str(aquarium.get_pets().size()) + " 阳光=" + str(aquarium.get_sun_value()))

	## ⑤b 进度条口径 = 阳光 / 1000
	var provider: LevelProgressProvider = mg.level_progress_controller.provider
	_check(a, title + ": 进度条数据源 = 水族馆阳光口径", provider is ZombiquariumProgressProvider,
		"实际=" + str(provider))
	mg.card_manager.card_slot_battle.sun_value = 500
	await a.frames(2)
	_check(a, title + ": 进度 = 阳光 / 1000（500 -> 50%）",
		provider != null and is_equal_approx(provider.get_progress(), 50.0),
		"实际=" + str(provider.get_progress() if provider != null else -1.0))

	## ⑤ 买奖杯通关：点卡槽里 1000 阳光那张
	var win_result: Array = []
	aquarium.signal_finished.connect(func(is_win: bool) -> void: win_result.append(is_win))
	mg.card_manager.card_slot_battle.sun_value = 1000
	await a.frames(2)
	var trophy_packet := _find_packet(ConstZombiquarium.TROPHY_SUN_COST)
	_check(a, title + ": 卡槽里有 1000 阳光的买奖杯种子包", trophy_packet != null, "卡槽里没有这张卡")
	if trophy_packet == null:
		return
	## 奖杯是「战利品掉落物」，挂在掉落层（CanvasLayerDropItem/AllDropGardenPlant），不是 CanvasLayerTemp
	var drop_root: Node2D = mg.get_node_or_null("CanvasLayerDropItem/AllDropGardenPlant")
	var temp_before: int = drop_root.get_child_count() if drop_root != null else 0
	trophy_packet.button.pressed.emit()
	await a.wait(1.0)
	_check(a, title + ": 关卡结束信号 = 通关", win_result == [true], "实际=" + str(win_result))
	var temp_after: int = drop_root.get_child_count() if drop_root != null else 0
	_check(a, title + ": 奖杯已抛出", temp_after > temp_before,
		"before=" + str(temp_before) + " after=" + str(temp_after))
#endregion


#region 工具
## 水族馆入口场景：挂在**水族馆那一层画布**下面（见
## `minigame_08_zombie_aquarium.AQUARIUM_LAYER_NAME`），这里按类递归找，不写死路径 ——
## 层号 / 层级以后再调，探针不用跟着改
func _find_aquarium(root: Node) -> ZombiquariumScene:
	if root is ZombiquariumScene:
		return root as ZombiquariumScene
	for child in root.get_children():
		var found := _find_aquarium(child)
		if found != null:
			return found
	return null


## 出战卡槽里那张价格正好等于 [param sun_cost] 的自定义种子包（见
## `minigame_08_zombie_aquarium._create_seed_packets`：100 买僵尸、1000 买奖杯）
func _find_packet(sun_cost: int) -> Card:
	var mg := GameContext.curr_main_game
	if mg == null or mg.card_manager == null or mg.card_manager.card_slot_battle == null:
		return null
	for card in mg.card_manager.card_slot_battle.curr_cards:
		if card.sun_cost == sun_cost:
			return card
	return null
#endregion


#region 第二轮：宠物全饿死 -> 判负
func _run_lose(a, title: String) -> void:
	a.log("---- " + title)
	var para: Resource = (load(LEVEL_AQUARIUM) as GDScript).new()
	Global.game_para = para
	await a.frames(3)
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	await a.wait(4.0)

	var mg := GameContext.curr_main_game
	var scene: ZombiquariumScene = _find_aquarium(mg)
	if scene == null:
		_check(a, title + ": 水族馆已挂上", false, "主游戏下没有 ZombiquariumScene")
		return
	var aquarium: ZombiquariumManager = scene.get_manager()
	_check(a, title + ": 重开后又是 2 只宠物", aquarium.get_pets().size() == 2,
		"实际=" + str(aquarium.get_pets().size()))
	## 全部饿死：走 pet.die()，死亡动画放完大概 2.6s（原版速率 14 → 36 帧 / 14）
	var dying_pet: ZombiquariumPet = aquarium.get_pets()[0]
	for pet in aquarium.get_pets().duplicate():
		pet.die()
	await a.frames(2)
	_check(a, title + ": 饿死时播死亡动画",
		dying_pet.get_curr_anim_name() == &"Zombie_snorkle_aquarium_death",
		"实际=" + str(dying_pet.get_curr_anim_name()))
	await a.wait(5.0)
	_check(a, title + ": 宠物全部死亡", aquarium.get_pets().is_empty(),
		"还剩 " + str(aquarium.get_pets().size()) + " 只")
	_check(a, title + ": 主游戏阶段 = GAME_OVER",
		mg.main_game_progress == MainGameManager.E_MainGameProgress.GAME_OVER,
		"实际=" + str(mg.main_game_progress))
#endregion


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[ZOMBAQ] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
