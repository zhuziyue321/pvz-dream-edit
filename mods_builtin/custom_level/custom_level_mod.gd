extends "../mod_base.gd"
## 自制关卡模组：把玩家目录（`user://custom_level`）与**所有模组各自目录下的 `levels/`**
##（随各模组加载根走，见 custom_choose_level.gd:get_mod_level_dirs()）里的自制关卡脚本
## 加载成可选关卡
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
## 开关：模组页面里开 / 关（存进 `user://<用户名>/mod_config.ini`），默认关闭（本体 = 原版体验）；
## `data/mods/mod_config.tres` 只是**没有存档文件时播种用的工程默认**。
## 装载时机与写法见 [模组机制](../../docs/参考存档/模组机制.md)。

## 选关界面的**运行时**路径：本模组从哪个根加载（`user://mods/` 优先，其次是内置源）就拼哪个根。
## 根目录取 `ModManager.get_mod_root()`，不在这里抄第二份 —— 抄成 `user://mods` 的话，
## 这份跑的是内置源时就会指到一个空目录（两个源不互相复制，见 [模组机制](../../docs/参考存档/模组机制.md) §二）。
static func _choose_level_scene_path() -> String:
	return ModManager.get_mod_root(ModIds.CUSTOM_LEVEL).path_join("custom_level/custom_choose_level.tscn")


## 选关界面：注入到 `MainSceneRegistry.get_scene_path(ChooseLevelCustom)`
## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**（实测 Godot 4.6.2），
## 所以同目录 / 上级的文件一律 preload 成常量再引用，不能写 `extends Xxx` / `var x: Xxx`
const CustomChooseLevel := preload("custom_choose_level.gd")
const ModBase := preload("../mod_base.gd")

## 主菜单场景：认它来决定「什么时候该挂入口按钮」
const START_MENU_TSCN := "res://src/menus/start_menu/start_menu.tscn"
## 入口按钮的挂载点（与本体其它模式按钮同层）
const START_MENU_ANCHOR := "BG_Right"
const ENTRY_BUTTON_NAME := "CustomLevelEntryButton"

const ENTRY_BUTTON_TSCN := preload("custom_level_entry_button.tscn")

## 最近一次挂上去的入口按钮（场景切走就随之销毁，uninstall() 时主动收掉）
var _entry_button: Node = null


func get_mod_id() -> StringName:
	return ModIds.CUSTOM_LEVEL


func get_mod_name() -> String:
	return "自制关卡"


func get_mod_description() -> String:
	return "读取 user://custom_level 与所有模组目录下 levels/ 里的自制关卡脚本并加一个主菜单入口；原版没有自制关卡"


func get_mod_categories() -> Array[StringName]:
	return [ModCategory.ADD_STRUCTURE]


## 模组页面右侧：关卡从哪读、读到了几个、装了它主菜单会多出什么
func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	## 目录约定写在选关界面上（`CustomChooseLevel.CUSTOM_LEVEL_DIR`），这里引用它，不抄第二份
	box.add_child(ModBase.create_detail_label("关卡目录：" + CustomChooseLevel.get_base_path() + "/" + CustomChooseLevel.CUSTOM_LEVEL_DIR))
	## 所有模组的自带关卡目录：每个模组目录下的 levels/（不论该模组启用与否），同 id 玩家目录优先
	box.add_child(ModBase.create_detail_label("模组关卡目录：各模组目录下的 %s/（当前约定 %d 个）" % [
		CustomChooseLevel.MOD_LEVEL_DIR, CustomChooseLevel.get_mod_level_dirs().size()]))
	box.add_child(ModBase.create_detail_label("两类目录里现在共有 %d 个条目（一个关卡包目录或一个关卡脚本算一个）" % _count_level_entries()))
	box.add_child(ModBase.create_detail_label("启用了它，主菜单会多一个「自制关卡」入口；关掉这个模组，入口按钮与选关页一起消失"))
	return box


## 数一下两类关卡目录里各有多少个条目（只数不加载：加载关卡脚本是选关界面该干的事）
func _count_level_entries() -> int:
	var count := _count_entries(CustomChooseLevel.get_base_path() + "/" + CustomChooseLevel.CUSTOM_LEVEL_DIR)
	for dir in CustomChooseLevel.get_mod_level_dirs():
		count += _count_entries(dir)
	return count


## 数一个目录下的顶层条目（关卡包目录 / 关卡脚本各算一个，不含点开头的隐藏文件）
static func _count_entries(dir_path: String) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var count := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	return count


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
	Global.main_scene_registry.set_scene_path(MainSceneRegistry.MainScenes.ChooseLevelCustom, _choose_level_scene_path())


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


func _remove_entry_button() -> void:
	if is_instance_valid(_entry_button):
		_entry_button.queue_free()
	_entry_button = null


func _on_entry_pressed() -> void:
	Global.game_para = null
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.ChooseLevelCustom))
#endregion
