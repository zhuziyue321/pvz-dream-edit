extends GardenBgPage
class_name TreeOfWisdom
## 智慧树页：花园的第 4 个背景（GardenManager.E_GardenBgType.TreeBg）
## 商店花 $10000 买断后才拥有（见 GlobalGameState.buy_tree_of_wisdom），原版是「从水族馆再往后翻一页」
## 本页不放植物格子（PLANT_CELL_NUM_PER_PAGE 里这一页是 0），只有一棵树：
## 喂一袋树肥料长高一英尺，并当场讲一句「智慧」（见 TreeFood.use_it）
##
## 2026-10-24 按原版 `Challenge::TreeOfWisdom*`
## （../PvZ-Portable-main/src/Lawn/Challenge.cpp）逐条对齐：
##   · 讲哪句**按台词编号**挑，编号 = 原版 `[TREE_OF_WISDOM_<编号>]`
##     （ConstTreeOfWisdom.get_give_wisdom_talk / get_babble_talk / get_repeat_talk）
##   · 状态机 WAITING_TO_BABBLE → BABBLING →（500 开场白后）重复旧台词；
##     每次长高 JUST_GREW → GIVE_WISDOM（TreeOfWisdomUpdate）
##   · 只在树说话时画对话气泡（Store_SpeechBubble2），位置按树高三档（TreeOfWisdomDraw）
##   · 点击判定用原版四档固定矩形（TreeOfWisdomHitTest）
##   · 高度文字 ≥ 50 英尺才显示，长高那一下弹一下（TreeOfWisdomDraw 的 aCurSize / aScale）
## 画面走**原版 51 档动画**（anim_grow1..51）：`animation/garden/tree_of_wisdom/treeofWisdom_growN.tres`，
## 2026-10-24 用 R2Ga 新版（C++ 版 v4.0_dev_4）从 `pak/reanim/treeofWisdom.reanim` 转出；
## 转换器一次性最多转 ~49 段动画（50 段就 0xC0000005 崩溃），所以源被拆成两批、文件名统一回来。
## `ConstTreeOfWisdom.TREE_STAGES` 的 10 档静态图只作**兜底**（动画缺失时才用）。

## 原版 STATECHALLENGE_TREE_* 的几个状态（外加「什么都不做」的 NORMAL）
enum E_State {
	NORMAL,
	JUST_GREW,
	WAITING_TO_BABBLE,
	BABBLING,
	GIVE_WISDOM,
}

## 悬停高亮用的白色叠加 shader（原版 Reanimation 的 mExtraOverlayColor）
const HOVER_SHADER_PATH := "res://shaders/tree_highlight.gdshader"
## 动画层整体偏移：转换产物用的就是 reanim 的 800×600 屏幕坐标，正常应当是 (0,0)。
## 万一实际画面偏了只改这一个数（先确认背景图没被挪过）
const TREE_ANIM_OFFSET := Vector2.ZERO

## 树干，贴图 / 位置 / 缩放随高度换档（有动画时只用来算点击判定与肥料落点）
@onready var trunk: Sprite2D = $Tree/Trunk
## 树根草丛，前几档没有（树大了才用更大的草丛盖住上一档的根部）
@onready var root_overlay: Sprite2D = $Tree/RootOverlay
## 页面自带的固定草坡：动画版里 reanim 的 Grass 图层会顶替它
@onready var page_grass: Sprite2D = $Grass
## 云，原版智慧树那页天上有云在飘（见 tree_of_wisdom_clouds.tscn，不自动播，这里手动开）
@onready var clouds_anim_lib: AnimationPlayer = $TreeOfWisdomClouds/AnimLib
## 高度显示，原版 [TREE_OF_WISDOM_HIEGHT]: "{HEIGHT}英尺高"
@onready var height_label: Label = $HeightLabel
## 对话气泡（原版 IMAGE_STORE_SPEECHBUBBLE2）：只有树在说话时才显示
@onready var speech_bubble: Sprite2D = $SpeechBubble
## 气泡里的台词
@onready var speech_label: Label = $SpeechBubble/Text

## 当前高度（英尺），喂一袋长一英尺
var _height := 0
## 当前状态（原版 mChallengeState）
var _state: E_State = E_State.NORMAL
## 状态剩余时长（秒）；对应原版 mChallengeStateCounter 的 tick 计数
var _state_counter := 0.0
## 当前台词编号（原版 mTreeOfWisdomTalkIndex，0 = 没在说话）
var _talk_index := 0

