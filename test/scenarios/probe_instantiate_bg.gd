extends RefCounted
## 探针：背景子场景能否独立实例化（不进主游戏场景也能 new 出来）。
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_instantiate_bg
## 校验点（BackgroundManager.init_background() 的运行期约定）：
##   1. 根节点必须是 Sprite2D —— 代码里 `bg_instance as Sprite2D`
##   2. 必须有 Home 节点且是 MainGameHome —— 房门 / 僵尸进家都挂在它下面
##   3. 屋顶图还要有 RoofSlope（MainGameSlope），平地没有

const PATHS: Array[String] = [
	"res://src/world/background/main_game_bg_front.tscn",
	"res://src/world/background/main_game_bg_pool.tscn",
	"res://src/world/background/main_game_bg_roof.tscn",
	"res://src/world/background/main_game_bg_front_5row.tscn",
]


func run(a) -> void:
	a.log("[BGINST] ===== 探针开始 =====")
	for p in PATHS:
		_probe_scene(a, p)
	a.log("[BGINST] ===== 探针结束 =====")
	a.quit_game()


func _probe_scene(a, path: String) -> void:
	var packed: PackedScene = load(path)
	if packed == null:
		a.log("   !! 背景场景加载失败: %s" % path)
		return
	var inst: Node = packed.instantiate()
	var home: Node = inst.get_node_or_null("Home")
	var slope: Node = inst.get_node_or_null("RoofSlope")
	a.log("   %s 根=%s Sprite2D=%s Home=%s isMainGameHome=%s RoofSlope=%s isMainGameSlope=%s" % [
		path.get_file(), inst.get_class(), str(inst is Sprite2D),
		str(home != null), str(home is MainGameHome),
		str(slope != null), str(slope is MainGameSlope)])
	inst.free()
