extends RefCounted
## 探针 PROBE9：第二大关（夜晚 2-1 ~ 2-10）
## 覆盖：
##   1. 10 关的关卡资源按原版夜晚流程配置：夜晚底图 / BGM、无天降阳光、开局墓碑、出怪表
##   2. 2-5 是锤僵尸关（原版打地鼠：固定 3 张卡 + 锤子），2-10 是传送带收尾关，其余是普通选卡关
##   3. 2-1 ~ 2-8 通关后依次解锁 阳光菇 / 大喷菇 / 墓碑吞噬者 / 魅惑菇 / 胆小菇 / 寒冰菇 / 毁灭菇，2-10 睡莲
##   4. 2-1 实机：点掉开场戴夫对话（CRAZY_DAVE_201~207，逐句点完才进得去）后进 MAIN_GAME、
##      墓碑数量 = init_tombstone_num、底图 = 夜晚、全程没有天降阳光、出怪正常开波
##   5. 墓碑吞噬者只能种在墓碑上，普通植物不能种在墓碑上（原版夜晚核心玩法）
## 机器可读汇总：最后一行 [NIGHT] result=PASS|FAIL failed=<n>

const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
## 关卡资源目录 + 文件名格式分开写：全文搜 res:// 引用时会把带参数的整路径字面量
## 当成真实路径，拼出来的名字并不存在。
const LEVEL_DIR := "res://src/levels/mode_adventure/"
const LEVEL_FILE_FORMAT := "adventure_02_%02d.gd"
## 2-1 在选关界面上的位置：第 2 个页（0 起 = 1）的第 1 关，关卡编号 0011
const PAGE_02 := 1
const ID_02_01 := "0011"
## 原版第二大关每关的波数（本仓库每 10 波 1 旗帜，波数 = 原版旗帜数 * 10）
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Night) 各关 Flags 列
const EXPECT_MAX_WAVE: Dictionary = {
	1: 10,	## 2-1 一旗
	2: 20,	## 2-2 两旗
	3: 10,	## 2-3 一旗
	4: 20,	## 2-4 两旗
	5: 10,	## 2-5 原版无旗帜（打地鼠关），本仓库最低 10 波
	6: 10,	## 2-6 一旗
	7: 20,	## 2-7 两旗
	8: 10,	## 2-8 一旗
	9: 20,	## 2-9 两旗
	10: 20,	## 2-10 两旗
}
## 原版第二大关每关的开局墓碑数（墓碑 = 夜晚僵尸的额外出怪口）
## 数据来源: PVZ Wiki 各关 Infobox 的 EM（初始墓碑数）字段
const EXPECT_INIT_TOMBSTONE: Dictionary = {
	1: 4, 2: 4, 3: 4, 4: 7, 5: 9, 6: 7, 7: 11, 8: 7, 9: 11, 10: 13,
}
## 特殊关的 BGM 不跟着夜晚走：2-5（打地鼠）Loonboon、2-10（传送带收尾）Ultimate Battle，
## 其余是夜晚 Moongrains
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Music_(PvZ))
const EXPECT_BGM_EXCEPT_NIGHT: Dictionary = {
	5: ConstLevelData.GameBGM.MiniGame,
	10: ConstLevelData.GameBGM.UltimateBattle,
}
## 生存夜晚关卡（原版 Survival: Night 一族）：墓碑会在每个大波前继续生长
const SURVIVAL_NIGHT_LEVELS: Array[String] = [
	"res://src/levels/mode_survival/survival_flag_02_night.gd",
	"res://src/levels/mode_survival/survival_flag_07_night.gd",
	"res://src/levels/mode_survival/survival_flag_12_night.gd",
]
## 第二大关的出战卡槽数：除 2-5 外一律跟存档走（基准 6，见 GlobalGameState.get_card_slot_num）
## 2-5 是原版「打地鼠」关（锤僵尸出怪）：关卡资源用 max_choosed_card_num = 3 覆盖存档卡槽数
const CARD_NUM_BASE := 6
const EXPECT_CARD_NUM_EXCEPT_BASE: Dictionary = {5: 3}
## 关卡资源自带的固定预选卡（键为小关号），未列出的关卡一律不写预选卡
## 2-5 = 土豆地雷 / 墓碑吞噬者 / 樱桃炸弹（原版固定卡：砸出来的阳光用来啃墓碑与炸僵尸）
const EXPECT_FIXED_CARD: Dictionary = {
	5: [CharacterRegistry.PlantType.P005PotatoMine,
		CharacterRegistry.PlantType.P012GraveBuster,
		CharacterRegistry.PlantType.P003CherryBomb],
}
## 原版第二大关解锁表：键为冒险模式关卡序号（2-x = 10 + x），值为该小关通关后拿到的植物
## 数据来源与 ConstPlantUnlock.ADVENTURE_LEVEL_UNLOCK_PLANT 的 2-x 段一致
const EXPECT_UNLOCK: Dictionary = {
	11: CharacterRegistry.PlantType.P010SunShroom,		## 2-1 阳光菇
	12: CharacterRegistry.PlantType.P011FumeShroom,		## 2-2 大喷菇
	13: CharacterRegistry.PlantType.P012GraveBuster,	## 2-3 墓碑吞噬者
	15: CharacterRegistry.PlantType.P013HypnoShroom,	## 2-5 魅惑菇
	16: CharacterRegistry.PlantType.P014ScaredyShroom,	## 2-6 胆小菇
	17: CharacterRegistry.PlantType.P015IceShroom,		## 2-7 寒冰菇
	18: CharacterRegistry.PlantType.P016DoomShroom,		## 2-8 毁灭菇
	20: CharacterRegistry.PlantType.P017LilyPad,		## 2-10 睡莲
}

