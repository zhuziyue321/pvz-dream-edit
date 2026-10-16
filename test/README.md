<!-- AGENT-DOC: pointer -->
# test/ —— 自动回归与调试工具

> **[给 AI Agent]** 动手前先看本目录 [AGENTS.md](./AGENTS.md)；仓库文档入口 [../AGENTS.md](../AGENTS.md)，**文档总目录** [../docs/README.md](../docs/README.md)。

`run_autopilot.ps1 -Scenario <name> -Windowed` 跑 `scenarios/probe_*.gd` 探针；`run_all_scenarios.ps1 [-Filter 'probe_*']` 批量跑完并汇总 PASS / FAIL（有失败就非 0 退出，可接 CI）；`autopilot*.gd` 是自动驾驶框架（输入 / 时钟 / 状态 / 报告），`debug_channel.bat` 启动调试通道。

玩法类改动**仍要打开游戏（带窗口）实测**，无头跑批不能替代 —— 见 [../docs/验证流程.md](../docs/验证流程.md)。

`git_hooks/pre-push`：推送前自动跑 `check_scripts.ps1` 的钩子（硬约束 §1-7 的自动化落点）。
已复制到本机 `.git/hooks/pre-push`；换机器后重做一次：
`cp test/git_hooks/pre-push .git/hooks/pre-push`，或 `git config core.hooksPath test/git_hooks`。
**本仓 `assets/` 不入库，云端 CI 跑不了这道门禁**（引用不到贴图会假红），故只做本地钩子。
