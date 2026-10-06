extends Node2D
class_name Coin

@export var coin_value := 50

@onready var anim_lib: AnimationPlayer = $AnimLib
@onready var button: TextureButton = $Button
## 金币存在时间
@export var coin_exist_time :float = 10

## 是否可以动画
@export var is_anim := false:
	set(value):
		is_anim = value
		if value:
			anim_lib.play("ALL_ANIMS")
		else:
			anim_lib.seek(0.0, true)  # 跳到第0秒（第一帧），并立即更新动画
			anim_lib.stop(true)

var coin_target_position := Vector2(0,0)

#抛物线
@export var gravity := -800.0         # 模拟重力
@export var duration := 1.0           # 飞行时间
@export var peak_height := 70.0      # 抛物线的最大高度（正值）
var tween: Tween = null

## 是否被获取
var is_get:bool = false

func setup(coin_target_pos:Vector2):
	coin_target_position = coin_target_pos

func _ready():
	## 信号连接
	button.pressed.connect(_on_button_pressed)
	## 自定义光标模式下系统鼠标平时是藏起来的（器皿级别的道具自己跟着鼠标走），
	## 悬停到金币这类能点的 UI 上要露出来，玩家才点得动
	if is_instance_valid(Global.main_game):
		Global.main_game.bind_custom_cursor_hover(button)

	await get_tree().create_timer(coin_exist_time, false).timeout
	fade_and_delete()


func fade_and_delete():
	TweenUtil.fade_out_and_free(self)


func launch(relative_target: Vector2):
	is_anim = false
	tween = TweenUtil.parabola_launch(self, relative_target, duration, peak_height)

	await tween.finished
	tween = null
	is_anim = true
	## 如果开启自动收集金币
	if Global.config_service.auto_collect_coin:
		button.pressed.emit()

func _on_interrupt_triggered():
	# 外部中断调用
	TweenUtil.kill_tween(tween)
	tween = null

## 点击金币
func _on_button_pressed() -> void:
	collect()


## 被蜗牛捡走：表现与玩家点击完全一致（响一声、飞向钱袋、淡出缩小消失），
## 不再像吸金石那样被吸到吸引者身上（见 be_attract_gold_magnet）
func be_picked_by_snail() -> void:
	collect()


## 收走这枚钱的统一表现（玩家点击 / 蜗牛捡走共用）：
## 响一声 → 飞向钱袋 → 入账 → 淡出缩小 → 删除
func collect() -> void:
	if is_get:
		return
	is_get = true
	SoundManager.play_other_SFX("coin")
	button.queue_free()
	##打断抛物线
	_on_interrupt_triggered()
	is_anim = false

	var click_tween:Tween = create_tween()
	click_tween.tween_property(self, "global_position", coin_target_position, 0.5)
	await click_tween.finished
	Global.global_game_state.coin_value += coin_value
	click_tween = create_tween()
	click_tween.set_parallel()
	click_tween.tween_property(self, "modulate:a", 0, 0.5)
	click_tween.tween_property(self, "scale", Vector2(0.5,0.5), 0.5)

	await click_tween.finished
	queue_free()


## 被吸金石吸引铁器
func be_attract_gold_magnet(target_global_pos:Vector2):
	if is_get:
		return
	is_get = true
	##打断抛物线
	_on_interrupt_triggered()

	var be_attract_tween:Tween = create_tween()
	be_attract_tween.tween_property(self, "global_position", target_global_pos, 0.5)
	await be_attract_tween.finished
	Global.global_game_state.coin_value += coin_value
	be_attract_tween = create_tween()
	be_attract_tween.set_parallel()
	be_attract_tween.tween_property(self, "modulate:a", 0, 0.5)
	be_attract_tween.tween_property(self, "scale", Vector2(0.5,0.5), 0.5)

	await be_attract_tween.finished
	queue_free()