var _failed := 0
## 戴夫对话的点击位置（设计分辨率 800x600 的屏幕中心；戴夫的点击面板覆盖全屏，点哪都能推进）
const DAVE_CLICK_POS := Vector2(400, 300)
## STEP3 是否出现过戴夫（2-1 的开场对话）
var _dave_seen := false


func run(a) -> void:
	a.log("")
	a.log("========== PROBE9 第二大关（夜晚 2-1 ~ 2-10）==========")

	_check_level_para(a)
	_check_unlock_table(a)
	if not await _check_level_02_01_runtime(a):
		_finish(a)
		return
	_check_tombstone_plant_condition(a)
	_check_conveyor_and_final_level(a)
	_check_survival_night_tombstone(a)
	_finish(a)


#region 静态：关卡资源开关
## 逐关核对「夜晚流程」的开关取值。
## 夜晚的判定不只看 is_day：底图 / BGM / 天降阳光 / 墓碑 / 出怪表各自独立，
## 少一项就会出现「白天底图的夜晚关」「夜晚还在掉阳光」这类半成品。
func _check_level_para(a) -> void:
	a.log("")
	a.log("STEP1 2-1 ~ 2-10 关卡资源开关")
	## 前院（Land）能自然刷新的僵尸白名单：出怪表写了名单外的僵尸会被 init_para 过滤掉
	var whitelist: Array = Global.global_read_data.whitelist_refresh_zombie_types_with_zombie_row_type[
		CharacterRegistry.ZombieRowType.Land
	]
	for small in range(1, 11):
		var para: ResourceLevelData = (load(_level_path(small)) as GDScript).new()
		var label := "2-%d" % small
		if para == null:
			_check(a, label + " 关卡资源可加载", false, _level_path(small))
			continue
		_check(a, label + " 关卡资源可加载", true)
		_check(a, label + " 底图 = 前院夜晚", para.game_BG == ConstLevelData.GameBg.FrontNight,
			str(para.game_BG))
		var expect_bgm: ConstLevelData.GameBGM = EXPECT_BGM_EXCEPT_NIGHT.get(
			small, ConstLevelData.GameBGM.FrontNight)
		_check(a, label + " BGM = %d" % expect_bgm, para.game_BGM == expect_bgm, str(para.game_BGM))
		_check(a, label + " 不是白天", not para.is_day, str(para.is_day))
		_check(a, label + " 没有天降阳光", not para.is_day_sun, str(para.is_day_sun))
		_check(a, label + " 墓碑会生成僵尸", para.is_have_tombston, str(para.is_have_tombston))
		_check(a, label + " 开局墓碑数 = 原版(%d)" % EXPECT_INIT_TOMBSTONE[small],
			para.init_tombstone_num == EXPECT_INIT_TOMBSTONE[small],
			str(para.init_tombstone_num))
		## 原版冒险夜晚关卡只有开局那一批墓碑，中途不再长（会长的只有生存夜晚 / 锤僵尸类）
		_check(a, label + " 墓碑中途不再生长", not para.is_tombstone_respawn,
			str(para.is_tombstone_respawn))
		_check(a, label + " 波数 = 原版旗帜数*10(%d)" % EXPECT_MAX_WAVE[small],
			para.max_wave == EXPECT_MAX_WAVE[small], str(para.max_wave))
		## 2-5 是原版「打地鼠」（锤僵尸）关：出怪走墓碑，出战卡由关卡资源固定，卡槽数 = 固定卡数；
		## 其余关卡不写 max_choosed_card_num，卡槽数取存档值
		var expect_card_num: int = EXPECT_CARD_NUM_EXCEPT_BASE.get(small, CARD_NUM_BASE)
		_check(a, label + " 卡槽数 = %d" % expect_card_num,
			para.get_max_choosed_card_num() == expect_card_num, str(para.get_max_choosed_card_num()))
		_check(a, label + " 关卡资源覆盖卡槽数 = %d" % EXPECT_CARD_NUM_EXCEPT_BASE.get(small, 0),
			para.max_choosed_card_num == EXPECT_CARD_NUM_EXCEPT_BASE.get(small, 0),
			str(para.max_choosed_card_num))
		var expect_pre_card: Array = EXPECT_FIXED_CARD.get(small, [])
		var prechosen_ids: Array = para.prechosen_cards.map(func(r): return r.content_id)
		_check(a, label + " 关卡资源预选卡 = %s" % str(expect_pre_card),
			_is_same_int_array(prechosen_ids, expect_pre_card),
			str(prechosen_ids))
		var is_wave_ok := not para.zombie_refresh_types.is_empty()
		for zombie_type: CharacterRegistry.ZombieType in para.zombie_refresh_types:
			## 旗帜僵尸由大波逻辑单独塞入，名单里不该出现；名单外的僵尸会被静默过滤
			if zombie_type == CharacterRegistry.ZombieType.Z002Flag or not whitelist.has(zombie_type):
				is_wave_ok = false
		_check(a, label + " 出怪表全部可自然刷新", is_wave_ok, str(para.zombie_refresh_types))
