extends Node2D
class_name Stinky
## 禅境花园的蜗牛(原版名 Stinky the Snail)
## 商店 $3000 买断后才会在花园里出现(见 ConstShop.SNAIL_PRICE 与 GardenManager._init_stinky),
## 且只在初始花园(阳光房)露面:翻到蘑菇园 / 水族馆就藏在原地(见 GardenManager._refresh_stinky_visible)
## 行为口径(原版一代 PC):
##   蜗牛平时在花园里睡觉,点一下把它叫醒(lawn_strings: ADVICE_STINKY_SLEEPING);
##   醒着时锁住最近的钱爬过去,爬到钱边上就捡走,撑 WAKE_TIME 秒后重新睡着;
##   钱落在产出它的植物旁边(高处架子上也有),所以爬行范围覆盖整个花园(见 move_range);
##   喂一块巧克力立刻醒来并加速(ADVICE_FOUND_CHOCOLATE),加速持续 CHOCOLATE_TIME 秒
## 动画见 animation/garden/stinky:AnimationTree 的转移条件直接读本脚本的 is_sleep / is_turn,
## 播放速度读 parameters/TimeScale/scale(见 stinky.tscn 的 BlendTree)

## 爬行速度(像素/秒)
const CRAWL_SPEED := 26.0
## 吃了巧克力后的速度倍率
const CHOCOLATE_SPEED_SCALE := 2.0
## 盯上钱之后的速度倍率:爬过去捡钱比闲逛快,不然钱只存在 10 秒,慢吞吞根本追不上
## 取 3:花园里的钱落在产出它的植物旁边,架子上的钱要斜着爬很远(最远约 440 像素),
## 常速 26 像素/秒得爬 17 秒、倍率 2 也要 8.5 秒,钱早没了;倍率 3 是 78 像素/秒约 5.6 秒,
## 吃了巧克力再翻倍到 156 像素/秒,够在钱消失前爬到
const CHASE_SPEED_SCALE := 3.0
## 一次能醒多久(秒),到点重新睡着
const WAKE_TIME := 60.0
## 一块巧克力的加速时长(秒):吃完撑满一轮再睡
const CHOCOLATE_TIME := 60.0
## 转向动画时长(与 animation/garden/stinky/stinky_turn.tres 的 length 一致)
const TURN_ANIM_TIME := 0.583333
## 爬到离钱这么近就算"到旁边了",顺手捡走(二维距离,像素)
## 太小会蹭不到,太大就还是像隔空取物;同时也是"够得着"的判据(见 _is_coin_reachable)
const PICK_COIN_DISTANCE := 20.0
## 出生点相对屏幕竖直中心的偏移(像素,往下为正):屏幕水平正中、中心再往下这么多
const SPAWN_OFFSET_Y := 150.0
## 闲逛时上下挪的速度(像素/秒):纵向比横向慢一点才像在爬
const WANDER_Y_SPEED := 16.0
## 隔多久换一个纵向落脚点(秒)
const WANDER_Y_CD := 3.0
## 没有钱可捡时,隔多久随机换个方向(秒)
const IDLE_TURN_CD := 6.0
## 转向死区(像素):与钱的横向差小于它就维持原朝向,
## 否则蜗牛爬到钱的正下方后会在"左 / 右"之间反复抖着转身
const DIRECTION_DEAD_ZONE := 4.0
## 没锁着钱时,隔多久重新找一次钱(秒)
const FIND_COIN_CD := 0.3

## 蜗牛能爬的范围(全局坐标:整个花园,连架子上的植物那几层也要爬得上去)
## 花园里的钱落在产出它的植物旁边(见 DIM_Coin.create_coin),高处架子上的钱也要爬上去捡,
## 所以范围得罩住三种背景(温室 / 蘑菇园 / 水族馆)的全部植物格子:
## 植物格子 y 从约 110(温室最上排)到约 580(蘑菇园最下排),钱的落点比格子中心再低一点
@export var move_range := Rect2(30.0, 130.0, 745.0, 460.0)
## 点击判定矩形(相对蜗牛 position):蜗牛很小,判定放宽一点
@export var click_rect := Rect2(-50.0, -45.0, 95.0, 65.0)

