extends Node
## 准备阶段展示僵尸（对齐原版 `CutScene::PlaceStreetZombies` / `PlaceAZombie`）
##
## 原版开场把**本关出怪表**摆到草坪右侧：5x5 网格互不重叠，先摆大体型（2x2 巨人 / 冰车）
## 再摆其余；镜头右移时玩家能看清本关会来哪些僵尸、各自大概几只。
##
## 本仓库没有预先建好的全波次出怪表（每波按战力上限在运行时随机生成），
## 所以用「出怪权重 ÷ spawn_count_weight_unit」还原每类僵尸在出怪表里的条目数
## （普僵权重 4000 → 4 条），再按原版公式分配预览份数：
##   预览数 = clamp(条目数 × 容量 ÷ 总条目数, 1, 条目数)
##
## 数据来源：`../re-plants-vs-zombies-main/Lawn/CutScene.cpp`
##   PlaceStreetZombies() / PlaceAZombie() / CanZombieGoInGridSpot() / FindPlaceForStreetZombies()
class_name ZombieShowInStart

@onready var zombie_manager: ZombieManager = %ZombieManager

@export_group("准备阶段展示僵尸")
## 按y轴顺序渲染
@onready var show_zombie_panel: Panel = %ShowZombiePanel
## 不按y轴顺序渲染
@onready var show_zombie_panel_2: Panel = %ShowZombiePanel2

## 预览容量（原版 `aPreviewCapacity`）：各类型按条目占比分到的预览总数
@export var preview_capacity := 10
## 小僵尸大麻烦的预览容量（原版 15）
## 原版还有「暴雨夜冒险 / 迷你 boss 18」，本仓库暂无这两类关卡，等有时再补判定
@export var preview_capacity_mini_zombie := 15
## 出怪权重 → 出怪表条目数的换算单位（普僵权重 4000 → 4 条）
@export var spawn_count_weight_unit := 1000.0
## 不参与预览的僵尸类型：原版出怪池里没有旗帜僵尸（旗帜是大波时才单独加进波次的）
@export var exclude_show_zombie_types: Array[StringName] = [
	ZombieIds.FLAG,
]
## 预览网格（原版 5x5；grid_x = 屏幕横向、grid_y = 纵向）
@export var preview_grid := Vector2i(5, 5)

## 每类预览最多 1 只的类型（原版：蹦极 / 雪橇「至多仅允许有 1 只预览僵尸」）
const AT_MOST_ONE_PREVIEW_TYPES: Array[StringName] = [
	ZombieIds.BUNGI,
	ZombieIds.BOBSLED,
]
## 需要冲刺距离的类型（原版 CanZombieGoInGridSpot 的 zombie_polevaulter 那一组）
const LONG_ZOMBIE_TYPES: Array[StringName] = [
	ZombieIds.ZAMBONI,
	ZombieIds.BOBSLED,
	ZombieIds.POLE_VAULTER,
]

## 原版 PlaceAZombie 的网格步长（像素）：x = gridX * 56，y = gridY * 90
const BASE_GRID_STEP := Vector2(56.0, 90.0)
## 原版预览区尺寸（相对 gridX 0 / gridY 0）：x 275、y 440（原版 y 70..510）
## 只用来把原版像素换算到本仓库的预览面板（ShowZombiePanel 220x400），改面板尺寸无需动这里
const BASE_PREVIEW_AREA := Vector2(275.0, 440.0)
## 奇数列整体下沉（原版 +30，两排僵尸错开）
const ODD_COLUMN_Y_OFFSET := 30.0
## 普通僵尸的随机抖动上限（原版 Rand(15)）
const PREVIEW_JITTER := 15.0
## 蹦极僵尸的预览点（原版 (gridX * 50 + 950, 50)，相对预览区左上角）
const BASE_BUNGI_POS := Vector2(120.0, -20.0)
## 雪橇队的固定预览点（原版 (1105, 480)，相对预览区左上角）
const BASE_BOBSLED_POS := Vector2(275.0, 410.0)

var show_zombies_array :Array[Zombie000Base]


#region 生成关卡前展示僵尸
## 生成一个展示僵尸（[pos] 是面板内坐标）
func create_show_zombie(zombie_type: StringName, parent_node: Panel, pos: Vector2) -> Zombie000Base:
	return CharacterShowFactory.create_show_zombie(
		zombie_type,
		parent_node,
		pos,
		{Zombie000Base.E_ZInitAttr.CurrZombieRowType: CharacterRegistry.ZombieRowType.Land}
	)