## 51 档动画层（节点 / 顺序 / 贴图全部来自转换产物）
var _anim_layer: Node2D
var _anim_player: AnimationPlayer
## 当前正在播的档位，避免同一档反复 seek
var _curr_anim_stage := -1

## 悬停高亮：树干组 / 树根草丛组的精灵（建动画层时按轨道名分好）
var _trunk_sprites: Array[Sprite2D] = []
var _root_sprites: Array[Sprite2D] = []
var _hover_mat_trunk: ShaderMaterial
var _hover_mat_root: ShaderMaterial
var _is_hovered := false


## 智慧树页没有植物格子：super 返回的就是空数组，顺手把树画出来
func init_curr_gb_page(bg_page_data: Dictionary, page: int) -> Array[Node]:
	var empty_plant_cells: Array[Node] = super(bg_page_data, page)
	clouds_anim_lib.play("ALL_ANIMS")
	_build_tree_anim_layer()
	_ensure_hover_materials()
	_height = get_height()
	_apply_tree_visual(_height, true)
	## 原版 TreeOfWisdomInit：先安静 700~1500 tick，然后自己嘟囔一句
	_state = E_State.WAITING_TO_BABBLE
	_state_counter = randf_range(ConstTreeOfWisdom.TIMER_WAIT_BABBLE_MIN,
		ConstTreeOfWisdom.TIMER_WAIT_BABBLE_MAX)
	_talk_index = 0
	_refresh_height_label()
	_refresh_speech_bubble()
	return empty_plant_cells


func _process(delta: float) -> void:
	_tick_state(delta)
	_update_hover()


#region 状态机（原版 Challenge::TreeOfWisdomUpdate）
func _tick_state(delta: float) -> void:
	if _state_counter <= 0.0:
		return
	_state_counter = maxf(_state_counter - delta, 0.0)
	if _state == E_State.JUST_GREW:
		## 弹跳与「高度晚一拍」都要逐帧更新
		_refresh_height_label()
	if _state_counter > 0.0:
		return
	_on_state_timeout()


func _on_state_timeout() -> void:
	match _state:
		E_State.JUST_GREW:
			_give_wisdom()
		E_State.WAITING_TO_BABBLE:
			_babble()
		E_State.BABBLING, E_State.GIVE_WISDOM:
			if _talk_index == ConstTreeOfWisdom.TALK_INDEX_REPEAT_INTRO:
				_say_repeat()
			else:
				_wait_to_babble()


## 长高后讲一句智慧（原版 TreeOfWisdomGiveWisdom）
func _give_wisdom() -> void:
	_state = E_State.GIVE_WISDOM
	_state_counter = ConstTreeOfWisdom.TIMER_GIVE_WISDOM
	_talk_index = ConstTreeOfWisdom.get_give_wisdom_talk(_height)
	_refresh_speech_bubble()


## 没长高时自己嘟囔（原版 TreeOfWisdomBabble）
func _babble() -> void:
	_state = E_State.BABBLING
	_state_counter = ConstTreeOfWisdom.TIMER_BABBLE
	_talk_index = ConstTreeOfWisdom.get_babble_talk(_height, randi_range(0, 2))
	_refresh_speech_bubble()


## 「我有一些久经考验的智慧……」讲完之后，重讲一句旧台词（原版 TreeOfWisdomSayRepeat）
func _say_repeat() -> void:
	_talk_index = ConstTreeOfWisdom.get_repeat_talk(_height)
	_state_counter = ConstTreeOfWisdom.TIMER_REPEAT
	_refresh_speech_bubble()


## 回到「等着嘟囔」的状态（原版两处 counter 区间不同：首次 700~1500，之后 700~1000）
func _wait_to_babble() -> void:
	_state = E_State.WAITING_TO_BABBLE
	_state_counter = randf_range(ConstTreeOfWisdom.TIMER_WAIT_BABBLE_AGAIN_MIN,
		ConstTreeOfWisdom.TIMER_WAIT_BABBLE_AGAIN_MAX)
	_talk_index = 0
	_refresh_speech_bubble()
#endregion