## AnimationTree 的 advance_expression 直接读这两个变量(见 stinky.tscn 的状态机)
var is_sleep := true
var is_turn := false

## 当前朝向:1 向右 / -1 向左
var direction := 1
var wake_time_left := 0.0
var chocolate_time_left := 0.0

## 花园里掉钱的父节点(GardenManager 注入,见 GardenManager._init_stinky)
var drop_coin_parent: Node2D

## 当前锁定的钱:盯上最近的一枚就一直爬向它,
## 直到捡到手 / 钱自己消失 / 掉到爬不到的地方才换下一枚(见 _update_target_coin)
var target_coin: Coin

var _base_body_x := 0.0
var _flip_offset_x := 0.0
var _find_coin_cd := 0.0
var _idle_turn_cd := 0.0
## 闲逛时想挪到的那条"横线"(全局 y)
var _target_y := 0.0
var _wander_y_cd := 0.0
var _is_turning := false

@onready var body: Node2D = $Body
@onready var anim_tree: AnimationTree = $AnimationTree


func _ready() -> void:
	_base_body_x = body.position.x
	## 翻面时以身体包围盒中心为轴,否则蜗牛会横向跳一段
	_flip_offset_x = _calc_body_center_offset_x() * 2.0
	position = _clamp_in_move_range(_get_spawn_position())
	## 第一次随机掉头也要等一会儿:初值若为 0,蜗牛一醒就在原地翻个身
	_idle_turn_cd = randf_range(IDLE_TURN_CD * 0.5, IDLE_TURN_CD)
	## 出生时就把身体摆成当前朝向(转身动画只在换方向时才播)
	_apply_facing()
	_target_y = position.y
	_wander_y_cd = randf_range(WANDER_Y_CD * 0.5, WANDER_Y_CD)


func _process(delta: float) -> void:
	anim_tree.set("parameters/TimeScale/scale", get_speed_scale())
	if is_sleep:
		return
	## 醒着 / 加速的计时不能被"正在转身"打断:转身时 _move 是停的,
	## 若在这里提前返回,蜗牛每转一次身就把清醒时间冻结一次,永远到不了点睡觉
	wake_time_left -= delta
	chocolate_time_left = maxf(chocolate_time_left - delta, 0.0)
	if wake_time_left <= 0.0:
		sleep()
		return
	_update_target_coin(delta)
	## 爬行动画要跟着实际移动倍速走:追钱时位移是 CHASE_SPEED_SCALE 倍,
	## 动画不同步就变成"脚底下打滑"(转身时不移动,按转身动画自己的倍速)
	anim_tree.set("parameters/TimeScale/scale", get_move_speed_scale())
	if _is_turning:
		return
	_move(delta)
	_try_pick_coin()


## 睡着:不再爬也不再捡钱,再点一次可以叫醒
func sleep() -> void:
	is_sleep = true
	## 睡着时别还挂在转身动画上(状态机里转身只连回爬行,不连睡眠)
	is_turn = false
	wake_time_left = 0.0
	target_coin = null


## 叫醒(点击睡着的蜗牛 / 喂巧克力时都会走这里)
func wake_up() -> void:
	is_sleep = false
	wake_time_left = WAKE_TIME
	SoundManager.play_other_SFX(&"wakeup")


## 吃一块巧克力:立刻醒来并加速一段时间
func eat_chocolate() -> void:
	wake_up()
	chocolate_time_left = CHOCOLATE_TIME


## 吃了巧克力之后的倍速
func get_speed_scale() -> float:
	return CHOCOLATE_SPEED_SCALE if chocolate_time_left > 0.0 else 1.0


## 当前真正移动的倍速(巧克力 × 追钱):位移与爬行动画都按它算,两者才同步
func get_move_speed_scale() -> float:
	return get_speed_scale() * (CHASE_SPEED_SCALE if _is_target_valid() else 1.0)


