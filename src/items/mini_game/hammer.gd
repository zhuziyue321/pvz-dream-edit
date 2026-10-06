extends Node2D
class_name Hammer
## 锤子 —— 玩家追着鼠标敲僵尸的手持道具（迷你游戏 15「打僵尸」/ 冒险 2-5「打地鼠」）
##
## **谁把我放进场**：常驻主场景的临时画布层（`CanvasLayerTemp` 的 RealHammer，与真铲子 / 真手套同层）。
## **谁决定我在不在玩家手上**：手持物组件 `HandComponentHammer` —— 它拿在手上我才显示、才跟鼠标、才能挥。
##   而那个组件由「锤僵尸」玩法规则启用，并被设成这两关的**空闲手持物**取代空手
##   （见 LevelRuleHammerZombie / HandManager.set_idle_hand_type）：
##   进 MAIN_GAME 自动在手上、种完植物后回到手上、非游玩阶段由本体收起。
##   本体不认识我这个类，也不需要为这两关留任何分支（硬约束 §1-8）。
## **系统鼠标**：由本体那套自定义光标开关统一显隐（见 MainGameManager.set_custom_cursor_mode）。

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var area_2d: Area2D = $Area2D
@onready var pow_effect: Sprite2D = $Pow

@export_group("锤击出阳光相关")
## 是否掉落阳光
@export var can_sun := true
## 掉落阳光概率
@export var pred_sun :int = 10
## 掉落阳光价值
@export var sun_value := 25
## 挥中僵尸后锤子进入冷却的秒数；0 = 不冷却
## （迷你游戏 15 / 冒险 2-5 默认连锤不设冷却；需要「一锤一冷却」的关卡把 cool_time 配成非 0，
##   冷却期间锤子从手上收起，冷却走完自动回到手上）
@export var cool_time := 0.0
## 锤子是否被拿在手上（由 HandComponentHammer 设置）
var is_used := false
## 剩余冷却（秒），<= 0 表示不在冷却
var _cool_remaining := 0.0


func _ready() -> void:
	_refresh_visible()


func _process(delta: float) -> void:
	## 冷却倒计时（不在手上也要继续走）
	if _cool_remaining > 0.0:
		_cool_remaining -= delta
		if _cool_remaining <= 0.0:
			_refresh_visible()
	if is_used:
		# 跟随鼠标移动
		position = get_global_mouse_position()


## 拿在手上 / 从手上放下：只由 HandComponentHammer 调（它是本关的空闲手持物，没有「手动收起」）
func set_is_used(value: bool) -> void:
	is_used = value
	_refresh_visible()


## 显示与否 = 拿在手上且不在冷却中；碰撞体跟着一起开关（不在手上就不做重叠检测）
func _refresh_visible() -> void:
	visible = is_used and _cool_remaining <= 0.0
	area_2d.monitoring = visible


func _unhandled_input(event: InputEvent) -> void:
	## 用 _unhandled_input 而不是 _input：点在 HUD 控件（卡槽/菜单）上的
	## 点击已被 GUI 消费，不会走到这里 —— 点 UI 不挥锤，点草坪才挥
	if not is_used or _cool_remaining > 0.0:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			hammer_once()
	## 右键不再收起锤子：锤子是这两关的空闲手持物，没有「放下」这回事

## 锤击一次
func hammer_once():
	animation_player.stop()
	animation_player.play("Hammer_whack_zombie")
	SoundManager.play_other_SFX("swing")

	hammer_zombie()

## 创建阳光
func spawn_sun(create_global_position:Vector2):
	var new_sun = SceneRegistry.SUN.instantiate()
	if new_sun is Sun:

		new_sun.init_sun(sun_value, Global.main_game.suns.to_local(create_global_position))
		Global.main_game.suns.add_child(new_sun)

		## 控制阳光下落
		var tween = create_tween()

		var center_y : float = -15
		var target_y : float = 45
		tween.tween_property(new_sun, "position:y", center_y, 0.3).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(new_sun, "position:y", target_y, 0.6).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		var tween2 = create_tween()
		tween2.tween_property(new_sun, "position:x", randf_range(-30, 30), 0.9).as_relative()

		tween2.finished.connect(new_sun.on_sun_tween_finished)

## 对僵尸造成锤子伤害
func hammer_zombie():
	##INFO:安卓适配 等待两物理帧后锤击，可以获取当前位置僵尸碰撞体，
	if OS.get_name() == "Android":
		position = get_global_mouse_position()
		await get_tree().physics_frame
		await get_tree().physics_frame
	var overlapping_areas = area_2d.get_overlapping_areas()
	## 如果为空，直接退出该函数
	if overlapping_areas.is_empty():
		return
	## 选择最左边的僵尸area
	var area_be_choosed :Area2D = null
	# 遍历所有重叠的区域
	for area in overlapping_areas:
		if area_be_choosed == null:
			area_be_choosed = area
		else:
			if area.global_position.x < area_be_choosed.global_position.x:
				area_be_choosed = area
	## 没有任何重叠区域、或 owner 不是僵尸（斜坡/道具 Area2D 也会触发）时直接返回，
	## 原来的直接强转会在下一行空引用崩溃
	if area_be_choosed == null:
		return
	var zombie_be_choosed := area_be_choosed.owner as Zombie000Base
	if zombie_be_choosed == null:
		return
	var global_position_zombie_be_choosed = zombie_be_choosed.global_position + Vector2(0,-100)

	## 锤子攻击僵尸,使用锤子攻击方法
	var zombie_is_death = zombie_be_choosed.be_attacked_hammer(1800)
	SoundManager.play_other_SFX("bonk")

	## 配了冷却的关卡：挥中后把锤子收起来（手上还是这把锤子，冷却走完自动回来）
	if cool_time > 0.0:
		_cool_remaining = cool_time
		_refresh_visible()

	## 锤击僵尸掉落阳光
	if zombie_is_death and can_sun:
		var curr_pred_value = randi_range(1,100)

		if curr_pred_value <= pred_sun:
			for i in range(3):
				spawn_sun(global_position_zombie_be_choosed)

	## 锤击僵尸特效
	var new_pow :Sprite2D= pow_effect.duplicate()
	new_pow.visible = true
	new_pow.global_position = global_position
	new_pow.z_as_relative = false
	new_pow.z_index = 951
	get_parent().add_child(new_pow)
	await get_tree().create_timer(0.5).timeout
	new_pow.queue_free()

