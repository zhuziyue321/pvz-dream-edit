extends RefCounted
## 探针：模组「招笑版」里的**烟熏樱桃**（樱桃炸弹 → 不炸血 + 给僵尸上 30 秒烟熏）
##
## ① 改名：装模组前图鉴里叫「樱桃炸弹」，装上叫「烟熏樱桃」
## ② 每局安装：种一株樱桃炸弹 → 挂上观察者，且炸弹伤害被压成 0（`bomb_value == 0`）
## ③ 爆炸那一下：范围内（本行 + 上下各一行）的两只僵尸都吃到烟熏，**僵尸一滴血都不掉**
## ④ 烟熏效果一 —— **遇到植物时站着不啃**：让僵尸贴到一株植物上 →
##    · 本体自己把它停下（`is_attack == true`）
##    · 动画被换成**待机站姿**（`is_idle == true` 且状态机当前节点是 `Idle`）
##    · 植物**不掉血**（挨着啃 1.5 秒）
##    · 撤离后放开待机、走回走路
## ⑤ 烟熏效果二 —— **被同类索敌**：脚底有一株**隐形诱饵**（本体工具植物），
##    另一只僵尸靠近后把它当植物索敌并开啃 →
##    · 它的 `enemy_can_be_attacked` 就是那株诱饵
##    · **诱饵不掉血**，而**被烟熏的那只僵尸掉血**（伤害被原样转过去了）
## ⑥ 撤离：`stop_smoke()` 之后诱饵被拆掉
## ⑦ 关掉模组：名字还回去
##
## ⚠️ 三条踩过的坑（都写在这儿，免得后来者重踩）：
##   1. **别用 1-1**：它是教程关，探针「种下第一株植物」会推进教程流程、放出站在房子边上的
##      教程僵尸 → 几秒内「僵尸进家」判负、关卡收摊，之后所有引用都变成已释放实例、
##      `await` 也再也回不来（只在看门狗超时里结束）。这里用 1-10。
##   2. 即使这样也**先把房子关掉**（`MainGameHome.disable_home()`）：探针要摆好几只僵尸
##      还可能挪来挪去，任何一只走进房子都会把关卡收摊。⚠️ 房子在**背景子场景**里，
##      要从场景根往下找，不是 `MainGameManager` 的子节点。
##   3. **出生点可能超出「僵尸可存在范围」（x 上限 1000）**：波次一刷新就把场外僵尸清掉。
##      所以僵尸一生出来就**立刻**挪进场地，别等半秒再挪。
##   4. **樱桃炸弹爆完会当场死掉**（动画方法轨道：`bomb_once()` → `character_death()`），
##      所以它的引用与观察者只活一瞬：要测「爆炸派发」就得先把僵尸摆好、种下之后**立刻**调
##      `on_bomb_once()`；后面几步干脆不再碰它（自己 new 烟熏状态挂上去）。
##
## 机器可读汇总：最后一行 [ZHAOXIAO_CHERRY] result=PASS|FAIL failed=<n> checks=<n>

const Settings := preload("res://mods_builtin/zhaoxiao/zhaoxiao_settings.gd")
const Smoke := preload("res://mods_builtin/zhaoxiao/zhaoxiao_smoke.gd")
const CherryWatcher := preload("res://mods_builtin/zhaoxiao/zhaoxiao_cherry.gd")

## 见文件头坑 1：不用教程关
const LEVEL := "res://src/levels/mode_adventure/adventure_01_10.gd"
## 樱桃炸弹种哪一格
const BOMB_ROW := 2
const BOMB_COL := 1
## 「站着不啃」那一摊：本行放一株挨啃的植物
const STAND_ROW := 3
const STAND_COL := 1
## 「被同类啃」那一摊：本行**不放植物**，免得索敌被真植物抢走
const EATEN_ROW := 4

