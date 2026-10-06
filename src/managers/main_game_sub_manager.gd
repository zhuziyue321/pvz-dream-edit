@abstract
extends Node
class_name MainGameSubManager
## 主游戏场景内、挂在 Manager 等节点下的「场景子管理器」基类（需场景树与节点生命周期）。
## 主场景引用在 _enter_tree 中解析（自上而下进入树），早于本节点 _ready。

var main_game: MainGameManager
var game_para: ResourceLevelData

func _enter_tree() -> void:
	_get_main_game()

func _get_main_game() -> void:
	## 编辑器里整棵主游戏场景通常 owner 指向场景根，可作为快速路径
	if is_instance_valid(owner) and owner is MainGameManager:
		main_game = owner as MainGameManager
		game_para = main_game.game_para
		return
	## 运行时 new() 出来再 add_child 的子管理器（DaveSellManager / 结算、存档、失败流程子管理器）
	## 没有 owner：走全局引用，MainGameManager._enter_tree 已经把自己注册进 Global.main_game，
	## 且根节点 _enter_tree 先于子节点，所以这里一定能取到
	if Global.main_game != null:
		main_game = Global.main_game
		game_para = main_game.game_para
		return
	Log.error("MainGameSubManager: 根节点非 MainGameManager 且 Global.main_game 为空，节点: %s" % get_path())

@abstract
func init_manager() -> void
