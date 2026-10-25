<!-- 模组自述：README 只做指针与说明，规则正文在 docs/参考存档/模组机制.md §6.12 -->

# 僵尸卡

发僵尸卡牌 + 换上 PVZ2 的僵尸卡槽 / 僵尸卡面 / 脑光（原叫「僵尸卡（我是僵尸）」，玩家对战也用它之后去掉后缀）。

## 为什么需要它

本体那条僵尸卡通道是**关着**的（`ConstFeatureSwitch.ZOMBIE_CARD_ENABLED = false`）——
原版 PVZ1 的常规关卡没有「在关卡里直接放下僵尸」这件事。而「我是僵尸」关卡恰恰要靠僵尸卡开局：
没有它那关发不出牌、也判不了负。

打开那个总开关是**全局**的（普通关卡的选卡界面也会冒出僵尸页，玩家能在正常关里放僵尸），
所以本模组**不去动它**，改成只在需要僵尸卡的关卡里把僵尸卡直接发进出战卡槽。

## 做了什么（两类关卡，别的关卡一行都不走）

### 「我是僵尸」关卡（`game_para.is_zombie_mode`）

| 项 | 内容 |
|---|---|
| 发僵尸卡 | 关卡自己写的僵尸预选卡优先，没有就用默认四张（普通 / 路障 / 撑杆 / 铁桶） |
| 僵尸卡槽 | 出战卡槽底图 → PVZ2 `ZombieSeedBank`（446×87） |
| 僵尸卡牌 | 僵尸卡卡面 → PVZ2 `ZombieSeed`（50×70） |
| 选卡界面背景 | 待选区 → PVZ2 `SeedChooser_Background_I_Zombie`（465×513） |
| 脑光 | 脑子旁冒粉色星芒：被啃一口闪一下，脑子被吃掉时爆一下 |
| 脑子阳光 | 天上掉的阳光 → PVZ2 `BrainSun`（只换外观，收集行为不变） |

### 「玩家对战」关卡（`game_mode == ChooseLevelPlayerBattle`，配合玩家对战模组）

对战里只有**一个** 12 格出战卡槽（前 6 格植物 / 后 6 格僵尸与僵王，卡与冷却存同一份）——
本模组给它配分块与分池，右上只摆**银行视图**当外观宿主：

| 项 | 内容 |
|---|---|
| 12 槽合一 | 给本体出战卡槽配 `card_type_blocks` / `block_sizes = [6, 6]`（僵尸 / 僵王卡进后 6 格，各回各块的空位）、`shortcuts_enabled = false`（对战没有 1~0 快捷键）、`currency_of_card` / `on_card_cost`（分池：植物花阳光、僵尸花脑子）——三个口子都是本体通用件（见 `card_slot_battle.gd`），不带对战字样 |
| 银行视图 | 右上装一条**纯外观**的银行（`zombie_card_battle_slot.tscn`，不存卡）：底图 `ZombieSeedBank` **水平翻转**，脑子计数在**右面**；占位格 6~11 由接线从本体卡槽挪进来当宿主；出场/收场照植物卡槽同款 0.2s 平移 |
| 选僵尸卡面板 | 选卡阶段贴在植物待选区**右面**（`zombie_card_choose_panel.tscn`）：一行五张，全部已登记的僵尸卡**去掉**没选卡资格的（伴舞 / 单个雪橇车队员 / 鸭子救生圈，见 `zombie_card_settings.gd`）**再补上**僵王博士（不做解锁门槛），超高走滚动条（无翻页按钮），点卡飞进僵尸块第一个空位（上限六张），再点退回（空位不挤占）；飞行动画与本体选卡同款（经 `TemporaryCard` 中转 0.2s） |
| 发僵尸卡 | 玩家选的优先；一张都没选时选卡结束发默认六张（普通 / 路障 / 撑杆 / 铁桶 / 铁网门 / 橄榄球，见 `zombie_card_settings.gd`，按块放位不动植物那半），卡面 → PVZ2 `ZombieSeed` |
| 分池 | 植物卡花阳光（收阳光照旧只进植物那半）；僵尸 / 僵王卡花脑子，**不随阳光涨** |
| 起始脑子 | 150（脑子收入是对战逻辑的事，还没做；目前唯一的收入口是下面的产脑光墓碑） |
| 产脑光墓碑 | DLC 对战墓碑 **VSGravestone** 接成的运行期植物（`vsgravestone/`，50 脑光、冷却 7.5 s）：选卡面板**末尾**那格，选中后落僵尸块、**花脑子**（`costs_brains()` 单独判它），种下去行为类似向日葵 —— 周期性从头顶弹出一颗**脑子阳光**（`SunSpawner.pop_up`，向日葵同款弹跳落地，PVZ2 BrainSun 皮），点收时入僵尸方脑子账（25 / 次，`add_brains()`；不进植物方阳光池）并飞向**右上银行的脑子计数**（银行里的 `%Marker2DBrainTarget`，与植物阳光飞自己的计数器同一套规则）；出土用 `Panel clip_children = 2` 裁在地面以上（同本体墓碑）。⚠️ 这块板配起来有讲究，四种配法只有最后一种对：模式 `1` 裁「直接子节点」（= 动画挂点、自己不画东西）→ 裁剪区为空、整棵不渲染；模式 `2` + `StyleBoxEmpty`/全透明底 → 没有裁剪区、完全不裁；模式 `2` + 低 alpha 底 → 绘制被剔除、连石碑一起裁没；**正解 = 模式 `2` + `StyleBoxFlat` + 输出全透明的 `mask_invisible.gdshader`**（命令照常提交所以裁剪区成立，光栅化被 shader 抹掉所以看不见）。落位资格跟僵尸走（`vsgravestone/condition_zombie_side_plant.gd`）。动画是从 DLC 反编译 reanim 转的两段：`animation/character/plant/VSGravestone/`（idle 静帧 + rise 出土） |

## 素材

`*.png` 六张，取自本机那份 PVZ2 DLC 的 `_unpacked/images/`（随模组一起分发）。
读法统一走 `ModManager.load_mod_asset(ModIds.ZOMBIE_CARD, "<文件名>")`。

## 相关文档

- 机制正文：[../../docs/参考存档/模组机制.md](../../docs/参考存档/模组机制.md) §6.12
- 僵尸卡通道本体口径：[../../docs/参考存档/卡片与选卡流程.md](../../docs/参考存档/卡片与选卡流程.md) §僵尸卡片
- 回归探针：`test/scenarios/probe_zombie_card_mod.gd`（我是僵尸）/ `probe_player_battle_mod.gd`（玩家对战的卡槽部分）/ `probe_zombie_card_vsgravestone.gd`（产脑光墓碑）