var _failed := 0
var _checks := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：模组「招笑版」· 烟熏樱桃 ==========")

	# ------------------------------------------------ STEP1/2 改名
	a.log("STEP1-2 装上模组 → 图鉴名字从「樱桃炸弹」变「烟熏樱桃」")
	_check(a, "模组关着时叫「樱桃炸弹」", _almanac_name() == "樱桃炸弹", _almanac_name())
	ModManager.set_mod_enabled(ModIds.ZHAOXIAO, true)
	_check(a, "装上模组后叫「烟熏樱桃」", _almanac_name() == "烟熏樱桃", _almanac_name())

	# ------------------------------------------------ STEP3 进关
	a.log("STEP3 进一个白天关，先摆好两只僵尸（不碰教程关）")
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
	await a.wait(1.0)
	## 关掉房子（见文件头坑 2）
	var home := _find_home(mg.get_tree().current_scene)
	_check(a, "找得到房子并把它关掉（探针不跑失败流程）", home != null, "没找到 MainGameHome")
	if home != null:
		home.disable_home()
	var manager: PlantCellManager = mg.plant_cell_manager
	var bomb_cell: PlantCell = manager.all_plant_cells[BOMB_ROW][BOMB_COL]
	if bomb_cell == null:
		_check(a, "樱桃炸弹那一格拿得到", false, "格子为空")
		_finish(a)
		return

	# ------------------------------------------------ STEP4 爆炸那一下派发烟熏
	a.log("STEP4 把两只僵尸摆进爆炸范围，再种樱桃并手动炸一次 → 都吃到烟熏、都不掉血")
	var near_a := _spawn_zombie(mg, BOMB_ROW)
	var near_b := _spawn_zombie(mg, BOMB_ROW - 1)
	_check(a, "两只僵尸都摆得下", near_a != null and near_b != null)
	if near_a == null or near_b == null:
		_finish(a)
		return
	## ⚠️ **立刻**挪进场（见文件头坑 3）；位置按**格子**算（樱桃还没种，先别指望它）
	_place_at(near_a, bomb_cell.global_position + Vector2(40.0, -25.0))
	_place_at(near_b, bomb_cell.global_position + Vector2(70.0, -25.0))
	await a.wait(0.8)
	if not _still_running(mg, near_a, near_b):
		_check(a, "等到两只僵尸站稳（引用还在）", false, "引用已释放")
		_finish(a)
		return
	_place_at(near_a, bomb_cell.global_position + Vector2(40.0, -25.0))
	_place_at(near_b, bomb_cell.global_position + Vector2(70.0, -25.0))
	await a.wait(0.3)
	var hp_a_before := _hp(near_a)
	var hp_b_before := _hp(near_b)
	## 种下樱桃（它会自己爆、自己死，所以下面每一步都要在这一瞬间里做完）
	var bomb_plant: Plant000Base = _plant(manager, BOMB_ROW, BOMB_COL, PlantIds.CHERRY_BOMB)
	_check(a, "樱桃炸弹种得下", bomb_plant != null, "格子不可用")
	if bomb_plant == null:
		_finish(a)
		return
	## 观察者节点上的方法要动态调，这里一律用**无类型**变量接（见 check_scripts.ps1 的 KNOWN LIMITATION 2）
	var watcher = bomb_plant.get_node_or_null(CherryWatcher.NODE_PATH)
	var bomb: BombComponentBase = \
		bomb_plant.get_node_or_null(^"BombComponent") as BombComponentBase
	_check(a, "这一株挂上了观察者", watcher != null)
	_check(a, "炸弹组件在", bomb != null)
	if watcher == null or bomb == null:
		_finish(a)
		return
	_check(a, "炸弹伤害被压成 0（一点血都不炸掉）", bomb.bomb_value == 0, str(bomb.bomb_value))
	## ⚠️ 先等一个物理帧再炸：爆炸框是**刚建出来**的 Area2D，
	## `get_overlapping_areas()` 在它过完一个物理帧之前是空的（量出来 0 只僵尸）
	await a.wait(0.2)
	watcher.on_bomb_once()
	await a.wait(0.4)
	_check(a, "本行那只吃到了烟熏", _has_smoke(near_a))
	_check(a, "上一行那只也吃到了烟熏（樱桃炸弹覆盖上下各一行）", _has_smoke(near_b))
	_check(a, "本行那只**一点血都没掉**", _hp(near_a) == hp_a_before,
		"%d → %d" % [hp_a_before, _hp(near_a)])
	_check(a, "上一行那只也没掉血", _hp(near_b) == hp_b_before,
		"%d → %d" % [hp_b_before, _hp(near_b)])

	# ------------------------------------------------ STEP5 遇到植物站着不啃
	a.log("STEP5 烟熏效果一：贴到植物上就**站着播待机**、植物一滴血都不掉")
	var wall: Plant000Base = _plant(manager, STAND_ROW, STAND_COL, PlantIds.WALL_NUT)
	if wall == null:
		_check(a, "挨啃的植物种得下", false, "格子不可用")
	else:
		var stander := _spawn_zombie(mg, STAND_ROW)
		_check(a, "站着的那只摆得下", stander != null)
		if stander != null:
			## 贴到植物右边（僵尸朝左走，脸对着植物）
			_place_at(stander, wall.global_position + Vector2(46.0, 0.0))
			await a.wait(0.8)
			if not _still_running(mg, stander, wall):
				_check(a, "等到它贴到植物上（引用还在）", false, "引用已释放")
				_finish(a)
				return
			_place_at(stander, wall.global_position + Vector2(46.0, 0.0))
			## 樱桃炸弹早爆完死了 —— 这里自己挂烟熏（只测「烟熏」这一层）
			var smoke_node := _attach_smoke(stander)
			_check(a, "它身上挂上了烟熏状态", smoke_node != null)
			await a.wait(0.8)
			_check(a, "本体把它停下（is_attack 已置位）", bool(stander.is_attack))
			_check(a, "动画被换成**待机**（is_idle = true）", bool(stander.is_idle))
			_check(a, "动画状态机当前就在 Idle 上", String(_current_state(stander)) == "Idle",
				String(_current_state(stander)))
			var wall_hp := _hp(wall)
			await a.wait(1.5)
			_check(a, "挨着啃了 1.5 秒，植物**一滴血都没掉**", _hp(wall) == wall_hp,
				"%d → %d" % [wall_hp, _hp(wall)])
			if smoke_node != null:
				smoke_node.stop_smoke()
			await a.wait(0.4)
			_check(a, "撤离后放开待机（is_idle 放回 false）", not bool(stander.is_idle))
			_check(a, "撤离后它自己走回走路（状态机离开 Idle）",
				String(_current_state(stander)) != "Idle", String(_current_state(stander)))

	# ------------------------------------------------ STEP6 被同类索敌
	a.log("STEP6 烟熏效果二：脚底的隐形诱饵把同类引过来啃，伤害转到被烟熏的那只身上")
	var victim := _spawn_zombie(mg, EATEN_ROW)
	_check(a, "被啃的那只摆得下", victim != null)
	if victim == null:
		_finish(a)
		return
	_place_at(victim, Vector2(460.0, mg.get_row_base_global_y(EATEN_ROW)))
	await a.wait(0.8)
	if not _still_running(mg, victim):
		_check(a, "等到它站稳（引用还在）", false, "引用已释放")
		_finish(a)
		return
	_attach_smoke(victim)
	await a.wait(0.2)
	_check(a, "它被标成「谁都能打它」（本体那个通用口子）",
		bool(victim.is_enemy_to_all_camps), str(victim.is_enemy_to_all_camps))
	_check(a, "它的归属阵营**没有变**（还是僵尸方，死亡计数不受影响）",
		BulletCampConfig.get_owner_camp(victim) == CharacterRegistry.CharacterType.Zombie,
		str(BulletCampConfig.get_owner_camp(victim)))
	_check(a, "**玩家植物照旧打得中它**（对植物方也是敌人）",
		BulletCampConfig.is_enemy(CharacterRegistry.CharacterType.Plant, victim))
	var attacker := _spawn_zombie(mg, EATEN_ROW)
	_check(a, "攻击者摆得下", attacker != null)
	if attacker == null:
		_finish(a)
		return
	## 攻击者摆在它**右边 45 像素**（僵尸的索敌框在身前十几像素处，45 就已经进范围了）。
	## ⚠️ 不能摆更远「等它自己走过来」：两只僵尸**同速同行**，距离永远不变、追不上。
	_place_at(attacker, victim.global_position + Vector2(45.0, 0.0))
	var attacker_detect: DetectComponent = \
		attacker.attack_component.detect_component as DetectComponent
	for _i in range(20):
		if not _still_running(mg, victim) or not is_instance_valid(attacker):
			break
		if attacker_detect != null and attacker_detect.enemy_can_be_attacked == victim:
			break
		await a.wait(0.3)
	if not _still_running(mg, victim) or not is_instance_valid(attacker):
		_check(a, "等到攻击者靠上来（引用还在）", false, "引用已释放")
		_finish(a)
		return
	_check(a, "攻击者把被烟熏的那只当成了索敌目标", attacker_detect != null
		and attacker_detect.enemy_can_be_attacked == victim,
		"目标是 %s" % str(attacker_detect.enemy_can_be_attacked if attacker_detect != null else null))
	var victim_hp := _hp(victim)
	await a.wait(0.6)
	_check(a, "被烟熏的那只**被同类啃掉血了**", _hp(victim) < victim_hp,
		"%d → %d" % [victim_hp, _hp(victim)])

	# ------------------------------------------------ STEP7 撤离
	a.log("STEP7 撤离：口子还回去")
	var smoke_victim = victim.get_node_or_null(Smoke.NODE_PATH)
	if smoke_victim != null:
		smoke_victim.stop_smoke()
	await a.wait(0.5)
	_check(a, "「谁都能打它」被撤掉了", not bool(victim.is_enemy_to_all_camps))
	_check(a, "撤掉之后同类又不再索敌它（僵尸方不再是敌人）",
		not BulletCampConfig.is_enemy(CharacterRegistry.CharacterType.Zombie, victim))
	_check(a, "而植物方一直打得中它（本来就是敌人，没被连累）",
		BulletCampConfig.is_enemy(CharacterRegistry.CharacterType.Plant, victim))

	# ------------------------------------------------ STEP8 关掉模组
	a.log("STEP8 关掉模组 → 名字还回去")
	ModManager.set_mod_enabled(ModIds.ZHAOXIAO, false)
	_check(a, "图鉴名字回到樱桃炸弹", _almanac_name() == "樱桃炸弹", _almanac_name())
	## 开关是**持久化**的，跑完必须存回去，别把后面的探针带歪
	ModManager.save_mods()
	_finish(a)


