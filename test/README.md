<!-- AGENT-DOC: pointer -->
# test/ —— 自动回归与调试工具

> **[给 AI Agent]** 动手前先看本目录 [AGENTS.md](./AGENTS.md)；仓库文档入口 [../AGENTS.md](../AGENTS.md)，**文档总目录** [../docs/README.md](../docs/README.md)。

`run_autopilot.ps1 -Scenario <name> -Windowed` 跑 `scenarios/probe_*.gd` 探针；`run_all_scenarios.ps1 [-Filter 'probe_*']` 批量跑完并汇总 PASS / FAIL（有失败就非 0 退出，可接 CI）；`autopilot*.gd` 是自动驾驶框架（输入 / 时钟 / 状态 / 报告），`debug_channel.bat` 启动调试通道。

玩法类改动**仍要打开游戏（带窗口）实测**，无头跑批不能替代 —— 见 [../docs/验证流程.md](../docs/验证流程.md)。

**探针的两类分工**（2026-10-16 补，见 [TODO清单.md](../docs/TODO清单.md) 的 H-10）：

- **结构 / 流程探针**（现有绝大多数）：证明「对象按预期建出来了」；
- **玩法链路探针** `scenarios/probe_gameplay_core.gd`：证明「打起来了」—— 种豌豆射手 → 索敌开火 → 子弹命中掉血 → 死亡信号 + 尸体离场。无头约 40 秒，是「改动触达角色 / 子弹 / 伤害管线」时的低成本回归。
  **写检查必须自证拦得住**：把 `bullet_registry.create_bullet()` 临时改成 `return null` 再跑，它**必须** FAIL（2026-10-16 实测：`血量 270 -> 270（掉 0）` → `result=FAIL`）。

`git_hooks/` 两个钩子（硬约束 §1-7 与 [V-02](../docs/参考存档/规范细则存档.md) 的自动化落点），**均已复制到本机 `.git/hooks/`**：

- **`pre-push`**：推送前跑 `check_scripts.ps1`，不过不让推。
- **`pre-commit`**：拦住明确不该入库的东西 —— 危险文件名（终端重定向产物 / `*.tmp` / `error_log.txt` / `package*.json` / 调试日志 / 跑批临时物）、孤儿 `.uid`、单文件 > 5 MB；一次暂存 > 30 个文件时打印提醒（不拦）。
  「根目录零散点文件」那一项带**放行名单** —— 仓库自身的 `.gitignore` / `.gitattributes` / `.editorconfig` / `.gdignore` 不算危险文件（2026-10-16 修过一次误拦：改 `.gitignore` 反被自己挡住）。
  它**不做**「路径是否属于本次任务」的判断（钩子拿不到那个输入），那部分仍靠 V-02 人工自检。

换机器 / 重克隆后重做一次：`cp test/git_hooks/pre-commit test/git_hooks/pre-push .git/hooks/`，或 `git config core.hooksPath test/git_hooks`。
跳过单次检查：`git push --no-verify` / `git commit --no-verify`。

`tools/check_doc_facts.ps1`（H-09）：把文档里声称的数字与链接与实测对账，输出「声称 vs 实测」表，有差异即 exit 1。**该脚本带 UTF-8 BOM**（PS 5.1 读无 BOM 脚本按 ANSI，中文会变乱码 —— 见 [AI调试通道.md §七](../docs/AI调试通道.md)）。

`tools/check_content_wiring.ps1`（H-14①）：把「新增一个角色要动哪几处」的纪律机械化 —— 遍历 `PlantIds.ALL` / `ZombieIds.ALL`，逐个校验「注册表数值表（`PLANT_INFO` / `ZOMBIE_INFO`）有条目 + 场景 preload 文件存在」，缺一项即 exit 1。写它时按 H-09 教训做了注入验证（把某个场景路径改坏 → `FAIL plant PEA_SHOOTER_SINGLE: scene missing`）。已知例外：植物 `WATER_BOWL`（运行期由模组注入的空槽位，故意不在数值表）。⚠️ 原方向里的「动画目录存在」**未做** —— 动画目录命名与 id 非简单对应，需先确认约定再补，避免假绿检查。

> 本仓 `assets/` **在版本控制内**（`git ls-files assets` 有 5339 个文件），云端 CI 技术上可行；
> 当前只做本地钩子是因为更快、无需 runner —— 先前记的「assets 不入库所以跑不了 CI」**已更正**。

**云端 CI**（2026-10-16 新增，TODO 清单 H-11）：`.github/workflows/ci.yml` 在 runner 上跑「编译门禁 + 快子集探针」。
⚠️ **该文件尚未在 runner 上实跑过**（本地无法验证 runner 环境），首次推送后请按文件头的「验证方法」确认再摘警告；
在此之前，**唯一被实跑验证过的门禁仍是本机 `pre-push` 钩子**。