#region 施肥 / 长高
## 智慧树现在多少英尺高（喂一袋长一英尺）
func get_height() -> int:
	return Global.global_game_state.get_tree_of_wisdom_height()


## 正在「刚长高」的弹跳里：这时候原版不给再喂（TreeOfWisdomCanFeed）
func is_growing() -> bool:
	return _state == E_State.JUST_GREW


## 施肥：长高一英尺，并把高度存盘（后续会话由状态机决定讲哪句）
## 原版 TreeOfWisdomGrow：播 anim_growN + 播生长音效；长过 1 英尺后进 JUST_GREW
func add_height(add_feet: int = ConstTreeOfWisdom.TREE_FOOD_GROW_FEET) -> void:
	_height = Global.global_game_state.add_tree_of_wisdom_height(add_feet)
	Global.save_service.save_now()
	_apply_tree_visual(_height)
	SoundManager.play_other_SFX("plantgrow")
	if _height > 1:
		_state = E_State.JUST_GREW
		_state_counter = ConstTreeOfWisdom.TIMER_JUST_GREW
	else:
		_state = E_State.NORMAL
		_state_counter = 0.0
	_refresh_height_label()
	_refresh_speech_bubble()


## 树肥料袋子倒下来的位置（原版 TreeOfWisdomFertilize 的 AddReanimation(340, 300)）
func get_feed_position() -> Vector2:
	return to_global(ConstTreeOfWisdom.FERTILIZE_POS)


## 是否点在树上（树肥料判定用）：原版四档固定矩形
func is_hit(global_pos: Vector2) -> bool:
	return _get_hit_rect().has_point(to_local(global_pos))


func _get_hit_rect() -> Rect2:
	if _height <= 1:
		return ConstTreeOfWisdom.HIT_RECT_SPROUT
	if _height < 7:
		return ConstTreeOfWisdom.HIT_RECT_SMALL
	if _height < 12:
		return ConstTreeOfWisdom.HIT_RECT_MID
	return ConstTreeOfWisdom.HIT_RECT_BIG
#endregion


#region 画面
## 按高度重画树（51 档动画 / 兜底的 10 档静态图）
## is_init = 进场那次：播到第 50 档并直接定在最后一帧；长高那次：播到第 51 档并按 8 帧/秒真播（有拉伸过程）
func _apply_tree_visual(height: int, is_init := false) -> void:
	var stage_sprite: Dictionary = ConstTreeOfWisdom.get_stage_sprite(
		ConstTreeOfWisdom.get_stage_index(height))
	## 树干贴图即使不显示也要设：走到兜底分支时直接用它
	trunk.texture = stage_sprite["trunk"]

	var has_anim := _anim_player != null and _anim_player.has_animation("grow1")
	if has_anim:
		## 原版 TreeOfWisdomInit：PlayReanim("anim_grow{clamp(height,1,50)}", PLAY_ONCE_AND_HOLD)
		trunk.visible = false
		root_overlay.visible = false
		## 页面自带的那块固定草坡在动画里有同源图层（Grass），不藏会叠两层
		page_grass.visible = false
		var max_stage := ConstTreeOfWisdom.ANIM_STAGE_INIT_MAX if is_init \
			else ConstTreeOfWisdom.ANIM_STAGE_GROW_MAX
		var stage := clampi(height, 1, max_stage)
		if not (is_init and stage == _curr_anim_stage):
			_curr_anim_stage = stage
			var anim_name := "grow%d" % stage
			if not _anim_player.has_animation(anim_name):
				anim_name = "grow1"
			_anim_player.play(anim_name)
			if is_init:
				## 原版 TreeOfWisdomInit：播完立刻 mAnimTime = 0.99，等于直接定在最后一帧
				_anim_player.speed_scale = 1.0
				_anim_player.seek(_anim_player.current_animation_length, true)
				_anim_player.pause()
			else:
				## 原版 TreeOfWisdomGrow：PlayReanim(..., PLAY_ONCE_AND_HOLD, 0, 8.0f)，
				## 素材 12fps、按 8 帧/秒 播，于是有 0.5~0.8 秒的"拉伸"过程，播完停在最后一帧
				var grow_anim := _anim_player.get_animation(anim_name)
				_anim_player.speed_scale = ConstTreeOfWisdom.ANIM_PLAY_RATE_GROW * grow_anim.step
				_anim_player.seek(0.0, true)
	else:
		## 兜底：10 档静态图（动画产物缺失 / 读取失败时才走这里）
		trunk.visible = true
		page_grass.visible = true
		trunk.position = stage_sprite["trunk_position"]
		trunk.scale = stage_sprite["trunk_scale"]
		var root_texture: Texture2D = stage_sprite["root"]
		root_overlay.texture = root_texture
		root_overlay.visible = root_texture != null
		if root_texture != null:
			root_overlay.position = stage_sprite["root_position"]
			root_overlay.scale = stage_sprite["root_scale"]
	_refresh_hover_strength()


