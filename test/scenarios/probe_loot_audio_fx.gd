extends RefCounted
## 探针：战利品拾取那段的**音效与粒子**是否按原版接上了
##
## 覆盖（原版出处见每条断言的注释）：
##   1. 静态：战利品 → 拾取音效的映射符合原版（Coin.cpp:1158-1218）
##   2. 静态：通关音效（FOLEY_WINMUSIC / FOLEY_FINAL_FANFARE）已登记且音频文件真的在
##   3. 巧克力 / 花园礼包被点开 → 爆 PRESENT_PICKUP 星火（Coin.cpp:1134 / 1071）
##   4. 结算线上的种子包被点开 → 挂上 SEED_PACKET_PICKUP 僵尸头粒子（Coin.cpp:1238）+ 星星爆裂
##   5. 结算线上的奖杯被点开 → 扇形散出钻石（Coin::FanOutCoins，Coin.cpp:1153-1173）
##
## 机器可读汇总：最后一行 [LOOTFX2] result=PASS|FAIL failed=<n>

const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const LEVEL_01_02 := "res://src/levels/mode_adventure/adventure_01_02.gd"
const PAGE_01 := 0
const ID_01_02 := "0002"
const DAVE_CLICK_POS := Vector2(400, 300)
## 掉落物落点（草坪中段）
const DROP_POS := Vector2(500, 300)
## 等掉落物出现 / 等表演播完的上限秒数
const MAX_WAIT := 20.0

var _failed := 0
## 探针流程有没有跑到最后（中途报错会让协程直接停掉，_finish 仍会执行，没这道兜底就会假 PASS）
var _reached_end := false


func run(a) -> void:
	a.log("")
	a.log("========== 探针 战利品拾取的音效与粒子 ==========")
	await a.wait(2.0)

	_check_static_sfx(a)
	await _run_level(a)

	_finish(a)


#region 1. 静态断言（音效映射 + 音频文件）
func _check_static_sfx(a) -> void:
	a.log("")
	a.log("--- 1. 拾取音效映射（原版 Coin.cpp:1158-1218）---")
	_check(a, "奖杯 → 清脆音（本仓库没有原版 SOUND_DIAMOND 的 .au，用 chime 顶替）",
		LootRegistry.get_sfx(LootRegistry.TROPHY) == "chime",
		LootRegistry.get_sfx(LootRegistry.TROPHY))
	_check(a, "铁铲（冒险 1-4）→ shovel",
		LootRegistry.get_sfx(LootRegistry.SHOVEL) == "shovel",
		LootRegistry.get_sfx(LootRegistry.SHOVEL))
	for loot_name: String in [LootRegistry.ALMANAC, LootRegistry.CAR_KEYS,
			LootRegistry.TACO, LootRegistry.WATERING_CAN]:
		_check(a, "%s → tap2（原版 2-4 / 3-4 / 4-4 关那一声）" % loot_name,
			LootRegistry.get_sfx(loot_name) == "tap2",
			LootRegistry.get_sfx(loot_name))

	a.log("")
	a.log("--- 2. 通关音效已登记且音频文件存在 ---")
	for sfx_name: String in ["winmusic", "finalfanfare", "seedlift", "tap2", "shovel", "chime"]:
		var key := StringName(sfx_name)
		var has_entry: bool = SoundManager.SFXOtherMap.has(key)
		var path: String = str(SoundManager.SFXOtherMap.get(key, ""))
		var file_exists := false
		if has_entry:
			file_exists = FileAccess.file_exists(path)
		_check(a, "音效 %s 已登记且文件存在" % sfx_name,
			has_entry and file_exists, path)
#endregion


