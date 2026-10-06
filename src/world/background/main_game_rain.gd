extends Control
class_name MainGameRain
## 雷雨表现:雨声 + 屏幕压暗 + 随机闪电(打雷时画面亮一下)。
## 只影响画面与音效,不参与出怪 / 卡槽 / 罐子等玩法逻辑。
## 是否开闪电由关卡资源的 is_lightning 决定(原版只有冒险 4-10 是雷雨夜),
## 由 MapBgAnimPool 实例化后调用 set_lightning() 打开。

## 压暗遮罩(常驻,闪电时短暂散开)
@onready var darkness: ColorRect = $Darkness
## 闪电白闪
@onready var flash: ColorRect = $Flash
@onready var lightning_timer: Timer = $LightningTimer

## 屏幕压暗的不透明度(雷雨夜,闪电时散开)
@export var darkness_alpha: float = 0.8
## 闪电白闪的最高不透明度
@export var flash_alpha: float = 0.85
## 两次闪电的间隔范围(秒)
@export var lightning_interval_range: Vector2 = Vector2(6.0, 14.0)

var is_lightning := false


func _ready() -> void:
	darkness.color.a = 0.0
	flash.color.a = 0.0
	if is_instance_valid(Global.main_game):
		SoundManager.play_rain_SFX()


func _exit_tree() -> void:
	SoundManager.stop_rain_SFX()


## 开关闪电:开启后屏幕压暗,并按随机间隔打雷
func set_lightning(enabled: bool) -> void:
	is_lightning = enabled
	lightning_timer.stop()
	darkness.color.a = darkness_alpha if enabled else 0.0
	flash.color.a = 0.0
	if enabled:
		_start_lightning_timer()


func _start_lightning_timer() -> void:
	lightning_timer.wait_time = randf_range(lightning_interval_range.x, lightning_interval_range.y)
	lightning_timer.start()


func _on_lightning_timer_timeout() -> void:
	strike()
	_start_lightning_timer()


## 打一次雷:黑暗散开 + 连闪两下,雷声在第一闪之后(光比声快)
func strike() -> void:
	if not is_lightning:
		return
	var tween := create_tween()
	tween.tween_property(flash, "color:a", flash_alpha, 0.06)
	tween.parallel().tween_property(darkness, "color:a", 0.0, 0.06)
	tween.tween_property(flash, "color:a", 0.0, 0.10)
	tween.tween_callback(SoundManager.play_thunder_SFX)
	tween.tween_property(flash, "color:a", flash_alpha, 0.06)
	tween.tween_property(flash, "color:a", 0.0, 0.16)
	tween.tween_property(darkness, "color:a", darkness_alpha, 0.35)
