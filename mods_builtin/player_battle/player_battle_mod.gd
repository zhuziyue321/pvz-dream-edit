extends "res://src/mods/mod_base.gd"
## 玩家对战模组：主菜单木牌上的「MULTIPLAYER」牌 → 玩家对战选关界面
##
## 原版没有对战玩法，所以整条链路都在模组里：
##   - 选关界面 `player_battle_choose_level.tscn`（页里挂着本模组自带的对局条目）
##   - 对局关卡 `levels/player_battle_day.gd`（**玩家对战：白天** —— 左植物 / 右僵尸两条卡槽已就位；
##     僵尸方每行摆一只**靶子僵尸**，植物方击破 3 只即算植物赢；
##     僵尸方**有一只走进房子**就算僵尸赢 —— 走本体「僵尸进家」那套失败流程）
##   - 入口：本体主菜单木牌上那张「MULTIPLAYER」牌（本体只留一个枚举槽位）
##
## 本体留给本模组的只有**一个槽位**（见 ModBase 边界规则 3）：
##   - `MainSceneRegistry.MainScenes.ChooseLevelPlayerBattle`（场景路径由本模组在 install() 时注入）
## 本体不认识本模组，也不出现本模组里的路径。
##
## 依赖「僵尸卡」模组（`get_mod_dependencies()`）：右侧那条反转的僵尸卡槽
## （六格、脑子计数在右）由僵尸卡模组装 —— 它认 `ChooseLevelPlayerBattle` 这个 game_mode，
## 见 `mods_builtin/zombie_card/zombie_card_pvp_wiring.gd`；打开本模组会把它一并打开。
##
## 本模组自己提供**产脑光墓碑**（`vsgravestone/`，DLC 对战墓碑 VSGravestone 接成的**运行期僵尸**，
## 2026-10-25 从僵尸卡模组迁来、同日由植物改成僵尸单位）：50 脑光、冷却 7.5 s、**花脑子**，
## 是僵尸方目前唯一的收入口。走 `ZombieRuntimeKit` 出卡（与「僵尸卡」模组的运行期僵尸同一套），
## 于是它天然排在选卡面板的僵尸卡里、落僵尸块、按僵尸卡扣脑子；
## 放置时占格（`PlantCell.set_occupied_by_zombie()`），同一格放不了第二块。
##
## 本模组还提供**靶子僵尸**（`targetzombie/`，DLC 的 Zombie_target 接成的热注册僵尸，
## 2026-10-25 从 DLC 模组挪到这里）：对战里由关卡每行摆一只、站着不动，植物方击破 3 只即胜。
## 它**不是卡**（不装 `ZombieRuntimeKit`），只注册进 `CharacterRegistry` 给关卡用。
##
## 开关：模组页面里开 / 关（存进 `user://<用户名>/mod_config.ini`）；
## `data/mods/mod_config.tres` 是**没有存档文件时播种用的工程默认**。
## 装载时机与写法见 [模组机制](../../docs/参考存档/模组机制.md)。

## 基类只有框架那一份（绝对路径）：`user://` 下不能用 `extends ModBase`
const ModBase := preload("res://src/mods/mod_base.gd")
const Settings := preload("player_battle_settings.gd")
## 植物卡的对战口径接线（阳光 / 冷却，每局挂一次）
const PlantWiring := preload("player_battle_plant_wiring.gd")
const TombstoneScene := preload("vsgravestone/zombie_vsgravestone.tscn")
## 靶子僵尸的场景（本体 `zombie_base.tscn` + DLC 动画 + 自写脚本，见 `targetzombie/`）
const TargetZombieScene := preload("targetzombie/zombie_target.tscn")

## 产脑光墓碑（运行期僵尸，数值见 `player_battle_settings.gd`）
var _tombstone_kit: ZombieRuntimeKit
## 靶子僵尸注册上了没（它没有 Kit，只有一个注册表条目）
var _target_zombie_registered := false

## 植物卡对战口径接线在主游戏里的节点名（重复 install 靠它防重，探针也按它找）
const PLANT_WIRING_NAME := &"PlayerBattlePlantWiring"

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
	return "主菜单木牌上的「MULTIPLAYER」牌：进玩家对战选关界面；目前只有一关「玩家对战：白天」" \
		+ "—— 左植物 / 右僵尸两条卡槽已就位；" \
		+ "另把 DLC 对战墓碑接成 **产脑光墓碑**（50 脑光，僵尸卡阵营里的**僵尸单位**；" \
		+ "放下去像向日葵一样周期性给僵尸方入账脑子，占一格、同一格放不了第二块）；" \
		+ "僵尸方每行还摆一只 **靶子僵尸**（DLC 的 Zombie_target），植物方击破 3 只即算植物赢；" \
		+ "僵尸方**有一只走进房子**即算僵尸赢"


## 分类：新增结构（入口 / 选关页）+ 新增单位（产脑光墓碑、靶子僵尸）
func get_mod_categories() -> Array[StringName]:
	return [ModCategory.ADD_STRUCTURE, ModCategory.ADD_UNIT]


