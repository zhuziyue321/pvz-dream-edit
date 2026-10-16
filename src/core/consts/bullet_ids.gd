extends RefCounted
class_name BulletIds
## 子弹类型 id 表：**用 StringName 当 id，不再用数字编号**。
##
## 为什么改：原来是 `BulletRegistry.BulletType` 这个 int 枚举（`Bullet001Pea = 1` …）。
## 编号带来三件麻烦：
##   ① 编号本身不携带语义 —— 看见 `.tscn` 里 `bullet_type = 13` 得回注册表查才知道是篮球；
##   ② 插一个新子弹要在 1–16 的缝里挑号，人多时撞号（见 docs/Agent协作协议.md 的编号段配额，
##      那套配额就是因为编号才需要的）；
##   ③ 编号被写进了 39 个 `.tscn` / 组件资源，改枚举值会**静默错位**而编译门禁查不出来。
## 改成字符串后：id 自己就是语义名，新增子弹加一行常量即可，没有取号问题。
##
## 与旧枚举的**值对应关系**（2026-10-13 迁移，旧 enum 已删除）：
##   pea=1  pea_snow=2  puff=3  fume=4  puff_long_time=5  pea_fire=6  cactus=7  star=8
##   cabbage=9  corn=10  butter=11  melon=12  basketball=13  cattail=14  winter_melon=15
##   cob_cannon=16  bowling=1001  bowling_bomb=1002  bowling_big=1003
##
## ⚠️ **存量资源必须同步改**：`@export var bullet_type` / `attack_bullet_type` 在 `.tscn` 里
## 存的是 int，迁移时已按上表逐个改成 `&"pea"` 这种 StringName 字面量。
## 之后**新增**子弹只加常量 + 在 `BULLET_SCENE_PATHS` 登记，**不要再出现裸数字**。
##
## 取 id 的规范写法：`BulletIds.PEA`；**不要**在业务代码里写裸字符串 `&"pea"`
## （写错了要到运行时才炸，而 `BulletIds.PEA` 写错是编译错误）。


## 空 id：没指定子弹类型（如基类场景 / 只做展示的子弹）。
const NULL := &""


#region 直线弹
const PEA := &"pea"					## 豌豆
const PEA_SNOW := &"pea_snow"			## 寒冰豌豆
const PEA_FIRE := &"pea_fire"			## 火焰豌豆
const PUFF := &"puff"					## 小喷孢子
const FUME := &"fume"					## 大喷孢子
const PUFF_LONG_TIME := &"puff_long_time"	## 胆小菇孢子（和小喷孢子一样，不过修改存在持续距离）
const CACTUS := &"cactus"				## 仙人掌尖刺
const STAR := &"star"					## 星星子弹
const CATTAIL := &"cattail"			## 香蒲子弹
#endregion


#region 投掷弹
const CABBAGE := &"cabbage"			## 卷心菜
const CORN := &"corn"					## 玉米
const BUTTER := &"butter"				## 黄油
const MELON := &"melon"				## 西瓜
const WINTER_MELON := &"winter_melon"	## 冰瓜子弹
const BASKETBALL := &"basketball"		## 篮球
const COB_CANNON := &"cob_cannon"		## 玉米加农炮子弹
#endregion


#region 保龄球（坚果保龄球迷你关专用）
const BOWLING := &"bowling"			## 保龄球
const BOWLING_BOMB := &"bowling_bomb"	## 爆炸保龄球
const BOWLING_BIG := &"bowling_big"	## 大保龄球
#endregion


## 全部已登记的 id（自检 / 预热 / 调试用）。新增常量**必须**同步加进这里，
## 否则 `ALL` 会漏掉它（`get_bullet_scenes()` 仍能取，但自检扫不到）。
const ALL: Array[StringName] = [
	PEA, PEA_SNOW, PEA_FIRE, PUFF, FUME, PUFF_LONG_TIME, CACTUS, STAR, CATTAIL,
	CABBAGE, CORN, BUTTER, MELON, WINTER_MELON, BASKETBALL, COB_CANNON,
	BOWLING, BOWLING_BOMB, BOWLING_BIG,
]


## 是不是一个已知的子弹 id（空 id 不算）
static func is_valid(bullet_id: StringName) -> bool:
	return bullet_id != &"" and bullet_id in ALL
