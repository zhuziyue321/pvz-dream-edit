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
## 战利品上方弹跳箭头的节点名：有就自动起（原版那套，见 §「原版战利品表现」）
const PICK_UP_ARROW_NODE := "PickUpArrow"
## 可点按钮的节点名：老场景两种命名并存（钱 / 阳光用 Button，其余用 TextureButton）
const PICK_BUTTON_NODES: Array[String] = ["Button", "TextureButton"]

## 原版战利品闪光的周期秒数（原版 GetFlashingColor(counter, 75)：75 帧 @60fps = 1.25 秒）
const LEVEL_AWARD_FLASH_PERIOD := 1.25
## 原版闪光的灰度下限（原版 GetFlashingColor 的最小值 55 / 255）
const LEVEL_AWARD_FLASH_MIN := 55.0 / 255.0

## 未被拾取时自动消失的秒数
@export var auto_free_time := DEFAULT_EXIST_TIME
## 落地后要不要跟着「自动收集」那个开关被收走
## false = 只能玩家自己点（原版「从礼物里散出来的钱」就是这种：
## COIN_MOTION_FROM_PRESENT 不参与自动收集，见 PvZ-Portable Coin.cpp 的 TryAutoCollectAfterLevelAward）
@export var auto_pick_on_landed := true
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
## 「原版战利品表现」是否已经起了（闪光 + 弹跳箭头）
var is_level_award_effect_started := false
## 闪光那条循环 tween（拾取 / 超时消失时要打断，否则它跟淡出抢 modulate）
var _level_award_flash_tween: Tween = null


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
## `auto_pick_on_landed = false` 的那几件（散币）不受开关影响：只能玩家自己点
func should_auto_pick_on_landed() -> bool:
	if not auto_pick_on_landed:
		return false
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
	## 按掉落物种类补一次拾取特效（目前只有巧克力有）
	## —— 放在**基类**里而不是 ChocolateDrop 里：那个文件是 GBK 编码的老文件，
	##    改它容易把中文注释弄成乱码，基类这边是 UTF-8
	_play_kind_pick_fx()
	pick()


## 按掉落物种类补的那次拾取特效
## 原版：巧克力被点开时爆一蓬星火（`PARTICLE_PRESENT_PICKUP`，PvZ-Portable Coin.cpp:1134）
func _play_kind_pick_fx() -> void:
	if drop_kind == ItemRegistry.E_DropKind.Chocolate:
		play_present_pickup_fx()


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
	## 落地那一刻：原版在这时给关卡奖励挂上弹跳箭头（见 notify_loot_landed）
	notify_loot_landed()
	_on_landed()


## 打断抛物线（拾取 / 被吸走时都要先停住它，否则 tween 还在改位置）
func kill_launch_tween() -> void:
	TweenUtil.kill_tween(launch_tween)
	launch_tween = null


func _on_landed() -> void:
	if should_auto_pick_on_landed():
		pick()


func _start_exist_timer() -> void:
	## **<= 0 = 永不过期**（原版的关卡奖励就是这种：不点掉就不消失）
	if auto_free_time <= 0.0:
		return
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
	## 闪光在改 modulate，会跟淡出抢同一个属性 —— 先停掉
	stop_level_award_effects()
	TweenUtil.fade_scale_out_and_free(self, _fade_duration)


## 指定实体编号：客户端收到主机的下发后、入树**之前**调用（`_ready()` 看到非 0 就不再自己分配）
func assign_entity_id(new_id: int) -> void:
	entity_id = new_id
#endregion


#region 原版战利品表现（关卡奖励那套）
## **起原版「关卡奖励」那套表现**：周期闪光 + 上方弹跳箭头
##
## 原版出处（PvZ-Portable `src/Lawn/Coin.cpp`）：
##   · 闪光：`Coin::Draw` 里 `if (IsLevelAward() && !mIsBeingCollected) GetFlashingColor(mCoinAge, 75)`
##     —— 灰度在 55 ~ 255 之间走三角波，周期 75 帧（60fps → 1.25 秒）
##   · 箭头：落地那一刻挂上 `PARTICLE_AWARD_PICKUP_ARROW`（原版 pak/particles/AwardPickupArrow.xml），
##     种子包用 `PARTICLE_SEED_PACKET`（pak/particles/SeedPacket.xml），箭头部分一模一样
##
## 谁来起：`notify_loot_landed()` —— 战利品落到地上那一刻（抛物线结束 / 抛掷结束）
func start_level_award_effects() -> void:
	if is_level_award_effect_started:
		return
	is_level_award_effect_started = true
	_start_level_award_flash()
	_start_level_award_arrow()


## **停掉那套表现**：拾取 / 超时消失都要停 —— 闪光在改 modulate，跟淡出抢同一个属性
## （停了就不再来：这一件已经收尾了，别在它飞向屏幕中心时又闪起来）
func stop_level_award_effects() -> void:
	TweenUtil.kill_tween(_level_award_flash_tween)
	_level_award_flash_tween = null
	## 复位亮度但保留已有的淡出 alpha（别把正在淡出的东西拉回不透明）
	modulate = Color(1, 1, 1, modulate.a)
	var arrow := get_node_or_null(PICK_UP_ARROW_NODE) as LootPickupArrow
	if arrow != null:
		arrow.stop_bob()
		arrow.visible = false


