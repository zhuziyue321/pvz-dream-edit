extends Node2D
class_name ChocolateDrop
## 僵尸掉落的巧克力
##
## 原版口径(一代 PC):巧克力不在商店出售,杀了僵尸随机掉;买了蜗牛(Stinky the Snail)之前一块都不掉
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Chocolate)
##   "Randomly from killing zombies"、
##   "Chocolate will not appear until the player purchases Stinky the Snail"、
##   "It can be obtained in all game modes, with the exception of the Zen Garden itself"
##
## 掉落逻辑与金币 / 种子包一致(见 DropItemComponent.drop_chocolate / DIM_Chocolate / Coin):
##   僵尸死亡处 -> 抛物线弹出 -> 落地等玩家点击 -> 点开加一块巧克力库存
## 巧克力是消耗型花园工具(喂蜗牛 / 喂完美状态的植物),持有上限 ConstShop.TOOL_MAX_OWN_NUM

## 未被点击时自动消失的秒数(与礼物盒一致,见 Present)
@export var auto_free_time := 10.0
## 点开后提示文本停留的秒数
@export var tip_show_time := 2.0
## 抛物线飞行时间(与 Coin 同参数)
@export var duration := 1.0
## 抛物线的最大高度
@export var peak_height := 70.0

## 拾取提示(原版见 data/strings/lawn_strings.txt 的 ADVICE_FOUND_CHOCOLATE)
const TIP_FOUND_CHOCOLATE := "你找到了巧克力！把它喂给蜗牛吃，就能让蜗牛速度加快！"

## 是否已经拾取,避免自动收集与手动点击重复触发
var is_opened := false

var _tween: Tween = null

@onready var pick_up_glow: Sprite2D = $PickUpGlow
@onready var texture_button: TextureButton = $TextureButton


func _ready() -> void:
	texture_button.pressed.connect(_on_texture_button_pressed)
	## 拾取光晕呼吸,提示玩家可以点
	TweenUtil.breath_scale_loop(pick_up_glow)

	await get_tree().create_timer(auto_free_time).timeout
	if not is_opened:
		fade_and_delete()


## 抛物线弹出(与 Coin.launch 一致,relative_target 是相对当前位置的落点偏移)
func launch(relative_target: Vector2) -> void:
	_tween = TweenUtil.parabola_launch(self, relative_target, duration, peak_height)

	await _tween.finished
	_tween = null
	## 开启自动收集金币时落地即拾取(与金币 / 礼包 / 种子包一致)
	if Global.config_service.auto_collect_coin:
		_on_texture_button_pressed()


## 点开拾取:加一块巧克力库存 -> 弹提示 -> 淡出
func _on_texture_button_pressed() -> void:
	if is_opened:
		return
	is_opened = true
	SoundManager.play_other_SFX("prize")
	## 打断抛物线
	TweenUtil.kill_tween(_tween)
	_tween = null
	texture_button.queue_free()

	Global.global_game_state.add_garden_tool_num(GardenManager.E_GardenTool.Chocolate, 1)
	Global.save_service.save_now()

	var reminder_info: ReminderInformation = SceneRegistry.REMINDER_INFORMATION.instantiate()
	get_tree().current_scene.add_child(reminder_info)
	reminder_info._init_info([TIP_FOUND_CHOCOLATE], tip_show_time)

	var fade_tween := create_tween()
	fade_tween.set_parallel()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	fade_tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.5)
	await fade_tween.finished
	queue_free()


func fade_and_delete() -> void:
	TweenUtil.fade_out_and_free(self)