## 高度文字：只有 ≥ 50 英尺才显示；「刚长高」期间前 0.9 秒还显示旧高度，并弹一下
func _refresh_height_label() -> void:
	var cur_size := _height
	var scale := 1.0
	if _state == E_State.JUST_GREW:
		if _state_counter > 30 * ConstTreeOfWisdom.TICK:
			cur_size -= 1
		scale = _get_grow_pulse_scale()
	height_label.visible = cur_size >= ConstTreeOfWisdom.HEIGHT_TEXT_MIN_HEIGHT
	height_label.text = ConstTreeOfWisdom.HEIGHT_TEXT % cur_size
	height_label.scale = Vector2(scale, scale)


## 原版 PvzpAnimateCurveFloat(55, 20, counter, 1.0, 1.2, CURVE_BOUNCE)
## CURVE_BOUNCE = 1 - |2t - 1|（三角波），t ≥ 1 时回到起点
func _get_grow_pulse_scale() -> float:
	var from := ConstTreeOfWisdom.GROW_PULSE_FROM
	var to := ConstTreeOfWisdom.GROW_PULSE_TO
	var t := (_state_counter - from) / (to - from)
	if t <= 0.0 or t >= 1.0:
		return 1.0
	return 1.0 + ConstTreeOfWisdom.GROW_PULSE_SCALE * (1.0 - absf(2.0 * t - 1.0))


## 台词气泡：只在 BABBLING / GIVE_WISDOM 时出现，位置按树高三档（原版 TreeOfWisdomDraw）
func _refresh_speech_bubble() -> void:
	var talking := _state == E_State.BABBLING or _state == E_State.GIVE_WISDOM
	speech_bubble.visible = talking and _talk_index != 0
	if not speech_bubble.visible:
		return
	if _height < 7:
		speech_bubble.position = ConstTreeOfWisdom.SPEECH_BUBBLE_POS_SMALL
	elif _height < 12:
		speech_bubble.position = ConstTreeOfWisdom.SPEECH_BUBBLE_POS_MID
	else:
		speech_bubble.position = ConstTreeOfWisdom.SPEECH_BUBBLE_POS_BIG
	speech_label.text = ConstTreeOfWisdom.get_talk_line(_talk_index)


## 建 51 档动画层：节点名 / 顺序 / 贴图轨道全部从转换产物里读，不手写
## （产物里每个 Sprite2D 都是 centered = false，坐标即左上角；轨道 path 形如 "Tree1:position"）
func _build_tree_anim_layer() -> void:
	var probe_path := ConstTreeOfWisdom.ANIM_DIR + ConstTreeOfWisdom.ANIM_PREFIX + "1.tres"
	if not ResourceLoader.exists(probe_path):
		return
	var probe_anim := load(probe_path) as Animation
	if probe_anim == null:
		return

	_trunk_sprites.clear()
	_root_sprites.clear()

	_anim_layer = Node2D.new()
	_anim_layer.name = "TreeAnimLayer"
	_anim_layer.position = TREE_ANIM_OFFSET
	add_child(_anim_layer)
	## 插在原来的 Tree 节点位置：背景 / 云 / 旧 Grass 之后，高度文字之前
	move_child(_anim_layer, $Tree.get_index())

	_anim_player = AnimationPlayer.new()
	_anim_player.name = "TreeAnim"
	_anim_layer.add_child(_anim_player)
	_anim_player.root_node = NodePath("..")

	var lib := AnimationLibrary.new()
	for stage in range(1, ConstTreeOfWisdom.ANIM_STAGE_GROW_MAX + 1):
		var path := ConstTreeOfWisdom.ANIM_DIR + ConstTreeOfWisdom.ANIM_PREFIX + str(stage) + ".tres"
		if not ResourceLoader.exists(path):
			continue
		var anim := load(path) as Animation
		if anim != null:
			lib.add_animation("grow%d" % stage, anim)
	if not lib.has_animation("grow1"):
		## 一段都没读出来：整层拆掉，_apply_tree_visual 会退回 10 档静态图
		_anim_layer.queue_free()
		_anim_layer = null
		_anim_player = null
		return
	_anim_player.add_animation_library("", lib)

	## 节点集合要取**所有档位的并集**（压缩后小树那几档只有 Tree01 / Grass，按 grow1 建节点会让大树缺图层）；
	## 顺序按大档位先扫，天然就是 reanim 的绘制顺序（tree01 → tree1..9 → grass → overlay → leaf → bunch）
	var created: Array[String] = []
	for stage in range(ConstTreeOfWisdom.ANIM_STAGE_GROW_MAX, 0, -1):
		var anim: Animation = lib.get_animation("grow%d" % stage)
		if anim == null:
			continue
		for track in anim.get_track_count():
			var node_name := _get_track_node_name(anim, track)
			if node_name == "" or created.has(node_name):
				continue
			created.append(node_name)
			var sprite := Sprite2D.new()
			sprite.name = node_name
			sprite.centered = false
			_anim_layer.add_child(sprite)
			_sort_sprite_into_hover_group(sprite)


