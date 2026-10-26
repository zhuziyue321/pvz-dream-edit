extends RefCounted
## 僵尸卡模组的共享常量
##
## ⚠️ 单独一份是为了让入口脚本与接线脚本都能读它，又不会互相 preload 成环
## （照 `glove_settings.gd` / `hammer_settings.gd` 的拆法，见 docs/参考存档/模组机制.md §四）。

## 「我是僵尸」关卡没写僵尸预选卡时，发哪几张僵尸卡
##
## 选的是原版最基础的四只：普通僵尸 / 路障僵尸 / 撑杆跳僵尸 / 铁桶僵尸
## —— 它们的卡在原版 `all_cards.tscn` 里都有登记，造得出来。
const DEFAULT_ZOMBIE_CARDS: Array[StringName] = [
	ZombieIds.NORM,
	ZombieIds.CONE,
	ZombieIds.POLE_VAULTER,
	ZombieIds.BUCKET,
]

## 「玩家对战」里僵尸块的格数（出战卡槽 12 格 = 植物块 6 + 僵尸块 6，
## 一个存储；这个数也是右上银行视图的宽与分块宽的口径）
const PLAYER_BATTLE_SLOT_NUM := 6

## 「玩家对战」选卡面板**不给选**的僵尸：原版里没有「选卡资格」的
## （都是战场上被别人带出来 / 受场景限制的，选了也没法正常用）
##
## 2026-10-25：**伴舞僵尸（`ZombieIds.DANCER`）按用户要求放开**（排到舞王后面，
## 见 `PLAYER_BATTLE_MOVE_AFTER`）—— 原版它是舞王召唤出来的，但这里既然要能选，
## 就把它当普通僵尸卡处理（花费走注册表的 50，冷却见 `PLAYER_BATTLE_ZOMBIE_COOLDOWNS`）。
const PLAYER_BATTLE_EXCLUDED_ZOMBIES: Array[StringName] = [
	ZombieIds.BOBSLED_SINGLE,  ## 单个雪橇车小队队员：雪橇车压冰道后补员的
	ZombieIds.DUCKYTUBE,       ## 鸭子救生圈：只在水面出现
]

## 「玩家对战」选卡面板里**改显示位置**的规则：每项 = `[要挪的卡, 挪到谁的后面]`
##
## 2026-10-25 用户要求的两条：
##   · 产脑光墓碑 → 普僵后面（它按 `ZombieRuntimeKit` 插卡会排在**僵尸卡列表末尾**，
##     换到第 2 格才好找；先前写的是「墓碑 ↔ 旗帜对调」，旗帜挪走之后等价于这个位置）；
##   · 旗帜僵尸 → 海豚骑士后面。
## 规则按数组顺序逐条执行；要挪的卡或目标卡不在列表里就跳过（比如玩家对战模组没开、墓碑没装）。
## ⚠️ 只影响这一面的**排法**：`AllCards.zombie_card_ids` 的编号、卡槽格子换算、别的选卡页一概不动。
## ⚠️ 产脑光墓碑是玩家对战模组的运行期僵尸（id 前缀 `zombie_card_` 是历史原因，见
##    `mods_builtin/player_battle/player_battle_settings.gd`）：这里**只按 id 认它**，
##    不要再给它开别的特判（僵尸卡模组与它之间没有依赖）。
const PLAYER_BATTLE_MOVE_AFTER: Array = [
	[&"zombie_card_vsgravestone", ZombieIds.NORM],
	[ZombieIds.FLAG, ZombieIds.DOLPHINRIDER],
]

## 「玩家对战」里僵尸方的起始脑子（分池：不随阳光涨，账记在接线的 `_brains`）
##
## ⚠️ 僵尸方目前的「脑子收入」还没做（对战逻辑未完成），开局给一笔花；
##    数值取「我是僵尸」关卡的 150 同一口径，之后做收入时再调。
const PLAYER_BATTLE_START_BRAINS := 150

