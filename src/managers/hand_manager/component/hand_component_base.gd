@abstract
extends ComponentNormBase
class_name HandComponentBase
## 手持物组件基类
##
## 手持物的「状态 + 行为 + 界面」全部收敛在组件内部，HandManager 只做三件事：
##   1. 注册挂在它下面的手持物组件（组件自己声明类型）
##   2. 把格子 / 输入事件派发给「当前手持组件」
##   3. 维护「手持中 ⇄ 空手」的切换（含启停、界面刷新、跨阶段清理）
##
## 新增一个手持物（锤子、手套、水壶…）只需要四步：
##   1. 在 E_HandComponentType 里加一个类型
##   2. 写一个继承本类的组件脚本，重写下面标了「子类重写」的函数
##   3. 在 HandManager 下加一个挂该脚本的 Node2D 节点
##   4. 组件自己在 _ready_component() 里订阅触发它的事件，或由外部调
##      hand_manager.take_hand(类型, 参数)
## HandManager 里不需要再改任何 match 分支。

## 手持物组件类型：HandManager 用它把「触发事件」映射到「组件」
enum E_HandComponentType {
	Null,		## 空手：兜底组件，必须存在，永远默认激活
	Character,	## 手持角色：植物卡片、僵尸卡片
	Shovel,		## 手持道具：铲子
	Glove,		## 手持道具：手套（把场上的植物搬到另一个格子，不铲除不重种）
	Hammer,		## 手持道具：锤子（锤僵尸玩法的锤子，见 LevelRuleHammerZombie / HandComponentHammer）
}

## 所属手持管理器，由 HandManager 在注册时注入
var hand_manager: HandManager
## 主游戏管理器（= hand_manager.main_game）
var main_game: MainGameManager
## 本局关卡参数（= hand_manager.game_para）
var game_para: ResourceLevelData


#region 生命周期（只由 HandManager 调用）
## 组件初始化：由 HandManager 注册时调用一次
func init_component(p_hand_manager: HandManager) -> void:
	hand_manager = p_hand_manager
	main_game = hand_manager.main_game
	game_para = hand_manager.game_para
	_ready_component()

## 子类初始化：重写这里，不要重写 _ready
func _ready_component() -> void:
	pass

## 本组件对应的手持类型（子类必须重写）
@abstract
func get_hand_component_type() -> E_HandComponentType

## 是否为「空手」兜底组件
func is_null_component() -> bool:
	return get_hand_component_type() == E_HandComponentType.Null

## 本组件当前是否拿在手上
func is_curr_hand() -> bool:
	return is_instance_valid(hand_manager) and hand_manager.curr_hand_component == self

## 进入手持态
## payload 由发起方决定（角色组件收到 Card，铲子组件不需要参数）；
## 返回 false 表示拒绝手持，HandManager 会退回空手
func enter_hand(_payload: Variant = null) -> bool:
	return true

## 退出手持态
## 必须幂等：可能在没有 enter_hand 的情况下被调用，也可能被连续调用两次
func exit_hand() -> void:
	pass

## 每帧：只有当前手持组件会收到
func hand_process() -> void:
	pass
#endregion


#region 格子事件（只由 HandManager 派发，只有当前手持组件会收到）
## 鼠标进入格子
func mouse_enter(_plant_cell: PlantCell) -> void:
	pass

## 鼠标移出格子
func mouse_exit(_plant_cell: PlantCell) -> void:
	pass

## 点击格子
## 返回 true 表示这次点击用完了手持物（HandManager 切回空手）；
## 返回 false 表示手持继续（例如点到了不能种植的格子）
func click_cell(_plant_cell: PlantCell) -> bool:
	return false
#endregion


#region 界面
## 刷新手持物相关界面
## HandManager 在「手持切换 / 组件启停 / 游戏阶段变化」时统一调用，
## 组件据此收敛自己那部分界面的显隐（例如铲子图标的显隐规则只写在铲子组件里）
func refresh_ui() -> void:
	pass
#endregion


#region 启停（复用 ComponentNormBase 的启停机制）
func enable_component(is_enable_factor: E_IsEnableFactor) -> void:
	super(is_enable_factor)
	refresh_ui()

func disable_component(is_enable_factor: E_IsEnableFactor) -> void:
	super(is_enable_factor)
	refresh_ui()
#endregion
