extends Control
class_name StartMenuRoot

@onready var dialog: Dialog = $Dialog
@onready var dialog_label: Label = $Dialog/Label
@export var bgm:AudioStream
@onready var user: User = $User

## 未解锁的模式按钮置灰色(与 ChooseLevelButton.lock_choose_level_button() 保持一致)
const LOCKED_BUTTON_COLOR := Color(0.687, 0.687, 0.687, 1.0)

## 受冒险模式进度限制的模式按钮: 按钮节点路径 -> 对应选关模式
const MODE_BUTTON_PATHS: Dictionary[String, MainSceneRegistry.MainScenes] = {
	"BG_Right/Menu/Button2": MainSceneRegistry.MainScenes.ChooseLevelMiniGame,
	"BG_Right/Menu/Button3": MainSceneRegistry.MainScenes.ChooseLevelPuzzle,
	"BG_Right/Menu/Button4": MainSceneRegistry.MainScenes.ChooseLevelSurvival,
}

## 道具栏里"没解锁就不该出现"的按钮:花园(5-5 戴夫交给你) / 图鉴(2-4 掉落大图鉴) / 商店(3-4 拿到车钥匙)
## 与模式按钮不同:模式按钮未解锁时置灰并保留(与 ChooseLevelButton 同口径,玩家能看到还有哪些玩法),
## 这三个属于"拿到了才有"的东西,没解锁时直接隐藏,不做置灰、也不做点击提示
const GARDEN_BUTTON_PATH := "BG_Right/Item/TextureButton"
const ALMANAC_BUTTON_PATH := "BG_Right/Item/TextureButton2"
const SHOP_BUTTON_PATH := "BG_Right/Item/TextureButton3"

## 花园状态图标(缺水 / 新植物气泡):与解锁表现一样是按存档算的,切换用户后要一起重算
const GARDEN_FLAG_PATH := "BG_Right/Item/TextureButton/GardenConditionFlag"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Cloud/AnimationPlayer.play("Idle")
	$BG_Right/Leaf/AnimationPlayer.play("Idle")
	$AnimationPlayer.play("Idle")

	SoundManager.setup_ui_start_menu_sound(self)
	SoundManager.play_bgm(bgm)

	Global.time_scale = 1.0
	Engine.time_scale = Global.time_scale

	_update_mode_lock_state()
	## 切换用户时存档是热加载的、本场景不重建,解锁表现要跟着新存档重算
	user.user_session_switched.connect(refresh_for_current_user)


## 该模式是否可进入: 控制台打开"开放所有关卡"时一律放行,否则看冒险模式进度
func _is_mode_enterable(game_mode: MainSceneRegistry.MainScenes) -> bool:
	if Global.config_service.open_all_level:
		return true
	return Global.global_game_state.is_mode_unlocked(game_mode)


## 花园是否可进入: 控制台打开"开放所有关卡"时一律放行,否则看冒险模式进度(5-5 戴夫交出花园后)
func _is_garden_enterable() -> bool:
	if Global.config_service.open_all_level:
		return true
	return Global.global_game_state.is_garden_unlocked()


## 图鉴是否可查看: 控制台打开"开放所有关卡"时一律放行,否则看冒险模式进度(2-4 掉落大图鉴后)
func _is_almanac_enterable() -> bool:
	if Global.config_service.open_all_level:
		return true
	return Global.global_game_state.is_almanac_unlocked()


## 商店是否可进入: 控制台打开"开放所有关卡"时一律放行,否则看冒险模式进度(3-4 拿到车钥匙后)
func _is_shop_enterable() -> bool:
	if Global.config_service.open_all_level:
		return true
	return Global.global_game_state.is_shop_unlocked()


## 按冒险模式进度处理主菜单入口:模式按钮置灰(迷你游戏 3-2 / 解谜 4-6 / 生存 5-10),
## 图鉴 / 商店按钮则整体隐藏(见 _apply_item_lock_state)
func _update_mode_lock_state() -> void:
	for node_path in MODE_BUTTON_PATHS:
		var button := get_node_or_null(NodePath(node_path)) as TextureButton
		if button == null:
			continue
		var game_mode: MainSceneRegistry.MainScenes = MODE_BUTTON_PATHS.get(node_path, MainSceneRegistry.MainScenes.Null)
		if _is_mode_enterable(game_mode):
			button.modulate = Color.WHITE
		else:
			button.modulate = LOCKED_BUTTON_COLOR
	_apply_item_lock_state()


