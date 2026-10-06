extends MainGameSubManager
class_name BackgroundManager
## 背景管理器,管理背景和前景
## 主游戏只有一份场景（见 docs/参考存档/地图实现.md），地图差异分两条路装配：
##   · 表现（泳池水面 / 浓雾 / 雨）→ 按 ResourceMapData.map_bg_script 挂一份 MapBgAnimBase 子类
##   · 逻辑（屋顶斜面、僵尸进家位置）→ 由本管理器按 ResourceMapData 装配
## 背景贴图按关卡的 game_BG 切换，与地图无关。

var background: Sprite2D
@onready var frontground: Node2D = %Frontground

var home: MainGameHome

## 本地图的背景动画脚本实例（表现侧，独立于关卡逻辑）
var map_bg_anim: MapBgAnimBase


func init_manager() -> void:
	init_background()

## 初始化背景
func init_background():
	var map_data_res: ResourceMapData = game_para.map_data
	if map_data_res == null or map_data_res.map_bg_scene == null:
		Log.error("关卡 %s 缺少地图背景场景，无法装配背景" % str(game_para.level_id))
		return
	## 按地图资源实例化专属背景子场景（含背景贴图宿主、房子、屋顶斜面、僵尸进家面板/落点），
	## 挂到 CanvasLayerBG 下。格子 / 僵尸行 / 小推车仍由 map_data 数据驱动生成。
	var bg_layer: CanvasLayer = main_game.get_node("CanvasLayerBG")
	var bg_instance: Node = map_data_res.map_bg_scene.instantiate()
	bg_layer.add_child(bg_instance)
	## add_child 排在末尾，而背景层的绘制顺序就是子节点顺序 —— 不挪的话运行期挂进来的
	## 背景会盖住场景里原有的兄弟节点（例如保龄球红线所在的 GameItemsInBg，z_index 同为 0）。
	## 背景必须永远在背景层最底下，所以挂完立刻挪到第一个孩子。
	bg_layer.move_child(bg_instance, 0)
	background = bg_instance as Sprite2D
	home = background.get_node("Home") as MainGameHome

	var curr_bg_texture: Texture2D = ConstLevelData.GameBgTextureMap[game_para.game_BG]
	## 地图可以指定自己的底图（如 1-1~1-3 用 background1unsodded 无草皮底图）
	if game_para.map_data != null and game_para.map_data.bg_base_texture != null:
		curr_bg_texture = game_para.map_data.bg_base_texture
	background.texture = curr_bg_texture
	home.init_home(game_para.game_BG)
	if not game_para.is_zombie_can_home:
		Log.debug("僵尸无法进房")
		home.disable_home()
	init_map_bg_anim()
	init_map_bg_logic()
	init_sod_overlay()


## 按 ResourceMapData.map_bg_script 挂一张地图的背景动画脚本。
## 顺序很重要：先 set_script 再 add_child，保证 _ready() 能拿到脚本里的 @onready / 子节点。
func init_map_bg_anim() -> void:
	var map_data: ResourceMapData = game_para.map_data
	if map_data == null:
		Log.error("关卡 %s 没有地图数据，无法挂载背景动画脚本" % str(game_para.level_id))
		return
	if map_data.map_bg_script == null:
		Log.error("地图 %s 没有登记 map_bg_script" % str(map_data.display_name))
		return
	var anim_node := Node2D.new()
	anim_node.name = &"MapBgAnim"
	anim_node.set_script(map_data.map_bg_script)
	## 挂在场景根下：动画脚本自己决定往背景层还是前景层加节点，这里只提供宿主
	main_game.add_child(anim_node)
	map_bg_anim = anim_node as MapBgAnimBase
	if map_bg_anim == null:
		Log.error("地图 %s 的 map_bg_script 不是 MapBgAnimBase 子类" % str(map_data.display_name))
		return
	map_bg_anim.init_bg_anim(background, frontground, game_para)


## 按地图数据装配逻辑侧的地形：屋顶斜面 + 僵尸进家面板与落点。
## 必须在其它子管理器之前跑：屋顶小推车 roof_cleaner._ready 里就要查 main_game_slope。
func init_map_bg_logic() -> void:
	var map_data: ResourceMapData = game_para.map_data
	if map_data == null:
		return
	init_slope(map_data.have_slope, map_data.display_name)
	init_zombie_go_home(map_data)