## 收进预览列表（创建失败时返回 null，别把 null 塞进数组 —— 删除阶段会报错）
func add_show_zombie(zombie: Zombie000Base) -> void:
	if zombie == null:
		return
	show_zombies_array.append(zombie)

## 生成关卡前展示僵尸（原版 CutScene::PlaceStreetZombies）
## 原版有 `mPlacedZombies` 幂等闸门：时间轴事件重复触发时不重复摆一遍
func create_prepare_show_zombies():
	if not show_zombies_array.is_empty():
		return
	## 网格配成 0 时占位表是空的，后面的索引会越界
	if preview_grid.x <= 0 or preview_grid.y <= 0:
		Log.error("僵尸预览网格配置非法: " + str(preview_grid))
		return
	var preview_num := get_preview_num_by_type()
	var zombie_grid := create_preview_grid()
	## 原版顺序：先摆大体型（2x2 巨人 / 冰车），再摆其余
	for zombie_type in get_preview_types_in_place_order(preview_num.keys()):
		for _i in range(preview_num[zombie_type]):
			place_preview_zombie(zombie_type, zombie_grid)
	## 蹦极僵尸不按 y 轴排序渲染，单独放一层（`is_bungi` 的关它不进 `zombie_refresh_types`）
	if zombie_manager.is_bungi:
		add_show_zombie(create_show_zombie(
			ZombieIds.BUNGI, show_zombie_panel_2, get_bungi_panel_pos()))

## 各类型的预览份数（原版 aZombieTypeCount → aZombiePreviewNum）
func get_preview_num_by_type() -> Dictionary[StringName, int]:
	var entry_count := get_preview_entry_count_by_type()
	var total_count := 0
	for zombie_type in entry_count:
		total_count += entry_count[zombie_type]
	if total_count <= 0:
		return {}
	var capacity := get_preview_capacity()
	var preview_num: Dictionary[StringName, int] = {}
	for zombie_type in entry_count:
		var num_in_wave: int = entry_count[zombie_type]
		var num := roundi(float(num_in_wave) * capacity / total_count)
		## 下限 1：预览的作用就是让玩家看清本关有哪些僵尸；上限 = 该类型条目数
		preview_num[zombie_type] = clampi(num, 1, num_in_wave)
	return preview_num

## 出怪表条目数：原版统计全波次出怪表里每种僵尸出现了几次。
## 本仓库没有预生成表，用出怪权重折算（普僵 4000 → 4 条）；蹦极 / 雪橇最多 1 只（原版同款）。
func get_preview_entry_count_by_type() -> Dictionary[StringName, int]:
	var entry_count: Dictionary[StringName, int] = {}
	var create_manager := zombie_manager.zombie_wave_manager.zombie_wave_create_manager
	var weight_unit := maxf(spawn_count_weight_unit, 1.0)
	for zombie_type in get_show_zombie_types():
		var count := 1
		if create_manager != null:
			## 上限按容量夹一次：热注册 / 未配权重的类型会拿到 9999 这种极大值
			count = clampi(
				roundi(create_manager.get_zombie_weight(zombie_type) / weight_unit),
				1, get_preview_capacity())
		if zombie_type in AT_MOST_ONE_PREVIEW_TYPES:
			count = 1
		entry_count[zombie_type] = count
	## 泳池关必定预览一只鸭子僵尸（原版：出怪表里没有也单独补一条）
	if is_stage_has_pool():
		entry_count[ZombieIds.DUCKYTUBE] = maxi(entry_count.get(ZombieIds.DUCKYTUBE, 0), 1)
	return entry_count

## 参与预览的出怪类型（原版出怪池不含旗帜僵尸）
## 原版另有两条例外（雪人只在暴雨夜、雪橇只在雪橇狂欢关）：本仓库的出怪表是按关卡配的，
## 这两类不会出现在别关的表里，等价于原版判断，故不重复写死
func get_show_zombie_types() -> Array[StringName]:
	var show_types: Array[StringName] = []
	for zombie_type in zombie_manager.zombie_refresh_types:
		if zombie_type in exclude_show_zombie_types:
			continue
		show_types.append(zombie_type)
	return show_types

## 预览容量（原版 aPreviewCapacity）
func get_preview_capacity() -> int:
	if is_mini_zombie_level():
		return preview_capacity_mini_zombie
	return preview_capacity