## 轨道 path "Tree1:position" -> 节点名 "Tree1"
static func _get_track_node_name(anim: Animation, track: int) -> String:
	var path := String(anim.track_get_path(track))
	var sep := path.find(":")
	return path if sep < 0 else path.substr(0, sep)


## 原版按轨道名前缀分渲染组：tree → 树干组，overlay / leaf / bunch → 树根草丛组
func _sort_sprite_into_hover_group(sprite: Sprite2D) -> void:
	var node_name := sprite.name
	if node_name.begins_with("Tree"):
		_trunk_sprites.append(sprite)
	elif node_name.begins_with("Overlay") or node_name.begins_with("Leaf") \
			or node_name.begins_with("Bunch"):
		_root_sprites.append(sprite)
#endregion


#region 悬停高亮（原版 TreeOfWisdomDraw 的 mEnableExtraOverlayDraw）
## 光标拿着树肥料指着树时，树干 / 树根草丛各叠一层白色（alpha 见 ConstTreeOfWisdom.HOVER_ALPHA_*）
func _update_hover() -> void:
	var tree_food: TreeFood = null
	if garden_manager != null:
		tree_food = garden_manager.tree_food
	var on := tree_food != null and is_instance_valid(tree_food) and tree_food.is_activate \
		and is_hit(get_global_mouse_position())
	_set_hover(on)


func _set_hover(on: bool) -> void:
	if on == _is_hovered:
		return
	_is_hovered = on
	_refresh_hover_strength()


func _ensure_hover_materials() -> void:
	var shader := load(HOVER_SHADER_PATH) as Shader
	if shader == null:
		return
	_hover_mat_trunk = ShaderMaterial.new()
	_hover_mat_trunk.shader = shader
	_hover_mat_root = ShaderMaterial.new()
	_hover_mat_root.shader = shader


func _refresh_hover_strength() -> void:
	if _hover_mat_trunk == null:
		return
	var trunk_alpha := ConstTreeOfWisdom.HOVER_ALPHA_TRUNK_SMALL \
		if _height < ConstTreeOfWisdom.HOVER_SMALL_TREE_HEIGHT \
		else ConstTreeOfWisdom.HOVER_ALPHA_TRUNK_BIG
	_hover_mat_trunk.set_shader_parameter("strength", trunk_alpha)
	_hover_mat_root.set_shader_parameter("strength", ConstTreeOfWisdom.HOVER_ALPHA_ROOT)
	var trunk_mat: Material = _hover_mat_trunk if _is_hovered else null
	var root_mat: Material = _hover_mat_root if _is_hovered else null
	## 有动画时是动态建的精灵；兜底静态图时就是 Trunk / RootOverlay 两个节点
	if _anim_player != null:
		for sprite in _trunk_sprites:
			if is_instance_valid(sprite):
				sprite.material = trunk_mat
		for sprite in _root_sprites:
			if is_instance_valid(sprite):
				sprite.material = root_mat
	else:
		trunk.material = trunk_mat
		root_overlay.material = root_mat
#endregion
