extends RefCounted
class_name ZombieRuntimeKit
## 一只「运行期僵尸」的**卡片装 / 卸**：往 `AllCards` 插卡 + 画卡面 + 进已解锁名单，卸时反向全撤
##
## ★ 为什么要有这一层（与 `PlantRuntimeKit` 同一套理由）：`register_runtime_zombie()` 只让
##   「这只僵尸存在」，想让它在**选卡界面的僵尸卡页**里被选到还差三件事，每件都有坑：
##   · 插卡之后必须 `AllCards.rebuild()`（编号按源目录节点顺序算，不重排新卡没有编号）；
##   · **卡面不能照植物那样从场景取帧**：热注册僵尸是「本体场景 + 脚本」，桶的贴图 / 防具是脚本
##     在 `build_runtime_parts()` 里换的，`AnimationFrameUtil.create_frame_node()` 会先把脚本剥掉
##     —— 取回来的一定是本体那张铁桶脸。必须让这只僵尸先真的活一次（进树走 `ready_show()`），
##     再把它身上那棵**已经换好贴图**的 `Body` 摘下来当卡面；
##   · 取形象要往场景树里挂临时容器，`_ready()` 里挂不进去 → 推到帧末；
##   · 待选区只点亮「已解锁名单」（`GlobalGameState.curr_zombie`）里的僵尸，而**读档会照存档重建
##     那份名单** → 解锁要每局补一次（`on_level_para_ready()`，它在卡槽建成之前）；
##   · 撤销时**先摘卡再注销僵尸**：重排编号要按类型查冷却与阳光，僵尸先注销了会查不到。
##
## 用法（见 `mods_builtin/more_armor/more_armor_mod.gd`）：
## ```gdscript
## var _kit := ZombieRuntimeKit.new()
##
## func install() -> void:                    ## 僵尸先自己注册好（ZombieRuntimeRecipe）
## 	_kit.install(recipe.zombie_type)
##
## func on_level_para_ready(_main_game) -> void:
## 	_kit.unlock()                            ## 每局补一次解锁
##
## func uninstall() -> void:
## 	_kit.uninstall()                         ## 先摘卡，再注销僵尸
## ```
##
## ⚠️ 一个 Kit 管一只僵尸：要装三只就 new 三个。
## 僵尸卡页本身只在「僵尸卡可用」时生成（总开关 or 控制台「调试模式」，见
## `GlobalGameState.is_zombie_card_enabled()`）—— 本 Kit 只管「有这张卡」，不管那页出不出。
##
## 关联：[僵尸热注册](../../../../docs/参考存档/僵尸热注册.md) §7 ｜ `PlantRuntimeKit` ｜ `ZombieRuntimeRecipe` ｜
## `CharacterShowFactory` ｜ `AnimationFrameUtil` ｜ `AllCards`

## 卡片模板：运行期插进 `AllCards` 的源目录
var CARD_SCENE := AssetRegistry.get_scene("res://src/ui/card/card.tscn")

## 卡面取僵尸身上哪一枝：**只留 `Body`**（与 `all_cards.tscn` 里那 27 张手摆卡面同一口径 ——
## 那批卡面就是 `CharacterStatic → ZombieXXX → Body → …` 一棵纯精灵树，血条 / 组件容器都在外面）
const BODY_PATH := ^"Body"
## 卡面形象的缩放与落点（照 `all_cards.tscn` 里僵尸卡面那一层写：绝大多数是 0.3 / (2,17)）
const FACE_SCALE := Vector2(0.3, 0.3)
const FACE_POSITION := Vector2(2, 17)

## 当前装着的僵尸（没装 = Null）
var zombie_type: StringName = ZombieIds.NULL
## 插进源目录的那张卡（卸的时候摘掉）
var _card: Card = null


## 装一只僵尸的卡片：插卡 → 解锁
## [param new_zombie_type] 已注册的僵尸 id（热注册的或内置的都行）
## [return] 这只僵尸没注册 / 拿不到卡片源目录返回 false
func install(new_zombie_type: StringName) -> bool:
	if not Global.character_registry.has_zombie(new_zombie_type):
		Log.error("运行期僵尸卡：%s 还没注册，先注册再装卡片" % str(new_zombie_type))
		return false
	zombie_type = new_zombie_type
	_install_card()
	unlock()
	Log.info("运行期僵尸卡：已装 %s" % str(zombie_type))
	return true


## 卸一只僵尸的卡片：摘卡 → 撤解锁（顺序见类注释：摘卡要在注销僵尸之前）
func uninstall() -> void:
	if zombie_type == ZombieIds.NULL:
		return
	_remove_card()
	_lock()
	Log.info("运行期僵尸卡：已卸 %s" % str(zombie_type))
	zombie_type = ZombieIds.NULL


## 每局补一次解锁：读档会照存档重建 `curr_zombie`，只装一次的话一读档这张卡就又暗了
func unlock() -> void:
	if zombie_type == ZombieIds.NULL:
		return
	var curr_zombie := Global.global_game_state.curr_zombie
	if not curr_zombie.has(zombie_type):
		curr_zombie.append(zombie_type)


