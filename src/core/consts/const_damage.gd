extends RefCounted
class_name ConstDamage
## 伤害系统的常量表：伤害模式（怎么结算）与伤害来源（谁打的）。
##
## 为什么单独一张表：伤害类型原先挂在 `BulletRegistry.AttackMode` 名下，
## 但它早就不只是子弹在用 —— 锤子（`Hammer`）、爆炸、啃食、冰冻伤害、残血流失
## 都在传同一个枚举。叫「子弹攻击模式」却出现在炸弹和僵尸嘴里，读代码的人
## 每次都要愣一下。这里按它**真正的语义**改名并集中，BulletRegistry 只管子弹本身。
##
## 与旧的 `BulletRegistry.AttackMode` **值逐一对应**（旧枚举已从 BulletRegistry 删除）：
##   Norm / Penetration / Real / BowlingFront / BowlingSide / Hammer = 0 / 1 / 2 / 3 / 4 / 5
## 存量 `.tscn` 里存的是 int，数值不变所以**不需要改任何场景文件**。
##
## 新增伤害模式 / 来源时请加在这里，不要在业务代码里写裸 int。


## 伤害模式：决定一次伤害在「二类防具 / 一类防具 / 本体」三层血之间怎么分配。
##
## 分配规则的实现集中在 `HpComponentZombie.hp_loss()`（植物只有本体血，见 `HpComponent`）。
## **加一种模式必须同步改那里的 match**，否则新模式会静默按「不处理」走掉
## （不掉血、不发信号，症状是「这个技能打人没伤害」且没有任何报错）。
##
## 「秒杀」**不是**一种模式 —— 它压根不看伤害值，是 `DamageInfo.is_instant_kill` 字段。
enum E_DamageMode {
	Norm,			## 正常：按顺序溢出扣二类防具 → 一类防具 → 本体
	Penetration,	## 穿透：二类防具与一类防具同时扣（啃食 / 爆炸 / 溅射走这条）
	Real,			## 真实：跳过二类防具，直接打一类防具与本体
	BowlingFront,	## 保龄球正面：固定伤害（二类 400 / 一类 800 / 本体 1800）
	BowlingSide,	## 保龄球侧面：固定伤害（二类 1800，溢出 1800 继续打本体）
	Hammer,			## 锤子：无视二类防具，一类防具 900，本体直接清空
}


## 伤害来源：只做**语义标记**，不参与任何结算分支。
##
## 用途（都是为扩展留的，当前本体不依赖它做判定）：
##   · 反伤 / 免疫 / 吸血这类效果要「只对某一种来源生效」；
##   · 联机要把「谁打的谁」写进包里（光有伤害值对不上账）；
##   · 统计与成就（本局被啃死几只、炸死几只）。
##
## **不要拿它当结算分支用**：结算只看 `E_DamageMode`。
enum E_DamageCause {
	Unknown,	## 未标注（兼容存量调用，建议新代码都写清楚）
	Bullet,		## 子弹命中
	Spatter,	## 溅射 / 分裂（西瓜、冰瓜那一类按目标数平分的伤害）
	Bomb,		## 爆炸 / 灰烬（樱桃、土豆雷、毁灭菇…）
	Eat,		## 僵尸啃食（持续掉血）
	Hammer,		## 锤子（锤僵尸模式）
	Freeze,		## 冰冻附带伤害（寒冰菇：伤害是主体，冰冻是挂在这次伤害上的控制）
	Burn,		## 灼烧（辣椒烧一整行）
	Drain,		## 残血流失（临界值组件的自动掉血，不是"被打"）
	Crush,		## 碾压 / 压扁（小推车 / 倭瓜 / 钉耙这一类"直接压死"）
	Death,		## 直接清空血（铲子铲除 / 死亡消失 / 关卡脚本强制致死，见 `HpComponent.hp_loss_to_death`）
	Script,		## 关卡脚本 / 其它一次性机制（硬约束 §1-8：一关专属机制留在关卡脚本里）
}


## 伤害被取消的原因（`DamageResult.cancel_reason`）
enum E_CancelReason {
	None,			## 没取消
	NoTarget,		## 目标为空或已释放
	NoHpComponent,	## 目标没有血量组件（不该发生，记一条 Log.error）
	ZeroAmount,		## 包里只有伤害、且伤害值被加工成了 0（含负数被夹到 0）
	Modifier,		## 被修饰器显式取消（免疫 / 无敌一类）
	Target,			## 被**受击方**在加工阶段显式取消（见 `Character000Base.process_damage()`）
	NoEffect,		## 包里没有任何系统认得的效果（key 拼错、或全是留给受击方的特殊效果）
}


