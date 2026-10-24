extends "res://src/mods/mod_base.gd"
## 玩家对战模组：主菜单木牌上的「MULTIPLAYER」牌 → 玩家对战选关界面
##
## 原版没有对战玩法，所以整条链路都在模组里：
##   - 选关界面 `player_battle_choose_level.tscn`（页里挂着本模组自带的对局条目）
##   - 对局关卡 `levels/player_battle_day.gd`（**玩家对战：白天** —— 空关卡：草坪空着，对战逻辑还没做）
##   - 入口：本体主菜单木牌上那张「MULTIPLAYER」牌（本体只留一个枚举槽位）
##
## 本体留给本模组的只有**一个槽位**（见 ModBase 边界规则 3）：
##   - `MainSceneRegistry.MainScenes.ChooseLevelPlayerBattle`（场景路径由本模组在 install() 时注入）
## 本体不认识本模组，也不出现本模组里的路径。
##
## 开关：模组页面里开 / 关（存进 `user://<用户名>/mod_config.ini`）；
## `data/mods/mod_config.tres` 是**没有存档文件时播种用的工程默认**。
## 装载时机与写法见 [模组机制](../../docs/参考存档/模组机制.md)。

## 基类只有框架那一份（绝对路径）：`user://` 下不能用 `extends ModBase`
const ModBase := preload("res://src/mods/mod_base.gd")

## 选关界面的**运行时**路径：本模组从哪个根加载（`user://mods/` 优先，其次内置源）就拼哪个根。
## 根目录取 `ModManager.get_mod_root()`，不在这里抄第二份 —— 抄成 `user://mods` 的话，
## 这份跑的是内置源时就会指到一个空目录（两个源不互相复制，见 [模组机制](../../docs/参考存档/模组机制.md) §二）。
static func _choose_level_scene_path() -> String:
	return ModManager.get_mod_root(ModIds.PLAYER_BATTLE).path_join("player_battle/player_battle_choose_level.tscn")


func get_mod_id() -> StringName:
	return ModIds.PLAYER_BATTLE


func get_mod_name() -> String:
	return "玩家对战"


func get_mod_description() -> String:
	return "主菜单木牌上的「MULTIPLAYER」牌：进玩家对战选关界面；目前只有一关「玩家对战：白天」，是空关卡（对战逻辑还没做）"


func get_mod_categories() -> Array[StringName]:
	return [ModCategory.ADD_STRUCTURE]


## 模组页面右侧：现在做到了哪一步
func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label("入口：主菜单左下木牌上的「MULTIPLAYER」牌"))
	box.add_child(ModBase.create_detail_label("现状：选关界面已就位，页里有一关「玩家对战：白天」—— 空关卡（草坪空着，对战逻辑还没做）"))
	return box


#region 生命周期
## 全局安装（游戏启动，只调一次）：把选关界面路径填进注册表
## （`ChooseLevelPlayerBattle` 这个枚举槽位是本体留的，路径由本模组注入）
func install() -> void:
	Global.main_scene_registry.set_scene_path(MainSceneRegistry.MainScenes.ChooseLevelPlayerBattle, _choose_level_scene_path())


## 关掉模组 = 把槽位里的路径收走（本体那边就会提示「要在模组页面里打开」）
func uninstall() -> void:
	Global.main_scene_registry.MainScenesMap.erase(MainSceneRegistry.MainScenes.ChooseLevelPlayerBattle)
#endregion
