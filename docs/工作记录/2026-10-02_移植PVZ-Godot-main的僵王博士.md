# 2026-10-02 · 新增单位 · 移植 PVZ-Godot-main 的僵王博士（独立 Node2D 版，替换旧实现）

> **任务类型**：新增单位
> **推荐度**：**推荐**（做「非角色类 boss」照这个走：独立 Node2D + 鸭子类型接入）
> **耗时与成本**：约 3 轮对话，跑了无头探针；**未开窗口**（表现由人工验）
> **验证方式**：无头探针 `probe_zomboss` 全绿（20 条断言）；未开窗口人工看表现
> **补充自**：[2026-10-02\_实现僵王博士.md](2026-10-02_实现僵王博士.md)（那条用 `zombie_000_base` + Manager，本次整套推倒重做 → 已在它文末追加评价）

## 目标

把参考项目 `PVZ-Godot-main` 的僵王博士整套搬过来：本体是**独立 `Node2D`**（不进僵尸角色体系），
出招节奏 / 受击窗口 / 碾压范围 / 死亡演出全部对齐参考实现；旧的 `zombie_999_boss` + `ZombossManager` 方案废弃。

## 步骤

1. 先摸清参考实现的骨架：`PVZ-Godot-main/src/entities/character/zombie/zombie_boss.gd`（独立 Node2D、状态机 + 动作队列）、
   `zomboss_ball.gd`、以及它**四处接入点**（检测组件 / 直线子弹 / 抛物线子弹 / 溅射组件）。
2. 对照本仓库的同名接口做映射（见「踩坑」第 1 条），改写成本仓库写法。
3. 新建：`src/entities/character/zombie/zombie_boss.gd`（`ZombossBoss`）、`zombie_boss_ball.gd`（`ZombossBall`）、
   `src/ui/main_game_ui/ui_zomboss_hp_bar.gd`（`ZombossHpBar`）+ 两个 `.tscn`；
   把脚本直接挂到仓库现成的躯干场景 `src/entities/character/zombie/zombie_boss.tscn` 根节点上。
4. 四处接入点各加一条 `is ZombossBoss` 分支（检测组件补 `zomboss_can_be_attacked` + 位置索敌兜底）。
5. 关卡开关 `ResourceLevelData.is_boss` → 改名 `is_zomboss_fight`（跟参考项目一致），更新 5-10。
6. `MainGameManager` 生成僵王 + 挂血条；删掉 `%ZombossRoot` 与 `ZombossManager` 节点 / 脚本 / 注册表条目。
7. 写 `test/scenarios/probe_zomboss.gd` 跑无头验证。

## 关键决策与理由

- **本体用独立 `Node2D` 而不是 `Zombie000Base`** —— 僵王躯干是 reanim 拆出来的 ~50 个 `Sprite2D`，
  由 23 段动画直接驱动，没有「走 / 啃 / 死」这类能喂给组件状态机的行为，也没有防具分层；
  硬约束 §1 的「角色 = base + 组件」说的是**角色**，僵王对外只需要两个鸭子类型属性
  （`hurt_box_component` / `is_death`）和一个受击签名（`be_attacked_bullet`）就能接进已有链路。
  参考项目就是这么做的，因此**整套推倒**而不是在旧实现上打补丁。
- **保留本仓库的「一个文件只做一件事」**：参考项目把球放在 `src/main_game_item/`，这里按本仓库习惯放
  `src/entities/character/zombie/`；血条 UI 放 `src/ui/main_game_ui/`。
- **受击窗口只在低头期间开** —— 这是原版核心手感；抬头时 `hurt_box` 的 `monitorable` 直接关掉，
  并推 `zomboss_head_vulnerable` 事件让植物重判目标（僵王没有角色状态信号可用）。
- **破损贴图按「已损失血量占比」算**（20% / 50%），不用参考项目写死的 32000 / 20000 —— 重打时 60000 血也能在同节奏上换贴图。
- **球速 120 px/s 而不是参考的 20 px/s** —— 20 px/s 滚完一行要 40 多秒，明显是参考项目的遗留值。

## 踩坑

1. **`preload` 的贴图名对不上** → `Zombie_boss_neck.png` / `Zombie_boss_upperbody.png` 在本仓库不存在
   （这两张源图是 jpg，Godot 侧配套的是 **`Zombie_boss_neck_.png` / `Zombie_boss_upperbody_.png`**，带下划线）
   → **正解**：`preload` 前先 `Get-ChildItem assets/reanim -Filter 'Zombie_boss*'` 核对文件名。