## 花园 / 图鉴 / 商店未解锁时直接从道具栏隐藏:没拿到就是没有这个入口,不留置灰按钮、也不留点击提示
func _apply_item_lock_state() -> void:
	_apply_unlock_visible(GARDEN_BUTTON_PATH, _is_garden_enterable())
	_apply_unlock_visible(ALMANAC_BUTTON_PATH, _is_almanac_enterable())
	_apply_unlock_visible(SHOP_BUTTON_PATH, _is_shop_enterable())


## 按解锁状态显示 / 隐藏按钮:未解锁 => visible = false(隐藏后收不到点击,不需要额外拦截)
func _apply_unlock_visible(node_path: String, unlocked: bool) -> void:
	var button := get_node_or_null(NodePath(node_path)) as TextureButton
	if button == null:
		return
	button.visible = unlocked


## 切换用户后按新存档重算主菜单表现(User.user_session_switched)
func refresh_for_current_user() -> void:
	_update_mode_lock_state()
	var flag := get_node_or_null(NodePath(GARDEN_FLAG_PATH)) as GardenConditionFlag
	if flag != null:
		flag.judge_garden_condition()


## 进入与冒险模式进度挂钩的模式(迷你游戏/解谜/生存)
## 模式未解锁时弹出提示并返回 false,已解锁返回 true
func _try_enter_mode(game_mode: MainSceneRegistry.MainScenes, mode_name: String) -> bool:
	if _is_mode_enterable(game_mode):
		return true
	show_lock_tip(str("通关冒险模式 ") \
		+ ConstUnlockLevel.get_adventure_level_name(Global.global_game_state.get_mode_unlock_adventure_level(game_mode)) \
		+ str(" 后才能进入") + mode_name)
	return false

## 花园需要浇水
var garden_need_water:=true

## 功能未实现
func _unrealized():
	dialog.appear_dialog()

## 弹出未解锁提示
func show_lock_tip(text:String):
	dialog_label.text = text
	dialog.appear_dialog()

## 开始游戏
func _on_button_1_pressed() -> void:
	Global.game_para = null
	GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelAdventure])


## 迷你游戏(冒险模式 3-2 通关后解锁)
func _on_button_2_pressed() -> void:
	if not _try_enter_mode(MainSceneRegistry.MainScenes.ChooseLevelMiniGame, "迷你游戏"):
		return
	Global.game_para = null
	GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelMiniGame])

## 解密模式(冒险模式 4-6 通关后解锁)
func _on_button_3_pressed() -> void:
	if not _try_enter_mode(MainSceneRegistry.MainScenes.ChooseLevelPuzzle, "解密模式"):
		return
	Global.game_para = null
	GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelPuzzle])

## 生存模式(通关冒险模式 5-10 后解锁)
func _on_button_4_pressed() -> void:
	if not _try_enter_mode(MainSceneRegistry.MainScenes.ChooseLevelSurvival, "生存模式"):
		return
	Global.game_para = null
	GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelSurvival])

## 自定义关卡
func _on_custom_button_pressed() -> void:
	Global.game_para = null
	GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelCustom])

#region 选项
func _on_option_button_1_pressed() -> void:
	$StartMenuOptionDialog.appear_menu()


func _on_option_button_2_pressed() -> void:
	$Dialog_Help.appear_dialog()

## 退出游戏
func _on_option_button_3_pressed() -> void:
	get_tree().quit()


func _on_full_screen_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
#endregion


## 花园(按钮在通关冒险模式 5-5 拿到花园后才显示,这里的判定只是兜底)
func _on_item_button_1_pressed() -> void:
	if not _is_garden_enterable():
		return
	GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Garden])

## 图鉴(按钮在通关冒险模式 2-4 拿到大图鉴后才显示,这里的判定只是兜底)
func _on_item_button_2_pressed() -> void:
	if not _is_almanac_enterable():
		return
	GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Almanac])

## 商店(按钮在通关冒险模式 3-4 获得车钥匙后才显示,这里的判定只是兜底)
func _on_item_button_3_pressed() -> void:
	if not _is_shop_enterable():
		return
	GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Store])

## 点击用户更新时
func _on_button_update_user_pressed() -> void:
	user.visible = true
