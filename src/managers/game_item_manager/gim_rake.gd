extends Node
class_name GIM_Rake
## 钉耙管理器
##
## 原版一代 PC: 钉耙在疯狂戴夫商店 $200 买一次,管三关(lasts for three levels),
## 每关开局自动放在草坪上,踩到它的僵尸吃 1800 点伤害(除巨人类与高坚果僵尸外当场击杀)。
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Garden_Rake)
##
## 剩余关数存在 GlobalGameState.rake_use_num(买一次 +3,通关一关 -1);
## 放哪一行由地图数据 ResourceMapRowData.have_rake 决定(见 docs/参考存档/地图实现.md),
## 一行都没标时退到正中间那条陆地行 —— 原版放在「第一只僵尸出现的那一行」,
## 本仓库没有拖拽换行的交互,先用地图数据 + 中间行兜底。

@onready var game_item_manager: GameItemManager = %GameItemManager
@onready var rakes: Node2D = %Rakes

const RAKE_SCENE := preload("res://src/items/rake/rake.tscn")
## 钉耙落在「从右数第 2 列」(原版: "the second column (from the right)")
const RAKE_COL_FROM_RIGHT := 2
## 行内 z_index 偏移:僵尸行 30、小推车 40,钉耙压在僵尸脚下所以用 20
const RAKE_Z_INDEX_OFFSET := 20

var all_rakes: Array[Rake] = []


## 初始化钉耙:手上没有钉耙(剩余关数为 0)时什么都不做
func init_rakes() -> void:
	if not Global.global_game_state.is_rake_owned():
		return
	## 砸罐子这类没有自然刷怪的玩法不放钉耙(原版 Puzzle / Vasebreaker 同样不放)
	if game_item_manager.game_para.is_pot_mode:
		return
	create_all_rakes()


## 按地图数据在本关要放行上生成钉耙
func create_all_rakes() -> void:
	var map_data: ResourceMapData = game_item_manager.game_para.map_data
	if map_data == null or not map_data.is_valid():
		Log.warn("缺少地图数据，无法创建钉耙")
		return
	for lane in _get_rake_lanes(map_data):
		create_rake(map_data, lane)


## 本关要放钉耙的行:地图数据里 have_rake 的行;一行都没标时退到中间那条陆地行
func _get_rake_lanes(map_data: ResourceMapData) -> Array[int]:
	var lanes: Array[int] = []
	for i in range(map_data.get_row_num()):
		if map_data.rows[i].have_rake:
			lanes.append(i)
	if not lanes.is_empty():
		return lanes
	var default_lane := _get_default_lane(map_data)
	if default_lane >= 0:
		lanes.append(default_lane)
	return lanes


## 兜底行:优先正中间那行,该行不是陆地(泳池的水路行)就按距离顺延找一条陆地行
func _get_default_lane(map_data: ResourceMapData) -> int:
	var row_num := map_data.get_row_num()
	if row_num <= 0:
		return -1
	## 用浮点除法再取整,避免 int/int 触发 INTEGER_DIVISION 警告(row_num 为正,等价于向下取整)
	var middle := floori(row_num * 0.5)
	for offset in range(row_num):
		for lane in [middle + offset, middle - offset]:
			if lane < 0 or lane >= row_num:
				continue
			if map_data.rows[lane].zombie_row_type == CharacterRegistry.ZombieRowType.Land:
				return lane
	return -1


## 钉耙落点:该行「从右数第 2 列」格子的中心,脚部 y 与僵尸生成点对齐(屋顶斜面用 col_dy)
func _get_rake_global_pos(map_data: ResourceMapData, lane: int) -> Vector2:
	var col := maxi(0, map_data.get_col_num() - RAKE_COL_FROM_RIGHT)
	var row_data: ResourceMapRowData = map_data.rows[lane]
	return Vector2(
		map_data.col_x[col] + map_data.col_width[col] * 0.5 + row_data.get_col_dx(col),
		row_data.zombie_create_global_pos.y + row_data.get_col_dy(col)
	)


## 生成一把钉耙
func create_rake(map_data: ResourceMapData, lane: int) -> Rake:
	var rake: Rake = RAKE_SCENE.instantiate()
	rake.lane = lane
	rake.z_index = lane * 50 + RAKE_Z_INDEX_OFFSET
	## 节点挂在原点,所以减掉父节点位置后局部坐标 == 全局坐标
	rake.position = _get_rake_global_pos(map_data, lane) - rakes.global_position
	rakes.add_child(rake)
	all_rakes.append(rake)
	Log.debug(str("生成钉耙, 行:") + str(lane) + str(" 全局位置:") + str(rake.global_position))
	return rake


## 本关是否放下了钉耙(触发过的钉耙已经 queue_free,但记录还在)
func is_have_rake() -> bool:
	return not all_rakes.is_empty()


## 通关结算时消耗一次使用次数
## 原版: 哪怕本关一只僵尸都没踩到也算用掉(lasts for three levels),所以这里不判断是否触发过
func consume_rake_use_on_level_success() -> void:
	if not is_have_rake():
		return
	if Global.global_game_state.consume_rake_use():
		Log.debug(str("通关消耗一次钉耙,剩余可用关数:") + str(Global.global_game_state.get_rake_use_num()))
