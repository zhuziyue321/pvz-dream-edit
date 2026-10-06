# 2026-10-04 · 新增内容 · 实现迷你游戏第 7 关「观星」(Seeing Stars)

> **任务类型**：新增内容
> **推荐度**：**推荐**（下次做「非标准胜负条件的小游戏」照这个走）
> **耗时与成本**：约 3 轮对话（1 轮调研 + 1 轮实现 + 1 轮探针验证），带窗口跑了探针
> **验证方式**：打开游戏实测（带窗口探针 `probe_seeing_stars`，19 条断言全过，0 失败）；星形图案的观感需人工看一眼
> **补充自**：无（同类参考：[2026-10-04\_实现坚不可摧LastStand.md](2026-10-04_实现坚不可摧LastStand.md) 的探针写法）

## 目标

把 `minigame_07_seeing_stars.gd` 的空实现补完，满足三件事：
① 草坪上摆出星星形状的轮廓点；② 轮廓点上只允许种杨桃 / 南瓜头（及模仿者），别处不让种杨桃；
③ 通关条件 = 每个轮廓点都有一颗杨桃（不是打完最后一波），4 面旗帜内没种满算输。

## 步骤

1. 先查 wiki 定口径（`https://plantsvszombies.wiki.gg/wiki/Seeing_Stars` + 中文 wiki）：
   「预留的格子不能种植除杨桃和南瓜头以外的其他植物」；PC 版无限波次、iOS/Android 才是 4 面旗帜。**口径先查再写，别照着仓库 TODO 猜**。
2. 种植限制做成**格子级白 / 黑名单**（`PlantCell.only_allow_plant_types` / `forbidden_plant_types`），
   消费点放在 `ResourcePlantCondition.judge_is_can_plant()` 的最前面 —— 一处拦截，普通 / 紫卡 / 特殊植物全过这一关。
3. 轮廓节点 `SeeingStarsOutline` 仿保龄球红线（`WallnutBowlingStripe`）的落位：`GIM_Other.init_other_item()` 里按
   `is_seeing_stars` 创建，进关就把限制打好（各子管理器 init 之前格子已建好）。
4. 表现用 `_draw()` 现画五角星（外接圆 + 内接圆 × 0.382 交替取点）——**原版素材已移除，不能依赖贴图**。
5. 胜负判定写进 `run_flow()`：`await mg.main_game_start()` 之后自己轮询，**不用 `start_battle` 预制体**。
6. 写探针 `probe_seeing_stars.gd`，无头跑通后再带窗口跑一遍。

## 关键决策与理由

- **不用 `start_battle` 预制体** —— 它的结束条件是「最后一波刷完 + 僵尸清空」，观星是「种满就赢」，
  种满那一刻就得掉奖杯；出怪参数改在 `_init()` 里写进关卡数据（`max_wave` / `zombie_refresh_types`）。
- **限制做在格子上，不在手持组件上** —— 手持组件只管虚影 / 点击，系统代种、教程指向等其它路径不走它；
  放在种植条件的第一道闸才是「一处生效」。
- **轮廓点内只收杨桃 / 南瓜；轮廓点外只禁杨桃（不禁南瓜）** —— 南瓜头是正常防守植物，别处该用还得用；
  禁杨桃是为了避免玩家把 125 阳光的杨桃种到别处白扔。
- **杨桃放进 `pre_choosed_card_list_plant`** —— 原版 4-6 才解锁杨桃，没解锁的话这关永远打不完；
  预选卡直接从 `AllCards` 复制，玩家没拥有也进卡槽（原版是默认选中 + 摘掉弹警告）。
- **星形 21 个轮廓点** —— 原版是「giant star」，5 行 × 9 列按五角星铺满；成本 21 × 125 = 2625 阳光，
  靠天降阳光 + 玩家自己的向日葵在 40 波内凑齐（PC 原版是无限波次，这里用手机版 4 面旗帜收尾）。

## 踩坑

