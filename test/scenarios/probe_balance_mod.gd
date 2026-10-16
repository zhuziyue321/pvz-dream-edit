extends RefCounted
## 探针：模组「原版平衡」（10 条同人调整）
##
## ① 数据层（装模组前后各读一遍）：豌豆射手 / 咖啡豆 / 吸金磁的阳光、仙人掌子弹的穿透数
## ② 实例层：进一个白天关，直接调 `PlantCell.create_plant()` 造出植物来验 ——
##    寒冰菇伤害、机枪的补发数、卷心菜的三行检测区、吸金磁的吸铁组件（max_iron = 3）
## ③ 光照：火炬树桩点亮十字四格、路灯花点亮周围八格、向日葵按光照每级多产 5 阳光
##
## ★ 关掉模组要把数值还原成原版，所以每一条都**装前装后各验一次**（只验"改成了新值"
##   等于没验：写死常量也能过）。
##
## 机器可读汇总：最后一行 [BALANCE] result=PASS|FAIL failed=<n>

const LEVEL := "res://src/levels/mode_adventure/adventure_01_01.gd"

const VANILLA_SUN_PEA := 100
const VANILLA_SUN_COFFEE := 75
const VANILLA_SUN_GOLD_MAGNET := 50
const VANILLA_SUN_FLOWER_VALUE := 25

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：模组「原版平衡」==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装之前是原版
	a.log("STEP1 模组关着时，数值是原版")
	_check(a, "豌豆射手阳光 = %d（原版）" % VANILLA_SUN_PEA,
		_sun(registry, PlantIds.PEA_SHOOTER_SINGLE) == VANILLA_SUN_PEA,
		str(_sun(registry, PlantIds.PEA_SHOOTER_SINGLE)))
	_check(a, "咖啡豆阳光 = %d（原版）" % VANILLA_SUN_COFFEE,
		_sun(registry, PlantIds.COFFEE_BEAN) == VANILLA_SUN_COFFEE,
		str(_sun(registry, PlantIds.COFFEE_BEAN)))
	_check(a, "吸金磁阳光 = %d（原版）" % VANILLA_SUN_GOLD_MAGNET,
		_sun(registry, PlantIds.GOLD_MAGNET) == VANILLA_SUN_GOLD_MAGNET,
		str(_sun(registry, PlantIds.GOLD_MAGNET)))
	_check(a, "仙人掌子弹只打 1 个（原版，命中即销毁）", _cactus_pierce() == 1, str(_cactus_pierce()))

	# ------------------------------------------------ STEP2 装上之后
	a.log("STEP2 装上模组 → 数据层那几条生效")
	ModManager.set_mod_enabled(ModIds.BALANCE, true)
	_check(a, "豌豆射手阳光 = 75", _sun(registry, PlantIds.PEA_SHOOTER_SINGLE) == 75,
		str(_sun(registry, PlantIds.PEA_SHOOTER_SINGLE)))
	_check(a, "咖啡豆阳光 = 25", _sun(registry, PlantIds.COFFEE_BEAN) == 25,
		str(_sun(registry, PlantIds.COFFEE_BEAN)))
	_check(a, "吸金磁阳光 = 150", _sun(registry, PlantIds.GOLD_MAGNET) == 150,
		str(_sun(registry, PlantIds.GOLD_MAGNET)))
	_check(a, "仙人掌子弹最多打 3 个", _cactus_pierce() == 3, str(_cactus_pierce()))

	# ------------------------------------------------ STEP3 进关
	a.log("STEP3 进一个白天关（实例层那几条要种下植物才存在）")
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
	var manager: PlantCellManager = mg.plant_cell_manager

	# ------------------------------------------------ STEP4 光照
	a.log("STEP4 光照：火炬树桩十字四格、路灯花周围八格")
	var torch_cell: PlantCell = _plant_at(manager, 2, 2, PlantIds.TORCH_WOOD)
	if torch_cell == null:
		_check(a, "种得下火炬树桩", false, "格子不可用")
		_finish(a)
		return
	var cross: Array[PlantCell] = manager.get_plant_cell_cross(torch_cell)
	var lit := 0
	for cell: PlantCell in cross:
		if cell.light_level == 1:
			lit += 1
	_check(a, "火炬树桩点亮十字四格（每格 1 级）", lit == cross.size() and lit > 0,
		"%d/%d" % [lit, cross.size()])
	_check(a, "火炬树桩自己那格不亮", torch_cell.light_level == 0, str(torch_cell.light_level))
	## 斜角那格不在十字里 → 不该亮
	var diagonal: PlantCell = manager.all_plant_cells[1][1]
	_check(a, "斜角格不亮（只照十字，不是周围一圈）", diagonal.light_level == 0,
		str(diagonal.light_level))

	## 向日葵种在火炬照亮的格子上 → 产光 25 + 5 = 30
	var flower_cell: PlantCell = _plant_at(manager, 1, 2, PlantIds.SUN_FLOWER)
	if flower_cell == null:
		_check(a, "种得下向日葵", false, "格子不可用")
	else:
		_check(a, "向日葵所在的格子被照亮（1 级）", flower_cell.light_level == 1,
			str(flower_cell.light_level))
		_check(a, "向日葵产光 = 30（原版 25 + 1 级 × 5）", _sun_value(flower_cell) == 30,
			str(_sun_value(flower_cell)))
	## 没被照亮的向日葵仍是 25
	var dark_cell: PlantCell = _plant_at(manager, 3, 7, PlantIds.SUN_FLOWER)
	if dark_cell != null:
		_check(a, "没被照亮的向日葵仍是 25", _sun_value(dark_cell) == VANILLA_SUN_FLOWER_VALUE,
			str(_sun_value(dark_cell)))

	## 路灯花：周围一圈 8 格（用中间那几行，四邻齐全）
	var plantern_cell: PlantCell = _plant_at(manager, 2, 6, PlantIds.PLANTERN)
	if plantern_cell == null:
		_check(a, "种得下路灯花", false, "格子不可用")
	else:
		var lit_around := 0
		for other: PlantCell in manager.get_plant_cell_surrounding(plantern_cell):
			if other == plantern_cell:
				continue
			if other.light_level >= 1:
				lit_around += 1
		_check(a, "路灯花点亮周围八格（不含自己那格）", lit_around == 8, str(lit_around))
		_check(a, "路灯花自己那格不亮", plantern_cell.light_level == 0,
			str(plantern_cell.light_level))

	# ------------------------------------------------ STEP5 实例层那几条
	a.log("STEP5 实例层：寒冰菇 / 机枪 / 卷心菜 / 吸金磁")
	var ice: Plant000Base = _plant(manager, 0, 0, PlantIds.ICE_SHROOM)
	if ice == null:
		_check(a, "种得下寒冰菇", false, "格子不可用")
	else:
		var bomb: BombComponentBase = ice.get_node_or_null(^"BombComponent") as BombComponentBase
		_check(a, "寒冰菇伤害 = 100", bomb != null and bomb.bomb_value == 100,
			"null" if bomb == null else str(bomb.bomb_value))

	var gatling: Plant000Base = _plant(manager, 0, 1, PlantIds.GATLING_PEA)
	if gatling == null:
		_check(a, "种得下机枪射手", false, "格子不可用")
	else:
		var atk: AttackComponentBulletBase = gatling.get_node_or_null(
			^"AttackComponent") as AttackComponentBulletBase
		## 原版 4 发写在动画里，模组补 2 发 = 6 发
		_check(a, "机枪射手补发 2 颗（动画 4 + 补 2 = 6 连发）",
			atk != null and atk.burst_extra_num == 2,
			"null" if atk == null else str(atk.burst_extra_num))

	var cabbage: Plant000Base = _plant(manager, 3, 0, PlantIds.CABBAGE_PULT)
	if cabbage == null:
		_check(a, "种得下卷心菜投手", false, "格子不可用")
	else:
		var detect: DetectComponent = cabbage.get_node_or_null(
			^"AttackComponent/DetectComponent") as DetectComponent
		if detect == null:
			_check(a, "拿得到卷心菜的检测组件", false, "null")
		else:
			_check(a, "卷心菜有 3 块检测区（本行 + 上下两行）", detect.all_ray_area.size() == 3,
				str(detect.all_ray_area.size()))
			_check(a, "卷心菜关掉了同行限制（不然打不到别的行）", not detect.is_lane)

	var gold: Plant000Base = _plant(manager, 4, 0, PlantIds.GOLD_MAGNET)
	if gold == null:
		_check(a, "种得下吸金磁", false, "格子不可用")
	else:
		var magnet: MagnetComponent = gold.get_node_or_null(^"MagnetComponent") as MagnetComponent
		_check(a, "吸金磁装上了吸铁组件", magnet != null)
		if magnet != null:
			_check(a, "吸金磁一次最多吸 3 件铁器", magnet.max_iron == 3, str(magnet.max_iron))
			_check(a, "铁器容器挂在本体自己的 Body 下",
				is_instance_valid(magnet.curr_iron_container)
				and magnet.curr_iron_container.get_parent() == gold.get_node_or_null(^"Body"))

	# ------------------------------------------------ STEP6 关掉模组
	a.log("STEP6 关掉模组 → 数据层回到原版")
	ModManager.set_mod_enabled(ModIds.BALANCE, false)
	_check(a, "豌豆射手阳光回到 %d" % VANILLA_SUN_PEA,
		_sun(registry, PlantIds.PEA_SHOOTER_SINGLE) == VANILLA_SUN_PEA,
		str(_sun(registry, PlantIds.PEA_SHOOTER_SINGLE)))
	_check(a, "咖啡豆阳光回到 %d" % VANILLA_SUN_COFFEE,
		_sun(registry, PlantIds.COFFEE_BEAN) == VANILLA_SUN_COFFEE,
		str(_sun(registry, PlantIds.COFFEE_BEAN)))
	_check(a, "吸金磁阳光回到 %d" % VANILLA_SUN_GOLD_MAGNET,
		_sun(registry, PlantIds.GOLD_MAGNET) == VANILLA_SUN_GOLD_MAGNET,
		str(_sun(registry, PlantIds.GOLD_MAGNET)))
	_check(a, "仙人掌子弹回到只打 1 个", _cactus_pierce() == 1, str(_cactus_pierce()))
	## 开关是**持久化**的，跑完必须存回去，别把后面的探针带歪
	ModManager.save_mods()
	_finish(a)


