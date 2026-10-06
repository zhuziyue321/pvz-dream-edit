extends TextureRect
class_name MainGameMenuOptionDialog

@onready var dialog: Dialog = $"../Dialog"

@onready var music_h_slider: HSlider = $Option/VBoxContainer/Music/HSlider
@onready var sound_h_slider: HSlider = $Option/VBoxContainer/SoundEffect/HSlider
@onready var time_scale_h_slider: HSlider = $Option/VBoxContainer/TimeScale/HSlider
@onready var time_sacle_label: Label = $Option/VBoxContainer/TimeScale/Label
@onready var canvas_layer_console: CanvasLayerConsole = %CanvasLayerConsole
## 图鉴场景所在的画布层
@onready var canvas_layer_almanac: CanvasLayer = %CanvasLayerAlmanac
## 图鉴按钮(未解锁时置灰,与主菜单 StartMenuRoot.LOCKED_BUTTON_COLOR 同色)
@onready var almanac_button: CanvasItem = $Option/Button1

## 未解锁的按钮置灰色(与主菜单保持一致)
const LOCKED_BUTTON_COLOR := Color(0.687, 0.687, 0.687, 1.0)
## 未解锁提示的停留秒数
const LOCK_TIP_TIME := 4.0


func _ready() -> void:
	## 为按钮添加音效
	SoundManager.setup_ui_main_game_sound(self)
	## 图鉴在通关冒险模式 2-4 拿到大图鉴后才开放
	almanac_button.modulate = Color.WHITE if Global.global_game_state.is_almanac_unlocked() \
		else LOCKED_BUTTON_COLOR
	## 连接滑轨信号
	music_sound_signal(music_h_slider, AudioServer.get_bus_index("BGM"))
	music_sound_signal(sound_h_slider, AudioServer.get_bus_index("SFX"))
	time_sacle_signal(time_scale_h_slider)
	time_sacle_label.text = "倍速 " + str(Global.time_scale) + " 倍"


func music_sound_signal(h_slider: HSlider, bus_index: int) -> void:
	h_slider.value = SoundManager.get_volum(bus_index)
	h_slider.value_changed.connect(func (v:float):
		SoundManager.set_volume(bus_index, v)
		Global.config_service.save_config()
	)


func time_sacle_signal(h_slider: HSlider):
	h_slider.value_changed.connect(func (v:float):
		Global.time_scale = v
		time_sacle_label.text = "倍速 " + str(Global.time_scale) + " 倍"
		Engine.time_scale = Global.time_scale
		)

## 出现菜单
func appear_menu():
	await get_tree().create_timer(0.1).timeout
	# 游戏暂停

	TreePauseManager.start_tree_pause(TreePauseManager.E_PauseFactor.Menu)
	SoundManager.play_other_SFX("pause")

	visible = true
	#mouse_filter = Control.MOUSE_FILTER_STOP

## 关闭菜单
func return_button_pressed():
	await get_tree().create_timer(0.1).timeout
	SoundManager.play_other_SFX("pause")
	visible = false

	TreePauseManager.end_tree_pause(TreePauseManager.E_PauseFactor.Menu)
	#mouse_filter = Control.MOUSE_FILTER_IGNORE

## 图鉴(原版通关冒险模式 2-4 拿到戴夫掉落的大图鉴后才开放)
func encyclopedia():
	if not Global.global_game_state.is_almanac_unlocked():
		_show_almanac_lock_tip()
		return
	## 连点会叠出多个图鉴场景，已经打开就不再创建
	if canvas_layer_almanac.get_child_count() > 0:
		return
	var almance_node = load(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Almanac]).instantiate()
	canvas_layer_almanac.add_child(almance_node)


## 重新开始
func resume_game():
	EventBus.push_event("set_keep_system_cursor_visible", true)

	Global.main_game.save_manager.re_main_game()

	TreePauseManager.end_tree_pause_clear_all_pause_factors()
	Global.time_scale = 1.0
	Engine.time_scale = Global.time_scale
	get_tree().reload_current_scene()


## 返回主菜单
func return_main_menu():
	EventBus.push_event("set_keep_system_cursor_visible", true)
	TreePauseManager.end_tree_pause_clear_all_pause_factors()
	Global.time_scale = 1.0
	Engine.time_scale = Global.time_scale
	GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])

## 功能未实现
func _unrealized():
	dialog.appear_dialog()

## 弹出"图鉴未解锁"提示(暂停菜单里没有主菜单那种对话框,用与掉落道具同一套提示条)
func _show_almanac_lock_tip() -> void:
	var tip_text := str("通关冒险模式 ") \
		+ ConstUnlockLevel.get_adventure_level_name(ConstUnlockLevel.ALMANAC_UNLOCK_ADVENTURE_LEVEL) \
		+ str(" 拿到大图鉴后才能查看图鉴")
	var reminder_info: ReminderInformation = SceneRegistry.REMINDER_INFORMATION.instantiate()
	get_tree().current_scene.add_child(reminder_info)
	reminder_info._init_info([tip_text], LOCK_TIP_TIME)


## 出现控制台
func _on_button_console_pressed() -> void:
	canvas_layer_console.appear_canvas_layer_control()

