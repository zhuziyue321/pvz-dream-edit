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

## 「玩家对战」关卡里反向僵尸卡槽默认发哪几张僵尸卡（六张，与六格卡槽对齐）
##
## 在「我是僵尸」那四只之外加了铁网门与橄榄球 —— 都是本体 `all_cards.tscn`
## 里登记过的卡，造得出来；想换阵容改这里即可。
const PLAYER_BATTLE_ZOMBIE_CARDS: Array[StringName] = [
	ZombieIds.NORM,
	ZombieIds.CONE,
	ZombieIds.POLE_VAULTER,
	ZombieIds.BUCKET,
	ZombieIds.SCREEN_DOOR,
	ZombieIds.FOOTBALL,
]

## 「玩家对战」里僵尸块的格数（出战卡槽 12 格 = 植物块 6 + 僵尸块 6，
## 一个存储；这个数也是右上银行视图的宽与分块宽的口径）
const PLAYER_BATTLE_SLOT_NUM := 6

## 「玩家对战」选卡面板**不给选**的僵尸：原版里没有「选卡资格」的
## （都是战场上被别人带出来 / 受场景限制的，选了也没法正常用）
const PLAYER_BATTLE_EXCLUDED_ZOMBIES: Array[StringName] = [
	ZombieIds.DANCER,          ## 伴舞：舞王召唤出来的
	ZombieIds.BOBSLED_SINGLE,  ## 单个雪橇车小队队员：雪橇车压冰道后补员的
	ZombieIds.DUCKYTUBE,       ## 鸭子救生圈：只在水面出现
]

## 「玩家对战」里僵尸方的起始脑子（分池：不随阳光涨，账记在接线的 `_brains`）
##
## ⚠️ 僵尸方目前的「脑子收入」还没做（对战逻辑未完成），开局给一笔花；
##    数值取「我是僵尸」关卡的 150 同一口径，之后做收入时再调。
const PLAYER_BATTLE_START_BRAINS := 150

## 产脑光墓碑（DLC 对战墓碑 VSGravestone）：50 脑光的运行期植物，
## 行为类似向日葵 —— **只在「玩家对战」用**：选卡面板末尾那格，选中后跟别的
## 僵尸卡一样落僵尸块、花脑子；种下去周期性给僵尸方入账脑子（25 / 次）。
##
## 数值口径：50 脑光（对齐 DLC 版）；冷却取向日葵同款 7.5 s（fast）。
## ⚠️ 这是**植物类卡**（走 `PlantRuntimeRecipe` 运行期注册，落位走植物的种植流程），
##    但花脑子（对战接线 `costs_brains()` 单独判它）；卡槽认不认它由 `AllCards`
##    的模板目录说了算，与是不是内置角色无关。
const TOMBSTONE_PLANT_ID := &"zombie_card_vsgravestone"
const TOMBSTONE_SUN_COST := 50
const TOMBSTONE_COOL_TIME := 7.5
