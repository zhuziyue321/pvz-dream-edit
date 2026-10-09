extends ModBase
class_name CustomLevelMod
## 自制关卡模组：把 `data/levels/params` 下的玩家自制关卡脚本加载成可选关卡
##
## 原版没有「玩家自制关卡」这个功能（原版只有内置的模式选关），所以整条链路都在模组里：
##   - 选关界面 `custom_choose_level.tscn`（扫描目录、动态建按钮、分页）
##   - 关卡按钮 `choose_level_button_customize.tscn`（按钮上直接显示关卡名）
##   - 主菜单入口 `custom_level_entry_button.tscn`（本体 start_menu.tscn 里没有这个按钮）
##
## 本体留给本模组的只有两个槽位（见 ModBase 边界规则 3）：
##   - `MainSceneRegistry.MainScenes.ChooseLevelCustom` 枚举值
##   - 主菜单的 `BG_Right` 节点（入口按钮挂它下面）
## 场景路径由本模组在 `install()` 时注入注册表 —— 本体不许出现模组里的路径。
##
## 开关在 `data/mods/mod_config.tres` 的 `enabled_mods`，默认关闭（本体 = 原版体验）。
## 装载时机与写法见 [模组机制](../../docs/参考存档/模组机制.md)。

## 选关界面：注入到 `MainSceneRegistry.MainScenesMap[ChooseLevelCustom]`
const CUSTOM_CHOOSE_LEVEL_TSCN := "res://src/mods/custom_level/custom_choose_level.tscn"
## 主菜单场景：认它来决定「什么时候该挂入口按钮」
const START_MENU_TSCN := "res://src/menus/start_menu/start_menu.tscn"
## 入口按钮的挂载点（与本体其它模式按钮同层）
const START_MENU_ANCHOR := "BG_Right"
const ENTRY_BUTTON_NAME := "CustomLevelEntryButton"

const ENTRY_BUTTON_TSCN := preload("res://src/mods/custom_level/custom_level_entry_button.tscn")

## 最近一次挂上去的入口按钮（场景切走就随之销毁，uninstall() 时主动收掉）
var _entry_button: Node = null


func get_mod_id() -> StringName:
	return ModIds.CUSTOM_LEVEL


func get_mod_name() -> String:
	return "自制关卡"


func get_mod_description() -> String:
	return "读取 data/levels/params 下的玩家自制关卡脚本并加一个主菜单入口；原版没有自制关卡"


#region 生命周期
func install() -> void:
	_register_choose_level_scene()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		Log.error("自制关卡模组：拿不到 SceneTree，主菜单入口不会装")
		return
	## 主菜单每次都是重新加载的场景，跟着「root 多了个子节点」补一次按钮
	if not tree.root.child_entered_tree.is_connected(_on_scene_entered):
		tree.root.child_entered_tree.connect(_on_scene_entered)
	## 已经挂在树上的场景补一次（比如运行期才打开开关）
	for node in tree.root.get_children():
		_on_scene_entered(node)


func uninstall() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.child_entered_tree.is_connected(_on_scene_entered):
		tree.root.child_entered_tree.disconnect(_on_scene_entered)
	_remove_entry_button()
	Global.main_scene_registry.MainScenesMap.erase(MainSceneRegistry.MainScenes.ChooseLevelCustom)
#endregion


#region 安装
## 把选关界面的路径填进注册表（`ChooseLevelCustom` 这个枚举槽位是本体留的）
func _register_choose_level_scene() -> void:
	Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelCustom] = CUSTOM_CHOOSE_LEVEL_TSCN


## 每次有场景进树：认出主菜单就补入口按钮
func _on_scene_entered(node: Node) -> void:
	if node == null or node.scene_file_path != START_MENU_TSCN:
		return
	_inject_entry_button(node)


## 现场挂按钮：本体场景里没有它的一席之地，全靠这里加
func _inject_entry_button(start_menu: Node) -> void:
	var parent := start_menu.get_node_or_null(START_MENU_ANCHOR)
	if parent == null:
		Log.error("自制关卡模组：主菜单缺少挂载点 %s，入口按钮不装" % START_MENU_ANCHOR)
		return
	if parent.get_node_or_null(ENTRY_BUTTON_NAME) != null:
		return
	var button := ENTRY_BUTTON_TSCN.instantiate()
	button.name = ENTRY_BUTTON_NAME
	button.pressed.connect(_on_entry_pressed)
	parent.add_child(button)
	_entry_button = button
	Log.debug("自制关卡模组：已挂主菜单入口按钮")


func _remove_entry_button() -> void:
	if is_instance_valid(_entry_button):
		_entry_button.queue_free()
	_entry_button = null


func _on_entry_pressed() -> void:
	Global.game_para = null
	GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelCustom])
#endregion