## 依赖：右侧那条反转僵尸卡槽由「僵尸卡」模组装（打开本模组把它一并打开）
func get_mod_dependencies() -> Array[StringName]:
	return [ModIds.ZOMBIE_CARD]


## 模组页面右侧：现在做到了哪一步
func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label("入口：主菜单左下木牌上的「MULTIPLAYER」牌"))
	box.add_child(ModBase.create_detail_label("现状：选关界面已就位，页里有一关「玩家对战：白天」——"))
	box.add_child(ModBase.create_detail_label("　· 左上：六格植物卡槽（选卡 / 种植走本体流程）"))
	box.add_child(ModBase.create_detail_label("　· 右上：六格僵尸卡槽，反转、脑子计数在右（由「僵尸卡」模组装）"))
	box.add_child(ModBase.create_detail_label("　· 放置限制已做（保龄球红线）；胜负已做：植物方击破 3 只靶子僵尸即胜，"
		+ "僵尸方有一只走进房子即胜"))
	box.add_child(ModBase.create_detail_label("产脑光墓碑：50 脑光的僵尸单位（在僵尸卡阵营里选），行为类似向日葵、周期给僵尸方入账脑子，"
		+ "冷却 7.5 秒、放下去占一格"))
	box.add_child(ModBase.create_detail_label("靶子僵尸：DLC 的 Zombie_target（原版未启用的残留类型）—— 每行一只、站着不动、不啃植物；"
		+ "200 血（受创 60 / 110 / 160 三档换更破的招牌），被植物打死算「击破」，击破 3 只植物赢"))
	box.add_child(ModBase.create_detail_label("植物卡对战口径：一部分植物的阳光 / 冷却按 DLC 对战表（白天前院），"
		+ "如寒冰射手 150、双发射手 175、墓碑吞噬者 50 且冷却 15 秒；表外的株与冒险模式一致"))
	return box


#region 对外口子（僵尸卡模组问这里）
## 这只僵尸是不是产脑光墓碑
##
## ★ 改动后它已经是**普通僵尸卡**（`CardType.Zombie`）：算不算花脑子、要不要换僵尸卡面，
##   僵尸卡模组按 `is_zombie_card()` 就能判，**不再需要**转问本模组。
##   这个方法留给探针 / 调试确认「这只僵尸归玩家对战模组管」，业务代码不要拿它当路由。
func is_tombstone_zombie(zombie_type: StringName) -> bool:
	return zombie_type == Settings.TOMBSTONE_ZOMBIE_ID


## 墓碑卡的**模板**（选卡面板自然会从 `AllCards` 的僵尸卡目录里取到它；
## 这个方法只是给探针 / 调试用的快捷入口）：没装上 / 没注册就返回 null
func get_tombstone_card_template() -> Card:
	if _tombstone_kit == null or not _tombstone_kit.is_installed():
		return null
	var ref := ResourceCardReference.create(
		ResourceCardReference.CardType.Zombie, Settings.TOMBSTONE_ZOMBIE_ID)
	if not AllCards.has_template(ref):
		return null
	return AllCards.get_template(ref)
#endregion


#region 生命周期
## 全局安装（游戏启动，只调一次）：把选关界面路径填进注册表 + 注册产脑光墓碑 + 靶子僵尸
## （`ChooseLevelPlayerBattle` 这个枚举槽位是本体留的，路径由本模组注入）
func install() -> void:
	Global.main_scene_registry.set_scene_path(MainSceneRegistry.MainScenes.ChooseLevelPlayerBattle, _choose_level_scene_path())
	_install_tombstone()
	_register_target_zombie()


## 每局接线：只在本模组的对战关卡里挂「植物卡对战口径」（阳光 / 冷却）
##
## 植物那半槽是**本体**的选卡 / 出战卡槽，本模组只按 id 把一部分株换成对战价
## （表在 `player_battle_settings.gd`，口径 = 白天前院，逐株抄自 DLC wiki）——
## 别的关卡（冒险模式 / 迷你游戏）一行代码都不走，注册表原值不受影响。
## 挂载时机由 `MainGameManager.init_manager()` 保证：`card_manager` 已建好
## （待选区容器、出战卡槽都在），`HandManager` 还没注册组件。
func install_to_main_game(main_game: MainGameManager) -> void:
	if main_game == null or main_game.game_para == null:
		return
	if main_game.game_para.game_mode != MainSceneRegistry.MainScenes.ChooseLevelPlayerBattle:
		return
	## 幂等：同一局已经有接线就不再挂第二份
	if main_game.get_node_or_null(String(PLANT_WIRING_NAME)) != null:
		return
	var wiring = PlantWiring.new()
	wiring.name = PLANT_WIRING_NAME
	main_game.add_child(wiring)
	wiring.setup(main_game)


## 关掉模组 = 把槽位里的路径收走（本体那边就会提示「要在模组页面里打开」）+ 撤掉墓碑与靶子僵尸
func uninstall() -> void:
	Global.main_scene_registry.MainScenesMap.erase(MainSceneRegistry.MainScenes.ChooseLevelPlayerBattle)
	_uninstall_tombstone()
	_unregister_target_zombie()