## 「玩家对战」僵尸卡的**脑子花费**（对战口径，2026-10-26 平衡性重调）
##
## 键 = `ZombieIds`；**没列出的沿用角色注册表原值**（雪人 / 蹦极空投 / 单个雪橇车队员 /
## 僵王 —— 对战卡池里它本来就不该按普通僵尸定价，仍走 `ZombieBossInfoData`）。
##
## 2026-10-25 本表首次从 PVZ DLC Edition wiki 的 `cost=…(Versus Mode)` 同步，但 wiki 对战花费
## 是按「原版对战模式」的**经济与胜利条件**标的，与**本仓库对战实现**有三处系统性偏差，这里按
## 实测数值修正：
##   1. **僵尸方收入没做**：开局只有 `PLAYER_BATTLE_START_BRAINS = 150`，无持续脑子收入
##      （见 `player_battle_settings.gd`）。所以昂贵的「中后期卡」（巨人 / 冰车 / 投石车 / 矿工 /
##      气球 / 蹦蹦）在实战里基本买不起 → 整体往下压，让 150 开局 + 墓碑能滚起来。
##   2. **胜利条件是「漏一只进门」**：植物方有 5 台割草机兜底，但矿工 / 气球 / 蹦蹦这三类
##      **绕过全部植物的越线单位**直接消耗割草机、之后任意漏一只就赢，是 PvP 真正的制胜点，
##      相对「纯肉」单位（路障 / 铁桶 / 橄榄球 / 铁网门）明显更值钱。
##   3. **本仓库数值与原版不同**：铁桶 / 铁网门 EHP ≈ 1370（5.1× 普僵）、橄榄球 EHP ≈ 1670
##      （6.2×、**本实现没加速，与普僵同速**）、旗帜僵尸**没有任何波次功能**（PvP 无 wave，等于普僵）
##      —— 这些按本仓库实测 `HpComponent.max_hp` + 防具算，不照搬 wiki。
##
## 定价口径（内部一致、可直接核对）：**基准 = 普僵 25 脑子**（270 EHP / 速度 20 / 无能力）。
##   · 坦度项：花费 ≈ 25 × (EHP / 270)，取整到 25（EHP 取本体 + 防具，见各僵尸 `.tscn` 的 `max_hp`）；
##   · 速度项：ori_speed ≠ 20 的（蹦蹦 45 / 海豚 80）按偏离加成；
##   · 越线项（无视植物直取房子）：矿工 / 气球 / 蹦蹦 这类「植物打不到」的加价；
##   · 拆植物项（就地杀植物但不越线）：投石车 / 小丑 / 蹦极；
##   · 支援项（给别的僵尸开路 / 召唤）：扶梯 / 舞王 / 伴舞；
##   · **对战中不成立的能力不加价**：旗帜的波次功能 → 0。
##
## ⚠️ 与「我是僵尸」表**不同**：本表只在玩家对战生效；`zombie_info_data.gd` 的 `SunCost` 仍是我是僵尸口径，别去改那边。
const PLAYER_BATTLE_ZOMBIE_COSTS: Dictionary = {
	ZombieIds.NORM: 25,              ## 基准（270 / 速度 20 / 无防具）
	ZombieIds.FLAG: 25,              ## PvP 无波次：与普僵数值完全一致，原 300 是按「波次加价」，本模式不成立
	ZombieIds.CONE: 50,              ## EHP 640 ≈ 2.4× 普僵；原 75 偏高（3×）
	ZombieIds.POLE_VAULTER: 50,      ## 270 血、只多「跳过一株」，原 100 偏高（≈4× 普僵）
	ZombieIds.BUCKET: 125,           ## EHP 1370 ≈ 5.1× 普僵；原 100 偏低（4×）
	ZombieIds.PAPER: 50,             ## EHP 420 + 掉报后狂暴（翻倍啃食），合理
	ZombieIds.SCREEN_DOOR: 125,      ## EHP 1370（铁门挡正面直射，等同铁桶坦度）
	ZombieIds.FOOTBALL: 150,         ## EHP 1670 ≈ 6.2×；⚠️本实现无加速，与普僵同速——原价偏贵但未动
	ZombieIds.JACKSON: 100,          ## 舞王：500 血 + 召唤 4 伴舞；本体慢，原 150 偏高
	ZombieIds.DANCER: 50,            ## 伴舞：可选后作为普通卡，与普僵同数值，吃注册表 50（显式登记，避免回退歧义）
	ZombieIds.SNORKLE: 50,           ## ⚠️白天前院(全 Land)放不出来（只水路），价格不动，见备注
	ZombieIds.ZAMBONI: 175,          ## 1350 血 + 碾压 + 冰道 + 死亡爆炸；原 150 偏低
	ZombieIds.BOBSLED: 100,          ## 4 只共 1080 血，但需要冰道（与冰车联动）；合理
	ZombieIds.DOLPHINRIDER: 100,     ## 4× 速度 + 跳一株；⚠️白天前院放不出来（只水路）
	ZombieIds.JACKBOX: 75,           ## 500 血、一次性 3×3 爆炸（自己也死），原 100 偏高
	ZombieIds.BALLOON: 150,          ## 空中免直射，但可被仙人掌 / 灰烬打掉；原 225（≈9× 普僵）过高
	ZombieIds.DIGGER: 175,           ## 地下穿越整条草坪、家门口(约 x=88)出土，只有灰烬类能拦——越线类最贵
	ZombieIds.POGO: 175,             ## 500 血 + 连续跳过植物 + 速度 45，越线类（保留 wiki）
	ZombieIds.BUNGI: 100,            ## 直接偷一株植物（可被保护伞挡），原 125 偏高
	ZombieIds.LADDER: 125,           ## 1000 血 + 给后续僵尸搭桥，原 150 偏高
	ZombieIds.CATAPULT: 150,         ## 850 血 + 距外砸植物，原 175 偏高
	ZombieIds.GARGANTUAR: 300,       ## 3000 血 + 瞬杀植物，压制力远超 250（原 250 ≈ 10× 普僵，仍偏低）
	ZombieIds.IMP: 25,               ## 270 血、最小单位，原 50 偏高（= 普僵价）
}

