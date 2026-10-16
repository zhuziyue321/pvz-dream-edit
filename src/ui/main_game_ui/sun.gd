extends Node2D
class_name Sun

@export var sun_value := 25

## 阳光存在时间
@export var exist_time:float = 10.0
var collected := false  # 是否已被点击收集
## 生产阳光移动的tween
var spawn_sun_tween:Tween

## 实体编号（与角色共用同一个分配器，全场唯一）
##
## 为什么要有：`get_instance_id()` 是进程内的，换个进程就对不上，也没法写进网络包。
## 联机要说清"哪一颗阳光"时，必须有两端一致的编号；单机不涉及，行为不变。
## 由主机下发生成的那一颗，入树之前先调 `assign_entity_id()`，这里就不再自动分配。
var entity_id:int = 0
## 这一颗从哪儿掉到哪儿（由生成方写入；联机下发时要带着这个落点，两端才落在同一处）
var spawn_target:Vector2 = Vector2.ZERO
## 掉这一趟用了多少秒（由生成方写入；联机下发时带着，两端的下落动画才一样快）
var spawn_fall:float = 0.0


## 记下**"弹起来再落下"**这一趟的落点与用时
##
## 四处生成点用同一套表现（向日葵产、禅境花园的宠物、宝石迷阵、锤子小游戏）：
## 先弹起 `rise`，再落下 `fall`，横向随机偏 `offset_x`，全程 `duration` 秒。
## 落点 = 起点 + (offset_x, rise + fall) —— 把这几个数收在这里，
## 免得四处各抄一遍"净位移是 +30、用时 0.9 秒"，改一个忘三个。
func mark_pop_up(offset_x: float, rise: float = -15.0, fall: float = 45.0, duration: float = 0.9) -> void:
	spawn_target = position + Vector2(offset_x, rise + fall)
	spawn_fall = duration

func _ready() -> void:
	if entity_id == 0:
		entity_id = Character000Base.take_next_entity_id()
	_sun_scale(sun_value)
	## 启动一个10秒定时器
	await get_tree().create_timer(exist_time, false).timeout

	# 如果还没被点击收集，自动销毁
	if not collected and is_instance_valid(self):
		_start_fade_out()

func init_sun(curr_sun_value:int, pos:Vector2):
	sun_value = curr_sun_value
	position = pos

func _sun_scale(new_sun_value:int):
	var new_scale = new_sun_value/25.0
	scale = Vector2(new_scale,new_scale)

## 指定实体编号：客户端收到主机的生成消息后、入树之前调用（`_ready()` 会跳过自动分配）
func assign_entity_id(new_id: int) -> void:
	entity_id = new_id


func _on_button_pressed() -> void:
	## 统一先过玩家操作上报口：被接管时（联机客户端）这一下只是**请求**，本地不动
	## （见 `GlobalUtils.submit_player_action`）
	if GlobalUtils.submit_player_action(GlobalUtils.E_PlayerAction.PickSun, [self]):
		return
	collect()


## 把这一颗收走（拾取的公共入口：按钮 / 自动收集 / 联机重放都走这里，**不过闸门**）
func collect() -> void:
	if spawn_sun_tween:
		spawn_sun_tween.kill()

	if collected:
		return  # 防止重复点击

	collected = true  # 设置已被收集
	var target_position = Vector2()
	SoundManager.play_other_SFX("points")
	if is_instance_valid(GameContext.curr_main_game):
		if is_instance_valid(GameContext.curr_main_game.marker_2d_sun_target):
			## 出战卡槽在canvaslayer中，位置和摄像头位置有偏移
			target_position = GameContext.curr_main_game.marker_2d_sun_target.global_position + GameContext.curr_main_game.camera_2d.global_position
		else:
			target_position = GameContext.curr_main_game.marker_2d_sun_target_default.global_position

		EventBus.push_event(ConstEventName.ADD_SUN_VALUE, [sun_value])

	var tween:Tween = get_tree().create_tween()
	# 将节点从当前位置移动到(100, 200)，耗时0.5秒
	tween.tween_property(self, "global_position", target_position, 0.3).set_ease(Tween.EASE_OUT)
	$Button.queue_free()
	await tween.finished
	## 到达位置，变透明
	tween = create_tween()
	tween.set_parallel()
	tween.tween_property(self, "modulate:a", 0, 0.5)
	await tween.finished
	queue_free()


func _start_fade_out() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)  # 🌫️ 1秒淡出
	tween.finished.connect(func():
		if not collected and is_instance_valid(self):
			self.queue_free()
	)

func on_sun_tween_finished():
	if Global.config_service.auto_collect_sun:
		_on_button_pressed()