#region 小工具
## 图鉴里樱桃炸弹那一条的「名字」
func _almanac_name() -> String:
	var read_data := Global.global_read_data
	read_data.ensure_almanac_loaded()
	var all_plant_data: Dictionary = read_data.data_almanac.get("Plant", {})
	var entry: Dictionary = all_plant_data.get(Settings.CHERRY_ALMANAC_KEY, {})
	return String(entry.get("名字", ""))


## 在指定格子种一株，返回那株植物（格子不可种 / 种不出来返回 null）
func _plant(manager, row: int, col: int, plant_type: StringName) -> Plant000Base:
	var cell: PlantCell = manager.all_plant_cells[row][col]
	if cell == null or not cell.can_common_plant:
		return null
	var plant := cell.create_plant(plant_type)
	return plant if is_instance_valid(plant) else null


func _spawn_zombie(mg, lane: int) -> Zombie000Base:
	var create_manager = mg.zombie_manager.zombie_wave_manager.zombie_wave_create_manager
	if create_manager == null:
		return null
	var zombie: Zombie000Base = create_manager.wave_create_zombie(ZombieIds.NORM, lane, 0)
	return zombie if is_instance_valid(zombie) else null


## 给一只僵尸挂一个烟熏状态节点，返回它（僵尸不在就给 null）
func _attach_smoke(zombie: Zombie000Base) -> Node:
	if not is_instance_valid(zombie):
		return null
	var smoke := Smoke.new()
	smoke.name = Smoke.NODE_NAME
	zombie.add_child(smoke)
	return smoke


