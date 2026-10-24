extends Node
class_name ItemRegistry
## **场上物件（掉落物 / 小推车 / 罐子…）的「类型 -> 场景」注册表**：与 `CharacterRegistry` /
## `BulletRegistry` 同一层（硬约束 §1-4：类型映射一律走注册表，别散在业务代码里）
##
## 目前登记的是**战利品种类**：联机下发要说清「掉了哪一件」，光说"掉了个金币"分不出银币还是钻石，
## 所以每种掉落物有一个编号 `E_DropKind`，生成与重建都按它查场景
## （见 `DropItemManager.create_drop_of_kind` / `DIM_Base`）。
##
## 谁在用它：
##   DropItemManager.create_drop_of_kind() —— 照主机下发的数据重建同一件掉落物
##   DIM_Coin / DIM_Chocolate            —— 随机决定"掉哪一种"后按它取场景
##   NetplayDropSync                     —— 上报 / 下发掉落物的种类编号
##
## 加一种掉落物 = 这里加一个枚举值 + 加一行场景；本体不认识任何具体掉落物（硬约束 §1-8）。

## 掉落物的**种类**（联机下发要说清"掉了哪一件"，见 `DropItemManager.create_drop_of_kind`）
enum E_DropKind{
	Silver,		## 银币
	Gold,		## 金币
	Diamond,	## 钻石
	Chocolate,	## 巧克力
}

## 种类 -> 场景（res:// 绝对路径，硬约束 §1-5）
## ★ `static var`：值是 AssetRegistry 取用结果（函数调用），且取用方是 static 函数
static var DROP_SCENE_MAP: Dictionary = {
	E_DropKind.Silver: AssetRegistry.get_scene("res://src/items/drop/coin_silver.tscn"),
	E_DropKind.Gold: AssetRegistry.get_scene("res://src/items/drop/coin_gold.tscn"),
	E_DropKind.Diamond: AssetRegistry.get_scene("res://src/items/drop/coin_diamond.tscn"),
	E_DropKind.Chocolate: AssetRegistry.get_scene("res://src/items/drop/chocolate.tscn"),
}


## 这一类的场景；没登记时返回 null（调用方兜住，别把玩家卡在场上）
static func get_drop_scene(kind: int) -> PackedScene:
	return DROP_SCENE_MAP.get(kind, null) as PackedScene


## 这个编号有没有登记
static func has_drop_kind(kind: int) -> bool:
	return DROP_SCENE_MAP.has(kind)


## 钱那三种（银 / 金 / 钻）：吸金磁与联机重建要按"是不是钱"分堆
static func is_coin_kind(kind: int) -> bool:
	return kind == E_DropKind.Silver or kind == E_DropKind.Gold or kind == E_DropKind.Diamond
