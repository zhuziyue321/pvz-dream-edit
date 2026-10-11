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

	_check_against_registry()

	_ready_update_page()

## 拿 LevelRegistry 对一遍：有没有「已经登记的关卡、却没挂到选关页上」
##
## 为什么需要这道护栏：关卡是**硬挂在选关 .tscn 的节点 @export 上**的，
## 于是「新增一个关卡脚本」和「把它加进选关页」是两件独立的事 ——
## 只做前者，这一关就**存在但玩不到**，而且全程没有任何报错（选关页只是少个按钮）。
## LevelRegistry 是扫目录自动登记的，所以它手里的清单才是「一共有哪几关」的真相源；
## 拿它跟场景里实际挂上的按钮对一遍，漏挂的当场在日志里点名。
##
## 只报「已登记但没挂上」，不报反向（挂上了但没登记）：后者意味着那个脚本不是
## LevelScriptBase 子类，多半是有意挂的别的脚本，报了就是噪音。
func _check_against_registry() -> void:
	var registered := LevelRegistry.ids_by_mode(game_mode)
	if registered.is_empty():
		return
	var mounted: Dictionary = {}
	for page in all_pages_array:
		for node in page.get_children():
			if not (node is ChooseLevelButton):
				continue
			var level_script: Script = node.level_script
			if level_script == null:
				continue
			mounted[level_script.resource_path.get_file().get_basename()] = true

	var missing: Array[String] = []
	for level_id in registered:
		## 测试关（*_day_test / *_pool_test / *_roof_test）是 LevelScriptBase 子类，
		## 会被注册表扫进来，但它们**故意不挂按钮**（靠调试入口进），跳过免得天天误报
		if level_id.ends_with("_test"):
			continue
		if not mounted.has(level_id):
			missing.append(level_id)
	if missing.is_empty():
		return
	Log.warn("选关页 %s 有 %d 个已登记关卡没挂上按钮（这些关玩不到）：%s"
		% [MainSceneRegistry.MainScenes.keys()[game_mode], missing.size(), ", ".join(missing)])

## 本模式初始开放的关卡数量: -1 = 全部开放, 0 = 模式未解锁(全部锁住)
## 冒险模式只开放 1 关; 迷你游戏与解谜模式按冒险模式进度解锁(3-2 / 4-6),首批各开放 3 关;
## 首次通关冒险模式(5-10)后, 迷你游戏与解谜模式的剩余关卡、生存模式全部开放;
## 控制台打开"开放所有关卡"时一律全开放
func calc_open_level_num() -> int:
	if Global.config_service.open_all_level:
		return -1
	if game_mode == MainSceneRegistry.MainScenes.ChooseLevelAdventure:
		return 1
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
	## 进关闸门：被占住时（联机客户端的关卡由房主开）这一次直接不进
	if GlobalUtils.enter_level_gate.is_valid() and not bool(GlobalUtils.enter_level_gate.call()):
		return
	Global.game_para = choose_level_button.curr_level_data_game_para
	choose_level_start_game(choose_level_button.curr_level_data_game_para.game_sences)

## 进入游戏关卡
func choose_level_start_game(game_scense:MainSceneRegistry.MainScenes):
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(game_scense))

## 返回开始菜单
func back_start_menu():
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.StartMenu))


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
