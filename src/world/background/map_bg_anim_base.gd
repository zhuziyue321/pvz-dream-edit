extends Node2D
class_name MapBgAnimBase
## 地图背景动画脚本基类 —— 一张地图一份子类，只做**表现**，不掺关卡逻辑。
##
## 主游戏只有一份场景（src/main/main_game_base.tscn），地图差异分两条路：
##   · 表现（泳池水面、浓雾、雨……）→ 本类子类，由 ResourceMapData.map_bg_script 指定，
##     BackgroundManager 在运行时 new 一个节点挂上脚本。
##   · 逻辑（格子几何、僵尸行、小推车、屋顶斜面坐标）→ 由各子管理器按 ResourceMapData 生成。
##
## 子类只重写自己需要的回调；不需要的回调留空即可（见 docs/参考存档/地图实现.md）。
## 挂载顺序：new 节点 → set_script → add_child → init_bg_anim()，
## 所以 _ready() 与 init_anim() 都能拿到 game_para / background / frontground。

## 背景层精灵（CanvasLayerBG/Background）：要盖在背景图上、但在格子之下的表现挂它下面
var background: Sprite2D
## 前景层（CanvasLayerFG/Frontground）：浓雾、雨这类要盖在格子之上的表现挂它下面
var frontground: Node2D
## 本局关卡参数（只读，表现需要的开关都从这里取）
var game_para: ResourceLevelData


## 由 BackgroundManager 装配完引用后调用，子类不要重写它，重写 init_anim()
func init_bg_anim(bg: Sprite2D, fg: Node2D, para: ResourceLevelData) -> void:
	background = bg
	frontground = fg
	game_para = para
	init_anim()


## 创建本地图的表现节点
func init_anim() -> void:
	pass


## 本地图的浓雾（没有雾的地图返回 null）。三叶草、灯笼草等要拿它做吹散 / 开洞。
func get_fog() -> Fog:
	return null


## 主游戏正式开始（红字结束、出怪之前）：浓雾进场等
func start_game() -> void:
	pass


## 多轮游戏进入下一轮：表现回退（浓雾退场等）
func start_next_round() -> void:
	pass
