extends "res://src/menus/choose_level/choose_level.gd"
## 玩家对战选关界面：页里挂着本模组自带的对局条目（目前只有「玩家对战：白天」）
##
## 界面由玩家对战模组在 install() 时注入 `MainSceneRegistry.MainScenes.ChooseLevelPlayerBattle` 槽位，
## 主菜单木牌上的「MULTIPLAYER」牌按下即进这里。
## 复用本体的选关页基类：返回主菜单、翻页、选关 BGM 都照旧。
##
## 关卡条目由**本模组**提供（`levels/player_battle_day.gd`），本体不认识它们。
## 按钮是**运行时**建的，不写死在 .tscn 里 —— .tscn 的 ext_resource 只能写 res:// 绝对路径，
## 那样这份模组从 `user://mods/` 加载时就指不到自己的关卡脚本了（两个加载源，见 [模组机制]）。
## 以后加对局：在 BATTLE_LEVELS 里再加一条即可（关卡脚本由本模组自己提供）。

## 本体的关卡按钮场景（复用，不自带一份）
const CHOOSE_LEVEL_BUTTON := preload("res://src/menus/choose_level/choose_level_button.tscn")

## 本模组自带的对局：id → 显示名 + 关卡脚本
##
## 关卡脚本用**相对路径** preload：跟着本模组的加载根走（内置源 / 玩家那份都对）。
const BATTLE_LEVELS: Array[Dictionary] = [
	{
		"level_id": "0001",
		"title": "玩家对战：白天",
		"script": preload("levels/player_battle_day.gd"),
	},
]


## 本模式没有关卡，也就没有「解锁名额」这回事：一律按全开放算
## （不去查冒险模式的解锁表 —— 这个模式与冒险模式进度无关）
func calc_open_level_num() -> int:
	return -1


func _ready() -> void:
	## 基类先跑：它认的是 .tscn 里写死的按钮（这一页一个也没有），顺带把翻页 / BGM 弄好
	super._ready()
	_build_battle_levels()


## 把本模组的对局做成选关按钮挂进网格
##
## 基类的 _ready() 已经跑完（它只认 .tscn 里写死的按钮），所以这里自己接一遍线：
##   设存档名 → 接「点了这一关」信号 → 刷新通关标记。
func _build_battle_levels() -> void:
	var grid := get_node_or_null("AllPage/GridContainer") as GridContainer
	if grid == null:
		Log.error("玩家对战选关界面：找不到 AllPage/GridContainer，关卡按钮挂不上去")
		return
	for one in BATTLE_LEVELS:
		var button := CHOOSE_LEVEL_BUTTON.instantiate() as ChooseLevelButton
		## level_script 必须在进树之前写好：按钮的 _ready() 里靠它 new 出关卡数据
		button.level_script = one["script"] as Script
		_set_button_title(button, str(one["title"]))
		grid.add_child(button)
		button.signal_choose_level_button.connect(_on_choose_level_button)
		button.curr_level_data_game_para.set_choose_level(game_mode, 0, str(one["level_id"]))
		button.update_curr_level_button_state(
			Global.global_game_state.curr_all_level_state_data.get(
				button.curr_level_data_game_para.save_game_name, {}))


## 按钮上显示的对局名（本体按钮默认写死的是「白天」）
func _set_button_title(button: ChooseLevelButton, title: String) -> void:
	var label := button.get_node_or_null("TextureButton/Label") as Label
	if label == null:
		return
	label.text = title
	## 「玩家对战：白天」有 7 个字，按钮那格放不下默认字号，压小一号
	label.add_theme_font_size_override("font_size", 14)
