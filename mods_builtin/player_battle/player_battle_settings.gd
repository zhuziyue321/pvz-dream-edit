extends RefCounted
## 玩家对战模组的共享常量
##
## ⚠️ 单独一份是为了让入口脚本与别的脚本都能读它，又不会互相 preload 成环
## （照 `zombie_card_settings.gd` / `glove_settings.gd` 的拆法，见 docs/参考存档/模组机制.md §四）。

## 产脑光墓碑（DLC 对战墓碑 VSGravestone）：50 脑光的**僵尸单位**，
## 行为类似向日葵 —— **只在「玩家对战」用**：走僵尸卡链路（`ZombieRuntimeKit` 出卡），
## 在选卡面板里跟别的僵尸卡排在一起、落僵尸块、花脑子，放下去周期性给僵尸方入账脑子（25 / 次）。
##
## 数值口径：50 脑光（对齐 DLC 版）；冷却取向日葵同款 7.5 s（fast）。
## ⚠️ 2026-10-25 之前它是**植物类卡**（运行期植物 + 自定义种植条件 + 受击层补丁）；
##    改成僵尸后这些全撤了：阵营 / 索敌 / 受击 / 放置资格都是僵尸本体口径。
##    **占格**走 `PlantCell.set_occupied_by_zombie()`（僵尸侧特殊状态 `IsOccupied`，
##    与本体墓碑的植物侧 `IsTombstone` 对称），见 `vsgravestone/vsgravestone_zombie.gd`。
##
## ⚠️ id 里的 `zombie_card_` 前缀是历史原因（这块 2026-10-25 从僵尸卡模组迁到本模组，
##    同日再由植物改成僵尸）：改名会让玩家存档里那份解锁名单 / 卡牌目录指向一个
##    不存在的单位，故保留不动。
const TOMBSTONE_ZOMBIE_ID := &"zombie_card_vsgravestone"
const TOMBSTONE_SUN_COST := 50
const TOMBSTONE_COOL_TIME := 7.5
## 墓碑卡面在本模组里的**落点**（`ZombieRuntimeKit.face_position`，默认值是标准僵尸的 `(2, 17)`）。
## 为什么不能吃默认值：卡面是把整枝 `Body` 原样搬进卡里的，墓碑的身板 + 招牌整个偏在原点**左上**，
## 用 `(2,17)` 会摆到卡片左上角（2026-10-25 实测：内容中心比卡片中心偏 (-9.2, -12.4) px）。
## 量法：卡面里所有可见 Sprite2D 的矩形取并集（**要连 Panel 裁剪板的子节点一起走**，
## `AnimationFrameUtil.get_content_rect` 只递归 Node2D，对本卡面恒返回空），
## 差 ÷ 父节点缩放（=1）补到落点上。⚠️ 换了墓碑动画 / 改了招牌尺寸要重新量。
##
## ⚠️ 这个值和 `zombie_vsgravestone.tscn` 的**站位**绑死：卡面 wrapper 缩放是 0.3，
##    `VSGravestoneAnim.position` 一动，卡面就跟着动 `×0.3`。2026-10-25 修站位时整枝在 Body 里
##    右移 35 / 下移 50（板放宽漏补），落点同步减掉 (10.5, 15)，卡面才保持居中。
const TOMBSTONE_CARD_FACE_POSITION := Vector2(0.74, 14.42)

