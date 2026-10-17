extends RefCounted
class_name PlantRuntimeKit
## 一株「运行期植物」的**装 / 卸**：登记 + 卡片 + 卡面 + 解锁，卸的时候反向全撤
##
## ★ 为什么要有这一层：模组新增一株植物要做四件事（登记进注册表、插一张卡、给卡画张脸、
##   把植物解锁），这四件事**每件都有坑**，而且坑是同一套的：
##   · 插卡之后必须 `AllCards.rebuild()`（编号按源目录节点顺序算，不重排新卡没有编号）；
##   · 卡面取帧要往 `tree.root` 挂临时容器，`_ready()` 里挂不进去 → 得推到帧末；
##   · 取帧拿到的整株带着血条 / 组件容器那批 UI，得剥成一棵纯精灵树；
##   · 撤销时**先摘卡再清注册表**（重排编号时还得查得到冷却与阳光）；
##   · 撤销解锁要连「上次选卡」里的条目一起清（不清会点到一个不存在的卡位）。
## 以前这些全写在模组里（`mods_builtin/water_bowl/` 一开始就是这么写的），
## 每一只新植物都要重踩一遍 —— 现在收在这里，模组只管填 `PlantRuntimeRecipe`。
##
## 用法（见 `mods_builtin/water_bowl/water_bowl_mod.gd`）：
## ```gdscript
## var _kit := PlantRuntimeKit.new()
##
## func install() -> void:
## 	_kit.install(_build_recipe())
## 	_kit.make_selectable()   ## 还想让玩家在选卡界面里挑到它，就补这一行
##
## func uninstall() -> void:
## 	_kit.uninstall()
## ```
##
## ⚠️ 一个 Kit 管一株植物：要装三株就 new 三个。
## 关掉模组 = 调 `uninstall()`，本体与卡片目录回到「这株植物从没出现过」。
##
## 关联：[运行期植物](../../../../docs/参考存档/运行期植物.md) ｜ `PlantRuntimeRecipe` ｜ `CharacterRegistry` ｜ `AllCards`

## 卡片模板：运行期插进 `AllCards` 的源目录
const CARD_SCENE := preload("res://src/ui/card/card.tscn")

## 当前装着的配方（没装 = null）
var recipe: PlantRuntimeRecipe = null
## 插进源目录的那张卡（卸的时候摘掉）
var _card: Card = null


## 装一株植物：登记 → 插卡 → 解锁
## [param new_recipe] 配方；`plant_type` 留空时由注册表自动分配 id，装完从 `recipe.plant_type` 读回来
## [return] 登记失败（配方不合法 / id 撞了内置植物）返回 false，其它一步都没做
##
## ⚠️ 装完这株植物**还没有进选卡界面** —— 想在待选区挑到它，装完之后再写一行
## `make_selectable()`（注册 / 解锁都不等于可选，理由见那个函数）。
func install(new_recipe: PlantRuntimeRecipe) -> bool:
	if new_recipe == null:
		Log.error("运行期植物：配方是空的，不装")
		return false
	if not Global.character_registry.register_runtime_plant_recipe(new_recipe):
		return false
	recipe = new_recipe
	_install_card()
	unlock()
	Log.info("运行期植物：已装 %s（id %s）" % [recipe.get_display_name(), recipe.plant_type])
	return true


## 卸一株植物：摘卡 → 退出可选列表 → 清注册表 → 撤解锁
## （摘卡必须排在清注册表之前，理由见 `_remove_card()`；退出可选列表与摘卡谁先谁后都行）
func uninstall() -> void:
	if recipe == null:
		return
	var plant_type := recipe.plant_type
	_remove_card()
	AllCards.remove_selectable_plant(plant_type)
	Global.character_registry.clear_runtime_plant(plant_type)
	Global.global_game_state.lock_plant(plant_type)
	Log.info("运行期植物：已卸 %s（id %s）" % [recipe.get_display_name(), plant_type])
	recipe = null


## 把这株植物登记进「可选植物列表」（= 它进选卡界面，见 `AllCards.add_selectable_plant`）
##
## ★ 注册 / 解锁都**不等于**可选：`install()` 做到的是「这株植物存在 + 有卡 + 已解锁」，
##   要不要让玩家在待选区里挑到它由模组自己说 —— 装完之后再写这一行就有了。
##   为什么要有这道门禁：模组注册的植物未必都想上选卡界面（只给关卡脚本 / 传送带发货的也有），
##   以前「注册了」就等于「可选」，两者分不开。
##   卸载时 Kit 会把它从列表里摘掉（见 `uninstall()`），模组不必自己撤。
##
## [return] 本次是否真的登记了（没装 / 已经在列表里返回 false）
func make_selectable() -> bool:
	if recipe == null:
		return false
	return AllCards.add_selectable_plant(recipe.plant_type)


