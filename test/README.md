<!-- AGENT-DOC: pointer -->
# test/ —— 自动回归与调试工具

> **[给 AI Agent]** 动手前先看本目录 [AGENTS.md](./AGENTS.md)；仓库文档入口 [../AGENTS.md](../AGENTS.md)，**文档总目录** [../docs/README.md](../docs/README.md)。

`run_autopilot.ps1 -Scenario <name> -Windowed` 跑 `scenarios/probe_*.gd` 探针；`autopilot*.gd` 是自动驾驶框架（输入 / 时钟 / 状态 / 报告），`debug_channel.bat` 启动调试通道。

玩法类改动**仍要打开游戏（带窗口）实测**，无头跑批不能替代 —— 见 [../docs/验证流程.md](../docs/验证流程.md)。