#endregion


#region 静态：原版解锁表
## 2-1 ~ 2-10 通关后解锁的植物，必须与 ConstPlantUnlock 的 2-x 段一致。
## 选关界面第 2 页的「本关看点」图标就是按这张表摆的（见 docs/参考存档/选关界面与解锁.md 选关界面一节）。
func _check_unlock_table(a) -> void:
	a.log("")
	a.log("STEP2 2-1 ~ 2-10 解锁表")
	for level in range(11, 21):
		var level_name: String = ConstUnlockLevel.get_adventure_level_name(level)
		var got: Array = ConstPlantUnlock.get_unlock_plant_on_adventure_level(level)
		var expect: Variant = EXPECT_UNLOCK.get(level, null)
		if expect == null:
			_check(a, "通关 %s 没有新植物" % level_name, got.is_empty(), str(got))
		else:
			_check(a, "通关 %s 解锁 %s" % [level_name, _plant_name(expect)],
				got.size() == 1 and got[0] == expect, str(got))
#endregion


#region 运行期：2-1 实机
## 实机进入 2-1，核对墓碑 / 底图 / 天降阳光 / 出怪。
func _check_level_02_01_runtime(a) -> bool:
	a.log("")
	a.log("STEP3 2-1 实机（新档首次进入）")
	## 新档只拥有豌豆射手：卡槽 6 >= 拥有卡数 1，选卡阶段会被自动跳过
	Global.global_game_state.curr_plant.assign([CharacterRegistry.PlantType.P001PeaShooterSingle])
	Global.global_game_state.curr_all_level_state_data = {}

	var para: ResourceLevelData = (load(_level_path(1)) as GDScript).new()
	para.set_choose_level(ADV, PAGE_02, ID_02_01)
	Global.game_para = para
	a.log("[场景] 进入 2-1（%s）" % para.save_game_name)
	await a.wait(2.0)
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	if not await _wait_main_game(a, 40.0):
		_check(a, "2-1 进入 MAIN_GAME", false, "超时")
		return false
	_check(a, "2-1 进入 MAIN_GAME", true)
	_check(a, "2-1 开场播了戴夫对话（CRAZY_DAVE_201~207）", _dave_seen, str(_dave_seen))
	await a.wait(1.0)

	var mg = Global.main_game
	var tombstone_num: int = mg.plant_cell_manager.tomb_stone_manager.tombstone_num
	_check(a, "2-1 关卡参数已生效（夜晚）", mg.game_para.game_BG == ConstLevelData.GameBg.FrontNight,
		str(mg.game_para.game_BG))
	_check(a, "2-1 墓碑数 = init_tombstone_num(%d)" % para.init_tombstone_num,
		tombstone_num == para.init_tombstone_num, str(tombstone_num))
	var bg_texture: Texture2D = mg.background_manager.background.texture
	_check(a, "2-1 底图 = 夜晚前院",
		bg_texture == ConstLevelData.GameBgTextureMap[ConstLevelData.GameBg.FrontNight],
		str(bg_texture))

	## 夜晚不掉阳光：等一段足够长的时间，场上不应该出现任何未收集的阳光
	await a.wait(8.0)
	_check(a, "2-1 8 秒后场上仍无掉落阳光", mg.suns.get_child_count() == 0,
		str(mg.suns.get_child_count()))

	## 夜晚关同样要正常开波（僵尸管理器不因夜晚而停摆）
	## 超时需大于关卡的 first_wave_delay（默认 20 秒）
	var wave_manager = mg.zombie_manager.zombie_wave_manager
	if not await _wait_wave_start(a, wave_manager, 40.0):
		_check(a, "2-1 僵尸波次已开始", false, str(wave_manager.curr_wave))
		return false
	_check(a, "2-1 僵尸波次已开始", true, "curr_wave=" + str(wave_manager.curr_wave))
	return true