## 靶子僵尸（DLC 的 Zombie_target，原版未启用的残留类型）：**对战里僵尸方要守的靶子** ——
## 每行摆一只、站在**第 10 列**（草坪 9 列之外的那一列；见 `TARGET_ZOMBIE_STAND_COLUMN`，
## 与小推车在草坪外最左面同一个口径）+ `TARGET_ZOMBIE_STAND_EXTRA_OFFSET_X` 的右移量、
## 站着不动、不啃植物；
## 植物方击破 3 只即算植物赢（见 `levels/player_battle_day.gd`）。
## 僵尸方的胜法不是它：**任意一只僵尸走进房子** = 僵尸方赢（本体「僵尸进家」失败流程）。
##
## 它不是「卡」：本模组只把它热注册进 `CharacterRegistry` 给关卡摆，**不**装
## `ZombieRuntimeKit`（僵尸卡页里看不到、玩家放不出来）。
## 数值：**200 血** —— 来源：DLC Edition wiki
## `https://pvz-dlc-edition.fandom.com/wiki/Target_Zombie`（信息框 Toughness 200，
## Overview 写「absorb 60 / 110 / 160 换外观、累计 200 死」；同页图鉴文案的
## 「Toughness: low」与信息框冲突，取 200）。落位在 `zombie_target.tscn` 的
## `HpComponent.max_hp`（本体默认 270）。
## **三档受创换装已接**（2026-10-25）：累计受创 60 / 110 / 160 ⇒ 剩余 140 / 90 / 40 血，
## 手里那块招牌换成 DLC 的 `TARGET_1/2/3`（`zombie_target_damage01~03.png`，
## 见 `PVZ_DLC/_unpacked/properties/resources.xml`）。临界值与三份换装资源都在
## `zombie_target.tscn` 的 `HpStageChangeComponent` 上。
## ⚠️ 素材里的 `Zombie_target_body2.png`（身上带伤）**故意没接**：DLC 本体没有任何引用
## （`resources.xml` 只有 TARGET_1~3，exe 里搜不到这个名字），属素材包残留。
## 同页另写：0 脑 / 15 秒充能、放置时眩晕整条路 —— 本模组不做这张卡，只记在这里；
## 靶子口径「开局每路 1 只、共 5 只」与本关实现一致（见上面 `TARGET_ZOMBIE_LANES`）。
const TARGET_ZOMBIE := &"pb_target_zombie"
## 摆几行（前院 5 行，每行一只）
const TARGET_ZOMBIE_LANES := 5
## 击破几只算植物赢
const TARGET_ZOMBIE_DEFEAT_TO_WIN := 3
## 站在**第几列**（1 起算）：草坪只有 9 列，**第 10 列**是草坪之外的那一列 ——
## 靶子的**身体**站在该列正中（= 最后一列右边缘再往右半格 + 下面那段视觉偏移），
## 身体骑在屏幕右边缘上，一半左右露在屏幕外（原版 DLC 里靶子就是半截露在草坪外）。
## ⚠️ 别为了「看得更全」把这一列往回收：往右是设计要求，往左就退回草坪第 9 列了。
const TARGET_ZOMBIE_STAND_COLUMN := 10
## 站位列之外**再往右挪多少像素**（0 = 不挪）——
## 2026-10-25 加：按第 10 列正中摆时身体骑在屏幕右边缘上（约 44% 露在屏幕外），
## 想让它更靠右、更贴「半截露在草坪外」的观感就调这个数；**只会往右，不设负数**。
## ⚠️ 一格 ≈ 78px：别超过一格 —— 探针里「靶子还有一部分身体在屏幕内」会先报
## （+30px 时视觉包围盒约 x=761~886 / 视口宽 800，约 31% 还看得见）。
const TARGET_ZOMBIE_STAND_EXTRA_OFFSET_X := 30.0
## 靶子**身体的视觉中心**相对角色原点的水平偏移（负数 = 身体画在原点左边）——
## 招牌 / 脑袋 / 手臂全都落在原点左侧，实测（探针 `probe_player_battle_target_win.gd`
## 把所有可见 Sprite2D 的外接矩形并起来量）约 **-19.5px**（idle 各帧 ±2px）。
## 站位要把这一段补回去：只按原点算的话，看着像站在第 9 列的右边，不在第 10 列。
## ⚠️ 换了动画 / 改过招牌贴图尺寸之后这个数要重新量（探针里那条「视觉中心落在该列正中」会先报）。
const TARGET_ZOMBIE_BODY_VISUAL_OFFSET_X := -19.5