#region 2. 实机
func _run_level(a) -> void:
	a.log("")
	a.log("--- 3. 进 1-2 ---")
	var para: ResourceLevelData = (load(LEVEL_01_02) as GDScript).new()
	if para == null:
		_check(a, "（前置）1-2 关卡资源可加载", false, LEVEL_01_02)
		return
	_mark_cleared(1)
	Global.game_para = para
	para.set_choose_level(ADV, PAGE_01, ID_01_02)
	a.log("[场景] 进入 1-2（%s）" % para.save_game_name)
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	if not await _wait_main_game(a, 90.0):
		_check(a, "1-2 进入 MAIN_GAME", false, "超时，阶段=%s" % _progress_name())
		return
	_check(a, "1-2 进入 MAIN_GAME", true)
	var cfg: Object = Global.config_service
	if "auto_collect_coin" in cfg:
		## 关掉「自动收集金币」，否则散出来的钻石会被立刻收走，看不到扇形散开
		cfg.auto_collect_coin = false

	await _check_present_pickup_fx(a)
	await _check_seed_packet_fx(a)
	await _check_fan_out_coins(a)

	_reached_end = true
#endregion


## 巧克力 / 花园礼包被点开 → PRESENT_PICKUP 星火
func _check_present_pickup_fx(a) -> void:
	a.log("")
	a.log("--- 4. 巧克力 / 花园礼包被点开 → PRESENT_PICKUP 星火 ---")
	var dim := GameContext.curr_main_game.drop_item_manager
	## 巧克力：走 request_pick（玩家的那一下），基类按 drop_kind 补星火
	var chocolate := dim.dim_chocolate.create_chocolate(DROP_POS)
	if chocolate == null:
		_check(a, "造得出巧克力", false)
		return
	await a.wait(0.4)
	_check(a, "巧克力的 drop_kind 是 Chocolate",
		chocolate.drop_kind == ItemRegistry.E_DropKind.Chocolate,
		str(chocolate.drop_kind))
	chocolate.request_pick()
	await a.wait(0.3)
	_check(a, "巧克力被点开时爆了 PRESENT_PICKUP",
		_count_fx("LootPresentPickup") > 0, str(_count_fx("LootPresentPickup")))

	## 花园礼包：pick() 里 is_garden_plant 那一支
	var garden_plant := dim.dim_garden_plant.create_garden_plant(DROP_POS)
	if garden_plant == null:
		_check(a, "造得出花园礼包", false)
		return
	await a.wait(0.4)
	var before := _count_fx("LootPresentPickup")
	garden_plant.pick()
	await a.wait(0.3)
	_check(a, "花园礼包被点开时爆了 PRESENT_PICKUP",
		_count_fx("LootPresentPickup") > before, str(_count_fx("LootPresentPickup")))


## 结算线上的种子包被点开 → SEED_PACKET_PICKUP（挂在它自己身上）+ 星星爆裂
func _check_seed_packet_fx(a) -> void:
	a.log("")
	a.log("--- 5. 种子包被点开 → 僵尸头粒子 + 星星爆裂 ---")
	var dim := GameContext.curr_main_game.drop_item_manager
	var packet := dim.create_loot_drop("peashooter_seed_packet", DROP_POS) as SeedPacket
	if packet == null:
		_check(a, "造得出结算线种子包", false)
		return
	dim.mark_level_complete_drop(packet)
	await a.wait(0.4)
	_check(a, "它是结算线上的掉落物", packet.is_level_complete_drop)
	var before_burst := _count_fx("LootStarburst")
	packet.pick()
	await a.wait(0.3)
	_check(a, "点开时爆了星星爆裂（PARTICLE_STARBURST）",
		_count_fx("LootStarburst") > before_burst, str(_count_fx("LootStarburst")))
	var has_pickup_fx := false
	for child in packet.get_children():
		if child is LootSeedPacketPickup:
			has_pickup_fx = true
	_check(a, "点开时挂上了 SEED_PACKET_PICKUP 僵尸头粒子（跟它一起飞向屏幕中心）",
		has_pickup_fx, str(packet.get_children()))