## 在底图上叠加草皮条（sod1row / sod3row），只覆盖地图里标记为 Grass 的行。
## 草皮覆盖矩形由 map_data 的 Grass 行与列边界算出（世界坐标），
## 与 PlantCellManager 生成的格子几何完全一致，所以草皮正好盖住没铺草皮的底图。
## 底图与草皮条都画在 CanvasLayerBG 层，天然位于格子（layer 0）之下。
func init_sod_overlay() -> void:
	var map_data: ResourceMapData = game_para.map_data
	if map_data == null or map_data.bg_sod_overlay == null:
		return
	var tex: Texture2D = map_data.bg_sod_overlay
	var grass_top: float = INF
	var grass_bottom: float = -INF
	for row_data: ResourceMapRowData in map_data.rows:
		if row_data == null:
			continue
		if row_data.plant_cell_type != PlantCell.PlantCellType.Grass:
			continue
		grass_top = min(grass_top, row_data.row_y)
		grass_bottom = max(grass_bottom, row_data.row_y + row_data.row_height)
	if grass_top == INF or grass_bottom <= grass_top:
		Log.error("地图 %s 没有可铺草皮的行，无法叠加草皮贴图" % str(map_data.display_name))
		return
	var col_num: int = map_data.get_col_num()
	if col_num <= 0:
		Log.error("地图 %s 列数为 0，无法叠加草皮贴图" % str(map_data.display_name))
		return
	var left: float = map_data.col_x[0]
	var right: float = map_data.col_x[col_num - 1] + map_data.col_width[col_num - 1]
	## 草皮贴图内的绿色内容本身已居中，所以用「原生尺寸、不缩放」把整张贴图
	## 居中到「草皮行 + 列」围成的车道区域即可，草皮正好盖住对应车道，不会出现缩放变形。
	var region_center := Vector2((left + right) * 0.5, (grass_top + grass_bottom) * 0.5)
	var overlay := Sprite2D.new()
	overlay.name = &"SodOverlay"
	overlay.texture = tex
	overlay.centered = false
	## 背景精灵绘制起点在它的 position；子节点局部坐标 = 世界坐标 - 背景 position。
	## centered=false 时 position 是贴图左上角，把整张贴图居中到车道区域中心。
	overlay.position = Vector2(
		region_center.x - background.position.x - tex.get_width() * 0.5 + 5,
		region_center.y - background.position.y - tex.get_height() * 0.5
	)
	background.add_child(overlay)


## 场景里常驻 RoofSlope 节点，非屋顶地图直接释放，免得斜面碰撞体留在场景里
func init_slope(have_slope: bool, map_name: String) -> void:
	var slope_node: Node = background.get_node_or_null(^"RoofSlope")
	if slope_node == null:
		if have_slope:
			Log.error("地图 %s 需要斜面，但背景层里没有 RoofSlope 节点" % str(map_name))
		return
	if not have_slope:
		slope_node.queue_free()
		return
	if slope_node is MainGameSlope:
		main_game.main_game_slope = slope_node as MainGameSlope
	else:
		Log.error("地图 %s 的 RoofSlope 节点不是 MainGameSlope" % str(map_name))


## 僵尸进家的面板矩形与落点：不同地图房门画的位置不同，由地图数据给出
func init_zombie_go_home(map_data: ResourceMapData) -> void:
	var panel: Panel = background.get_node_or_null("Home/Door/DoorDown/PanelZombieGoHome")
	var marker: Marker2D = background.get_node_or_null("Home/Door/DoorDown/PanelZombieGoHome/Marker2DZombieGoHome")
	if panel == null or marker == null:
		Log.error("地图 %s 缺少僵尸进家面板或落点节点" % str(map_data.display_name))
		return
	## 进家面板与落点归失败流程子管理器管（见 MgmLoseManager）
	main_game.lose_manager.panel_zombie_go_home = panel
	main_game.lose_manager.marker_2d_zombie_go_home = marker
	main_game.lose_manager.panel_zombie_go_home.position = map_data.zombie_go_home_panel.position
	main_game.lose_manager.panel_zombie_go_home.size = map_data.zombie_go_home_panel.size
	main_game.lose_manager.marker_2d_zombie_go_home.position = map_data.zombie_go_home_marker


## 取当前地图的浓雾（没有雾的地图返回 null），转发给地图动画脚本
func get_fog() -> Fog:
	if map_bg_anim == null:
		return null
	return map_bg_anim.get_fog()


## 主游戏正式开始：交给动画脚本（浓雾进场等）
func start_main_game_background_manager_update() -> void:
	if map_bg_anim != null:
		map_bg_anim.start_game()


## 多轮游戏的下一轮：交给动画脚本（浓雾退场等）
func start_next_game_background_manager_update() -> void:
	if map_bg_anim != null:
		map_bg_anim.start_next_round()