#endregion


#region 运行期：墓碑种植判定
## 墓碑吞噬者只能种在墓碑上；普通植物不能种在墓碑上（原版：墓碑上种不了普通植物）。
func _check_tombstone_plant_condition(a) -> void:
	a.log("")
	a.log("STEP4 墓碑种植判定（原版夜晚核心玩法）")
	var mg = Global.main_game
	var tombstone_cell: PlantCell = null
	for row_cells: Array in mg.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			if is_instance_valid(plant_cell.tombstone):
				tombstone_cell = plant_cell
				break
		if tombstone_cell != null:
			break
	if tombstone_cell == null:
		_check(a, "场上存在墓碑格子", false, "墓碑数=" + str(mg.plant_cell_manager.tomb_stone_manager.tombstone_num))
		return
	_check(a, "场上存在墓碑格子", true, str(tombstone_cell.row_col))

	var grave_buster_condition: ResourcePlantCondition = Global.character_registry.get_plant_info(
		CharacterRegistry.PlantType.P012GraveBuster,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	var norm_condition: ResourcePlantCondition = Global.character_registry.get_plant_info(
		CharacterRegistry.PlantType.P001PeaShooterSingle,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	_check(a, "墓碑吞噬者可以种在墓碑上",
		grave_buster_condition.judge_is_can_plant(tombstone_cell, CharacterRegistry.PlantType.P012GraveBuster),
		str(tombstone_cell.row_col))
	_check(a, "普通植物不能种在墓碑上",
		not norm_condition.judge_is_can_plant(tombstone_cell, CharacterRegistry.PlantType.P001PeaShooterSingle),
		str(tombstone_cell.row_col))
#endregion


#region 静态：特殊关卡类型与 2-10 收尾
## 本区的特殊关卡：
##   2-5  = 原版「打地鼠」关（E_MonsterMode.HammerZombie）：僵尸从墓碑冒出，用锤子砸，
##          出战卡由关卡资源固定（土豆地雷 / 墓碑吞噬者 / 樱桃炸弹），阳光全靠砸僵尸掉落。
##   2-10 = 传送带收尾关，出怪表要含本区重点僵尸（舞王）、大波倍率 1（原版无倍率）、波数按原版两旗 = 20 波。
func _check_conveyor_and_final_level(a) -> void:
	a.log("")
	a.log("STEP5 2-5 锤僵尸 / 2-10 传送带与收尾关")
	for small in range(1, 11):
		var para: ResourceLevelData = (load(_level_path(small)) as GDScript).new()
		var label := "2-%d" % small
		var want_conveyor: bool = small == 10
		var is_conveyor: bool = para.card_mode == ConstLevelData.E_CardMode.ConveyorBelt
		_check(a, label + ("" if want_conveyor else " 不是") + "传送带关", is_conveyor == want_conveyor,
			"card_mode=" + str(para.card_mode))
		if want_conveyor:
			_check(a, label + " 传送带卡池非空", not para.conveyor_weights.is_empty(),
				str(para.conveyor_weights.size()))
		var want_hammer: bool = small == 5
		_check(a, label + ("" if want_hammer else " 不是") + "锤僵尸出怪模式",
			(para.monster_mode == ConstLevelData.E_MonsterMode.HammerZombie) == want_hammer,
			"monster_mode=" + str(para.monster_mode))
		## 锤子不再挂在关卡数据上（is_hammer 字段已删），改由本关那条玩法规则装
		## （见 LevelRuleHammerZombie）；实锤与否由动态探针 probe_tmp_2_5 跑一遍验
		if want_hammer:
			_check(a, label + " 不可选卡（出战卡由关卡固定）", not para.can_choosed_card,
				str(para.can_choosed_card))
			_check(a, label + " 起始阳光 = 0（阳光全靠砸僵尸掉落）", para.start_sun == 0,
				str(para.start_sun))
			_check(a, label + " 不天降阳光（夜晚）", not para.is_day_sun, str(para.is_day_sun))

	## 2-10 = 该区重点僵尸「舞王」，与选关界面第 2 页 2-10 的本关看点图标对应
	var para_10: ResourceLevelData = (load(_level_path(10)) as GDScript).new()
	_check(a, "2-10 出怪表含舞王", para_10.zombie_refresh_types.has(CharacterRegistry.ZombieType.Z009Jackson),
		str(para_10.zombie_refresh_types))
	## 原版没有「出怪倍率」，收尾关统一 1：倍率 2 会让末波战力翻倍，密度远超原版
	_check(a, "2-10 大波倍率 = 1（原版无倍率）", para_10.zombie_multy == 1, str(para_10.zombie_multy))
	_check(a, "2-10 波数 = 20（原版两旗）", para_10.max_wave == 20, str(para_10.max_wave))
#endregion


#region 静态：生存夜晚的墓碑
## 原版 Survival: Night 一族：每个大波（本轮最终波）前先补一批墓碑，再由全部墓碑放伏击僵尸。
## 普通冒险夜晚关卡（2-x）只有开局那一批，打完就不长
## （开关见 ResourceLevelData.is_tombstone_respawn，消费方见 ZombieWaveManager.start_next_wave）
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Grave_(PvZ) "Survival: Night Levels")
func _check_survival_night_tombstone(a) -> void:
	a.log("")
	a.log("STEP6 生存夜晚墓碑会继续生长")
	for path: String in SURVIVAL_NIGHT_LEVELS:
		var para: ResourceLevelData = (load(path) as GDScript).new()
		var label: String = path.get_file().trim_suffix(".gd")
		if para == null:
			_check(a, label + " 关卡资源可加载", false, path)
			continue
		_check(a, label + " 是夜晚关", not para.is_day, str(para.is_day))
		_check(a, label + " 开局墓碑 = 5（原版 Survival: Night）", para.init_tombstone_num == 5,
			str(para.init_tombstone_num))
		_check(a, label + " 墓碑会继续生长", para.is_tombstone_respawn, str(para.is_tombstone_respawn))
#endregion


#region 断言与工具
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[NIGHT] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 两个整型列表逐项相等（预选卡是 Array[PlantType]，这里按 int 比）
func _is_same_int_array(got: Array, expect: Array) -> bool:
	if got.size() != expect.size():
		return false
	for i in range(expect.size()):
		if int(got[i]) != int(expect[i]):
			return false
	return true


## 某个小关（1 ~ 10）对应的关卡资源路径
func _level_path(small: int) -> String:
	return LEVEL_DIR + (LEVEL_FILE_FORMAT % small)


## 植物名（只用于日志可读性）
func _plant_name(plant_type: CharacterRegistry.PlantType) -> String:
	return str(Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.PlantName))


