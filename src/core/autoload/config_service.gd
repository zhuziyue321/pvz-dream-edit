extends Node
class_name ConfigService

## 配置服务：只负责 config.ini 的读写、保存当前设置、并对外提供配置值
## 运行态逻辑请直接通过 Global.config_service/<var> 与 <signal> 获取

signal signal_change_disappear_spare_card_placeholder
signal signal_change_display_plant_HP_label(value: bool)
signal signal_change_display_zombie_HP_label(value: bool)
signal signal_change_card_slot_top_mouse_focus
signal signal_fog_is_static
## 子弹无目标时追踪鼠标
signal signal_track_bullet_mouse

@onready var user_manager: UserManager = %UserManager

const CURRENT_CONFIG_FILE := "config.ini"

## 用户选项（持久化字段）
var auto_collect_sun := false
var auto_collect_coin := false

var disappear_spare_card_Placeholder := false:
	set(value):
		if disappear_spare_card_Placeholder == value:
			return
		disappear_spare_card_Placeholder = value
		signal_change_disappear_spare_card_placeholder.emit()

var display_plant_HP_label := false:
	set(value):
		if display_plant_HP_label == value:
			return
		display_plant_HP_label = value
		signal_change_display_plant_HP_label.emit(display_plant_HP_label)

var display_zombie_HP_label := false:
	set(value):
		if display_zombie_HP_label == value:
			return
		display_zombie_HP_label = value
		signal_change_display_zombie_HP_label.emit(display_zombie_HP_label)

var card_slot_top_mouse_focus := false:
	set(value):
		if card_slot_top_mouse_focus == value:
			return
		card_slot_top_mouse_focus = value
		signal_change_card_slot_top_mouse_focus.emit()

var fog_is_static := false:
	set(value):
		if fog_is_static == value:
			return
		fog_is_static = value
		signal_fog_is_static.emit()

var plant_be_shovel_front := true
var open_all_level := false

##追踪子弹无目标时跟随标
var track_bullet_mouse := false:
	set(value):
		if track_bullet_mouse == value:
			return
		track_bullet_mouse = value
		signal_track_bullet_mouse.emit()

## 控制台扩展项的通用键值区（控制台条目的 `ConsoleEntry.bind_config()` 落在这里）
##
## 为什么要有这一块：控制台现在是可扩展的（见 ConsoleRegistry），新增一项不该要求
## 回来给本服务加字段 + 加 load 一行 + 加 save 一行。整包读写之后，加一个持久化开关
## 只需要一句 `.bind_config("模组前缀.键名", 默认值)`，键名自己带前缀避免撞车。
var console_values: Dictionary = {}


## 读一个控制台扩展值（没存过就返回 [param default_value]）
func get_console_value(key: String, default_value: Variant = null) -> Variant:
	return console_values.get(key, default_value)


## 写一个控制台扩展值（只改内存，存盘发生在 `save_config()`）
func set_console_value(key: String, value: Variant) -> void:
	console_values[key] = value


func _get_config_path() -> String:
	if user_manager == null or user_manager.curr_user_name.is_empty():
		return ""
	return "user://" + user_manager.curr_user_name + "/" + CURRENT_CONFIG_FILE

func load_and_apply_config() -> void:

	var path := _get_config_path()
	if path.is_empty():
		return

	var config := ConfigFile.new()
	# config 不存在时 load 的返回值可能非 OK，此时仍使用默认值应用（不报错可提升兼容性）
	config.load(path)

	# 音量设置
	SoundManager.set_volume(SoundManager.Bus.MASTER, config.get_value("audio", "master", 1.0))
	SoundManager.set_volume(SoundManager.Bus.BGM, config.get_value("audio", "bgm", 0.5))
	SoundManager.set_volume(SoundManager.Bus.SFX, config.get_value("audio", "sfx", 0.5))

	# 用户选项控制台
	auto_collect_sun = config.get_value("user_control", "auto_collect_sun", false)
	auto_collect_coin = config.get_value("user_control", "auto_collect_coin", false)
	disappear_spare_card_Placeholder = config.get_value("user_control", "disappear_spare_card_Placeholder", false)
	display_plant_HP_label = config.get_value("user_control", "display_plant_HP_label", false)
	display_zombie_HP_label = config.get_value("user_control", "display_zombie_HP_label", false)
	card_slot_top_mouse_focus = config.get_value("user_control", "card_slot_top_mouse_focus", false)
	fog_is_static = config.get_value("user_control", "fog_is_static", false)
	plant_be_shovel_front = config.get_value("user_control", "plant_be_shovel_front", true)
	open_all_level = config.get_value("user_control", "open_all_level", false)
	track_bullet_mouse = config.get_value("user_control", "track_bullet_mouse", false)
	console_values = config.get_value("console", "values", {})

	EventBus.push_event(ConstEventName.ON_CONFIG_UPDATE)

func save_config() -> void:
	var path := _get_config_path()
	if path.is_empty():
		return

	var config := ConfigFile.new()

	# 音乐相关
	config.set_value("audio", "master", SoundManager.get_volum(SoundManager.Bus.MASTER))
	config.set_value("audio", "bgm", SoundManager.get_volum(SoundManager.Bus.BGM))
	config.set_value("audio", "sfx", SoundManager.get_volum(SoundManager.Bus.SFX))

	# 用户选项控制台相关
	config.set_value("user_control", "auto_collect_sun", auto_collect_sun)
	config.set_value("user_control", "auto_collect_coin", auto_collect_coin)
	config.set_value("user_control", "disappear_spare_card_Placeholder", disappear_spare_card_Placeholder)
	config.set_value("user_control", "display_plant_HP_label", display_plant_HP_label)
	config.set_value("user_control", "display_zombie_HP_label", display_zombie_HP_label)
	config.set_value("user_control", "card_slot_top_mouse_focus", card_slot_top_mouse_focus)
	config.set_value("user_control", "fog_is_static", fog_is_static)
	config.set_value("user_control", "plant_be_shovel_front", plant_be_shovel_front)
	config.set_value("user_control", "open_all_level", open_all_level)
	config.set_value("user_control", "track_bullet_mouse", track_bullet_mouse)
	config.set_value("console", "values", console_values)

	config.save(path)
