<!-- AGENT-DOC: human -->
# 🌱 PVZ-Godot-Dream

> **[给 AI Agent]** 本仓库的文档面向 Agent 编写：**动手前请先读 [AGENTS.md](./AGENTS.md)** —— 它是唯一入口，含「按任务路由的文档表」与「硬约束速查」。全部文档地图见 **[docs/README.md](./docs/README.md)**。

用 Godot 复刻原版《植物大战僵尸》的学习 / 同人改版基座。

> **考虑到版权问题，原版素材文件已移除，需自行准备 `assets/`。**

## 当前版本简述

- **引擎与运行**：Godot 4 / GDScript，`gl_compatibility` 渲染，视口 800×600；打开 `project.godot` 即可运行。
- **架构主线**：**数据驱动 + 组件化** —— 主场景只有一份，地图 / 格子 / 僵尸行 / 波次全部由 `ResourceMapData` + `ResourceLevelData` 在运行时装配；角色 = base 场景 + 若干 `ComponentNormBase` 组件，状态本体在组件里，宿主只做转发。
- **已实装内容**：冒险模式 1-1 ~ 5-10（5-10 为僵王博士 Dr. Zomboss：出兵 / 踩踏 / 扔房车 / 空投蹦极 / 冰火球 / 低头受击窗口）、迷你游戏、解谜、生存四类模式，另含僵尸迷阵（含旋风）与僵尸水族馆等衍生玩法。
- **关卡系统**：关卡 = 数据（`.tres`）+ 关卡脚本；卡槽 / 传送带 / 进度条口径 / 场景设置（底图、BGM、昼夜）均可由关卡侧配置或覆盖。玩家自制关卡放 `data/levels/params/`（`ResourceLevelData`，见 `src/levels/core/level_data.gd`）。
- **规模**：`src/` 618 个 `.gd` + 240 个 `.tscn`；`data/` 116 个 `.tres`；`animation/` 505 个 `.tres`；`test/` 103 个 `.gd`（含 95 个自动回归场景）。
- **文档**：面向 Agent 的文档体系（`docs/` 顶层规则 + `docs/参考存档/` 机制说明 + `docs/工作记录/` 逐次任务记录），`src/` `data/` 等目录下另有指针文件。

欢迎在本开源项目基础上做属于自己的 PVZ 同人改版。有兴趣交流可加 QQ 群：**1046565016**。

## 📜 许可协议：Custom Non-Commercial License

本项目为学习作品，仅供个人学习与研究使用，**禁止任何形式的商业用途**，其余条款与 MIT 一致；原作《植物大战僵尸》相关版权归 PopCap Games 及其母公司 Electronic Arts（EA）所有。

🔗 完整条款见 [LICENSE](./LICENSE)

## 🙌 致谢

致敬《植物大战僵尸》原作团队（PopCap & EA）

### 项目贡献

- 植物图鉴初稿整理：[多003\_](https://space.bilibili.com/472181151)
- 宽屏（16:9）的部分素材使用[豆包ai](https://www.doubao.com/chat)生成,感谢ai

### 参考项目

- 樱桃炸弹爆炸动画粒子特效: [HYTommm](https://space.bilibili.com/3493140163988287)开源项目[Godot-PVZ](https://github.com/HYTommm/Godot-PVZ)
- 信号总线,随机选择器: [玩物不丧志的老李](https://space.bilibili.com/8618918)开源项目[godot\_core\_system](https://github.com/LiGameAcademy/godot_core_system)
- 种子雨雨幕：[简单的小雨氛围：shader写的雾、粒子做的雨和水花 | godot4教程](https://www.bilibili.com/video/BV15ibAz4EZi)