## 等主游戏进入 MAIN_GAME 阶段：关卡开场的戴夫对话要逐句点完才进得去（2-1 有开场对话）
func _wait_main_game(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if Global.main_game != null:
			if _find_dave() != null and not await _skip_dave_dialog(a):
				return false
			if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
				return true
		await a.wait(0.5)
		waited += 0.5
	return false


## 界面上正在说话的戴夫（挂在 canvas_layer_ui 下），没有则返回 null
func _find_dave() -> CrazyDave:
	var mg = Global.main_game
	if mg == null:
		return null
	for child in mg.canvas_layer_ui.get_children():
		if child is CrazyDave:
			return child as CrazyDave
	return null


## 点掉戴夫对话：戴夫的点击面板覆盖全屏，每点一次推进一句，说到最后一句后自动离场
func _skip_dave_dialog(a, timeout: float = 40.0) -> bool:
	var waited := 0.0
	while waited < timeout:
		if _find_dave() == null:
			return true
		_dave_seen = true
		await a.click(DAVE_CLICK_POS.x, DAVE_CLICK_POS.y)
		await a.wait(0.5)
		waited += 0.5
	return _find_dave() == null


## 等第一波僵尸开波
func _wait_wave_start(a, wave_manager, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if wave_manager.curr_wave >= 0:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false
#endregion
