extends RefCounted
class_name ConstArmor
## 防具的公共枚举：防具类别（一 / 二类）、防具类型标识、伤害吸收规则。
##
## 为什么单独一张表：防具本体是 `ArmorComponent`（一个角色可以挂多个、同类可叠加），
## 而这些枚举被**收集方**（`HpComponentZombie`）、**查找方**（`get_armor_by_type()`）与
## **防具自己**（`get_absorb_rule()`）三方共用，放在任何一个组件里都会造成
## core → entities 的反向依赖。
##
## ⚠️ 这里**只有枚举，没有任何「类型 → 场景 / 脚本 / 数值」映射表**（硬约束 §1-4）：
## 防具的具体数值与外观一律写在场景里挂着的 `ArmorComponent` 节点上。
##
## 与 `ConstDamage.E_DamageMode` 的分工：
##   模式决定「这一次伤害在防具与本体之间怎么走」，本文件的 `E_ArmorAbsorb` / `E_ArmorPass`
##   决定「走到某一层防具时，这一层吃多少、往下传多少」。两层相乘就是完整的分配规则。


## 防具类别：决定一次伤害先打到哪一层（**数值越大越外层，越先挨打**）
##
## 与原版口径的对应（重写前后一致）：
##   一类 = 头顶那件（路障 / 铁桶 / 橄榄球头盔 / 植物僵尸头顶植物）
##   二类 = 举在身前那件（报纸 / 铁门 / 梯子）
enum E_ArmorClass{
	Armor1 = 1,		## 一类防具
	Armor2 = 2,		## 二类防具
}


## 防具类型：只做**标识与查找**（`HpComponentZombie.get_armor_by_type()`），不做任何映射。
##
## 「某个僵尸戴的是什么」由场景里那个 `ArmorComponent` 节点的 `armor_type` 决定，
## 游戏本体不认识任何一个具体值 —— 加一种新防具只要在这里加一项，不需要改管理器。
enum E_ArmorType{
	Null,			## 未标注（纯血量防具，不参与按类型查找）
	Cone,			## 路障
	Bucket,			## 铁桶
	Football,		## 橄榄球头盔
	ScreenDoor,		## 铁门
	Newspaper,		## 报纸
	Ladder,			## 梯子
	Balloon,		## 气球
	Pickaxe,		## 矿工镐
	PlantHead,		## 植物僵尸头顶的那棵植物
}


## 这一层防具本次吸收多少伤害
enum E_ArmorAbsorb{
	None,		## 完全不受该伤害模式影响（伤害穿透本层继续往下走）
	Remain,		## 按传进来的剩余伤害扣（没扣完的部分按 `E_ArmorPass` 传给下一层）
	Fixed,		## 扣固定值（不管传进来多少，保龄球 / 锤子那一类）
}


## 吸收完之后把多少伤害交给下一层（更内层防具 / 本体）
enum E_ArmorPass{
	Overflow,	## 没吸收完的那部分（`Remain` 吸收时用）
	Unchanged,	## 原样传：本层照扣，但伤害不减少（穿透的二类防具）
		Zero,		## 不往下传（固定伤害打在防具上就到此为止）
	Fixed,		## 传固定值（保龄球侧面的二类防具：扣 1800、继续传 1800）
}