## 放置顺序：原版先放 2x2 巨人与冰车，再放其余（避免大体积僵尸被小僵尸挤掉位置）
func get_preview_types_in_place_order(types: Array) -> Array[StringName]:
	var jumbo: Array[StringName] = []
	var normal: Array[StringName] = []
	for zombie_type in types:
		if is_jumbo_preview_zombie(zombie_type):
			jumbo.append(zombie_type)
		else:
			normal.append(zombie_type)
	var ordered: Array[StringName] = []
	ordered.append_array(jumbo)
	ordered.append_array(normal)
	return ordered
#endregion


#region 原版占位规则（CutScene::FindAndPlaceZombie / CanZombieGoInGridSpot）
## 占位表：true = 这一格已经有僵尸（原版 bool aZombieGrid[5][5]）
func create_preview_grid() -> Array:
	var grid: Array = []
	for _x in range(preview_grid.x):
		var column: Array[bool] = []
		for _y in range(preview_grid.y):
			column.append(false)
		grid.append(column)
	return grid

## 摆一只预览僵尸：先占格（2x2 占 4 格），再算落点
func place_preview_zombie(zombie_type: StringName, zombie_grid: Array) -> void:
	var grid_pos := find_preview_grid_spot(zombie_type, zombie_grid)
	if zombie_type != ZombieIds.BUNGI:
		zombie_grid[grid_pos.x][grid_pos.y] = true
	if is_2x2_zombie(zombie_type) and grid_pos.x > 0 and grid_pos.y > 0:
		zombie_grid[grid_pos.x - 1][grid_pos.y] = true
		zombie_grid[grid_pos.x][grid_pos.y - 1] = true
		zombie_grid[grid_pos.x - 1][grid_pos.y - 1] = true
	add_show_zombie(create_show_zombie(
		zombie_type,
		show_zombie_panel,
		get_preview_panel_pos(zombie_type, grid_pos.x, grid_pos.y, show_zombie_panel)
	))

## 在空位里等权挑一个（原版 FindPlaceForStreetZombies）
func find_preview_grid_spot(zombie_type: StringName, zombie_grid: Array) -> Vector2i:
	if zombie_type == ZombieIds.BUNGI:
		return Vector2i.ZERO
	var spots: Array[Vector2i] = []
	for grid_x in range(preview_grid.x):
		for grid_y in range(preview_grid.y):
			if can_zombie_go_in_grid_spot(zombie_type, grid_x, grid_y, zombie_grid):
				spots.append(Vector2i(grid_x, grid_y))
	if spots.is_empty():
		## 原版找不到位置时压在 (2,2)：重叠总比不显示好（网格比 3x3 小时夹回网格内）
		Log.warn("僵尸预览没有空位了，%s 压在中央" % str(zombie_type))
		return Vector2i(
			clampi(2, 0, preview_grid.x - 1),
			clampi(2, 0, preview_grid.y - 1))
	return spots[randi_range(0, spots.size() - 1)]

## 这一格能不能放（原版 CanZombieGoInGridSpot，条件逐条对应）
func can_zombie_go_in_grid_spot(
	zombie_type: StringName, grid_x: int, grid_y: int, zombie_grid: Array
) -> bool:
	if zombie_grid[grid_x][grid_y]:
		return false
	var max_x: int = preview_grid.x - 1
	if is_2x2_zombie(zombie_type):
		## 2x2 要往左上各扩一格
		if grid_x == 0 or grid_y == 0:
			return false
		if zombie_grid[grid_x - 1][grid_y] or zombie_grid[grid_x][grid_y - 1] \
				or zombie_grid[grid_x - 1][grid_y - 1]:
			return false
	## 最靠里（屏幕最右）的一列：最上一格不放；冰车只能放这一列
	if grid_x == max_x:
		if grid_y == 0:
			return false
	else:
		if zombie_type == ZombieIds.ZAMBONI:
			return false
		if grid_x == 0 and is_stage_has_pool():
			return false
	## 屋顶最里一格放不下
	if is_stage_has_roof() and grid_x == 0 and grid_y == 0:
		return false
	## 浓雾关最里列的最上一格不放气球（会飘出画面）
	if grid_x == max_x and is_stage_has_fog() and zombie_type == ZombieIds.BALLOON:
		return false
	## 大体型 / 冰车 / 雪橇 / 撑杆要留冲刺距离，不能贴最里两列
	if is_2x2_zombie(zombie_type) or zombie_type in LONG_ZOMBIE_TYPES:
		if grid_x == 0:
			return false
		if grid_x == 1 and (is_stage_has_pool() or grid_y == 0):
			return false
	return true

## 2x2 大体型（原版 Is2x2Zombie：巨人 / 红眼巨人；本仓库红眼巨人不是独立类型）
func is_2x2_zombie(zombie_type: StringName) -> bool:
	return zombie_type == ZombieIds.GARGANTUAR

