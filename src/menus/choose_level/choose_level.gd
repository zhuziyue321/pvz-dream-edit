extends Control
class_name ChooseLevel

## 用于生成关卡 ID 的计数
var next_level_number: int = 1

@onready var all_page: Control = $AllPage
@onready var label_page: Label = get_node_or_null("LabelPage")

## 游戏模式,用于管理关卡存档
@export var game_mode:MainSceneRegistry.MainScenes = MainSceneRegistry.MainScenes.Null
## 开放关卡数量: -1 = 全部开放, 0 = 模式未解锁(全部锁住), 其余为开放名额数
## 由 calc_open_level_num() 按模式与冒险模式进度算出
var open_level_num:int = -1
var all_pages_array : Array[GridContainer]
@export var curr_page := 0

## 选卡bgm
var bgm_choose_card: AudioStream = preload("res://assets/audio/BGM/choose_your_seeds.mp3")

func _ready() -> void:
	open_level_num = calc_open_level_num()

	for page_i in all_page.get_child_count():
		var page = all_page.get_child(page_i)
		all_pages_array.append(page)
		page.visible = false
		for node in page.get_children():
			## 如果是选关按钮
			if node is ChooseLevelButton:
				var level_id:String = generate_level_id()
				if node.curr_level_data_game_para == null:
					continue
				node.signal_choose_level_button.connect(_on_choose_level_button)
				## 初始化游戏数据的选关数据
				node.curr_level_data_game_para.set_choose_level(game_mode, page_i, level_id)
				var curr_level_state_data:Dictionary = Global.global_game_state.curr_all_level_state_data.get(node.curr_level_data_game_para.save_game_name, {})
				node.update_curr_level_button_state(curr_level_state_data)
				update_lock_level(node, curr_level_state_data)

	Log.debug(str("当前模式关卡数量:") + str(next_level_number - 1))

	_ready_update_page()

## 本模式初始开放的关卡数量: -1 = 全部开放, 0 = 模式未解锁(全部锁住)
## 冒险模式只开放 1 关; 迷你游戏与解谜模式按冒险模式进度解锁(3-2 / 4-6),首批各开放 3 关;
## 首次通关冒险模式(5-10)后, 迷你游戏与解谜模式的剩余关卡、生存模式全部开放;
## 自定义关卡不做限制; 控制台打开"开放所有关卡"时一律全开放
func calc_open_level_num() -> int:
	if Global.config_service.open_all_level:
		return -1
	if game_mode == MainSceneRegistry.MainScenes.ChooseLevelAdventure:
		return 1
	if game_mode == MainSceneRegistry.MainScenes.ChooseLevelCustom:
		return -1
	if not Global.global_game_state.is_mode_unlocked(game_mode):
		return 0
	if Global.global_game_state.is_mode_all_level_open(game_mode):
		return -1
	return 3


## 更新关卡是否锁住 无尽模式默认开放，不占用开放名额
func update_lock_level(choose_level_button:ChooseLevelButton, curr_level_state_data:Dictionary):
	## 模式本身还没解锁: 全部锁住, 无尽关卡也不例外
	if open_level_num == 0:
		choose_level_button.lock_choose_level_button()
		return
	## 如果开放名额为-1，即所有关卡都开发
	if open_level_num == -1:
		return
	## 无尽模式
	if choose_level_button.curr_level_data_game_para.game_round == -1:
		return
	## 如果当前关卡通关
	if curr_level_state_data.get("IsSuccess", false):
		return
	## 还有开发关卡名额
	if open_level_num > 0:
		open_level_num -= 1
		return
	else:
		choose_level_button.lock_choose_level_button()

func _ready_update_page():
	## 如果从游戏中退出
	if Global.game_para != null and Global.game_para.game_mode == game_mode:
		curr_page = Global.game_para.level_page

	## 越界判断必须是 >=：curr_page == size 时下一行 all_pages_array[curr_page] 会越界
	if curr_page >= all_pages_array.size():
		curr_page = 0
	if not all_pages_array.is_empty():
		all_pages_array[curr_page].visible = true
		if is_instance_valid(label_page):
			_update_page(curr_page)

	SoundManager.play_bgm(bgm_choose_card)

## 获取关卡id
func generate_level_id() -> String:
	# 用格式化字符串，让数字变成 4 位，前面补 0
	# GDScript 支持类似 C 风格字符串格式化
	var id_str = "%04d" % next_level_number  # 例如 0 -> "0000", 12 -> "0012"
	next_level_number += 1
	return id_str

func _on_choose_level_button(choose_level_button:ChooseLevelButton):
	Global.game_para = choose_level_button.curr_level_data_game_para
	choose_level_start_game(choose_level_button.curr_level_data_game_para.game_sences)

## 进入游戏关卡
func choose_level_start_game(game_scense:MainSceneRegistry.MainScenes):
	GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap[game_scense])

## 返回开始菜单
func back_start_menu():
	GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])


func _on_last_pressed() -> void:
	_update_page(curr_page - 1)

func _on_next_pressed() -> void:
	_update_page(curr_page + 1)


func _update_page(new_page:int):
	new_page = posmod(new_page, all_pages_array.size())
	all_pages_array[curr_page].visible = false
	curr_page = new_page
	all_pages_array[curr_page].visible = true
	label_page.text = "当前页数:" + str(curr_page + 1) + "/" + str(all_pages_array.size())
