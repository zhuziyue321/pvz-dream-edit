extends Node2D
class_name ZombiquariumScene
## 僵尸水族馆（Zombiquarium，迷你游戏第 8 关）的**入口场景** —— 玩法本体的一层壳
##
## 本体 `ZombiquariumManager` 只能在主游戏里跑：位置要按相机左上角对齐、产出的阳光要在
## `Suns` 层（z_index 4002）之下、胜负要交回关卡流程，这让它自己没法单独打开运行。
## 本场景把「有没有主游戏」这件事收在一处，本体不用知道自己被谁开着：
##
##   ① **关卡模式**：`minigame_08_zombie_aquarium.gd` 实例化本场景 → `add_child` 到 MainGameManager
##      → `init_zombiquarium(mg)`：阳光走出战卡槽、胜负回关卡流程（与加壳之前完全一致）。
##   ② **独立预览**：Godot 里直接运行本场景（选中它按 F6 / 右键 Run Current Scene）——
##      没人来初始化，一拍之后自动进 `init_standalone()`：没有主游戏，阳光由本体自带，
##      够自私地看动画、看数值、看胜负，不用先跳进第 8 关。
##
## 只有上面两个出口，关卡 script 与本体都不认识对方（见 ZombiquariumManager 头部注释）。

## 本关结束（true = 买下奖杯通关，false = 宠物僵尸全死光判负）
signal signal_finished(is_win: bool)

## 独立预览的文案（壳自己负责，不污染玩法本体）
const TIP_STANDALONE := "独立预览：没有主游戏，阳光走本场景自带的一份"
const RESULT_WIN := "通关：买下了奖杯"
const RESULT_LOSE := "失败：宠物僵尸全部饿死了"

@onready var manager: ZombiquariumManager = $Zombiquarium
@onready var standalone_hud: CanvasLayer = $StandaloneHud
@onready var sun_label: Label = $StandaloneHud/Hud/SunLabel
@onready var tip_label: Label = $StandaloneHud/Hud/TipLabel

## 是否已被外部（关卡脚本 / 独立预览）初始化
var _is_inited := false


func _ready() -> void:
	standalone_hud.visible = false
	manager.signal_finished.connect(_on_manager_finished)
	manager.signal_sun_value_changed.connect(_on_sun_value_changed)
	## 直接跑本场景时，此时还没人调 init_zombiquarium —— 上一帧之后再判要不要自动切独立预览
	_auto_standalone.call_deferred()


## 关卡模式入口：由关卡脚本在 add_child 到 MainGameManager 之后调用
func init_zombiquarium(main_game: MainGameManager) -> void:
	_is_inited = true
	standalone_hud.visible = false
	manager.init_zombiquarium(main_game)


## 独立预览入口：没有主游戏，本体自备阳光（见 ZombiquariumManager 头部「独立预览」）
func init_standalone() -> void:
	_is_inited = true
	standalone_hud.visible = true
	tip_label.text = TIP_STANDALONE
	manager.init_zombiquarium(null)
	Log.debug("僵尸水族馆：独立预览（没有主游戏，阳光由本体自带）")


## 玩法本体（探针 / 调试通道 / UI 转发用）
func get_manager() -> ZombiquariumManager:
	return manager


func _auto_standalone() -> void:
	if _is_inited:
		return
	init_standalone()


func _on_manager_finished(is_win: bool) -> void:
	signal_finished.emit(is_win)
	if standalone_hud.visible:
		tip_label.text = RESULT_WIN if is_win else RESULT_LOSE


func _on_sun_value_changed(sun: int) -> void:
	if standalone_hud.visible:
		sun_label.text = "阳光：%d" % sun