1. `var plant_cell_manager := Global.main_game.plant_cell_manager` 直接报
   `Cannot infer the type ... because the value doesn't have a set type` → `Global.main_game` 是无类型的，
   `:=` 推不出成员类型 → **正解**：显式写 `var plant_cell_manager: PlantCellManager = ...`。
   （这一条会让整条依赖链全部 `Failed to compile depended scripts`，表现为「节点莫名是 null」。）
2. 多 agent 并行时 `run_autopilot.ps1` 共用 `%TEMP%\pvz_autopilot\userdir`，
   同时跑两个探针会互相 `Remove-Item` 失败 / 覆盖 `ap_out.txt`（我第一次读到的输出是别人的 `probe_pogo_party`）
   → **正解**：跑之前把 `$env:TEMP` 指到自己的目录再调 `run_autopilot.ps1`。

## 给后来者的最简路径

1. wiki 定口径 → 2. 格子级限种表 + `judge_is_can_plant()` 加一道闸 → 3. 仿 `WallnutBowlingStripe` 加一个
   `src/items/mini_game/` 下的道具节点（限制 + `_draw()` 表现）→ 4. 关卡脚本 `run_flow()` 里
   `main_game_start()` + 自写轮询判胜负 → 5. `prefab`-无关的部分照 `probe_last_stand.gd` 抄一个探针，
   **自己的 TEMP 目录**下跑 `-Windowed`。

## 人工验证方法（画面部分）

进迷你游戏第 7 关「观星」：草坪上应看到一颗**黄色五角星轮廓**（21 格，未种的亮、种上的暗）；
拿豌豆射手点轮廓点 → 没有虚影且点下去播 buzzer；拿杨桃点轮廓点 → 有虚影、能种下；
拿杨桃点轮廓点之外 → 不能种。21 格全部种上杨桃的瞬间掉奖杯；一直不种满，第 4 面旗帜升起时判负。

---

## 补充（2026-10-04）：本关的实现位置已整体迁移

本记录里「逻辑铺在 5 个文件」的写法**已被取代**：观星规则现在全在关卡脚本里，
`ResourceLevelData` 的观星开关、`GIM_Other` 的观星分支、`SeeingStarsOutline` 都已删除，
绘制层换成通用的 `CellStarOverlay`。
玩法行为与数值一律没变（带窗口探针 19 断言仍全过）。

见 [2026-10-04\_观星逻辑收拢进关卡脚本.md](2026-10-04_观星逻辑收拢进关卡脚本.md)。

---

## 补充（2026-10-04）：轮廓表现从「画五角星」换成「半透明杨桃虚影」

本记录步骤 4 的「`_draw()` 现画五角星」**已被取代**：轮廓点上的标记现在是
**一棵半透明、不动的杨桃**（`AnimationFrameUtil.create_frame_node()` 取
`StarFruit_idle` 第 0 帧，脚本 / AnimationTree / 播放器 / 碰撞体都被剥掉，
只留 `Body` 那一枝），达标与否用两档透明度区分（亮 = 该种、暗 = 已种上）。
不用卡片里手摆的 `CharacterStatic`——杨桃那张的 idle 主视觉缺贴图（没有身体）。

**踩坑**：别想着「取一次帧再 `duplicate()` 复用」——取出来的树是 PackedScene 实例化
来的、脚本又被剥过，`duplicate()`（默认走 DUPLICATE_USE_INSTANTIATION）结构对不上，
报 `get_child` 越界 + `Child node disappeared while duplicating`；老老实实每格现取一帧。

探针 `probe_seeing_stars` 加了两条虚影断言，21 断言全过；另带窗口跑了一次截图确认画面
（半透明杨桃摆出星形、无五角星贴图、无方框）。截图探针是临时的，验证完已删；
想复现：任意截图探针 `get_viewport().get_texture().get_image().save_png("user://x.png")`。

---

## 补充（2026-10-05）：星星图案换成 13 点的原版形状

上面「关键决策」第 5 条的 **21 点五角星**（以及末尾人工验证方法里的「21 格」）**已被取代**：
轮廓点换成下面这张 5 行 × 9 列的表（`#` = 轮廓点），共 **13 个点**，写死在
`minigame_07_seeing_stars.gd` 的 `STAR_CELLS` 里：

