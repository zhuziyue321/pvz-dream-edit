extends RefCounted
class_name DamageModifier
## 伤害修饰器基类：在伤害**落到血量组件之前**插一手，可改值、可改模式、可整个取消。
##
## 这是伤害系统留给扩展的口子。目前本体**没有任何内置修饰器**（改前改后行为完全一致），
## 先把管线和接口立好，将来要加"某种子弹对某类僵尸加伤""护盾免疫一次""反伤"都只写一个类，
## 不用再动任何发起方与血量组件。
##
## 用法：
##   1. 写一个子类，重写 `modify()`；
##   2. 要改伤害就改 `info.amount` / `info.mode`，要取消就 `return false`；
##   3. 注册：`DamageSystem.register_modifier(我的修饰器.new())`（用完记得 `unregister_modifier`）。
##
## **角色身上要挂修饰器请用 `DamageModifierComponent`**（组件版，能跟着角色启用/禁用、
## 角色没了自动注销），不要自己手动注册 —— 手动注册的生命周期没人管，切关就泄漏。
##
## 三条纪律：
##   · `modify()` 里**不要再调 `DamageSystem.apply()`**（嵌套伤害）。真要触发别的伤害，
##     用 `DamageSystem` 的重入保护也要绕开，正确做法是改完 info 返回，让管线自己去结算；
##   · 修饰器是**全局生效**的：它看到的是全场每一次伤害，想只对某类角色生效就自己判
##     `info.target`（例如 `info.target is Zombie000Base`）；
##   · 伤害值**允许改成 0 或负**，管线会把负数夹成取消（`ZeroAmount`），不会倒扣血。

## 优先级：**数字大的先跑**。默认的 0 适合"独立加成"这类不依赖别人结果的修饰器。
##
## 需要叠加顺序时才调它：比如"先按来源过滤（HIGH），再算倍率（NORMAL），最后夹取上下限（LOW）"。
var priority: int = 0
## 是否生效（false 时 `DamageSystem` 直接跳过，连 `modify()` 都不调）
var is_active: bool = true


## 修饰一次伤害。
## [param info] 本次伤害的描述，**可以直接改它的 `amount` / `mode`**
## [return] true = 继续结算；false = 取消这次伤害（一滴血都不掉）
func modify(_info: DamageInfo) -> bool:
	return true