## 「玩家对战」**植物卡**的**阳光花费**（对战口径）
##
## 键 = `PlantIds`；**没列出的沿用角色注册表原值**（DLC 模组那几株没有 `PlantIds` 常量，
## 用**字面量 id** —— 本模组不 preload 别的模组的脚本，按 id 认卡就够；那个模组没开时
## 这些条目匹配不到任何卡，自然不生效）。
##
## 数据来源：PVZ DLC Edition 官方 wiki（`pvz-dlc-edition.fandom.com`）各植物词条的
## `cost=<冒险模式值><br><对战值> <small>([[Versus: …]])</small>` 字段（2026-10-25 取）。
## **口径 = 白天前院**（本模组目前只有「玩家对战：白天」一关 ⇒ 对应 DLC 的 `Versus: Day`）：
##   · `Versus modes`（所有对战模式都改，Day 当然也在内）：
##     豌豆射手系没变；变的是 芦荟 0（50）/ 增幅鹅河菊 75（200）/ 血橙 100（75）/
##     甜菜守卫 50（75）/ 环轨仙人掌 175（225）/ 橡木射手 175（200）/ 缩小紫罗兰 75（100）/
##     水钵 0（25）；
##   · 白天对战专属（`Versus: Day` / `Daytime Versus modes`）：
##     墓碑吞噬者 50（75）、阳光菇 0（25）、光照蘑菇 0（50）、臼炮蘑菇 100（75，**涨价**）；
##   · `other Versus modes`（Roof / Moon 之外，含 Day）：寒冰射手 150（175）、
##     双发射手 175（200；`Versus: Legacy` 另是 150，那是主机版原版表）。
##
## ⚠️ 词条只标「对战与冒险模式不同」的株（其余株对战按冒险模式值），本表逐株抄下来，
##    **没标的株不等于是「漏了」**。本仓库没有的株（DLC 的 火焰豌豆 Fire Pea / 电击豌豆
##    Electric Pea / 冰豌豆 Ice Pea / 等离子豌豆 Plasma Pea / 等离子木 Plasmawood / 射击星
##    Shooting Star / 海星 Seastar / 鬼椒 Ghost Pepper / 腌辣椒 Pickled Pepper / 勇敢菇
##    Bravery-shroom / 吞噬者 Devourer / 霜冻菇 Frost-shroom / 荆棘苔 Thornmoss / 藤坚果
##    Vine-nut）不进表。
## ⚠️ 本表只在玩家对战的选卡界面 / 出战卡槽里生效：改的是**卡自己的 `sun_cost`**，
##    `data/character/registry_data/plant_info_data.gd` 与 DLC 模组的配方常量一个都不动
##    （冒险模式 / 图鉴 / 商店照旧）。落地见 `player_battle_plant_wiring.gd`。
## ⚠️ **紫卡**（本表只有环轨仙人掌这一株）种下之后会被卡槽既有的「紫卡按场上数量加价」
##    改写（`CardSlotBattle.update_card_purple_sun_cost()`：注册表 `SunCost` + 50 × 场上数量），
##    用的是**注册表原值**，不是本表 —— 也就是说对战价只对**第一张**有效。wiki 没写对战里
##    紫卡怎么加价，先保持本体这套机制不动；要改得先想清楚 Ramp-up 的基准价，别顺手改。
## ⚠️ 夜间 / 屋顶对战的差异本模组**还没有场地**，先不落地，等出那些关卡再照 wiki 补：
##    · 夜间对战蘑菇 +25 阳光：小喷菇 25 / 阳光菇 25 / 大喷菇 100 / 火焰蘑菇 100 /
##      光照蘑菇 25 / 臼炮蘑菇 125（wiki `Multiplayer` 词条的 Trivia 明写这条规则）；
##    · `Versus: Roof` / `Versus: Moon`：豌豆射手 50、蜜蜂射手 50、双发射手 100、寒冰射手 100、
##      火焰豌豆 125、橡木射手 100、海星 150、飓衣甘蓝 150（最后一是**涨价**）。
const PLAYER_BATTLE_PLANT_COSTS: Dictionary = {
	PlantIds.SNOW_PEA: 150,               ## 寒冰射手：other Versus modes（175 → 150）
	PlantIds.PEA_SHOOTER_DOUBLE: 175,     ## 双发射手：other Versus modes（200 → 175；Legacy 另是 150）
	PlantIds.GRAVE_BUSTER: 50,            ## 墓碑吞噬者：Daytime Versus modes（75 → 50）
	PlantIds.SUN_SHROOM: 0,               ## 阳光菇：Daytime Versus modes（25 → 0）
	PlantIds.WATER_BOWL: 0,               ## 水钵（DLC 的 Water Pot）：Versus modes（25 → 0）
	&"dlc_aloe": 0,                       ## 芦荟 Aloe Vera：Versus modes（50 → 0）
	&"dlc_ampliflower": 75,               ## 增幅鹅河菊 Ampliflower：Versus modes（200 → 75）
	&"dlc_bloodorange": 100,              ## 血橙 Blood Orange：Versus modes（75 → 100，涨价）
	&"dlc_chardguard": 50,                ## 甜菜守卫 Chard Guard：Versus modes（75 → 50）
	&"dlc_glowshroom": 0,                 ## 光照蘑菇 Lume-shroom：Day/Pool/Roof/Woods（50 → 0）
	&"dlc_kingcactus": 175,               ## 环轨仙人掌 Orbitus：Versus modes（225 → 175）
	&"dlc_mortarshroom": 100,             ## 臼炮蘑菇 Mortar-shroom：Day/Pool/Roof/Woods（75 → 100，涨价）
	&"dlc_oakarcher": 175,                ## 橡木射手 Oak Archer：other Versus modes（200 → 175）
	&"dlc_shrinkingviolet": 75,           ## 缩小紫罗兰 Shrinking Violet：Versus modes（100 → 75）
	## ---- 下面 4 条来源不同：**不是 wiki 抄的**，是 2026-10-25 用户按 DLC 版对战实机口述的 ----
	## wiki 上查不到这套值：主机版对战表是 200 / 75 / 125 / 125，DLC 冒险模式值是
	## 50 / 50 / 175 / 125，两者都对不上 ⇒ DLC 的对战在 wiki 之外另有一层重定价，
	## 而 wiki 只收录了「与冒险模式不同」的 36 株标注，没收整表。
	## **待补全**：其余株的实机值还没拿到，拿到后照这张表继续加（同一张表、同一个键）。
	PlantIds.THREE_PEATER: 225,           ## 三线豌豆（实机口径；主机版 200、DLC 冒险 50）
	PlantIds.SQUASH: 100,                 ## 窝瓜（实机口径；主机版 75、DLC 冒险 50）
	PlantIds.TORCH_WOOD: 50,              ## 火炬树桩（实机口径；主机版 125、DLC 冒险 175）
	PlantIds.TALL_NUT: 75,                ## 高坚果（实机口径；主机版 125、DLC 冒险 125）
}

