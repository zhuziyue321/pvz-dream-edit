extends Node2D
class_name DropItemBase
## **场上所有「点一下收走」的掉落物的公共基类**：钱 / 巧克力 / 种子包 / 礼包 / 阳光
##
## 以前这五类各自抄了一遍：编号分配、点击接线、拾取光晕、抛物线弹出、超时消失、自动拾取。
## 改一处要改五处，于是存在时长有了五个数、拾取入口有了两套（Coin.collect /
## ChocolateDrop._on_texture_button_pressed）、新增一种掉落物要动联机的三个 static 函数。
## 本类只管「一件掉落物从生到死」的**公共骨架**，业务尾巴（入账 / 提示 / 结算线）留在子类。
##
## 子类**不要重写 `_ready()`**（与 `Character000Base` / `ComponentNormBase` 同款约定，
## 见 docs/项目规范.md §1-3）：要插手就重写下面这几个钩子
##   `drop_ready()`            入树后的自家初始化（连私有节点之外的东西、设贴图 / 缩放）
##   `on_pick_button_ready()`  可点按钮已连好（要绑自定义光标 / 换贴图时用它）
##   `on_launch_start/end()`   抛物线起飞 / 落地那一刻（动画播放这类）
##   `pick()`                  **收走这一件的业务实现**（必写）
##   `has_launch_animation()`  本类有没有抛物线（没有 → 一出生就算「已落地」，礼包走这条）
##
## 拾取的两条入口要分清：
##   `request_pick()` —— **玩家点的那一下**：先过 `GlobalUtils.submit_player_action`，
##                       联机客户端被接管时只是发一个请求，主机放行了才会真走到 `pick()`
##   `pick()`         —— **收走这一件的动作本身**：联机主机重放、蜗牛捡钱这类「已经定了」的
##                       调用方直接调它，不再过闸门
##
## 关联：DropItemManager（生产） / DIM_Base（实例化） / SunSpawner（阳光的生成） /
##      docs/参考存档/掉落物说明.md

## 未被拾取时的默认存在秒数（各子类可 `@export` 覆盖，生产方也会按场景改）
const DEFAULT_EXIST_TIME := 10.0
## 拾取光晕的节点名：有就自动起呼吸动画，没有就算了（钱与阳光没有这一层）
const PICK_UP_GLOW_NODE := "PickUpGlow"
## 可点按钮的节点名：老场景两种命名并存（钱 / 阳光用 Button，其余用 TextureButton）
const PICK_BUTTON_NODES: Array[String] = ["Button", "TextureButton"]

## 未被拾取时自动消失的秒数
@export var auto_free_time := DEFAULT_EXIST_TIME
## 点开后提示文本停留的秒数
@export var tip_show_time := 2.0
## 抛物线飞行时间
@export var duration := 1.0
## 抛物线的最大高度（正值）
@export var peak_height := 70.0

## 实体编号：与角色共用 `Character000Base` 那份自增分配器（只要两端唯一即可，不参与玩法判定）
## 联机时"收走的是哪一件"要说清楚 —— 上行的是**编号**而不是数值
var entity_id:int = 0
## 抛物线落点（生成方写入）：联机下发时带着，两端才落在同一处
var spawn_target := Vector2.ZERO
## 这一件是**哪一种**（`ItemRegistry.E_DropKind`）：生成方写入，联机下发要说清"掉了哪一件"
var drop_kind:int = -1
## 是否已被拾取：自动拾取与手动点击共用，防重复触发（钱那边老名字叫 `is_get`，见 Coin）
var is_opened := false
## 是否是「本关结算线」上的掉落物（由 DropItemManager.mark_level_complete_drop 标记）
## true 表示玩家点开它之后本关就结束了：交给 CanvasLayerWhiteScreen 播收尾表演
var is_level_complete_drop := false

## 抛物线那一段 tween（拾取时要打断）
var launch_tween: Tween = null


func _ready() -> void:
	if entity_id == 0:
		entity_id = Character000Base.take_next_entity_id()
	_connect_pick_button()
	_start_pick_up_glow()
	drop_ready()
	## 没有抛物线的（礼包）一出生就算落了地，直接判一次"要不要自动拾取"
	if not has_launch_animation():
		_on_landed()
	_start_exist_timer()


#region 子类钩子（默认什么都不做，子类按需重写）
## 入树后的自家初始化（替代 `_ready()`）
func drop_ready() -> void:
	pass