## 结算线上的奖杯被点开 → 扇形散出钻石（原版 Coin::FanOutCoins）
func _check_fan_out_coins(a) -> void:
	a.log("")
	a.log("--- 6. 奖杯被点开 → 扇形散出钻石 ---")
	var dim := GameContext.curr_main_game.drop_item_manager
	var before := _count_diamonds()
	var trophy := dim.create_loot_drop(LootRegistry.TROPHY, DROP_POS) as Present
	if trophy == null:
		_check(a, "造得出结算线奖杯", false)
		return
	dim.mark_level_complete_drop(trophy)
	await a.wait(0.4)
	_check(a, "奖杯认得自己是奖杯（loot_name）",
		trophy.loot_name == LootRegistry.TROPHY, trophy.loot_name)
	trophy.pick()
	await a.wait(0.5)
	var after := _count_diamonds()
	_check(a, "奖杯被点开后散出了钻石（普通关 1 颗）",
		after - before == 1, "%d -> %d" % [before, after])
	## 散币飞行途中截一张（**开窗口跑时**才有内容）
	await a.wait(0.15)
	_screenshot(a, "fan_out_coins")


#region 工具
## 场景里现存的某类特效节点个数（按**脚本的全局类名**数）
## ⚠️ 不能用 `node.is_class("LootStarburst")`：is_class 只认引擎内置类，不认脚本类
func _count_fx(class_name_str: String) -> int:
	var count := 0
	var mg := GameContext.curr_main_game
	if mg == null:
		return 0
	for node in _walk(mg):
		var script: Script = node.get_script()
		if script == null:
			continue
		if str(script.get_global_name()) == class_name_str:
			count += 1
	return count


## 场上现存的钻石掉落物个数（散币）
func _count_diamonds() -> int:
	var count := 0
	var mg := GameContext.curr_main_game
	if mg == null:
		return 0
	for node in _walk(mg):
		if node is Coin and (node as Coin).drop_kind == ItemRegistry.E_DropKind.Diamond:
			count += 1
	return count


func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_walk(child))
	return out


func _find_dave() -> Node:
	var mg := GameContext.curr_main_game
	if mg == null:
		return null
	for node in _walk(mg):
		if node.name.to_lower().contains("dave"):
			return node
	return null


## 把通关记录写成「第 1 关 ~ 第 max_level 关全部通关」
func _mark_cleared(max_level: int) -> void:
	var state: Object = Global.global_game_state
	state.curr_all_level_state_data = {}
	for i in range(1, max_level + 1):
		state.curr_all_level_state_data["%d_0_%04d" % [ADV, i]] = {"IsSuccess": true}


func _progress_name() -> String:
	if GameContext.curr_main_game == null:
		return "main_game=null"
	return str(GameContext.curr_main_game.main_game_progress)


## 等进 MAIN_GAME：中途出现戴夫就逐句点完，停在选卡阶段就替玩家点「开始游戏」
func _wait_main_game(a, timeout: float) -> bool:
	var started := false
	var waited := 0.0
	while waited < timeout:
		if GameContext.curr_main_game == null:
			await a.wait(0.5)
			waited += 0.5
			continue
		if _find_dave() != null:
			await a.click(DAVE_CLICK_POS.x, DAVE_CLICK_POS.y)
			await a.wait(0.4)
			waited += 0.4
			continue
		if GameContext.curr_main_game.is_timeline_waiting_choose_card and not started:
			a.log("  点「开始游戏」（当前阶段=%d）" % GameContext.curr_main_game.main_game_progress)
			started = true
			GameContext.curr_main_game.main_game_start()
			await a.wait(1.5)
			waited += 1.5
			continue
		break
	return GameContext.curr_main_game != null


## 截一张当前画面（**开窗口跑时**才有内容；无头模式下是空图，存了也没用）
func _screenshot(a, tag: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var tex := tree.root.get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null or img.is_empty():
		return
	var path := "user://autopilot_reports/shot_%s.png" % tag
	var err := img.save_png(path)
	if err != OK:
		return
	a.log("  [截图] " + ProjectSettings.globalize_path(path))


func _check(a, what: String, ok: bool, extra := "") -> void:
	if ok:
		a.log("  [OK] " + what + ("  " + str(extra) if extra != "" else ""))
		return
	_failed += 1
	a.log("  [NG] " + what + ("  " + str(extra) if extra != "" else ""))


func _finish(a) -> void:
	if not _reached_end:
		_failed += 1
		a.log("  [NG] 流程没跑到最后（中途报错）")
	a.log("[LOOTFX2] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
#endregion