## 原版「先摆」的那一组：2x2 巨人与冰车
func is_jumbo_preview_zombie(zombie_type: StringName) -> bool:
	return is_2x2_zombie(zombie_type) or zombie_type == ZombieIds.ZAMBONI
#endregion


#region 原版落点（CutScene::PlaceAZombie）
## 原版落点（相对预览区左上角）→ 面板内坐标
func get_preview_panel_pos(zombie_type: StringName, grid_x: int, grid_y: int, panel: Control) -> Vector2:
	var base_pos := get_preview_base_pos(zombie_type, grid_x, grid_y)
	return Vector2(
		base_pos.x / BASE_PREVIEW_AREA.x * panel.size.x,
		base_pos.y / BASE_PREVIEW_AREA.y * panel.size.y
	)

## 原版落点（相对预览区左上角，单位 = 原版屏幕像素）
func get_preview_base_pos(zombie_type: StringName, grid_x: int, grid_y: int) -> Vector2:
	if zombie_type == ZombieIds.BUNGI:
		return BASE_BUNGI_POS
	var pos := Vector2(grid_x * BASE_GRID_STEP.x, grid_y * BASE_GRID_STEP.y)
	## 奇数列整体下沉，两排僵尸错开
	if grid_x % 2 == 1:
		pos.y += ODD_COLUMN_Y_OFFSET
	## 屋顶：越靠里越靠上（原版公式 y -= gridY * 2 - gridX * 7 + 30）
	if is_stage_has_roof():
		pos.y -= grid_y * 2 - grid_x * 7 + 30
		pos.x -= 5.0
	## 特殊体型 / 特殊关的抖动（原版同款）
	if zombie_type == ZombieIds.ZAMBONI:
		pos += Vector2(-30.0, -10.0)
	elif zombie_type == ZombieIds.BOBSLED:
		## 雪橇队固定在最靠里的冰面上
		return BASE_BOBSLED_POS
	elif is_mini_zombie_level():
		## 小僵尸大麻烦：各自随机错开，挤成一堆反而像原版
		pos += Vector2(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0))
	elif is_2x2_zombie(zombie_type):
		pos.x += randf_range(-20.0, -5.0)
	elif grid_y == preview_grid.y - 1:
		## 最后一行贴着面板底边，只横向抖动
		pos.x += randf_range(0.0, PREVIEW_JITTER)
	else:
		pos += Vector2(randf_range(0.0, PREVIEW_JITTER), randf_range(0.0, PREVIEW_JITTER))
	return pos

## 蹦极僵尸的预览点：挂在预览面板顶端（原版在画面最上方 (950, 50)）
func get_bungi_panel_pos() -> Vector2:
	return Vector2(show_zombie_panel_2.size.x * 0.45, 0.0)
#endregion


#region 场地 / 关卡判定
## 泳池场地（原版 StageHasPool：3/4 关与浓雾关都有水面）
func is_stage_has_pool() -> bool:
	if zombie_manager.game_para == null:
		return false
	var bg: ConstLevelData.GameBg = zombie_manager.game_para.game_BG
	return bg == ConstLevelData.GameBg.Pool or bg == ConstLevelData.GameBg.Fog

## 屋顶场地（原版 StageHasRoof：屋顶 / 僵王关（夜屋顶）/ DLC 月夜屋顶）
func is_stage_has_roof() -> bool:
	if zombie_manager.game_para == null:
		return false
	var bg: ConstLevelData.GameBg = zombie_manager.game_para.game_BG
	return bg == ConstLevelData.GameBg.Roof or bg == ConstLevelData.GameBg.Boss \
		or bg == ConstLevelData.GameBg.MoonRoof

## 浓雾场地
func is_stage_has_fog() -> bool:
	if zombie_manager.game_para == null:
		return false
	return zombie_manager.game_para.game_BG == ConstLevelData.GameBg.Fog

## 小僵尸大麻烦关卡（本关所有正常出战僵尸都带 IsMiniZombie 规则）
func is_mini_zombie_level() -> bool:
	var level_script := zombie_manager.game_para as LevelScriptBase
	if level_script == null:
		return false
	return bool(level_script.get_zombie_init_para_extra().get(
		Zombie000Base.E_ZInitAttr.IsMiniZombie, false))
#endregion


#region 删除关卡前展示僵尸
## 删除关卡前展示僵尸
func delete_prepare_show_zombies() -> void:
	for z in show_zombies_array:
		if is_instance_valid(z):
			z.queue_free()
	show_zombies_array.clear()  # 清空数组
#endregion