#region 小工具
## 在指定格子种一株，返回那株植物（格子不可种 / 种不出来返回 null）
func _plant(manager, row: int, col: int, plant_type: StringName) -> Plant000Base:
	var cell: PlantCell = manager.all_plant_cells[row][col]
	if cell == null or not cell.can_common_plant:
		return null
	var plant := cell.create_plant(plant_type)
	return plant if is_instance_valid(plant) else null


## 同上，返回格子（光照要读格子）
func _plant_at(manager, row: int, col: int, plant_type: StringName) -> PlantCell:
	var cell: PlantCell = manager.all_plant_cells[row][col]
	if cell == null or not cell.can_common_plant:
		return null
	if not is_instance_valid(cell.create_plant(plant_type)):
		return null
	return cell


func _sun(registry, plant_type: StringName) -> int:
	return int(registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.SunCost))


## 造一颗仙人掌子弹读它的「最多打几个」，读完释放
func _cactus_pierce() -> int:
	var bullet := Global.bullet_registry.create_bullet(BulletIds.CACTUS)
	if bullet == null:
		return -1
	var num: int = bullet.max_attack_num
	bullet.free()
	return num


## 读某格向日葵的产光值
func _sun_value(cell: PlantCell) -> int:
	var plant: Plant000Base = cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm)
	if not is_instance_valid(plant):
		return -1
	var create_sun: CreateSunComponent = \
		plant.get_node_or_null(^"CreateSunComponent") as CreateSunComponent
	return -1 if create_sun == null else create_sun.sun_value
#endregion


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[BALANCE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