## 「玩家对战」**植物卡**的**冷却时间**（秒；对战口径）
##
## 键 = `PlantIds`；**没列出的沿用原值**。
## 同一批 wiki 词条里，只有两株标了对战改冷却（都在 `Versus modes` 一行）：
##   · 芦荟 Aloe Vera：7.5 → **15**；
##   · 墓碑吞噬者：7.5 → **15**（它的阳光另有 50 的白天对战覆盖，见上表）。
## **待核实**：主机版对战表还给过 樱桃炸弹 / 火爆辣椒 / 寒冰菇 / 毁灭菇 60 s、
## 墓碑吞噬者 30 s、三线豌豆 / 杨桃 / 西瓜投手 15 s —— DLC 词条**没有**给这些株标对战冷却，
## 说明 DLC 自成一套口径（`Versus: Legacy` 才是主机版原样）。按「只有词条标注的株才变」处理，
## 故不进本表；等实测（进对战看卡面转多久）或后续 wiki 更新再改。
## ⚠️ 与阳光表一样：只改卡自己的 `cool_time`，冒险模式 / 本体的 `CoolTime` 不动。
const PLAYER_BATTLE_PLANT_COOLDOWNS: Dictionary = {
	PlantIds.GRAVE_BUSTER: 15.0,          ## 墓碑吞噬者（7.5 → 15）
	&"dlc_aloe": 15.0,                    ## 芦荟 Aloe Vera（7.5 → 15）
}