2. **器官理不出来的连锁 Parse Error**：一个 `preload` 失败 → 9 条
   `Compile Error: Failed to compile depended scripts`（`component_detect` / `bullet_000_norm_base` /
   `scary_pot` …都跟着挂）→ **正解**：先修**最上面那条** `Failed to load script`，不要挨个查被牵连的脚本。
3. **参考项目与本仓库的接口对照表**（照着改，别照抄）：
   | 参考项目 | 本仓库 |
   | --- | --- |
   | `Global.ZombieType.Z001Norm` | `CharacterRegistry.ZombieType.Z001Norm` |
   | `Global.AttackMode.Penetration` | `BulletRegistry.AttackMode.Penetration` |
   | `push_error` / `push_warning` | `Log.error` / `Log.warn`（硬约束 §1-6） |
   | `Global.main_game.zombie_manager` 等 | 同名，可直接用 |
   | `zomboss_ball.gd` 位置 | 挪到 `src/entities/character/zombie/` |
4. **`var main_game := Global.main_game` 会 `Parse Error: Cannot infer the type`**（弱类型 autoload 字段）
   → **正解**：写 `var main_game = Global.main_game`（不加 `:=`）。与上一条旧记录的踩坑同源。
5. **探针里 `var x := 容器[0][-1].属性` 无法推断类型** → **正解**：显式写 `var x: float = ...`。
6. **GDScript 的 lambda 对局部变量是值捕获** —— 探针里 `var got := false` + `func(): got = true`，
   回调跑完了外面还是 `false`，误报「僵王死了没出奖杯」→ **正解**：用字典 `var flags := {"trophy": false}`。
7. **驱动 `_do_head_attack()` 前要先等空闲** —— 僵王正在放别的招时它会直接 `return`（`is_busy` 为真），
   探针会一直等不到「受击窗口打开」→ **正解**：先 `while boss.is_busy: await`，再驱动。
8. **首次通关 5-10 掉的是「本关奖励」不是奖杯**（`mgm_reward_manager.create_trophy` 会先走
   `drop_adventure_reward_on_level_complete`）→ 探针不要去场景里搜 `Trophy`，改成订阅 `create_trophy` 事件。

## 给后来者的最简路径

1. 参考项目里有同名实现时，先把它**四处接入点**找全（检测 / 子弹 / 抛物线 / 溅射），漏一处就会「打不到」。
2. 按上面「踩坑」第 3 条的对照表改接口，再跑
   `godot --headless --path . --editor --quit` 一次全量解析 —— 能把 `preload` / `Parse Error` 一次揪干净。
3. 新 `class_name` 不用手改 `.godot/global_script_class_cache.cfg`：跑一次上面的无头编辑器导入，Godot 会自己登记。
4. 验证：`powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_zomboss`。

---

## 补充 / 评价（2026-10-02 · 对旧方案 `Z999Boss + ZombossManager` 的处置）

- **结论**：旧方案**已整套删除**（`zombie_999_boss.gd` / `zm_zomboss_manager.gd` / `zombie_999_boss_ball.gd`
  及其场景、注册表条目 `Z999Boss` + `ZombieRowType.Zomboss`、`%ZombossRoot` / `ZombossManager` 节点）。
- **为什么换**：旧方案为了守「角色 = base + 组件」，把 boss 硬塞进 `Zombie000Base`，结果要关掉移动 / 攻击、
  把受击框换成覆盖躯干的大矩形、还要单开一个 Manager 编排 —— 两边都不彻底。参考项目的独立 Node2D 版本
  出招节奏、受击窗口、碾压范围、死亡演出都更贴近原版，改动反而集中。
- **保留下来的**：`zombie_boss.tscn`（reanim 躯干场景，复用）、球「贴屋面」的 `$y = row_y + slope_y - 半径$` 算法、
  以及「冰火球都碾碎植物」的结论。

---

## 补充 / 评价（2026-10-05 · 「踩坑」第 1 条的结论已作废）

- `_` 结尾的 `Zombie_boss_neck_.png` / `Zombie_boss_upperbody_.png` **不是**「Godot 侧配套的贴图」，
  而是 PVZ 原版 `xxx.jpg` 的**配套黑白蒙版**（白 = 不透明）。引用蒙版会让脖子 / 上身显示成黑白图。
- 正解是先用 `tools/merge_alpha.ps1` 把蒙版烘进 alpha 再引用烘焙后的 `xxx.png`；
  修复过程与最简判据见 [2026-10-05\_移植僵王动画资源.md](2026-10-05_移植僵王动画资源.md) 文末「补充」节。
