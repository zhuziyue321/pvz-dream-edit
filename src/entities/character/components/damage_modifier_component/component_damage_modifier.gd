@abstract
extends ComponentNormBase
class_name DamageModifierComponent
## 角色身上的伤害修饰器（**组件版**，给扩展用）。
##
## 与 `DamageModifier`（裸修饰器）的区别在**生命周期**：
## 裸修饰器注册进 `DamageSystem` 后没人替它收尸，切关就留下一个失效引用；
## 本组件挂在角色节点下，注册 / 注销 / 启用 / 禁用全自动：
##   · `component_ready()` 时注册，`_exit_tree()` 时注销（角色被 free 不会泄漏）；
##   · 组件被 `disable_component()`（死亡 / 睡眠 / 魅惑…）时自动失效，不用在 `modify()` 里判。
##
## 用法（三步，不用改任何管理器）：
##   1. 写一个继承本类的脚本，重写 `modify()`；
##   2. 角色场景根节点下加一个挂该脚本的 Node2D，节点名 = 脚本类名同名的那个名字
##      （参照 `zombie_base.tscn` 里 CriticalValueComponent 的挂法）；
##   3. 完事。伤害会自动经过它，无需在角色脚本里写一行代码。
##
## ⚠️ 本组件是**抽象基类**，不要直接挂到场景上（挂了等于注册一个什么也不做的修饰器，
## 白付一次遍历开销）。要挂就挂它的子类。
##
## 把该节点从场景里删掉，角色仍能正常运行，只是失去该能力（K-01）。

## 优先级：数字大的先跑（同 `DamageModifier.priority`）
@export var priority: int = 0

## 真正注册进 `DamageSystem` 的包装体：把"组件当前是否启用"翻译成"修饰器是否生效"
var _modifier: _ComponentModifier


func component_ready() -> void:
	## 宿主角色走基类访问器（U-06）
	_modifier = _ComponentModifier.new(self, priority)
	DamageSystem.register_modifier(_modifier)


func _exit_tree() -> void:
	if _modifier != null:
		DamageSystem.unregister_modifier(_modifier)
		_modifier = null


## 修饰一次打到本角色 / 本角色所在方的伤害。
## [param _info] 本次伤害描述，可以直接改 `amount` / `mode`
## [return] true = 继续结算；false = 取消这次伤害
func modify(_info: DamageInfo) -> bool:
	return true


## 包装体：让"组件"能以"修饰器"的身份进 `DamageSystem` 的修饰器链。
##
## 为什么不直接让组件继承 DamageModifier：组件必须继承 `ComponentNormBase` 才能拿到
## 启用 / 禁用那一套（K-02），GDScript 没有多继承，只能包一层。
class _ComponentModifier extends DamageModifier:
	var _component: DamageModifierComponent

	func _init(component: DamageModifierComponent, modifier_priority: int) -> void:
		_component = component
		priority = modifier_priority

	## 组件被禁用 / 已释放时跳过：死亡后不该再有护盾、睡眠时不该再触发反伤
	func modify(info: DamageInfo) -> bool:
		if not is_instance_valid(_component) or not _component.is_enabling:
			return true
		return _component.modify(info)