## 当前装没装
func is_installed() -> bool:
	return zombie_type != ZombieIds.NULL


## 撤解锁：把这只僵尸从「已解锁」名单里摘掉（关掉模组时不再出现在待选区）
func _lock() -> void:
	if zombie_type == ZombieIds.NULL:
		return
	Global.global_game_state.curr_zombie.erase(zombie_type)


#region 卡片
## 往 `AllCards` 的僵尸源目录里加一张卡：**追加在最后一个容器的末尾**
##
## 为什么是最后一个容器：编号是按 `[ZombieCards, ZombieCards2]` 这个顺序重排的，
## 插在中间会把它后面每张卡的编号都挪一格（僵王的 card_id 还接在最后一张僵尸卡之后）。
func _install_card() -> void:
	var directories := AllCards.all_zombie_cards_parent_node_root
	if directories.is_empty():
		Log.error("运行期僵尸卡：拿不到僵尸卡片源目录，%s 没有卡位" % str(zombie_type))
		return
	var card: Card = CARD_SCENE.instantiate()
	card.name = str("CardRuntimeZombie_", zombie_type)
	card.card_zombie_type = zombie_type
	directories[-1].add_child(card)
	## 卡面推到帧末再画：**取形象要往场景树里挂临时容器**，而 `install()` 多半是在某个
	## `_ready()`（如 `ModManager`）里被调的 —— 那一刻 root 正忙着布置子节点，
	## `add_child()` 会被拒。卡已经先挂进源目录、编号也重排过了，晚一帧补张脸不影响任何东西。
	_build_card_face.call_deferred()
	_card = card
	AllCards.rebuild()


## 画卡面：从一只展示态僵尸身上摘 `Body` 那一枝
##
## ⚠️ 由 `_install_card()` **延迟到帧末**才调：这中间可能已经被 `uninstall()` 摘掉了，
## 所以开头先认一次「这张卡还是本 Kit 那张吗」。
func _build_card_face() -> void:
	if _card == null or not is_instance_valid(_card):
		return
	var face := create_card_face(zombie_type)
	if face == null:
		## 卡面一空，手持会直接报「卡片静态角色为空」拿不起来 —— 留一行 warn 好排查
		Log.warn("运行期僵尸卡：%s 的卡面没画出来（%s 下没有 %s）"
			% [str(zombie_type), str(zombie_type), str(BODY_PATH)])
		return
	_card.character_static.add_child(face)


## 取一只僵尸的卡面形象：让它先活一次（进树走 `ready_show()`，脚本在这一步换好贴图与防具），
## 再把 `Body` 那一枝摘下来剥成纯精灵树
## [return] 没有这一枝 / 临时容器没挂进树时返回 null
static func create_card_face(new_zombie_type: StringName) -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		Log.error("运行期僵尸卡：取不到 SceneTree，%s 的卡面画不出来" % str(new_zombie_type))
		return null
	var holder := Node2D.new()
	holder.name = "ZombieCardFaceHolder"
	tree.root.add_child(holder)
	## root 正"忙着布置子节点"时 add_child 会被拒（多半是在某个 `_ready()` 里取的）：
	## 容器没进树 → 僵尸走不到 `_ready` → 贴图没换，取回来的是本体那张铁桶脸
	if holder.get_parent() == null:
		Log.error("运行期僵尸卡：临时容器没挂进场景树（别在 _ready() 里取卡面） " + str(new_zombie_type))
		return null
	var zombie := CharacterShowFactory.create_show_zombie(new_zombie_type, holder)
	if zombie == null:
		holder.free()
		return null
	var body := zombie.get_node_or_null(BODY_PATH) as Node2D
	if body == null:
		holder.free()
		return null
	## 摘下来再连容器一起释放：留下的这棵树不再有脚本、也不再进树
	zombie.remove_child(body)
	holder.free()
	AnimationFrameUtil.detach_scripts(body)
	AnimationFrameUtil.strip_nodes(body, _is_not_drawable)
	## 剥掉场景身份：不剥的话 `duplicate()` 会按原场景重新实例化，
	## 换过的贴图与摘掉的节点会一起"复活"（见 AnimationFrameUtil.detach_scene_identity）
	AnimationFrameUtil.detach_scene_identity(body)
	var wrapper := Node2D.new()
	wrapper.name = str(new_zombie_type)
	wrapper.position = FACE_POSITION
	wrapper.scale = FACE_SCALE
	wrapper.add_child(body)
	return wrapper


## 卡面只留画得出来的：播放器 / 动画树（会覆盖姿态）、碰撞体、计时器与任何非 CanvasItem
static func _is_not_drawable(n: Node) -> bool:
	return n is AnimationPlayer or n is AnimationTree or n is CollisionObject2D \
		or n is Timer or not (n is CanvasItem)


## 摘卡并重排编号（**必须在注销僵尸之前**：重排时要按类型查冷却与阳光）
func _remove_card() -> void:
	if _card == null:
		return
	if is_instance_valid(_card):
		_card.get_parent().remove_child(_card)
		_card.queue_free()
	_card = null
	AllCards.rebuild()
#endregion
