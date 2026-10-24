extends DropItemBase
class_name Coin
## 掉落的钱（银币 / 金币 / 钻石）
##
## 生到死那套公共骨架（编号 / 点击 / 抛物线 / 超时淡出）在 `DropItemBase`，
## 这里只留钱自己的三件事：面值、飞向钱袋入账、被吸金石吸走。
##
## 由 `DIM_Coin` 实例化（战斗掉落）或花园植物产钱时推 `ConstEventName.CREATE_COIN`。

## 这一枚的面值
@export var coin_value := 50

@onready var anim_lib: AnimationPlayer = $AnimLib
@onready var button: TextureButton = $Button

## 收走时飞向的目标（钱袋，由 DIM_Coin 在实例化时给）
var coin_target_position := Vector2.ZERO

## 是否播动画（落地后停下开始播，飞行中不播）
var is_anim := false:
	set(value):
		is_anim = value
		if value:
			anim_lib.play("ALL_ANIMS")
		else:
			anim_lib.seek(0.0, true)  # 跳到第0秒（第一帧），并立即更新动画
			anim_lib.stop(true)

## 出生时刻（毫秒）：蜗牛选目标时要按"这枚钱还剩多久消失"加权
## （原版 StinkyPickGoal 用 mDisappearCounter 做 0~-40 的加权）
var spawn_ticks_msec := 0

func _ready() -> void:
	super()
	spawn_ticks_msec = Time.get_ticks_msec()


## 这枚钱已经存在了多少秒（见 DropItemBase.auto_free_time）
func get_exist_seconds() -> float:
	if spawn_ticks_msec <= 0:
		return 0.0
	return (Time.get_ticks_msec() - spawn_ticks_msec) / 1000.0


## 「已拾取」的老名字：花园的蜗牛与探针还在读 `is_get`，这里映射到基类的 `is_opened`
var is_get: bool:
	get:
		return is_opened
	set(value):
		is_opened = value


func on_pick_button_ready(pick_button: BaseButton) -> void:
	## 自定义光标模式下系统鼠标平时是藏起来的（器皿级别的道具自己跟着鼠标走），
	## 悬停到金币这类能点的 UI 上要露出来，玩家才点得动
	if is_instance_valid(GameContext.curr_main_game):
		GameContext.curr_main_game.bind_custom_cursor_hover(pick_button)


func on_launch_start() -> void:
	is_anim = false


func on_launch_end() -> void:
	is_anim = true


## 指定收走时飞向哪儿（钱袋，见 DIM_Coin.create_coin）
func setup(coin_target_pos:Vector2):
	coin_target_position = coin_target_pos


## 收走这一枚钱（玩家点击 / 蜗牛捡走 / 联机重放都走这里）
func pick() -> void:
	if is_opened:
		return
	is_opened = true
	SoundManager.play_other_SFX("coin")
	button.queue_free()
	## 打断抛物线
	kill_launch_tween()
	is_anim = false
	## 飞到钱袋 -> 入账 -> 淡出缩小删除
	fly_to_target(coin_target_position, _add_coin_value)


## **被蜗牛捡走**：表现与玩家点击完全一致（响一声、飞向钱袋、淡出缩小消失），
## 不再像吸金石那样被吸到吸引者身上（见 be_attract_gold_magnet）
func be_picked_by_snail() -> void:
	pick()


## 被吸金石吸引：吸到吸引者身上再入账（与钱袋那条路的区别只在于飞去哪儿）
func be_attract_gold_magnet(target_global_pos:Vector2):
	if is_opened:
		return
	is_opened = true
	## 打断抛物线
	kill_launch_tween()
	fly_to_target(target_global_pos, _add_coin_value)


## 入账（飞到目的地之后才记，与旧实现同一步伐）
func _add_coin_value() -> void:
	Global.global_game_state.coin_value += coin_value


## 老名字的入口（联机重放 / 花园那边在调）：一律走 `pick()`
func collect() -> void:
	pick()