```
...#.....
...#.....
.######..
...###...
...#..#..
```

换算成 `Vector2i(row, col)`：`(0,3)`、`(1,3)`、`(2,1)~(2,6)`、`(3,3)~(3,5)`、`(4,3)`、`(4,6)`。

连带调整：

- 通关成本从 21 × 125 = 2625 阳光降到 **13 × 125 = 1625 阳光**（4 面旗帜 40 波的时间更宽裕了）。
- 探针 `probe_seeing_stars.gd` 的 `STAR_CELL_NUM` 21 → 13（**这个常量必须跟着改**，否则 STEP2 三条断言全挂）。
- 带窗口重跑探针：日志 `观星：共 13 个星星轮廓点`、19 条断言全过；结算时
  `已种槽位=13` 且坐标与上面这张表逐格对齐（`(0,3) (1,3) (2,1)~(2,6) (3,3)~(3,5) (4,3) (4,6)`）。

**经验**：想换星形只改 `STAR_CELLS` 一张表就够了（越界坐标会被 `_resolve_star_cells()` 丢掉并打日志），
但**探针里的点数常量不是自动同步的**，改完表一定跟着改 `STAR_CELL_NUM`。

---

## 补充（2026-10-06）：进度条换成观星口径（已种轮廓点 / 总数）

1. 新增 `src/levels/mode_minigame/seeing_stars_progress_provider.gd`（`SeeingStarsProgressProvider`），
   继承 `LevelProgressBattleProvider`，覆写 `get_progress()` / `is_bar_visible()` /
   `get_flag_num()` / `take_flag_raise_index()`。
   关卡脚本只要 `create_progress_provider()` 返回它的实例（一条钩子，本体零改动）。
2. 进度本体仍在关卡脚本上（`star_cells` / `get_unplanted_num()`），数据源每帧读一次。
3. **进度条不画旗帜**（`get_flag_num()` = 0）—— 见下面的追加修正。

**踩坑**：

1. 新建的 `.gd` 带 `class_name` 时，**直接 `run_autopilot.ps1` 会报
   `Could not find type "SeeingStarsProgressProvider" in the current scope`** —— 全局类缓存
   （`.godot/global_script_class_cache.cfg`）是编辑器扫描时才更新的，命令行跑游戏不会更新
   → **正解**：先跑一次
   `& '<godot.exe>' --headless --path '<工程>' --import`（顺带把 `.uid` 也生成了），再跑探针。
2. `provider.is_bar_visible()` 在刚进 `MAIN_GAME` 那一刻仍是 false（要等开第一波
   `is_wave_started` 才置位）→ 探针里这条断言**必须轮询等**（我第一轮就挂在只查一次）。

**验证**：带窗口 `probe_seeing_stars`，25 条断言全过（`[SEESTARS] result=PASS failed=0`），
新增 STEP2.5（数据源类型 / 不画旗帜 / 不升旗 / 开局 0% / 开战前不显示）与
STEP5（开打后显示 / 种 1 个 = 1/13 / 全种满 = 100%）。

---

## 补充（2026-10-06 追加修正）：观星进度条不画旗帜

上面第 1 条里最初写的是「旗帜沿用战斗口径、照旧画 4 面旗」，**已被推翻**：
进度条既然被种植进度占满，再画 4 面旗会被读成「进度跟波次有关」——
本关的 4 面旗帜只是「没种满就判负」的倒计时，归波次管，不占进度条。

改法：`get_flag_num()` 返回 0（控制器收到 0 会清掉上一批旗帜）、`take_flag_raise_index()` 返回 -1。
**继承 `LevelProgressBattleProvider` 只剩一个用途**：复用「开第一波之后才显示」
（`is_bar_visible()` → `zombie_manager.is_battle_started()`）。

连带：`docs/参考存档/特殊关卡.md` 观星表两处（轮廓点 **13 个** = 13 颗杨桃、星形图案换成 13 点那张）一并改正 ——
那张表此前还停在老的 21 点五角星上。
