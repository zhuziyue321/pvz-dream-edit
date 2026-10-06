<!-- AGENT-DOC: pointer -->
# AGENTS.md —— `test/` 目录指针

> **[面向 AI Agent]** ｜ **触发条件**：要跑自动回归、写探针脚本、或自己启动游戏取运行期证据时
> **读完你能**：知道本目录怎么用（`run_autopilot.ps1` + `scenarios/probe_*.gd`）、真正的验证方式在哪份文档
> **强制级别**：**参考**（纯指针） ｜ **不读的风险**：用无头跑批代替「打开游戏实测」，结论不可信
> **关联**：仓库唯一入口 [../AGENTS.md](../AGENTS.md) ｜ **文档总目录** [../docs/README.md](../docs/README.md) ｜ 调试通道 [../docs/AI调试通道.md](../docs/AI调试通道.md)

本文件**只做指针**：规则正文一律在 `docs/`。

## 动手前必读

| 顺序 | 文档 | 什么时候 |
|----|----|----|
| 1 | [../docs/AI调试通道.md](../docs/AI调试通道.md) | 要自己启动**带窗口的真实游戏**、模拟操作、取回状态 |
| 2 | [../docs/验证流程.md](../docs/验证流程.md) | 交付前判断「要不要验证」+ 人工回归清单（§3） |
| 3 | [../docs/项目规范.md](../docs/项目规范.md) | E-02：自动回归脚本的写法约定 |
| 4 | [../docs/README.md](../docs/README.md) | 找不到某份文档时（**全仓库文档总目录**） |

## 本目录是什么

自动回归与调试工具：

| 文件 / 目录 | 内容 |
|------|------|
| `run_autopilot.ps1` | 跑批入口：`-Scenario <name> -Windowed` |
| `scenarios/probe_*.gd` | 各类探针场景（按主题写一个，不写大而全的） |
| `autopilot*.gd` + `autopilot.tscn` | 自动驾驶框架（输入、时钟、状态、报告） |
| `inject/` | 注入辅助 |
| `debug_channel.bat` / `debug_channel_auto.bat` | 调试通道启动脚本 |

> 仓库**没有**静态检查器（原 `test/verify.ps1` 一套已删除）。无头跑批只证明「跑得完」，**不能**代替打开游戏实测。
