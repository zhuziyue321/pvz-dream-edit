# 2026-10-04 · 新增内容 · 迷你游戏第 16 关「坚不可摧」(Last Stand) 完整实现

> **任务类型**：新增内容（兼关卡与地图）
> **推荐度**：**推荐**
> **耗时与成本**：约 2 轮；带窗口跑 `probe_last_stand`，一次 PASS
> **验证方式**：带窗口实机探针 `probe_last_stand`（`result=PASS failed=0`）+ 已给出人工验证方法

## 目标

把 `minigame_16_last_stand.gd` 从「能进能打的骨架」做成原版玩法，骨架里留的三条 TODO 全做掉：

1. 选卡界面禁掉阳光生产类与免费植物（含模仿者版本）；
2. 开局 5000 阳光 + **布阵阶段**：先种好防线，点「开始战斗！」才出怪；
3. 每过一波补 250 阳光，撑过 5 面旗帜（50 波）通关。

## 步骤

1. **布阵阶段做成一个时间轴事件**（而不是在 `MainGameManager` 里加开关）：
   新建 `src/levels/core/timeline_event/level_timeline_event_wait_battle_start.gd`，
   `run()` 里先 `await main_game.allow_lawn_operation()`（这一步本来是教程用的，
   语义正好 =「能操作但不开战」），再挂按钮等点击；`level_prefabs.gd` 加门面方法 `wait_battle_start()`。
2. **按钮** `src/ui/main_game_ui/lets_rock_button.tscn/.gd`（`PVZButtonBase` 子类，
   右下角 Bottom-Right 锚点，文案取自原版 `lawn_strings` 的 `[LETS_ROCK_BUTTON]`「开始战斗！」），
   登记进 `SceneRegistry.LETS_ROCK_BUTTON`。
3. **禁选卡**：关卡数据加字段 `banned_plant_types_in_choose_card`，
   由 `CardSlotNorm.init_card_slot_norm()` 转调 `CardSlotCandidate.set_plant_card_banned()`
   （普通页 + 模仿者页各一份容器，下标都是 `AllCards.plant_card_ids[被模仿的植物]`）。
4. **关卡脚本**：`minigame_16_last_stand.gd` 重写 `_init()`（禁选表 / `is_day_sun=false` /
   `first_wave_delay=6` / `zombie_multy=1`）与 `run_flow()`（布阵 → 每波补阳光 → `start_battle(50, …)`）。

## 关键决策与理由

- **布阵阶段复用 `allow_lawn_operation()`，不多做一个「布阵模式」**：
  它已经是「推进到 MAIN_GAME + 出战卡槽进场 + 不出怪 + 不天降阳光」，正是布阵阶段需要的；
  出怪 / 天降阳光 / 墓碑仍由「开战」事件负责，两者职责本来就分开了。
- **禁选的表现用「整张卡不出现」而不是「置灰不可点」**：
  `Card.set_card_disable()` 的灰化只在 MAIN_GAME 阶段判 `is_can_click`，选卡阶段点击不检查它，
  要置灰就得改点击链路；隐藏则天然点不到，只补一道「重选上次卡片」的模拟点击拦截即可。
- **每波阳光写在关卡脚本里而不是新增关卡字段**：
  只有这一关要「过一波补一次」，挂 `zombie_wave_manager.signal_wave_refresh` 一行就够，
  用 `wave_manager.curr_wave > 0` 跳过开局那一波（5000 是本钱，不该开局再送 250）。
- **等按钮不用 `await button.pressed`**：关卡中途被销毁时那个 await 永远不返回（协程泄漏）；
  改成按钮自带 `player_pressed`（不能叫 `is_pressed`，会遮住 `BaseButton` 同名方法而报 SHADOWED_VARIABLE_BASE_CLASS）
  + 基类 `wait_until()` 轮询，`MainGameManager` 失效的那一刻自己退出。

## 踩坑

1. **断言「总波数 = 50」一开始失败（读到 30）**：`max_wave` 是「开战」事件
   `LevelTimelineEventStartBattle._apply_battle_para()` 才写进关卡数据的，布阵阶段读到的还是
   关卡默认值 30。**这不是 bug，是断言时机错了**，把这条断言挪到点完按钮之后即可。
2. **`run_autopilot.ps1 -Scenario probe_last_stand` 那次跑起来的却是上一个探针**
   （报告头写着 `probe_zombie_nimble.gd`，而 ps1 打印的 `$resPath` 是对的）。
   **绕开办法**：直接调 Godot 传参 ——
   `Godot_v4.6.2-stable_win64.exe --path <项目> -- --scenario=res://test/scenarios/probe_last_stand.gd`。
   另外 Windows GUI 子系统下 **PowerShell 的 `> 文件` 重定向拿不到 Godot 的 stdout（文件 0 行）**，
   必须用管道 `2>&1 | Select-String`（或 ps1 里那样的 `cmd /c` 重定向）。

## 验证

带窗口跑 `test/scenarios/probe_last_stand.gd`，`[LASTSTAND] result=PASS failed=0`，覆盖：

- 向日葵 / 小喷菇（普通页 + 模仿者页）不出现，豌豆射手 / 坚果墙正常出现；
- 布阵阶段：已是 MAIN_GAME（能种）、`curr_wave == -1`、场上 0 僵尸、阳光 5000、`is_day_sun == false`；
- 点按钮后按钮收起、第一波进场、第一波不补阳光；
- 推进下一波后阳光 +250；开战后 `max_wave == 50`（5 面旗帜）。

**人工验证方法**（主菜单 → 迷你游戏 → 第 16 关坚不可摧）：

1. 选卡界面翻一遍：向日葵 / 阳光菇 / 双子向日葵 / 小喷菇 / 海蘑菇及其模仿者都不在待选区；
2. 进关后右下角有「开始战斗！」按钮，屏幕下方提示「先把防线种好…」；
   此时阳光 5000、天上不掉阳光、僵尸一只不来，可以慢慢种满 6 行；
3. 点按钮 → 按钮和提示条收起 → 约 6 秒后第一波进场；
4. 每推进一波阳光 +250；撑到第 5 面旗帜（第 50 波）清完出奖杯；
5. 按钮位置是否压住卡槽 / 铲子（右下角 160×54）需肉眼确认一次。

## 给后来者的最简路径

1. 要「等玩家点个按钮再往下走」的关卡 → 照 `level_timeline_event_wait_battle_start.gd` 造一个新事件：
   `allow_lawn_operation()` → 挂 UI → 按钮自带 `player_pressed` → `wait_until()` 轮询 → 收尾 `queue_free()`。
2. 要禁掉某几张卡 → 关卡 `_init()` 里填 `banned_plant_types_in_choose_card`，不用碰选卡 UI。
3. 跑探针优先直接调 Godot 传 `--scenario=`（见踩坑 2），别把 stdout 重定向到文件。
