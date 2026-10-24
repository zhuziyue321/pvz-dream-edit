extends RefCounted
## PVZ2 ↔ 模组「PAM 动画播放器」的桥：把播放器脚本挂到节点上、把素材按**当前加载根**读出来
##
## ★ 为什么要有这一层，而不是在场景里 `preload("res://mods_builtin/pam/...")`：
##   模组有两个加载根（`user://mods/` 优先、`res://mods_builtin/` 兜底），而 `.tscn` 里的
##   `res://` 脚本 / 贴图路径是**写死的绝对路径** —— 玩家把 pvz2 拷进 `user://mods/` 之后，
##   它就会去指 `res://` 里那份（可能是旧版、也可能因为没装而根本不存在）。
##   所以这里统一改走 `ModManager.get_mod_asset_path()` / `load_mod_asset()`：
##   **谁在生效就从谁的目录读**，与模组放在哪个根无关。
##
## ★ 用法（战斗植物一株就三处）：
##   1. `character_ready()` 里 `PamBridge.attach(...)` 把 `Body/<Xxx>Anim` 那个空 Node2D
##      变成播放器（脚本 + bin + 贴图 + 装扮黑名单 + 摆位），返回是否成功；
##   2. `ready_norm_signal_connect()` 里连它的信号（`animation_finished` / `loop_completed` /
##      `state_frame_changed`）—— 播放器不是全局类，**变量声明成无类型**再调（`var _anim`），
##      静态类型写成 `Node2D` 会编译不过「Node2D 没有 set_state()」；
##   3. 配方里 `build_card_face()` 用 `create_static_frame()` 造定格节点（PAM 路线没有
##      `AnimationPlayer`，通用 `AnimationFrameUtil` 取帧会得到一棵空树）。
##
## ★ 贴图为什么由这里塞（`texture_override`）：`.pam.bin` 里内嵌的贴图路径是**烘焙时**写的
##   `res://` 绝对路径，运行时同样不可靠。这里按**本模组**的加载根读好贴图交给播放器，
##   播放器就不再读 bin 里的路径（口径见 `pam/runtime/pam_animator.gd` 的 `texture_override`）。

## 播放器脚本相对「PAM 动画播放器」模组目录的路径
const ANIMATOR_REL_PATH := "runtime/pam_animator.gd"
## 定格渲染器（卡面 / 图鉴）相对路径
const STATIC_FRAME_REL_PATH := "runtime/pam_static_frame.gd"


## 取「PAM 动画播放器」模组里某个脚本（拿不到给 null 并打一行 error）
##
## ⚠️ 用 `load()` 而不是 `preload()`：路径要到运行时才知道（取决于加载根），
##    而且引擎会自己按路径缓存脚本资源，重复调用不会再解析一次。
static func _load_player_script(rel_path: String) -> Script:
	var path: String = ModManager.get_mod_asset_path(ModIds.PAM, rel_path)
	if not ResourceLoader.exists(path):
		Log.error("PVZ2：取不到 PAM 播放器脚本 ", path,
			"（模组「PAM 动画播放器」没装 / 没启用？PVZ2 依赖它）")
		return null
	var resource: Resource = load(path)
	if resource is Script:
		return resource as Script
	Log.error("PVZ2：PAM 播放器脚本不是 Script：", path)
	return null


## 把 `anim_node`（场景里的空 Node2D）变成 PAM 播放器并立刻加载
##
## [param bin_rel_path] 相对**本模组**目录的 `.pam.bin`
## [param atlas_rel_path] 相对**本模组**目录的图集 png
## [param pivot_offset] 画布中心 → 脚下 的补偿（`(0, -45)` 表示地面线在画布 y=240）
## [param scale_value] 整株缩放（格子 76×95 的参照，见各株场景注释）
static func attach(anim_node: Node2D, bin_rel_path: String, atlas_rel_path: String,
		hidden_parts: Array[String], oneshot_states: Array[String],
		pivot_offset: Vector2, scale_value: float) -> bool:
	if not is_instance_valid(anim_node):
		Log.error("PVZ2：动画挂点为空（场景里少了 Body/<Xxx>Anim？）")
		return false
	var script := _load_player_script(ANIMATOR_REL_PATH)
	if script == null:
		return false

	## ⚠️ 顺序不能反：`set()` 只对**已经挂上脚本**的节点生效（空 Node2D 上设 `binary_path`
	##    之类的属性不会报错，只是静默丢掉，症状是「节点挂上了但什么都没发生」）
	anim_node.set_script(script)

	var atlas: Resource = ModManager.load_mod_asset(ModIds.PVZ2, atlas_rel_path)
	if atlas is Texture2D:
		anim_node.set("texture_override", atlas as Texture2D)
	else:
		Log.error("PVZ2：读不到图集 ", atlas_rel_path, "（这条只能靠 bin 里内嵌的 res:// 路径兜底）")

	anim_node.set("hidden_parts", hidden_parts)
	anim_node.set("oneshot_states", oneshot_states)
	anim_node.set("pivot_offset", pivot_offset)
	anim_node.scale = Vector2(scale_value, scale_value)

	## ⚠️ 脚本是**进树之后**才挂上去的（场景里不能写死路径，见文件头）——
	##    这样不会自动跑一次 `_ready()`，所以 `_process` 与 `load_bin()` 都得手动来：
	##    少了 `set_process(true)` 的表现是「画出了第一帧，然后一动不动」，不报任何错。
	anim_node.set_process(true)
	var bin_path: String = ModManager.get_mod_asset_path(ModIds.PVZ2, bin_rel_path)
	if not anim_node.call("load_bin", bin_path):
		Log.error("PVZ2：加载 PAM 失败：", bin_path)
		return false
	return true


## 造一个**定格**在 [param state] 第 0 帧的播放器节点（卡面 / 图鉴用）
##
## 不入树：调用方自己 `add_child()`。两层缩放的用意与本体手摆卡面一致 ——
## 外层由配方设（`card_face_scale`），内层是本株在场上那层 [param scale_value]。
static func create_static_frame(bin_rel_path: String, atlas_rel_path: String,
		hidden_parts: Array[String], pivot_offset: Vector2, scale_value: float,
		state: String = "idle") -> Node2D:
	var script := _load_player_script(STATIC_FRAME_REL_PATH)
	if script == null:
		return null

	var node := Node2D.new()
	node.name = "PAMStaticFrame"
	## 先挂脚本再 `set()`（见 `attach()` 里那条关于顺序的说明）
	node.set_script(script)

	var atlas: Resource = ModManager.load_mod_asset(ModIds.PVZ2, atlas_rel_path)
	if atlas is Texture2D:
		node.set("texture_override", atlas as Texture2D)
	node.set("hidden_parts", hidden_parts)
	node.set("pivot_offset", pivot_offset)
	node.set("static_state", state)
	node.scale = Vector2(scale_value, scale_value)
	var bin_path: String = ModManager.get_mod_asset_path(ModIds.PVZ2, bin_rel_path)
	node.call("load_bin", bin_path)
	## 定格：脚本里 `_process()` 已经是空实现，这里再停一次进程（复制出去的卡面也不会动）
	node.call("set_state", state)
	node.set_process(false)
	return node
