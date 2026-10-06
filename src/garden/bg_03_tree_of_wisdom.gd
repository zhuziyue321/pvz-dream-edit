extends GardenBgPage
class_name TreeOfWisdom
## 智慧树页:花园的第 4 个背景(GardenManager.E_GardenBgType.TreeBg)
## 商店花 $10000 买断后才拥有(见 GlobalGameState.buy_tree_of_wisdom),原版是"从水族馆再往后翻一页"
## 本页不放植物格子(PLANT_CELL_NUM_PER_PAGE 里这一页是 0),只有一棵树:
## 喂一袋树肥料长高一英尺,并当场讲一句"智慧"(见 TreeFood.use_it 与 ConstTreeOfWisdom)
## 画面是 tree_bg(天空) + tree_grass(草坡) + 树干 + 树根草丛叠出来的,
## 各部件的摆放直接取自 assets/all_reanim/treeofWisdom.reanim,见 ConstTreeOfWisdom.TREE_STAGES

## 树干,贴图 / 位置 / 缩放随高度换档
@onready var trunk: Sprite2D = $Tree/Trunk
## 树根草丛,前几档没有(树大了才用更大的草丛盖住上一档的根部)
@onready var root_overlay: Sprite2D = $Tree/RootOverlay
## 云,原版智慧树那页天上有云在飘(见 tree_of_wisdom_clouds.tscn,不自动播,这里手动开)
@onready var clouds_anim_lib: AnimationPlayer = $TreeOfWisdomClouds/AnimLib
## 高度显示,原版 [TREE_OF_WISDOM_HIEGHT]: "{HEIGHT}英尺高"
@onready var height_label: Label = $HeightLabel
## 智慧树讲的话
@onready var wisdom_label: Label = $WisdomLabel

## 当前高度(英尺),喂一袋长一英尺
var _height := 0


## 智慧树页没有植物格子:super 返回的就是空数组,顺手把树画出来
func init_curr_gb_page(bg_page_data: Dictionary, page: int) -> Array[Node]:
	var empty_plant_cells: Array[Node] = super(bg_page_data, page)
	clouds_anim_lib.play("ALL_ANIMS")
	refresh_visual()
	return empty_plant_cells


## 智慧树现在多少英尺高(喂一袋长一英尺)
func get_height() -> int:
	return Global.global_game_state.get_tree_of_wisdom_height()


## 施肥:长高一英尺,并把这袋肥料换来的那句智慧讲出来
func add_height(add_feet: int = ConstTreeOfWisdom.TREE_FOOD_GROW_FEET) -> void:
	_height = Global.global_game_state.add_tree_of_wisdom_height(add_feet)
	Global.save_service.save_now()
	refresh_visual()
	wisdom_label.text = _get_wisdom_text(_height)


## 树肥料倒下来的位置(树根上方一点,克隆体在那播"倒肥料"动画)
func get_feed_position() -> Vector2:
	var size := trunk.texture.get_size() * trunk.scale
	return trunk.global_position + Vector2(size.x * 0.5, size.y - 60.0)


## 是否点在树上(树肥料判定用)
## 树干贴图四周大片是透明的,判定按整张贴图算,再跟树根附近一片取并集:
## 刚买下时树只有一截幼苗,不放宽就点不中
func is_hit(global_pos: Vector2) -> bool:
	if trunk == null or trunk.texture == null:
		return false
	var size := trunk.texture.get_size() * trunk.scale
	var hit_rect := Rect2(trunk.global_position, size)
	## 顶部工具栏那一条不算树:手上拿着树肥料时点工具栏不该把肥料喂出去
	var top: float = maxf(hit_rect.position.y, 90.0)
	hit_rect = Rect2(Vector2(hit_rect.position.x, top),
		Vector2(size.x, maxf(size.y - (top - hit_rect.position.y), 0.0)))
	## 树根附近兜底一块,边长至少 180 × 160
	var base_center := trunk.global_position + Vector2(size.x * 0.5, size.y)
	hit_rect = hit_rect.merge(Rect2(base_center - Vector2(90.0, 150.0), Vector2(180.0, 170.0)))
	return hit_rect.has_point(global_pos)


## 按高度重画树(贴图 / 位置 / 缩放 / 树根 / 高度文字)
func refresh_visual() -> void:
	_height = get_height()
	var stage := ConstTreeOfWisdom.get_stage_index(_height)
	var stage_sprite: Dictionary = ConstTreeOfWisdom.get_stage_sprite(stage)
	trunk.texture = stage_sprite["trunk"]
	trunk.position = stage_sprite["trunk_position"]
	trunk.scale = stage_sprite["trunk_scale"]

	var root_texture: Texture2D = stage_sprite["root"]
	root_overlay.texture = root_texture
	root_overlay.visible = root_texture != null
	if root_texture != null:
		root_overlay.position = stage_sprite["root_position"]
		root_overlay.scale = stage_sprite["root_scale"]

	height_label.text = ConstTreeOfWisdom.HEIGHT_TEXT % _height
	wisdom_label.text = _get_wisdom_text(_height)


## 这个高度它讲哪句话(原版"高度 -> 讲哪句"的对应关系未考证,口径见 ConstTreeOfWisdom)
func _get_wisdom_text(height: int) -> String:
	if height <= 0:
		## 还没喂过肥,它讨食
		return ConstTreeOfWisdom.LINE_NOT_FED_YET
	if ConstTreeOfWisdom.MILESTONE_HEIGHT_LINE.has(height):
		## 100 / 500 / 1000 英尺:讲解锁秘籍那句
		return str(ConstTreeOfWisdom.MILESTONE_HEIGHT_LINE[height])
	if height <= ConstTreeOfWisdom.WISDOM_TIPS.size():
		## 前 48 袋:一袋一句新智慧
		return ConstTreeOfWisdom.WISDOM_TIPS[height - 1]
	## 智慧讲完了:隔一次重讲一条旧的(原版 TREE_OF_WISDOM_500),
	## 剩下的按树的大小在自己的闲聊台词里挑一句
	if height % 2 == 0:
		return ConstTreeOfWisdom.LINE_REPEAT_PREFIX + "\n" \
			+ str(ConstTreeOfWisdom.WISDOM_TIPS.pick_random())
	return str(ConstTreeOfWisdom.get_generic_lines(
		ConstTreeOfWisdom.get_stage_index(height)).pick_random())
