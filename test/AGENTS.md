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
| `run_autopilot.ps1` | 跑单个探针：`-Scenario <name> -Windowed`（无头 = CI 回归，带窗口 = 排查） |
| `run_all_scenarios.ps1` | **批量回归**：按 `-Filter` 跑完一批探针，汇总 PASS / FAIL / DONE / ERROR，有 FAIL / ERROR 就非 0 退出（**必须串行**，见脚本头注释） |
| `run_netplay_pair.ps1` | **双进程联机实测**：起两个 headless 实例连 localhost（主机 + 客户端），约 4 分钟。联机类改动**只有它验得到**「主机推事件 ⇒ 发命令 ⇒ 客户端重建」这一段（单进程里 `rpc()` 无对端时**不本地回调**） |
| `scenarios/probe_*.gd` | 各类探针场景（按主题写一个，不写大而全的） |
| `scenarios/tool_compile_scenarios.gd` | 把 `test/scenarios/*.gd` 逐个 `load()` 一遍 —— **补编译门禁的洞**：`check_scripts.ps1` 走 `--import`，覆盖不到运行期按路径加载的探针 |
| `scenarios/tool_semantic_scan.gd` | 语义扫描：沿继承链核对每个「裸调用」是否真存在 —— **补编译门禁的第二类洞**（`--import` 不做方法调用解析，`portal_manager.gd` 曾用这招溜过去）。用法：`godot --headless --path . --script res://test/scenarios/tool_semantic_scan.gd`，结果写到 `test/_semantic_scan_result.txt`（已 gitignore）。**⚠️ 已知会误报**：内置函数名单是手写的，漏一个就会把好代码报成问题 —— 报出来先自己确认一眼 |
| `autopilot*.gd` + `autopilot.tscn` | 自动驾驶框架（输入、时钟、状态、报告） |
| `inject/` | 注入辅助 |
| `debug_channel.bat` / `debug_channel_auto.bat` | 调试通道启动脚本 |

> 仓库**没有**静态检查器（原 `test/verify.ps1` 一套已删除）。无头跑批只证明「跑得完」，**不能**代替打开游戏实测。