## 该全局坐标是否点在蜗牛身上(喂巧克力 / 点击叫醒都用它判定)
## 不在初始花园时蜗牛是藏起来的(见 GardenManager._refresh_stinky_visible),那时点不到也喂不到
func is_hit(global_pos: Vector2) -> bool:
	if not visible:
		return false
	return Rect2(global_position + click_rect.position, click_rect.size).has_point(global_pos)


## 锁钱:已经盯上一枚且它还捡得到就一直锁着(中途冒出更近的也不换,免得来回改主意);
## 只有它进了口袋 / 自己消失 / 掉到爬不到的地方,才重新挑最近的一枚
func _update_target_coin(delta: float) -> void:
	if _is_target_valid():
		return
	if target_coin != null:
		target_coin = null
		## 刚丢目标就立刻重找一遍,别白等一个冷却
		_find_coin_cd = 0.0
	_find_coin_cd -= delta
	if _find_coin_cd > 0.0:
		return
	_find_coin_cd = FIND_COIN_CD
	target_coin = _find_nearest_coin()


## 锁着的这枚钱还追不追得:被捡走了 / 节点没了 / 掉到爬不到的地方都算失效
func _is_target_valid() -> bool:
	return (target_coin != null and is_instance_valid(target_coin)
		and not target_coin.is_get and _is_coin_reachable(target_coin))


func _find_nearest_coin() -> Coin:
	if drop_coin_parent == null or not is_instance_valid(drop_coin_parent):
		return null
	var nearest: Coin = null
	var nearest_distance := INF
	for child in drop_coin_parent.get_children():
		var coin := child as Coin
		if coin == null or coin.is_get or not _is_coin_reachable(coin):
			continue
		## 比的是"要爬多远":到落脚点的二维距离,谁的爬过去最快就先捡谁
		var distance := global_position.distance_to(_get_coin_stand_pos(coin))
		if distance < nearest_distance:
			nearest = coin
			nearest_distance = distance
	return nearest


## 这枚钱蜗牛够不够得着:爬行范围已覆盖整个花园,判据就是
## "离它最近的落脚点(钳进爬行范围后的位置)与它的距离还在拾取范围内"
## —— 掉在爬行范围外的钱(画面边上 / 太靠下),蜗牛爬不到它边上,既不去追也捡不走
func _is_coin_reachable(coin: Coin) -> bool:
	return _get_coin_stand_pos(coin).distance_to(coin.global_position) <= PICK_COIN_DISTANCE


func _move(delta: float) -> void:
	var chasing := _is_target_valid()
	## 盯上钱就加快脚步:钱只存在 10 秒,按闲逛的速度多半爬不到
	var speed := CRAWL_SPEED * get_move_speed_scale()
	var wanted_direction := direction
	if chasing:
		## 锁着钱:朝它的落脚点爬过去(横向纵向一起走,架子上的钱也照爬)。
		## 爬到边上(距离 <= PICK_COIN_DISTANCE)就由 _try_pick_coin 收走
		var to_coin: Vector2 = _get_coin_stand_pos(target_coin) - global_position
		if absf(to_coin.x) > DIRECTION_DEAD_ZONE:
			wanted_direction = 1 if to_coin.x > 0.0 else -1
		var distance := to_coin.length()
		## 一步不许迈过目标点,免得在钱边上左右来回蹭
		if distance > 0.0:
			global_position += to_coin / distance * minf(speed * delta, distance)
	else:
		target_coin = null
		## 没钱就随便逛:隔一阵子换换方向,隔一阵子换条横线落脚,不是只沿一条横线爬
		_idle_turn_cd -= delta
		if _idle_turn_cd <= 0.0:
			_idle_turn_cd = randf_range(IDLE_TURN_CD * 0.5, IDLE_TURN_CD)
			wanted_direction = -direction
		global_position.x += direction * speed * delta
		_wander_y_cd -= delta
		if _wander_y_cd <= 0.0:
			_wander_y_cd = randf_range(WANDER_Y_CD * 0.5, WANDER_Y_CD)
			_target_y = randf_range(move_range.position.y, move_range.position.y + move_range.size.y)
		global_position.y = move_toward(
			global_position.y, _target_y, WANDER_Y_SPEED * get_speed_scale() * delta)
	global_position = _clamp_in_move_range(global_position)
	## 撞到爬行范围边界:这一侧已经走不动了,必须掉头。
	## 原来这里撞边界时传的是原朝向,_start_turn 不变向 -> 蜗牛卡在边界反复播转身动画
	if _is_at_x_edge():
		wanted_direction = -direction
	if wanted_direction != direction:
		_start_turn(wanted_direction)