## 「玩家对战」僵尸卡的**冷却时间**（秒；对战口径，2026-10-25 从 PVZ DLC Edition wiki 同步）
##
## 键 = `ZombieIds`；**没列出的沿用角色注册表原值**（0 = 不冷却，那是「我是僵尸」口径；
## 雪人 / 蹦极空投 / 单个雪橇车队员 / 产脑光墓碑 / 僵王都不进这张表）。
##
## 数据来源与口径（wiki 只写了一部分，逐条写清出处）：
##   - **wiki 明写**：撑杆跳僵尸 30 s（`pvz-dlc-edition.fandom.com/wiki/Pole_Vaulting_Zombie`
##     信息框 `recharge=30 seconds`）。同一批词条里另有 纸箱头 30 s / 垃圾桶 15 s / 靶子 15 s，
##     那三只不在对战卡池（或不是卡），故不进本表；
##   - **其余 16 只**：DLC wiki 的 `Versus: Legacy` 词条明写「本图复刻**主机版对战模式**的
##     卡费 / 冷却」，故取主机版对战冷却表（`pvzvm.fandom.com/wiki/Almanac_PVZVM` 的
##     Zombie Units 「Recharge BSD」列，2026-10-25 取）：
##     普僵 7.5 / 旗帜 30 / 路障 30 / 铁桶 30 / 报纸 15 / 铁网门 15 / 橄榄球 30 / 舞王 30 /
##     冰车 60 / 小丑 30 / 矿工 30 / 蹦蹦 60 / 蹦极 30 / 扶梯 30 / 投石车 60 / 巨人 60；
##     撑杆那只两处一致（30），可当交叉验证。
##   - **待核实**：潜水 / 雪橇 / 海豚 / 气球 / 小鬼这 5 只是 DLC 新增卡、主机版对战里没有，
##     wiki 两处都没登记；先按「慢」档众数 30 s 填，等实测或后续资料再改。
##     同理 **伴舞**（2026-10-25 才放开可选）—— 对战表里没有这张独立卡，也先按 30 s 填；
##     不给它填的话会吃到注册表的 0 冷却（无限放），别漏。
##
## ⚠️ 与「我是僵尸」表**不同**：本表只在玩家对战的卡槽 / 选卡面板里生效，
##    `data/character/registry_data/zombie_info_data.gd` 的 `CoolTime` 仍是 0，别去改那边。
const PLAYER_BATTLE_ZOMBIE_COOLDOWNS: Dictionary = {
	ZombieIds.NORM: 7.5,
	ZombieIds.FLAG: 7.5,             ## PvP 无波次，旗帜 = 普僵；冷却对齐普僵 7.5 s，原 30 s 会让这张卡比普僵还差
	ZombieIds.CONE: 30.0,
	ZombieIds.POLE_VAULTER: 30.0,   ## wiki 明写（Pole_Vaulting_Zombie 的 recharge）
	ZombieIds.BUCKET: 30.0,
	ZombieIds.PAPER: 15.0,
	ZombieIds.SCREEN_DOOR: 15.0,
	ZombieIds.FOOTBALL: 30.0,
	ZombieIds.JACKSON: 30.0,        ## 舞王
	ZombieIds.DANCER: 30.0,         ## 伴舞（2026-10-25 放开可选）：对战表没登记，先按 30 s，待核实
	ZombieIds.SNORKLE: 30.0,        ## 待核实（主机版对战没有这只）
	ZombieIds.ZAMBONI: 60.0,
	ZombieIds.BOBSLED: 30.0,        ## 待核实（主机版对战没有这只）
	ZombieIds.DOLPHINRIDER: 30.0,   ## 待核实（主机版对战没有这只）
	ZombieIds.JACKBOX: 30.0,
	ZombieIds.BALLOON: 30.0,        ## 待核实（主机版对战没有这只）
	ZombieIds.DIGGER: 30.0,
	ZombieIds.POGO: 60.0,
	ZombieIds.BUNGI: 30.0,
	ZombieIds.LADDER: 30.0,
	ZombieIds.CATAPULT: 60.0,
	ZombieIds.GARGANTUAR: 60.0,
	ZombieIds.IMP: 30.0,            ## 待核实（主机版对战没有这只）
}

## 僵尸卡的**卡面底图**（PVZ2 `Seeds_ZombieSun`，50×70，右下角是阳光图标那张卡包）：
## 模组里**所有**僵尸卡都用这一张 —— 「我是僵尸」的重塑、玩家对战的候选 / 收尾都读它。
## 两条接线各留一份常量必漂移（曾经就是一边 `ZombieSeed` 一边 `Seeds_ZombieSun`），统一放这里。
const ASSET_ZOMBIE_CARD_BG := "Seeds_ZombieSun.png"

## 产脑光墓碑不在这里：它归**玩家对战模组**（`mods_builtin/player_battle/`，
## `player_battle_settings.gd` 里那组 `TOMBSTONE_*`）—— 2026-10-25 起它是**僵尸单位**，
## 由那边 `ZombieRuntimeKit` 插进僵尸卡目录，本模组按普通僵尸卡照常处理
## （面板自动排进列表、`costs_brains()` 走 `is_zombie_card()`）。