#region 效果名（`DamageInfo.effects` 字典的 key）
##
## 一次伤害不再只是「掉多少血」，而是**一个效果包**：发起方往包里塞若干效果，
## 系统与受击方各取所需。本段登记所有效果的**名字**，分两类：
##
##   · **通用效果** —— `DamageSystem` 在「应用包」阶段认得并亲自施加，
##     所有角色一视同仁。加一种通用效果 = 在这里加一个常量 + 在
##     `DamageSystem._register_effect_handlers()` 里登记一个处理函数。
##   · **特殊效果** —— 系统**不认**，也不碰，纯粹是一张「便条」：
##     发起方写给受击方看，受击方在「加工包」阶段自己消费、自己决定怎么翻译
##     （翻译成伤害 / 翻译成免疫 / 直接无视）。
##
## 为什么要留特殊效果这一档：把「洗冰车被地刺秒杀」这类**只对一种角色有意义**的规则
## 塞进系统，系统就要认识「洗冰车」「地刺」这些具体角色 —— 那是硬约束 §1-8 明令禁止的。
## 交给受击方自己翻译，系统从头到尾不知道世界上有个洗冰车。
##
## ⚠️ 一律用 `StringName`（`&"..."`）当 key：字典查找比 String 快，且与 Godot 的
## 信号 / 节点名体系一致。**不要**用裸字符串拼 key，拼错了不报错、只是静默失效。

## 【通用】伤害：值为 int（伤害值）；分配方式看 `DamageInfo.mode`
const EFFECT_DAMAGE := &"damage"
## 【通用】减速：值为 Dictionary { time:float 持续秒数, factor:float 速度系数 }
const EFFECT_SLOW := &"slow"
## 【通用】完全冰冻：值为 Dictionary { time:float 冰冻秒数, after_slow:float 解冻后减速秒数 }
const EFFECT_FREEZE := &"freeze"
## 【通用】黄油定身：值为 float（定身秒数）。只有僵尸认（`Zombie000Base.be_butter`）
const EFFECT_BUTTER := &"butter"

## 【特殊】地刺扎：值为 true。发起方 = 地刺 / 钢地刺，受击方自己决定后果
## （洗冰车 / 投石车 → 秒杀 + 载具反伤，巨人 → 无视，其余含雪橇车小队 → 正常挨伤害）
const EFFECT_CALTROP := &"caltrop"

## 【特殊】载具反伤：值为 true。发起方 = 洗冰车 / 投石车（被地刺类扎到时反过来打发起者一下），
## 受击方自己决定后果。
##
## 车打回去的那一下是**0 伤害**的（原版里车并不会"打"地刺，它只是把地刺压/扎废了），
## 真正的后果由受击方在 ② 加工阶段**自己写进包里**：
##   · 地刺      → `info.is_instant_kill = true`（直接报废）
##   · 钢地刺     → `info.amount = 自己的受损值`（掉一截血，扛得住）
##   · 其余角色    → 不认识，0 伤害包什么也不发生
## 也就是说**受损数值一律落在 `effects[EFFECT_DAMAGE]` 这张字典里**，由受击方填，
## 车不给任何数字、也不认识任何一种地刺（硬约束 §1-8）。
const EFFECT_VEHICLE_BACKLASH := &"vehicle_backlash"
#endregion


#region 元信息 key（`DamageInfo.effects` 里**不是效果**的那几个）
##
## 一次伤害除了「施加什么效果」，还得带上「谁打谁、怎么算、掉不掉东西」这些上下文。
## 它们与效果**同住一张字典** —— `DamageInfo.effects` 是唯一真源，两处各存一份必然漂移；
## 但**不是效果**：系统不施加它们，受击方也不消费它们，只是随包走一段路。
##
## 为什么统一加 `meta_` 前缀：
##   · 调试打印 / 遍历包时能一眼把「上下文」和「效果」分开；
##   · 万一将来某个效果也叫 `source`，不会撞 key 还**静默失效**（拼错 key 是不报错的）。
##
## ⚠️ `DamageInfo` 上的具名字段（`mode` / `attacker` / `is_instant_kill` …）现在**全是代理访问器**，
## 读写的就是这几项（跟 `amount` 一个做法）。业务代码照旧写 `info.mode = ...`，
## **不要**绕过具名字段直接碰 `meta_*` —— 那是给打印与遍历用的。

## 伤害模式（见 `E_DamageMode`）
const KEY_MODE := &"meta_mode"
## 伤害来源（见 `E_DamageCause`）
const KEY_CAUSE := &"meta_cause"
## 受击者
const KEY_TARGET := &"meta_target"
## 发起者
const KEY_ATTACKER := &"meta_attacker"
## 伤害载体（那一发子弹）
const KEY_SOURCE := &"meta_source"
## 是否秒杀
const KEY_INSTANT_KILL := &"meta_instant_kill"
## 死亡时是否有掉落
const KEY_DROP_ON_DEATH := &"meta_drop_on_death"
## 掉落的额外条件
const KEY_DROP_2 := &"meta_drop_2"
## 是否播放受击音效
const KEY_SFX := &"meta_sfx"
## 结算后的实际伤害值（由 `DamageSystem` 回填）
const KEY_FINAL_AMOUNT := &"meta_final_amount"

## 全部元信息 key（调试打印时用它过滤掉上下文，只留下真正的效果；顺序 = 打印顺序）
const META_KEYS: Array[StringName] = [
	KEY_MODE,
	KEY_CAUSE,
	KEY_TARGET,
	KEY_ATTACKER,
	KEY_SOURCE,
	KEY_INSTANT_KILL,
	KEY_DROP_ON_DEATH,
	KEY_DROP_2,
	KEY_SFX,
	KEY_FINAL_AMOUNT,
]
#endregion