## 解锁这株植物；每局开局补一次（读档会按存档重建 `curr_plant`，只装一次的话一读档就没了）
func unlock() -> void:
	if recipe == null:
		return
	Global.global_game_state.unlock_plant(recipe.plant_type)


## 当前装没装
func is_installed() -> bool:
	return recipe != null


#region 卡片
## 往 `AllCards` 的植物源目录里加一张卡：**追加在最后一个容器的末尾**
##
## 为什么是最后一个容器：编号是按 `[PlantCards, PlantCards2]` 这个顺序重排的，
## 插在中间会把它后面每一张卡的编号都挪一格（PlantCards2 里还挂着保龄球坚果那批卡）。
## 待选区的规矩也是「普通植物在最前面且顺序固定，调试模式 / 模组新增的追加在最后」
## （见 `AllCards.get_plant_types_in_choose_order()`）。
func _install_card() -> void:
	var directories := AllCards.all_plant_cards_parent_node_root
	if directories.is_empty():
		Log.error("运行期植物：拿不到植物卡片源目录，%s 没有卡位" % recipe.get_display_name())
		return
	var card: Card = CARD_SCENE.instantiate()
	card.name = str("CardRuntimePlant_", recipe.plant_type)
	card.card_plant_type = recipe.plant_type
	directories[-1].add_child(card)
	## 卡面推到帧末再画：**取帧要往场景树里挂临时容器**（AnimationFrameUtil），
	## 而 `install()` 多半是在某个 `_ready()`（如 `ModManager`）里被调的 —— 那一刻 root
	## 正忙着布置子节点，`add_child()` 会被拒，帧取不到。
	## 卡已经先挂进源目录、编号也重排过了，晚一帧补张脸不影响任何东西。
	_build_card_face.call_deferred()
	_card = card
	AllCards.rebuild()


## 画卡面：从配方指定的动画里取一帧定格；取不到就借另一张卡的脸
##
## ⚠️ 由 `_install_card()` **延迟到帧末**才调：这中间可能已经被 `uninstall()` 摘掉了，
## 所以开头先认一次「这张卡还是本 Kit 那张吗」。
func _build_card_face() -> void:
	if recipe == null or _card == null or not is_instance_valid(_card):
		return
	var card := _card
	var face := recipe.build_card_face()
	if face == null:
		face = _borrow_card_face()
	if face == null:
		## 卡面一空，手持会直接报「卡片静态角色为空」拿不起来 —— 留一行 warn 好排查
		Log.warn("运行期植物：%s 的卡面没画出来（既没取到帧、也没借到脸）"
			% recipe.get_display_name())
		return
	card.character_static.add_child(face)


## 取帧失败时借用另一张植物卡的卡面形象（配方里 `card_face_fallback_plant`）
##
## ★ 借的是源卡 `CharacterStatic` **下面的那株植物**，不是 `CharacterStatic` 本身：
##   `CharacterStatic` 是卡内的挂点（card.tscn 里 `position = (24, 30)`），本函数的结果却要挂到
##   **新卡自己的** `CharacterStatic` 之下 —— 把带挂点的节点原样搬过去，两份挂点叠在一起，
##   卡面（含待选区种子包 / 出战卡槽 / 手持虚影）就整块往右下歪：明日方舟精英化的
##   种子包贴图偏移就是这么来的。只搬植物那一枝，结构就与手摆原版卡完全一致
##   （`CharacterStatic → PlantXXX → Body`），其它按 `get_child(0).scale = Vector2.ONE`
##   还原实际大小的地方（手持 / 整列虚影）也才认得出「第 0 个孩子就是植物」。
func _borrow_card_face() -> Node2D:
	if recipe.card_face_fallback_plant == PlantIds.NULL:
		return null
	var owner_card: Card = AllCards.all_plant_card_prefabs.get(recipe.card_face_fallback_plant, null)
	if owner_card == null or not is_instance_valid(owner_card.character_static):
		return null
	if owner_card.character_static.get_child_count() == 0:
		return null
	return owner_card.character_static.get_child(0).duplicate() as Node2D


## 摘卡并重排编号（**必须在清注册表之前**：重排时要按类型查冷却与阳光）
func _remove_card() -> void:
	if _card == null:
		return
	if is_instance_valid(_card):
		_card.get_parent().remove_child(_card)
		_card.queue_free()
	_card = null
	AllCards.rebuild()
#endregion
