# 2026-10-06 · 其它 · 移除 start_first_wave 及其调用（第一波只由开战开）

> **任务类型**：其它
> **推荐度**：**推荐**（下次同类任务照这个走）
> **耗时与成本**：约 2 轮对话，开了游戏（带窗口跑 2 个探针）
> **验证方式**：打开游戏实测（带窗口探针 `probe_tutorial_1_2` / `probe_level_progress_bar`）
> **补充自**：无

## 目标

把「提前开第一波」这一整条链路删掉：`ZombieWaveManager.start_first_wave`、
`LevelScriptBase.start_first_wave`（关卡 DSL）、`LevelTimelineEventStartFirstWave`、
`adventure_01_02` 里的 `await start_first_wave()`。
改完后第一波**只由开战**（`main_game_start()` → `ZombieManager.start_game()`）开，
1-2 教学期间不再出怪（与原版有出入，用户明确选择接受）。

## 步骤

1. 先按 [AGENTS.md](../../AGENTS.md) §2 路由取文档，确认这条链路牵到
   [僵尸波次.md](../参考存档/僵尸波次.md) / [关卡时间轴.md](../参考存档/关卡时间轴.md) /
   [新手教程.md](../参考存档/新手教程.md) 三份文档，改代码要同步改它们。
2. `zm_zombie_wave_manager.gd` 删 `start_first_wave()`（它只做三件事：
   `start_next_wave()` + `every_wave_progress_timer.start()` + `is_wave_started = true`）。
3. 唯一剩下的调用点 `ZombieManager.start_game()` 把这三行**就地内联**
   （没有另起一个新名字 —— 换个马甲等于没删）。
4. 删 `level_timeline_event_start_first_wave.gd` + `LevelScriptBase.start_first_wave()` +
   `adventure_01_02` 那句 `await start_first_wave()`；顺带清掉
   `addons/todo_controller/config/config.tres` 里那条指向已删文件的行。
5. `test/scenarios/probe_pogo_party.gd` 里那句手动开波同样改内联。
6. `probe_tutorial_1_2` 的三条断言跟着改口径（见「踩坑」第 2 条）。
7. 三份文档同步：删事件表行 / 改「第一波时机」表 / 改 1-2 教学说明。

## 关键决策与理由

- **出怪器基类的 `start_first_wave()` 保留没删** —— 用户勾选了「全链路都删」，但同一轮里又选了
  「锤僵尸出怪器先不动它」，两条冲突。`wave_source` 在 `ZombieManager` 里是
  **静态类型** `ZombieWaveSourceBase`，基类删了方法、锤僵尸子类还在 → `wave_source.start_first_wave()`
  直接编译不过（`Cannot find member`）。所以基类这一条保留，出怪器侧整体没动。
  **教训：删「父类声明 + 子类实现」这种成对出现的接口时，要先确认有没有静态类型在调。**
- **内联而不是改名** —— 换一个新名字（如 `start_battle_wave()`）等于只做了重命名，
  「移除」这件事没真正做到，还会让调用点以为有语义差别。
- **没有把 timer / 标志并进 `start_next_wave()`** —— `Timer.start()` 重启会清掉已走的时间，
  每波都重启会让进度条最多落后一秒（一局累积约几 %），属于**改节奏**，先问再做
  （见 [2026-10-05_回迁旧版四项优化.md](2026-10-05_回迁旧版四项优化.md) 的撤回教训）。

## 踩坑

1. **手动跑探针撞上别人正在跑**：`run_autopilot.ps1` 的临时目录是全局共享的
   （`%TEMP%\pvz_autopilot\userdir`），并发跑会报
   `文件正由另一进程使用`，而且 stdout 会读到**别人那个探针**的输出（我看到的是 `probe_night`）。
   → 正解：确认 `Get-Process Godot*` 有别人在跑就等一会儿再跑；看到输出里的
   `场景脚本: res://test/scenarios/xxx.gd` 与自己传的 `-Scenario` 不一致，说明读串了，重跑。
2. **断言查得太早会假红**：教学收尾后立刻查 `zombie_manager.is_first_wave_started` 是 false ——
   `main_game_start()` 先等 1 秒播 BGM 才调 `start_game()`。
   → 正解：先 `await` 等第一波真的落下来（探针里加 `_wait_wave_started()`），再断言标志位。
3. **删事件脚本要顺手清登记**：`addons/todo_controller/config/config.tres` 里有按路径登记的行，
   文件删了不留一行悬空路径。

## 给后来者的最简路径

1. 删函数 → 调用点**就地内联**（别改名）。
2. 删事件脚本 + `LevelScriptBase` 上的同名 DSL 方法 + 关卡脚本里的 `await`。
3. 全局搜 `start_first_wave` / `StartFirstWave`，把 `config.tres` 之类的路径登记一起清掉。
4. 改 `probe_tutorial_1_2` 三条断言 + 三份文档。
5. 带窗口跑 `probe_tutorial_1_2`（教学 + 开波）+ `probe_level_progress_bar`（进度条仍会涨）。