func _is_at_x_edge() -> bool:
	var min_x: float = move_range.position.x
	var max_x: float = move_range.position.x + move_range.size.x
	return (direction > 0 and global_position.x >= max_x) or (direction < 0 and global_position.x <= min_x)


func _clamp_in_move_range(global_pos: Vector2) -> Vector2:
	return Vector2(
		clampf(global_pos.x, move_range.position.x, move_range.position.x + move_range.size.x),
		clampf(global_pos.y, move_range.position.y, move_range.position.y + move_range.size.y))


## 转身:动画播完才翻面(转身动画的最后一帧已经是朝新方向的)
func _start_turn(new_direction: int) -> void:
	if _is_turning:
		return
	direction = new_direction
	_is_turning = true
	is_turn = true
	await get_tree().create_timer(TURN_ANIM_TIME / get_speed_scale()).timeout
	## 等动画的这段时间里可能已经退出花园(节点被释放),别再去动身体
	if not is_instance_valid(self):
		return
	_apply_facing()
	is_turn = false
	_is_turning = false


## 按当前朝向摆身体
## 素材默认朝左(触角 / 头在左、尾巴在右,见 stinky.tscn 里 Antenna 与 Tail 的 x),
## 所以向右爬(direction = 1)要翻面,向左爬才是素材原样
func _apply_facing() -> void:
	body.scale.x = float(-direction)
	body.position.x = _base_body_x + (_flip_offset_x if direction > 0 else 0.0)


## 爬到钱边上就把它捡走:表现与玩家点金币完全一致(见 Coin.collect),
## 不做"吸到蜗牛身上"那套(那是吸金石的效果)
func _try_pick_coin() -> void:
	if not _is_target_valid():
		target_coin = null
		return
	## 用真实二维距离判定:拿"钳进爬行范围后的落脚点"算的话,爬不到的钱会被隔空吸走
	if global_position.distance_to(target_coin.global_position) > PICK_COIN_DISTANCE:
		return
	target_coin.be_picked_by_snail()
	target_coin = null


## 要爬过去的位置:钱可能掉在爬行范围外(半空 / 角落),落脚点取钳进范围后离它最近的点
func _get_coin_stand_pos(coin: Coin) -> Vector2:
	return _clamp_in_move_range(coin.global_position)


## 进场景时的出生点:屏幕水平正中、竖直中心往下 SPAWN_OFFSET_Y 像素
## 不在整个爬行范围里随机取:范围已经扩到整个花园,随机可能把它扔到架子上悬着
func _get_spawn_position() -> Vector2:
	var view_size: Vector2 = get_viewport_rect().size
	return Vector2(view_size.x * 0.5, view_size.y * 0.5 + SPAWN_OFFSET_Y)


## 身体各部件包围盒中心相对 Body 原点的 x:翻面时以它为轴,蜗牛才不会横向跳位
func _calc_body_center_offset_x() -> float:
	var merged := Rect2()
	var has_rect := false
	for child in body.get_children():
		var sprite := child as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var sprite_rect := sprite.get_rect()
		merged = sprite_rect if not has_rect else merged.merge(sprite_rect)
		has_rect = true
	return merged.get_center().x if has_rect else 0.0