## 全局存档重读完：解锁会被存档覆盖，补一次（僵尸卡的解锁名单是 `curr_zombie`）
func on_session_reloaded() -> void:
	if _tombstone_kit != null:
		_tombstone_kit.unlock()


## 注册产脑光墓碑（**僵尸**：注册表条目 + 僵尸卡 + 卡面 + 解锁都在下面两步里）
##
## 顺序不能反：先 `register_runtime_zombie()`（让这只僵尸存在），
## 再 `ZombieRuntimeKit.install()`（插卡 / 画卡面 / 解锁）—— 后者开头就会查注册表。
func _install_tombstone() -> void:
	## 幂等：已经装着就不再装第二份 —— 重复 install 会「卡牌身份重复注册」，
	## 而且旧那份卡摘不掉（卸载只认当前 Kit 手里那张），目录里会留一具空卡
	if _tombstone_kit != null and _tombstone_kit.is_installed():
		Log.warn("玩家对战模组：产脑光墓碑已装着，跳过重复 install")
		return
	if not Global.character_registry.register_runtime_zombie(_build_tombstone_recipe()):
		Log.error("玩家对战模组：产脑光墓碑注册失败（id 撞车或配方不合法）")
		return
	_tombstone_kit = ZombieRuntimeKit.new()
	## 卡面落点：墓碑的身形整体偏在原点左上方，标准僵尸那套 (2,17) 会把它摆到卡片左上角
	## （量法与口径见 `player_battle_settings.gd` 的 `TOMBSTONE_CARD_FACE_POSITION`）
	_tombstone_kit.face_position = Settings.TOMBSTONE_CARD_FACE_POSITION
	if not _tombstone_kit.install(Settings.TOMBSTONE_ZOMBIE_ID):
		Log.error("玩家对战模组：产脑光墓碑的卡没装上（拿不到僵尸卡源目录？）")
		_tombstone_kit = null
		Global.character_registry.unregister_runtime_zombie(Settings.TOMBSTONE_ZOMBIE_ID)


## 墓碑的运行期僵尸配方：本体 + 脚本（场景根已经挂着 `vsgravestone_zombie.gd`，不再 set_script）
##
## 出怪权重 / 战力留 0：它不进自然出怪池，只能由玩家从僵尸卡槽放出来。
func _build_tombstone_recipe() -> ZombieRuntimeRecipe:
	var recipe := ZombieRuntimeRecipe.new()
	recipe.zombie_type = Settings.TOMBSTONE_ZOMBIE_ID
	recipe.zombie_name = &"VsGravestone"
	recipe.base_scene = TombstoneScene
	recipe.cool_time = Settings.TOMBSTONE_COOL_TIME
	recipe.sun_cost = Settings.TOMBSTONE_SUN_COST
	recipe.row_type = CharacterRegistry.ZombieRowType.Land
	recipe.spawn_power = 0
	recipe.spawn_weight = 0
	return recipe


## 卸载：先摘卡（Kit 内部会重排编号，那时僵尸还得在）→ 再注销僵尸 → 撤解锁
func _uninstall_tombstone() -> void:
	if _tombstone_kit != null:
		_tombstone_kit.uninstall()
		_tombstone_kit = null
	if Global.character_registry.is_runtime_zombie(Settings.TOMBSTONE_ZOMBIE_ID):
		Global.character_registry.unregister_runtime_zombie(Settings.TOMBSTONE_ZOMBIE_ID)


## 热注册靶子僵尸（对战摆的目标物）
##
## ★ 故意**不装 `ZombieRuntimeKit`**：它不该出现在僵尸卡阵营里 —— 玩家放不出来，
##   只能由关卡脚本按行摆（见 `levels/player_battle_day.gd`）。所以这里只有一个注册表条目。
## ★ 出怪权重 / 战力都留 0：不进自然出怪池，关卡想出它自己点名。
func _register_target_zombie() -> void:
	if _target_zombie_registered:
		return
	var recipe := ZombieRuntimeRecipe.new()
	recipe.zombie_type = Settings.TARGET_ZOMBIE
	recipe.zombie_name = &"TargetZombie"
	## 场景根已经挂着 `target_zombie.gd`，配方里不再 `set_script`
	recipe.base_scene = TargetZombieScene
	recipe.row_type = CharacterRegistry.ZombieRowType.Land
	recipe.spawn_power = 0
	recipe.spawn_weight = 0
	if not Global.character_registry.register_runtime_zombie(recipe):
		Log.error("玩家对战模组：靶子僵尸注册失败（id 撞车或配方不合法）")
		return
	_target_zombie_registered = true


## 撤掉靶子僵尸的注册（幂等：没注册过就什么都不做）
func _unregister_target_zombie() -> void:
	if not _target_zombie_registered:
		return
	_target_zombie_registered = false
	if Global.character_registry.is_runtime_zombie(Settings.TARGET_ZOMBIE):
		Global.character_registry.unregister_runtime_zombie(Settings.TARGET_ZOMBIE)
#endregion
