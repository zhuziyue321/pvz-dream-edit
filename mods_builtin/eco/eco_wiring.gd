extends RefCounted
## 模组「生态版」里**每局接线**的那几条（植物种下之后才有的组件）
##
## ★ 与 `eco_plant_patcher.gd` 的分工：那边改「数据层」（注册表 / 子弹，装一次全局生效），
##   这边改「实例层」—— 爆炸伤害、连发数、检测区、吸铁组件、产光值都在植物实例上，
##   实例随关卡销毁，格子的光照等级也每局清零重算，所以每一局都要接一次。
##
## ★ 全部走本体给的通用口子（本体不认识本模组）：
##   格子 `light_level` / `DetectComponent.add_extra_ray_area()` / 攻击组件 `burst_extra_num`
##   / `MagnetComponent.max_iron` / `CreateSunComponent.sun_value`。
##
## ⚠️ `user://` 下的脚本拿不到静态类型推断（`var x := 无类型的返回值` 会被判编译错误），
##   所有从数组 / `get_node_or_null()` 里取出来的东西**必须显式写类型**。

const Settings := preload("eco_settings.gd")

## 磁力菇场景：只用来**取一份吸铁组件的模板**（不进树，只 duplicate 它那一棵子树）
const MAGNET_SHROOM_TSCN := "res://src/entities/character/plant/plant_magnet_shroom.tscn"
static var _magnet_template: Node = null


## 每局安装：接上格子的「种下 / 移除」信号（照明范围随种植变化），并把当前光照算一遍
static func install(main_game: MainGameManager) -> void:
	if main_game == null or main_game.plant_cell_manager == null:
		return
	for row in main_game.plant_cell_manager.all_plant_cells:
		for cell: PlantCell in row:
			if cell == null:
				continue
			if not cell.signal_plant_create.is_connected(_on_plant_create):
				cell.signal_plant_create.connect(_on_plant_create)
			if not cell.signal_plant_free.is_connected(_on_plant_free):
				cell.signal_plant_free.connect(_on_plant_free)
	refresh_light()


#region 光照：火炬树桩（十字四格）/ 路灯花（周围八格） → 向日葵每级多产 5 阳光
## 重算全场光照并把结果写进向日葵的产光值
##
## 为什么不增量维护：照明植物被铲掉 / 被啃掉时范围要跟着收，增量就得记「谁给谁加过」；
## 全场重算（几十个格子）成本可以忽略，而且**不会算错** —— 每次都从零开始，天然幂等。
static func refresh_light() -> void:
	var manager: PlantCellManager = _manager()
	if manager == null:
		return
	for row in manager.all_plant_cells:
		for cell: PlantCell in row:
			cell.set_light_level(0)
	for row in manager.all_plant_cells:
		for cell: PlantCell in row:
			var plant: Plant000Base = cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm)
			if not is_instance_valid(plant):
				continue
			match plant.plant_type:
				PlantIds.TORCH_WOOD:
					for other: PlantCell in manager.get_plant_cell_cross(cell):
						other.add_light_level(Settings.LIGHT_TORCH_WOOD)
				PlantIds.PLANTERN:
					for other: PlantCell in manager.get_plant_cell_surrounding(cell):
						## 「周围 8 格」不含路灯花自己那一格
						if other == cell:
							continue
						other.add_light_level(Settings.LIGHT_PLANTERN)
	for row in manager.all_plant_cells:
		for cell: PlantCell in row:
			var plant: Plant000Base = cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm)
			if not is_instance_valid(plant) or plant.plant_type != PlantIds.SUN_FLOWER:
				continue
			var create_sun: CreateSunComponent = \
				plant.get_node_or_null(^"CreateSunComponent") as CreateSunComponent
			if create_sun == null:
				continue
			create_sun.sun_value = Settings.VANILLA_SUN_FLOWER_VALUE \
				+ Settings.SUN_PER_LIGHT_LEVEL * cell.light_level
#endregion


#region 植物种下 / 移除
static func _on_plant_create(_cell: PlantCell, _plant_type: StringName) -> void:
	var manager: PlantCellManager = _manager()
	if manager == null:
		return
	## 信号只带类型，实例从格子里取（信号是在 `create_plant()` 末尾发的，此时实例已就绪）
	_apply_created_plants(manager)
	refresh_light()


static func _on_plant_free(_cell: PlantCell, _plant_type: StringName) -> void:
	refresh_light()


## 把「实例层」那几条调到场上所有还没调过的植物上
## （只扫一遍全场而不是只处理刚种下的那一株：读存档开局、传送带补种植物的路径不止一条，
##   幂等地刷一遍最省心 —— 下面每个 `_apply_*` 自身都是幂等的）
static func _apply_created_plants(manager: PlantCellManager) -> void:
	for row in manager.all_plant_cells:
		for cell: PlantCell in row:
			var plant: Plant000Base = cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm)
			if not is_instance_valid(plant):
				continue
			match plant.plant_type:
				PlantIds.ICE_SHROOM:
					_apply_ice_shroom(plant)
				PlantIds.GATLING_PEA:
					_apply_gatling_pea(plant)
				PlantIds.CABBAGE_PULT:
					_apply_cabbage_pult(plant)
				PlantIds.GOLD_MAGNET:
					_apply_gold_magnet(plant)
