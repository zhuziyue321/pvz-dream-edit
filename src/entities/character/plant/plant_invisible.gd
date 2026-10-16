extends Plant000Base
class_name PlantInvisible
## 隐形植物：**看不见、不攻击、不生产**，只留一副「能被僵尸索敌」的受击框
##
## ★ 它是**工具植物**，不是玩法内容：本体自己一株都不种、没有卡、不进选卡界面、
##   也不在 `PlantIds.ALL` 里（那份名单是「内置玩法植物」，进去了会凭空多一张卡 / 一条图鉴）。
##   它的用户是**调试代码与模组**：
##     · 想把「僵尸会不会去啃某个东西」单独拿出来看 —— 把它挂到那个东西身上当靶子；
##     · 想让某只僵尸被同类索敌 —— 它当诱饵，伤害由 `damage_link` 转走（见下）。
##
## ★ **伤害转移**：`damage_link` 非空时，打在它身上的伤害**原样转给那个角色**
##   （只换 `info.target`，再走同一个入口）—— 于是「僵尸啃诱饵」等于「僵尸啃 `damage_link`」，
##   而诱饵自己怎么啃都不掉血。
##
## ⚠️ 创建方式与普通植物一样：`instantiate()` → `init_plant({...IsNorm, PlantCell: 格子})`
##    → `add_child()`。⚠️ `IsNorm` 而不是 `IsShow`：展示态会**关掉受击框**
##    （`Character000Base.ready_show()`），那就谁都索敌不到它了。
##    「格子」只是一个**坐标载体**（`row_col` 决定 `lane`），不必是场上真实的格子 ——
##    传一个没入树的 `PlantCell.new()` 即可，这样它不会占任何真实格子、也不进存档。

## 伤害转移的目标：打在本植物身上的伤害原样转给它（空 = 自己照常挨打）
##
## ⚠️ 由创建方在 `add_child()` **之前**赋值（模组 / 调试代码），本体不写它
var damage_link: Character000Base


## 统一伤害入口：把这一下**改投**给 `damage_link`
##
## 为什么堵在 `apply_damage()` 而不是 `process_damage()` / `take_damage()`：
## 后两个分别是「受击方加工 / 结算」阶段，那时「该不该挨这一下」已经定了 ——
## 只有**入口**这一处能换掉目标。这里改的只是 `info.target`（伤害包本身一行不动），
## 所以伤害模式 / 因果 / 发起者 / 附带效果（减速、冰冻、地刺标记…）全都原样带过去。
func apply_damage(info: DamageInfo) -> DamageResult:
	if info != null and is_instance_valid(damage_link) and info.target != damage_link:
		info.target = damage_link
		return damage_link.apply_damage(info)
	return super(info)
