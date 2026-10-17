extends RefCounted
## 模组「生态版」的**数值表**：每一条都写着「原版值 → 本模组用的值」
##
## 为什么单独一份文件：入口 / 应用器 / 每局接线三处都要读这些数，互相 `preload` 会成环；
## 而 `user://` 下的脚本 `class_name` 不注册，一律 preload 成常量引用（见 `mods_builtin/README.md`）。
##
## ★ 口径：原版数值是多少就该是多少，这里每一条都是**同人调整** —— 关掉本模组，
##   这些数一条都不生效（应用器负责把原版值放回去，一个字节都不留）。
##
## ★ 加一条新调整的三步：本文件加一对常量 → `eco_plant_patcher.gd`（改注册表 / 子弹）
##   或 `eco_wiring.gd`（改植物实例）→ `eco_mod.gd` 的详情面板加一行说明。

#region 阳光消耗
## 豌豆射手：原版 100 → 75
const SUN_PEA_SHOOTER := 75
const VANILLA_SUN_PEA_SHOOTER := 100
## 咖啡豆：原版 75 → 25
const SUN_COFFEE_BEAN := 25
const VANILLA_SUN_COFFEE_BEAN := 75
## 吸金磁：原版 50 → 150（多花的钱买的是「也能吸铁器，且一次能吸 3 个」）
const SUN_GOLD_MAGNET := 150
const VANILLA_SUN_GOLD_MAGNET := 50
#endregion

#region 光照（原版没有这个机制）
## 火炬树桩：给**正十字**四邻的格子各加 1 级光照
const LIGHT_TORCH_WOOD := 1
## 路灯花：给**周围一圈** 8 格（不含自己那格）各加 1 级光照
const LIGHT_PLANTERN := 1
## 向日葵每 1 级光照多产多少阳光
const SUN_PER_LIGHT_LEVEL := 5
## 向日葵原版产光值
const VANILLA_SUN_FLOWER_VALUE := 25
#endregion

#region 战斗数值
## 寒冰菇伤害：原版 20 → 100
const ICE_SHROOM_DAMAGE := 100
const VANILLA_ICE_SHROOM_DAMAGE := 20
## 机枪射手一次攻击打出几颗（原版是**动画里的 4 次发射轨道** = 4 颗）
const GATLING_BURST_NUM := 6
const VANILLA_GATLING_BURST_NUM := 4
## 仙人掌子弹最多打几个僵尸（原版 1 个：命中即销毁）
const CACTUS_PIERCE_NUM := 3
const VANILLA_CACTUS_PIERCE_NUM := 1
## 卷心菜投手索敌几行（原版只打本行）
const CABBAGE_LANE_NUM := 3
const VANILLA_CABBAGE_LANE_NUM := 1
## 吸金磁最多同时吸几件铁器（原版吸金磁**不能**吸铁器）
const GOLD_MAGNET_IRON_NUM := 3
const VANILLA_GOLD_MAGNET_IRON_NUM := 0
#endregion
