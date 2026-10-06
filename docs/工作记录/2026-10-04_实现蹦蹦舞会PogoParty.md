<!-- AGENT-DOC: worklog -->
# 2026-10-04 · 新增内容 · 迷你游戏第 19 关「蹦蹦舞会」(Pogo Party)

> **任务类型**：新增内容（关卡，走「关卡与地图」那一套也更合适）
> **推荐度**：**推荐**（下次做「某关僵尸特别单一」的关卡照这个走）
> **耗时与成本**：约 2 轮（1 轮探查 + 1 轮改 + 1 次带窗口探针，第一次探针断言写错，重跑一次）
> **验证方式**：打开游戏实测（带窗口跑 `-Scenario probe_pogo_party -Windowed`，`[POGOPARTY] result=PASS failed=0`）
> **补充自**：[2026-10-04_实现坚不可摧LastStand.md](2026-10-04_实现坚不可摧LastStand.md)（探针骨架照它抄）

## 目标

把 `minigame_19_pogo_party.gd` 从「一张普通屋顶关的骨架」做成真正的「蹦蹦舞会」：
**除旗帜波外，场上全是蹦蹦僵尸**。可判定标准写在探针 `test/scenarios/probe_pogo_party.gd` 里。

## 步骤

1. **先确认「蹦蹦舞会」就是指这一关**，别凭猜：全仓库搜 `蹦蹦舞会` 命中三处 ——
   文案库 `data/strings/lawn_strings.txt:2482 [POGO_PARTY]`、选关按钮
   `src/menus/choose_level/mini_game_choose_level.tscn:265`、以及本关卡脚本自己的 TODO。
2. **取原版口径**：PVZ Wiki `https://plantsvszombies.wiki.gg/wiki/Pogo_Party` ——
   Roof / **Three flags** / "features **purely** Pogo Zombies outside of flag waves" /
   "Levels with pre-placed plants" / 开场到第一波约 **55 秒** / 播「Graze the Roof」。
3. 只改那一个关卡脚本（属性 + `run_flow()` 里的出怪表），**不加任何 engine 侧代码**。
4. 抄 `probe_last_stand.gd` 写 `probe_pogo_party.gd`，带窗口跑一遍。

## 关键决策与理由

- **出怪表只写 `Z019Pogo`**，不是调权重 —— 原版是「purely Pogo Zombies」，只有一种就直接写死；
  之前那版 TODO 想的是「把 Z019Pogo 的权重堆高」，但仓库没有 per-level 权重覆盖字段，
  为了它去改 `ResourceLevelData` / `ZombieWaveCreateManager` 是**过度设计**。
- **`zombie_multy = 4` 保留了骨架里的原值**，理由是它能让主题成立：
  波次战力上限 = `int(波数/3 + 1) * zombie_multy`，而蹦蹦僵尸战力恰好是 **4** →
  非旗帜波的战力预算刚好是整数只蹦蹦僵尸，凑不出不足 4 点的余额去补普僵，
  于是非旗帜波真能「一只别的都没有」（探针 STEP5 全 30 波逐波核对通过）。
- **删掉 `is_bungi = true`** —— 那是抄别的屋顶关骨架带过来的，原版本关没有蹦极偷植物。
- **`game_BGM` 从 `MiniGame` 改成 `Roof`** —— 原版它是仅有的两个播屋顶曲的小游戏之一。
- **`first_wave_delay = 55.0`** —— 原版 Trivia 明确写了约 55 秒（与「全面冻结」同源）。

## 踩坑

1. **探针把旗帜波的构成断言写成「1 旗帜 + 8 普僵」，`[NG] 第 9 波不符: {2:1, 1:7, 19:8}`**
   → 原因：`get_curr_wave_zombie_list()` 在战力余额不足一只本波僵尸（`min_power`）时，
   会用普僵补齐余数；所有关卡本来就这写法，不是本关的问题
   → **正解**：旗帜波断言改成「1 旗帜 + ≥4/8 普僵 + 其余只能也是蹦蹦 + 蹦蹦仍是主体」，
   严格断言只留给非旗帜波（那才是本关的主题线）。
2. **`Parent node is busy adding/removing children` 报在探针的 `change_scene_to_file` 那一行**
   → 协程里换场景撞上树正在增删子节点 → **结论**：其它探针也一样，不影响结果，不用管。
3. **Stderr 里一片 `Cannot infer the type of "row2"`（`beghouled_manager.gd:530`）及其级联
   `Failed to compile depended scripts`** → 与本次改动无关：本机 Godot 是 4.6.2 而项目标称 4.5.1，
   类型推断更严；游戏照常跑起来（管理器初始化完成、僵尸正常刷出）。

## 给后来者的最简路径

1. 先全仓库搜关卡中文名 → 定位到 `src/levels/mode_minigame/minigame_*.gd`（**通常已有骨架和 TODO**）。
2. 取原版口径只查 wiki 那一页的 infobox：Location / Flags / Zombie 三行基本就能定满出口参数。
3. 「某一种僵尸特别多」这类需求，**先试收窄 `zombie_refresh_types`**，不够再谈权重；
   挑 `zombie_multy` 时看能不能让「战力预算 ÷ 该僵尸战力」整除，能整除就一波都不用补杂兵。
4. 抄 `probe_last_stand.gd` 写探针，波次构成的断言直接调
   `zombie_wave_create_manager.create_curr_wave_zombie_list(wave, is_big)` 逐波核对
   —— 它是纯列表计算、秒出结果、不依赖随机，比真刷波等几十秒快得多。