#endregion


#region 各条调整
## 寒冰菇：爆炸伤害（原版 20）—— 伤害由角色攻击力承载（`BombComponentIce` 读 `attack_value`）
static func _apply_ice_shroom(plant: Plant000Base) -> void:
	plant.attack_value = Settings.ICE_SHROOM_DAMAGE


## 机枪射手：一次攻击打出 6 颗
## 原版那 4 发是**写在射击动画里**的（`gatling_pea_shooting.tres` 有 4 个 `_shoot_bullet` 轨道），
## 动画是原版资源不能改，所以这里只补「动画之外再发几颗」的差额。
static func _apply_gatling_pea(plant: Plant000Base) -> void:
	var attack: AttackComponentBulletBase = \
		plant.get_node_or_null(^"AttackComponent") as AttackComponentBulletBase
	if attack == null:
		return
	attack.burst_extra_num = maxi(0,
		Settings.GATLING_BURST_NUM - Settings.VANILLA_GATLING_BURST_NUM)


## 卷心菜投手：索敌三行
## 本行那块检测区是现成的，把它复制两份挪到上下相邻行（`DetectComponent.add_extra_ray_area()`）；
## 再关掉检测组件的「同行限制」—— 不然索敌够了，投出去的子弹仍会因为不同行而打不到。
static func _apply_cabbage_pult(plant: Plant000Base) -> void:
	var attack: AttackComponentBulletBase = \
		plant.get_node_or_null(^"AttackComponent") as AttackComponentBulletBase
	if attack == null:
		return
	var detect: DetectComponent = attack.get_node_or_null(^"DetectComponent") as DetectComponent
	if detect == null:
		return
	## 已经接过就跳过（检测组件下本来就有 Area2D + 掩码组件两个子节点，
	## 所以只能按**检测区**的数量判，不能按子节点数判）
	if detect.all_ray_area.size() > 1:
		return
	var base_area := _first_area_2d(detect)
	if base_area == null:
		return
	var manager: PlantCellManager = _manager()
	if manager == null or plant.plant_cell == null:
		return
	var row: int = plant.plant_cell.row_col.x
	var col: int = plant.plant_cell.row_col.y
	## 行距按**相邻格子的实际中心**算（屋顶有斜坡，不能写死一个常数）
	var base_y: float = plant.to_local(plant.plant_cell.global_position).y
	for offset in [-1, 1]:
		var other_row: int = row + offset
		if other_row < 0 or other_row >= manager.row_col.x:
			continue
		var other_cell: PlantCell = manager.all_plant_cells[other_row][col]
		if other_cell == null:
			continue
		var area := base_area.duplicate() as Area2D
		area.position.y += plant.to_local(other_cell.global_position).y - base_y
		detect.add_extra_ray_area(area)
	detect.is_lane = false
	attack.is_lane = false


## 吸金磁：装上「吸铁器」的能力，一次最多吸 3 件
## 组件本体是原版就有的（`MagnetComponent`，磁力菇在用），这里照磁力菇那份复制一个挂上去 ——
## 不新造一份同名的，免得又多一套「两种写法」。
static func _apply_gold_magnet(plant: Plant000Base) -> void:
	if plant.get_node_or_null(^"MagnetComponent") != null:
		return
	var template := _get_magnet_template()
	var body: Node2D = plant.get_node_or_null(^"Body") as Node2D
	if template == null or body == null:
		return
	## 吸进来的铁器要有地方放（磁力菇挂在 `Body/CurrIronContainer`，这里照着建一个）
	var container := Node2D.new()
	container.name = "CurrIronContainer"
	body.add_child(container)

	var magnet := template.duplicate() as MagnetComponent
	magnet.name = "MagnetComponent"
	magnet.max_iron = Settings.GOLD_MAGNET_IRON_NUM
	plant.add_child(magnet)
	## duplicate 带过来的 `curr_iron_container` 指向的是模板里那个容器，必须改成这一个
	magnet.curr_iron_container = container
#endregion


#region 小工具
static func _manager() -> PlantCellManager:
	var main_game := GameContext.curr_main_game
	if main_game == null:
		return null
	return main_game.plant_cell_manager


static func _first_area_2d(parent: Node) -> Area2D:
	for child in parent.get_children():
		if child is Area2D:
			return child
	return null


## 取磁力菇的吸铁组件当模板（instantiate 一份磁力菇场景，只留那个节点当母本）
static func _get_magnet_template() -> Node:
	if is_instance_valid(_magnet_template):
		return _magnet_template
	var scene := load(MAGNET_SHROOM_TSCN) as PackedScene
	if scene == null:
		return null
	var sample := scene.instantiate()
	if sample == null:
		return null
	_magnet_template = sample.get_node_or_null(^"MagnetComponent")
	return _magnet_template
#endregion