## **战利品落到地上那一刻**：原版在这时给关卡奖励挂上弹跳箭头
## （原版 Coin::UpdateFall 里 `mHitGround` 那一支，`mNeedsBouncyArrow` 时挂粒子）
## 抛物线结束（launch）与抛掷结束（见 MgmRewardManager.throw_to）都会走到这里
func notify_loot_landed() -> void:
	## 已经被拾取的那一件就别再起表现了（它正在飞向屏幕中心）
	if is_level_complete_drop and not is_opened:
		start_level_award_effects()


## 战利品上方弹跳箭头的位置（相对战利品中心）
## 原版：战利品中心 + (宽/2, 高/2 - 60)（PvZ-Portable Coin.cpp:522-536）
## —— 注意这是**相对贴图中心**的：原版礼物盒的贴图画在中心上方 20 像素，箭头也同步上移 20，
## 两者相减正好是这个式子，所以本仓库的贴图居中画时直接套即可。
func get_level_award_arrow_offset() -> Vector2:
	var icon_size := get_level_award_icon_size()
	return Vector2(icon_size.x * 0.5, icon_size.y * 0.5 - 60.0)


## 战利品贴图的尺寸（决定箭头摆在哪）：默认是礼物盒 80x80
func get_level_award_icon_size() -> Vector2:
	return Vector2(80, 80)


## **拾取战利品时的一次性特效**：原版关卡奖励被点开时播一次星星爆裂
## （原版 `PARTICLE_STARBURST`，PvZ-Portable Coin.cpp:1220）
func play_level_award_pick_fx() -> void:
	var parent := get_parent()
	if parent == null:
		return
	if SceneRegistry.LOOT_STARBURST == null:
		return
	var fx := SceneRegistry.LOOT_STARBURST.instantiate() as LootStarburst
	if fx == null:
		return
	## 挂在**容器**里而不是战利品身上：战利品之后还要放大飞向屏幕中心，挂身上会被一起放大
	parent.add_child(fx)
	fx.global_position = global_position
	fx.play()


## **拾取「带提示的礼物」时的星火**：原版 `PARTICLE_PRESENT_PICKUP`
## （PvZ-Portable Coin.cpp:1071 / 1090 / 1104 / 1118 / 1134 / 1231 ——
##   花园植物礼包、迷你 / 解谜 / 生存模式解锁、巧克力、信件）
##
## 同样挂在**容器**里（理由见上：战利品之后还要放大）
func play_present_pickup_fx() -> void:
	var parent := get_parent()
	if parent == null:
		return
	if SceneRegistry.LOOT_PRESENT_PICKUP == null:
		return
	var fx := SceneRegistry.LOOT_PRESENT_PICKUP.instantiate() as LootPresentPickup
	if fx == null:
		return
	parent.add_child(fx)
	fx.global_position = global_position
	fx.play()


## **种子包被点开时那串僵尸头粒子**：原版 `PARTICLE_SEED_PACKET_PICKUP`
## （PvZ-Portable Coin.cpp:1238，原版是 AttachParticle 挂在掉落物身上）
##
## 这里挂在**种子包自己身上**（不是容器）：它要跟着种子包一起飞向屏幕中心。
## 种子包身上此时 modulate 已复位成白色（闪光在拾取时停掉了），粒子不会被一起变暗。
func play_seed_packet_pickup_fx() -> void:
	if SceneRegistry.LOOT_SEED_PACKET_PICKUP == null:
		return
	var fx := SceneRegistry.LOOT_SEED_PACKET_PICKUP.instantiate() as LootSeedPacketPickup
	if fx == null:
		return
	add_child(fx)
	fx.play()


## 闪光的循环 tween：灰度在 255（白）与 55（暗）之间线性来回（原版那个三角波）
func _start_level_award_flash() -> void:
	_level_award_flash_tween = create_tween()
	_level_award_flash_tween.set_loops()
	var half := LEVEL_AWARD_FLASH_PERIOD * 0.5
	var dim_color := Color(LEVEL_AWARD_FLASH_MIN, LEVEL_AWARD_FLASH_MIN, LEVEL_AWARD_FLASH_MIN, 1.0)
	_level_award_flash_tween.tween_property(self, "modulate", dim_color, half) \
		.set_trans(Tween.TRANS_LINEAR)
	_level_award_flash_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), half) \
		.set_trans(Tween.TRANS_LINEAR)


## 起上方的弹跳箭头（场景里没有那个节点就跳过）
func _start_level_award_arrow() -> void:
	var arrow := get_node_or_null(PICK_UP_ARROW_NODE) as LootPickupArrow
	if arrow == null:
		return
	arrow.position = get_level_award_arrow_offset()
	arrow.visible = true
	arrow.start_bob()
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
