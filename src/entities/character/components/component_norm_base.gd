@abstract
extends Node2D
class_name  ComponentNormBase
## 普通组件基类
"""
组件可以启用或禁用
"""

## 是否正在启用
var is_enabling := true
## 默认是否启用组件
@export var is_enable_default := true

## 影响节点是否启用的因素
enum E_IsEnableFactor{
	Default,	## 默认是否启用组件,只有角色不使用该组件时在检测器中禁用该组件
	InitType,	## 初始化状态类型（正常、展示、花园）
	Character,	## 角色本身特殊需要禁用组件(确保该条件不会冲突)
	MainGameProgress,	## 主游戏当前运行阶段
	Global,		## 全局禁用组件,追踪子弹全局检测组件使用
	Death,		## 死亡禁用组件
	Prepare,	## 准备（土豆雷）
	Sleep,		## 睡眠
	Scaredy,	## 害怕
	Jump,		## 跳跃
	Hypno,		## 魅惑重启节点
	Attack,		## 攻击(影响眨眼)
	Lose,		## 失去该组件(小丑爆炸匣子)
	Balloon,	## 气球在空中禁用攻击组件
	DownGround,	## 矿工在地下禁用攻击组件
	Garlic,		## 大蒜禁用攻击组件
	GameMode,	## 游戏模式，我是僵尸禁用生产组件
	HandItem,	## 手持物组件：关卡参数或游戏阶段不允许持有该手持物（如关卡没有铲子）
	Netplay,	## 联机：客户端的僵尸只渲染，判定交给主机（见 NetplayStateSync）
}

var is_enable_factors:Dictionary[E_IsEnableFactor, bool] = {}

func _ready() -> void:
	if not is_enable_default:
		disable_component(E_IsEnableFactor.Default)
	## 组件自己的初始化一律写 component_ready()，由本处统一调用（硬约束 1-3）
	component_ready()


## **组件的初始化入口** —— 子类要初始化请重写这个，**不要**重写 `_ready()`
##
## 为什么单独开一个钩子：`_ready()` 里这一步「场景配了 is_enable_default = false 就禁用组件」
## 是组件框架的条件；子类一旦重写 `_ready()` 又忘了 `super()`，这个条件就静默失效
## —— 表现为「某个植物明明在场景里关掉了组件，进游戏却还在跑」。
## 把它关在基类的 `_ready()` 里，子类再怎么重写都绕不过去。
##
## ⚠️ **重写本方法时第一行必须调 `super()`**（父类有重写时）
##
## 这是本钩子和 `_ready()` 最容易踩混的地方：
## `_ready()` 里写 `super()` 是**逐层级联**的 —— 子类 super → 父类 _ready → 祖类 _ready，每层都跑；
## 而 `component_ready()` 由基类 `_ready()` **只分派一次**（虚调用落到最派生的那个重写版本），
## 中间各层的实现**不会自动执行**。所以把 `_ready()` 改名为 `component_ready()` 时，
## 原样保留的 `super()` 不能删，删了就等于把父类的初始化整段丢掉。
##
## 漏调的症状很隐蔽：不报错、不崩溃，只是「某个角色不攻击 / 不响应」，
## 因为父类那条链上往往正是「连上检测组件的 signal_can_attack」这类接线代码
## （见 AttackComponentBase.component_ready() → detect_component_init()）。
##
## 注意执行时机：Godot 先跑子节点的 `_ready()` 再跑父节点，
## 所以**这里访问宿主的 `@onready` 成员可能还是 null**（(见 component_attack_zom_botany_pea.gd)
## 那条注释就是踩过这个坑）。要拿宿主的东西请用 `owner` 访问器，别直接读它的 `@onready` 变量。
func component_ready() -> void:
	pass


## 改变组件是否启用状态
func change_is_enabling(value:bool, is_enable_factor:E_IsEnableFactor):
	if value:
		enable_component(is_enable_factor)
	else:
		disable_component(is_enable_factor)

## 启用组件
func enable_component(is_enable_factor:E_IsEnableFactor):
	is_enable_factors[is_enable_factor] = true
	is_enabling = is_enable_factors.values().all(func(v): return v)

## 禁用组件
func disable_component(is_enable_factor:E_IsEnableFactor):
	is_enable_factors[is_enable_factor] = false
	is_enabling = false

## 修改速度
func owner_update_speed(_speed_product:float):
	pass


## 主场景访问器：组件需要的主场景能力一律走这里，**不要**直接写 Global.main_game。
##
## 为什么：组件直接取全局单例，等于绕开硬约束 1-2「组件只通过 owner / 信号 / 场景配置通信」
## —— 表面上没有 get_parent()，实际上把耦合换成了更隐蔽的全局依赖。
##
## **不要在本方法里转问 owner**：曾经写成 `owner as Character000Base` 再取宿主的访问器，
## 结果组件的 owner 一旦不是角色基类就静默返回 null —— 攻击组件因此拿不到 bullets 父节点，
## 表现为「植物不发射子弹」，且没有任何报错。主场景本来就是全局单例，直接取即可。
## 「当前这一局」的真相源在 GameContext（Global.main_game 只是它的转发，见 global.gd）。
func get_main_game() -> MainGameManager:
	return GameContext.curr_main_game