## 可点按钮已经连上 `request_pick()`（要绑自定义光标 / 换按钮贴图时用）
func on_pick_button_ready(_button: BaseButton) -> void:
	pass


## 本类出生时有没有抛物线动画：
## true  → 落地那一刻才判自动拾取（钱 / 巧克力 / 种子包）
## false → 一出生就判（礼包没有抛物线；阳光的弹起由 SunSpawner 驱动）
func has_launch_animation() -> bool:
	return true


## 抛物线起飞 / 落地那一刻（动画播放这类）
func on_launch_start() -> void:
	pass


func on_launch_end() -> void:
	pass


## 落地（或一出生）时要不要自动收走：默认跟着「自动收集金币」那个开关
## 阳光另有一个「自动收集阳光」开关，由 SunSpawner 在落地回调里判（见 Sun.on_sun_tween_finished）
func should_auto_pick_on_landed() -> bool:
	return Global.config_service.auto_collect_coin


## 玩家点这一件时上报的**操作种类**（阳光与掉落物不是同一个口）
func get_player_action() -> int:
	return GlobalUtils.E_PlayerAction.PickDrop
#endregion


#region 拾取
## 玩家点了这一下：被接管时（联机客户端）只是**请求**，主机收走了两端才一起生效
func request_pick() -> void:
	if GlobalUtils.submit_player_action(get_player_action(), [self]):
		return
	pick()


## **收走这一件的业务实现**（子类必写）：入账 / 弹提示 / 播特效 / 收尾表现都在里面
## 已经判过 `is_opened` 的重复点击由基类挡在 `request_pick()` 之外，但重放也可能直接调 `pick()`
func pick() -> void:
	Log.warn("掉落物没有实现 pick()：" + str(get_script()))
#endregion


#region 生命周期
## 抛物线弹出：[param relative_target] 是**相对当前位置的落点偏移**
## 落点同时写进 `spawn_target`（联机下发要带着它，两端才落在同一处）
func launch(relative_target: Vector2) -> void:
	spawn_target = global_position + relative_target
	kill_launch_tween()
	launch_tween = TweenUtil.parabola_launch(self, relative_target, duration, peak_height)
	on_launch_start()
	await launch_tween.finished
	launch_tween = null
	on_launch_end()
	_on_landed()


## 打断抛物线（拾取 / 被吸走时都要先停住它，否则 tween 还在改位置）
func kill_launch_tween() -> void:
	TweenUtil.kill_tween(launch_tween)
	launch_tween = null


func _on_landed() -> void:
	if should_auto_pick_on_landed():
		pick()


func _start_exist_timer() -> void:
	await get_tree().create_timer(auto_free_time, false).timeout
	if is_opened or not is_instance_valid(self) or is_queued_for_deletion():
		return
	fade_and_delete()
#endregion


#region 公共表现
## 拾取后的收尾：飞向 [param target]（为 ZERO 时原地不动）→ 到点回调（入账这类）→ 淡出缩小 → 删除
func fly_to_target(target: Vector2, on_arrived := Callable(), fly_duration := 0.5) -> void:
	if target != Vector2.ZERO:
		var fly_tween := create_tween()
		fly_tween.tween_property(self, "global_position", target, fly_duration)
		await fly_tween.finished
	if not is_instance_valid(self):
		return
	if on_arrived.is_valid():
		on_arrived.call()
	fade_and_delete()


## 淡出 + 缩小后删除（超时消失与拾取收尾共用）
func fade_and_delete(_fade_duration := 0.5) -> void:
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	TweenUtil.fade_scale_out_and_free(self, _fade_duration)


## 指定实体编号：客户端收到主机的下发后、入树**之前**调用（`_ready()` 看到非 0 就不再自己分配）
func assign_entity_id(new_id: int) -> void:
	entity_id = new_id
#endregion


#region 接线
func _connect_pick_button() -> void:
	var button := get_pick_button()
	if button == null:
		return
	button.pressed.connect(request_pick)
	on_pick_button_ready(button)


## 本掉落物身上那个可点的按钮（老场景两种命名并存）；没有返回 null
func get_pick_button() -> BaseButton:
	for node_name: String in PICK_BUTTON_NODES:
		var node := get_node_or_null(node_name)
		if node is BaseButton:
			return node as BaseButton
	return null


func _start_pick_up_glow() -> void:
	var glow := get_node_or_null(PICK_UP_GLOW_NODE) as Sprite2D
	if glow != null:
		TweenUtil.breath_scale_loop(glow)
#endregion
