<!-- AGENT-DOC: pointer -->
# test/ —— 自动回归与调试工具

> **[给 AI Agent]** 动手前先看本目录 [AGENTS.md](./AGENTS.md)；仓库文档入口 [../AGENTS.md](../AGENTS.md)，**文档总目录** [../docs/README.md](../docs/README.md)。

`run_autopilot.ps1 -Scenario <name> -Windowed` 跑 `scenarios/probe_*.gd` 探针；`run_all_scenarios.ps1 [-Filter 'probe_*']` 批量跑完并汇总 PASS / FAIL（有失败就非 0 退出，可接 CI）；`autopilot*.gd` 是自动驾驶框架（输入 / 时钟 / 状态 / 报告），`debug_channel.bat` 启动调试通道。

玩法类改动**仍要打开游戏（带窗口）实测**，无头跑批不能替代 —— 见 [../docs/验证流程.md](../docs/验证流程.md)。

`git_hooks/` 两个钩子（硬约束 §1-7 与 [V-02](../docs/参考存档/规范细则存档.md) 的自动化落点），**均已复制到本机 `.git/hooks/`**：

- **`pre-push`**：推送前跑 `check_scripts.ps1`，不过不让推。
- **`pre-commit`**：拦住明确不该入库的东西 —— 危险文件名（终端重定向产物 / `*.tmp` / `error_log.txt` / `package*.json` / 调试日志 / 跑批临时物）、孤儿 `.uid`、单文件 > 5 MB；一次暂存 > 30 个文件时打印提醒（不拦）。
  它**不做**「路径是否属于本次任务」的判断（钩子拿不到那个输入），那部分仍靠 V-02 人工自检。

换机器 / 重克隆后重做一次：`cp test/git_hooks/pre-commit test/git_hooks/pre-push .git/hooks/`，或 `git config core.hooksPath test/git_hooks`。
跳过单次检查：`git push --no-verify` / `git commit --no-verify`。

`tools/check_doc_facts.ps1`（H-09）：把文档里声称的数字与链接与实测对账，输出「声称 vs 实测」表，有差异即 exit 1。**该脚本带 UTF-8 BOM**（PS 5.1 读无 BOM 脚本按 ANSI，中文会变乱码 —— 见 [AI调试通道.md §七](../docs/AI调试通道.md)）。

> 本仓 `assets/` **在版本控制内**（`git ls-files assets` 有 5339 个文件），云端 CI 技术上可行；
> 当前只做本地钩子是因为更快、无需 runner —— 先前记的「assets 不入库所以跑不了 CI」**已更正**。