func _has_smoke(zombie) -> bool:
	return is_instance_valid(zombie) and zombie.get_node_or_null(Smoke.NODE_PATH) != null


## 把一只角色摆到世界坐标某处（引用已经没了就什么都不做）
func _place_at(character, global_pos: Vector2) -> void:
	if is_instance_valid(character):
		character.global_position = global_pos


## 场景树里那扇「房子」（按类型找，不猜路径）
func _find_home(node) -> MainGameHome:
	if node is MainGameHome:
		return node
	for child in node.get_children():
		var found := _find_home(child)
		if found != null:
			return found
	return null


## 引用还能不能用（**关卡一旦收摊，场上节点全被释放**：
## 之后每一步都会踩「previously freed」，而 `await` 也再也回不来 —— 只会在看门狗里超时）
func _still_running(mg, a_ref, b_ref = null) -> bool:
	if not is_instance_valid(mg) or not is_instance_valid(a_ref):
		return false
	return b_ref == null or is_instance_valid(b_ref)


## 角色的血（角色已释放算 0）
func _hp(character) -> int:
	if not is_instance_valid(character) or character.hp_component == null:
		return 0
	return int(character.hp_component.curr_hp)


## 动画状态机当前那个状态名（拿不到给空串）
func _current_state(zombie) -> StringName:
	if not is_instance_valid(zombie):
		return &""
	var tree := zombie.get_node_or_null(^"AnimationTree") as AnimationTree
	if tree == null:
		return &""
	var playback := tree.get(Smoke.PLAYBACK_PARAM) as AnimationNodeStateMachinePlayback
	if playback == null:
		return &""
	return playback.get_current_node()
#endregion


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	_checks += 1
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


## ⚠️ 除了 failed，也把**跑过的断言条数**报出来：某一段因为脚本报错整段没跑到时
## `failed` 仍是 0（假绿），但条数会掉下来 —— 与上一次跑的数一比就看出来了。
func _finish(a) -> void:
	a.log("")
	a.log("[ZHAOXIAO_CHERRY] result=%s failed=%d checks=%d"
		% ["PASS" if _failed == 0 else "FAIL", _failed, _checks])
	a.finish(true)
