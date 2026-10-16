<!-- AGENT-DOC -->
# Agent 协作协议（多 agent 并行开发）

> **[面向 AI Agent]** ｜ **触发条件**：任何一次「多个 agent 同时改这套仓库」的任务（spawn worker 之前必读）
> **读完你能**：给每个 agent 划清所有权分区与枚举编号段配额，知道 hub 文件只能由 main 改、验证（打开游戏）必须串行
> **强制级别**：**必须**（并行开发时） ｜ **不读的风险**：后写入者静默覆盖前人改动、枚举插入互撞、多个窗口同时跑游戏争抢 `.godot/` 导致误报
> **关联**：仓库入口 [../AGENTS.md](../AGENTS.md) ｜ 文档地图 [README.md](README.md)

> 适用范围：任何一次「多个 agent 同时改这套仓库」的任务。
> 目的：让并行开发**不丢工作、不静默互相覆盖、合并不爆**。
> 与本仓库其他文档的关系：
> - 怎么写代码 → [项目规范.md](项目规范.md)
> - 验证怎么跑 → [验证流程.md](验证流程.md)（打开游戏实测；改动较小可免验证）
> 本文只写「多 agent 之间如何划清边界」。

---

## 0. 冲突模型（先看清敌人）

本仓库**没有**语言级的「自动注册」（GDScript 的 `enum` 不能跨文件追加），
所以「加一个新植物 / 新僵尸 / 新子弹」会**被迫回写同一个中心文件**。
多 agent 并行时，真正的冲突源只有两类：

1. **共享 hub 文件**：多个 agent 编辑同一个文件的不同区域，最后写入者胜、前面的改动被静默覆盖。
2. **中心枚举插入**：`MainSceneRegistry.MainScenes` 等 int 枚举在语义上是一个整体，
   但物理上是一行一行的字面量，两个 agent 在同一段内插入就会撞。
   （植物 / 僵尸 / 僵王 / 子弹 2026-10-13~14 已改成 StringName id，见 §3，不再有这一类的冲突。）

本协议的两条对策正好一一对应：
- 对策 A（§2 所有权分区）：给每个 agent 分配**互不重叠的目录/文件** → 消除第 1 类。
- 对策 B（§3 编号段配额）：给每个 agent 预留**互不重叠的枚举编号段** → 消除第 2 类。

> 只要两条都满足，多个 agent 可以安全地在**同一工作树**里同时编辑，无需为每个 agent 单独建仓库。

---

## 1. Git 工作流（P0 前提）

已执行 `git init` 并建立基线提交，可随时 `git stash` / `git reset --hard <基线>` 回滚。
`.gitignore` 已正确忽略 `.godot/`、`test/_userdir/`、`agents.state.json` 等本地物。

**分支约定**

- 主 agent（maintainer）长期在 `main` 分支。
- 每个 worker 开工前由 main 切出独立分支：`agent/<任务>-<编号>`（如 `agent/plant-pack-a`）。
- worker 只在自己的分支 + 自己的所有权分区内改。
- worker 完成后，**不自行**合并、不自行跑完整验证，统一交给 main 评审合并。

**更强的隔离（可选）**：若 runner 能为每个 agent 提供独立沙箱，用 git worktree 更彻底：

```powershell
git worktree add ../pvz-agent-a agent/plant-pack-a
```

每个 worktree 独立 `.godot/` 缓存，互不争抢（见 §4 关于验证串行化的说明）。

**禁止**

- 禁止在 `main` 之外直接 `git push` 到任何远端（本仓库默认无远端，纯本地协作）。
- **禁止用 `git add -A` 或通配符暂存**：`'./*.md'` 这类写法在 git pathspec 里 `./` 会被规范化掉，`*.md` **跨目录匹配**，会把无关文件一并暂存。一律**逐路径** `git add -- <文件>`，提交前看 `git diff --cached --name-status`（见 [V-02](../参考存档/规范细则存档.md#v-02-提交前自检清单)）。
- 禁止提交 `.godot/`、`test/_userdir/`、`*.tmp` —— 已被 `.gitignore` 挡住，但仍要自查 `git status --short`。
- 禁止 `git commit --amend` 改写已交给 main 的历史。

### 1.1 开工声明：让并行的人看得见

> **本文档原来只管「怎么划边界」，管不了「怎么看见对方」。** 这一节补上后者。

**背景（2026-10-16 实际踩到）**：两个会话在同一工作树上并行时**彼此完全不可见** —— 一方 `git add` 之后另一方发现暂存区里冒出陌生文件；一次误用通配符 `git add` 更把 4 个与本次任务无关、属于另一个会话的文档一起暂存并提交（已 `git reset --soft HEAD~1` 掉头重做）。

**要求**

- **开工第一步**：`git status --short`，把每个改动标成「我的 / 不是我的」。**不是我的一个都不碰**（不改、不暂存、不提交、也不还原）。
- **建议**开工时留一处**能被看见的声明**（写在 `docs/工作记录/` **之外**，避免污染该目录的索引体系）：谁 / 在改哪些目录或文件 / 起始时间；收工或合并后删掉。不需要精确，只需要可见。
- **发现暂存区里有不属于自己的文件**时，**不要** `git restore --staged .` 一锅端（会连带撤掉别人的暂存）；改用 `git commit -- <只列自己的路径>` 精确提交。
- **同一文件里混有别人的改动**时（例如 `docs/工作记录/README.md` 正被对方改、你又要补索引行）：**不要提交该文件**，把「待补」写进自己的记录文件，等对方落盘后再补。

---

## 2. 冲突热点与所有权分区

### 2.1 绝对 hub（多个 agent 都会想碰，必须由 main 独占或严格锁）

| 文件 | 行数 | 被引用 | 所有者 | 并行策略 |
|------|------|--------|--------|----------|
| `src/core/autoload/character_registry.gd` | 545 | 多 | **main 独占** | 仅枚举插入走 §3 配额；数据字典（P2）后续搬出后再下放 |
| `src/core/autoload/bullet_registry.gd` | 163 | 多 | **main 独占** | 子弹 id 已改 StringName（2026-10-13），只在 `BulletIds` + `BULLET_SCENE_PATHS` 各加一行，**不再占编号段** |
| `project.godot`（autoload / layer 段） | — | 全体 | **main 独占** | 新 autoload 一律 main 加 |
| `src/core/autoload/all_cards.tscn` | — | 全体 | **main 独占** | 新卡片预制 main 登记 |
| `src/managers/main_game_manager.gd` | 805 | 多 | main 为主 | 改波次/关卡先和 main 对齐 |
| `test/scenarios/`（行为回归探针） | — | — | **main 独占** | worker 需要新探针时交给 main |

> 这些文件**不要分配给 worker**。worker 若需要登记新单位，把「枚举名 + 编号」按 §3 配额占好位后，
> 由 main 统一写进 registry —— 或先把条目留言给 main，等 P2 数据外移后改为「新增一个文件」即可下放。

### 2.2 天然安全区（可直接下放给任意 agent，互不重叠即零冲突）

- `src/entities/character/plant/plant_NNN_*.gd` 与同名 `src/entities/character/plant/`、`data/character/`
- `src/entities/character/zombie/zombie_NNN_*.gd` 与对应 `src/`、`data/`
- `src/entities/character/components/<功能域>_component/` 下的不同功能域目录
- `src/entities/bullet/`（按 `bullet_NNN_*.gd` 拆）
- `src/entities/character/components/*_component/`、各 UI/界面域（`ui/`、`store/`、`almanac/`、`garden/`、`start_menu/`）
- `src/`、`animation/`、`data/` 中按单位/资源各自独立的子目录

**铁律**：一个 agent 拥有某个 `plant_NNN` 后，该编号对应的 `.gd`、`.tscn`、`.tres`、`.uid` 全部归它，
别的 agent 不得动同一单位。跨单位的能力（组件）若被多个单位复用，则归**定义该组件的 agent**，调用方只读。

---

## 3. 编号段配额（治标关键，零代码改动即可生效）

中心枚举是「一行一个成员」的字面量。给每个 agent 预留**互不重叠的编号段**后，
插入点天然分散，git 三方合并对非重叠 hunk 自动合并，不再冲突。

reserved 段（按本仓库现状）：

- 植物：`P001–P048` 已用；`P999` 模仿者、`P1000` 萌芽、`P1001` 保龄球 特殊占用；
  `1000` 段全段预留给小游戏/特殊模式（见 项目规范 D-02）。
- 僵尸：`Z001–Z024` 已用；`Z999` boss 特殊占用。
- 子弹：**不再有编号**（2026-10-13 起 id 是 StringName，见 `BulletIds`）。新增子弹只在
  `BulletIds` 加一个语义常量，天然不撞段，**不需要配额**。

**默认配额表**（开工前由 main 按实际 agent 数调整，填进下表）：

> 2026-10-14 起**植物 / 僵尸 / 僵王编号也改成了 StringName id**（`PlantIds` / `ZombieIds` /
> `ZombieBossIds`，和 10-13 的子弹同一套做法）：加一只新植物 / 僵尸 = 在 id 表里加一个常量，
> **天然不撞段，不需要配额**。下表只留给还在用 int 编号的中心枚举（如 `MainScenes`）。

| Agent | 植物 | 僵尸 | 子弹段 | 负责的组件功能域 |
|-------|------|------|--------|------------------|
| A | — 不占段 | — 不占段 | — 不占段 | `attack_behavior_component/` |
| B | — 不占段 | — 不占段 | — 不占段 | `detect_component/` |
| C | — 不占段 | — 不占段 | — 不占段 | `bullet/movement/` |
| D | — 不占段 | — 不占段 | — 不占段 | `fx/`、`camera/` |

**编号段使用规则（硬约束）**

1. 枚举值**一旦分配，不得跨段**：agent A 绝不给 `P071` 起名字，即使自己段满了也先找 main 扩段。
2. 每个新单位只占用自己段内**当前最小空闲编号**，不要跳号制造空洞（便于后续 agent 续接）。
3. 枚举插入位置：GDScript 枚举成员顺序无所谓，插在各自段的连续区块即可；
   多 agent 在同一文件不同段插入 → git 自动合并无冲突。
4. 若任务需要跨段（例如某僵尸需要一种新建子弹），该子弹 id 由**拥有僵尸的 agent** 加进 `BulletIds`
   —— 字符串 id 按语义命名，天然不会撞，不需要分段。

> §3 是「今天就能用」的止血方案。彻底方案（把 `PlantInfo`/`ZombieInfo` 字典外移为按单位的数据文件）
> 见 项目规范 §9 / M-03，列入 P2，等基线稳定后再做。

---

## 4. 交付与验证约定（已选：串行化，主 agent 统一验证）

**决策**：多个游戏实例 / 编辑器扫描同时跑会争抢 `.godot/` 缓存与导出产物，因此采用**串行化**：

- **worker 禁止自行跑整轮验证**。改动较小 / 确定不会出问题 → **免验证**（见 [验证流程.md](验证流程.md) §1）；
  确实要开游戏时，确认不和其他 agent 同时跑。
- worker 完成其所有权分区后，把改动交给 **main**。
- **main 在合并后、一次只开一个游戏实例验证**：

```powershell
powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario <name> -Windowed
```

- 任一 worker 改动触达「扩展点类」逻辑（新增组件、手持物、关卡、能力）时，main 还需按
  [验证流程.md](验证流程.md) §3 人工回归清单在真窗口里确认。
- 递归爆栈、autoload 初始化顺序这类故障只有真跑才暴露 —— 拿不准就不要判「免验证」。

**为什么串行**：打开游戏本身会写 `.godot/` 与临时导出物；并发会互相干扰导致误报。
串行化以「一点延迟」换「零争抢、结果可信」。

**2026-10-04 实测的并发坑（跑批那一个就不用 `run_autopilot.ps1` 的默认临时目录）**：
`test/run_autopilot.ps1` 的 stdout / stderr / 用户目录**三样都是固定的**
（`%TEMP%\pvz_autopilot\ap_out.txt` 与 `...\userdir\`，脚本里写死，不能传参）。
两个 agent 同时跑批时：

- 后启动的那次会把前一个的 `ap_out.txt` **覆盖**，先跑完的 agent 读回来的是别人的报告
  （表现为「我的场景怎么变成了 `probe_column_mode.gd`」、`exitCode` 也对不上）；
- 两个游戏实例共用同一份用户目录，**互相覆盖存档**；
- 谁先 `--import` 谁后 `--import` 会把另一个正在编辑期的中间状态写进
  `.godot/global_script_class_cache.cfg`，出现「XXX 类型找不到」的假报错。

串行不了的时候（并行任务各自要验证），**给自己一份隔离的临时目录**，别碰共享那份：

```powershell
$tmp = "$env:TEMP\pvz_<自己任务的代号>"
New-Item -ItemType Directory -Force -Path "$tmp\userdir" | Out-Null
$old = $env:APPDATA; $env:APPDATA = "$tmp\userdir"
$godot = "C:\Users\a a\Desktop\Godot_v4.6.2-stable_win64.exe"
$proj  = "c:\Users\a a\Desktop\Dream"
cmd.exe /c "`"$godot`" --path `"$proj`" -- --scenario=res://test/scenarios/<探针>.gd --autopilot-max-seconds=240 > `"$tmp\out.txt`" 2> `"$tmp\err.txt`""
$env:APPDATA = $old
Get-Content "$tmp\out.txt" -Encoding UTF8
```

等价于 `run_autopilot.ps1 -Windowed`（没有 `--headless` 就是带窗口），只是三样 Writable 的东西都换成自己的。

---

## 5. 多 agent 下最容易踩的红线（强制）

1. **M-01 改名/移动必须连 `.uid` 一起，且先关 Godot 编辑器**。
   每个 `.gd` 都伴随同名 `.uid`；编辑器开着批量重命名会把瞬时消失的 `.uid` 当孤儿删掉
   （本仓库曾一次被删 17 个）。worker 移动文件前**先关编辑器**，并用 `git mv` 自动带走 `.uid`。
2. **禁止跨段改枚举**（见 §3 规则 1）—— 这是多 agent 冲突的头号来源。
3. **禁止 worker 改 §2.1 的 hub 文件**，确有需要走 main。
4. **禁止裸 `print()`**（项目规范 S-02，靠评审 + 看控制台）；一律 `Log.*`。
5. **禁止字典直接下标读取可能缺键的字段**（S-06），一律 `.get()` / `PlantCell.get_plant()`。
7. **禁止组件用 `get_parent()` 抓宿主改字段**（K-03，红线第 3 条），反向引用宿主用内建 `owner`。

> **排版项不是红线**：4 空格缩进 / BOM / CRLF / 行尾空格（对应 S-01）
> 按 [E-06](参考存档/规范细则存档.md#e-06-细枝末节规则的强制级别判定) 判为参考 —— 排版只影响观感，见 [参考意见存档.md](参考意见存档.md) R-01。

---

## 6. 接入清单（spawn 一个 agent 前，main 填好这一张）

每开一个 worker，把以下信息写进它的系统提示 / 任务描述：

```
文档入口:          ../AGENTS.md（先读）+ docs/README.md（文档地图）
Agent 标识:        A / B / C / D
所有权分区:        src/entities/character/plant/plant_05x_* 等（列具体目录）
编号段:            植物 / 僵尸 / 子弹都是 StringName id，不占段（各 id 表加常量即可）
负责组件域:        attack_behavior_component/
禁止触碰(hub):     character_registry.gd / bullet_registry.gd / project.godot / all_cards.tscn / test/scenarios/
需要 main 代办:    枚举登记、autoload、卡片注册、探针登记
验证方式:          改动较小可免验证；要验证不自跑，完成后交 main 串行打开游戏验证
```

> 把这张表存进 `docs/`（或团队的任务看板）并随 agent 数更新；§3 配额表与之同步。

---

## 附录：现状速查（2026-10-16 实测）

- `src/`：**643** 个 `.gd` + **239** 个 `.tscn`。**规模数字的唯一来源**在 [架构总览.md §15](../架构总览.md)，本节不复制（[E-08](../参考存档/规范细则存档.md)）。
- 最大业务脚本（总行数含空行与注释）：`items/plant_cell.gd` **921**、`levels/core/level_data.gd` **817**、`managers/zombie_manager/zombie_manager.gd` **725**；完整表见架构总览 §15.1。
- autoload 单例 **11** 个：`Log` `Global` `SoundManager` `SceneRegistry` `AllCards` `GlobalUtils` `EventBus` `DamageSystem` `TreePauseManager` `ModManager` `DebugChannel`（口径 = `project.godot` 的 `[autoload]` 段）。
- 验证方式：**编译门禁必过**（`test/check_scripts.ps1`，已挂本地 `pre-push` 钩子 —— 见 `test/git_hooks/pre-push`）；**打开游戏（带窗口）实测为建议**，改动较小 / 确定不会出问题 → 不开。
- 红线见 [项目规范.md](项目规范.md) §1（**8** 条）；仓库已无静态检查器，靠评审 + 打开游戏实测兜底。

> **本节的命名口径已过时**：§2.2 / §3 里写的 `plant_NNN_*.gd` / `zombie_NNN_*.gd` 是**编号入文件名**时代的写法。
> 现在**编号是注册表 id，不写进文件名**（`plant_pea_shooter_single.gd` 这样），且植物 / 僵尸 / 僵王 / 子弹 id 已全部改为
> StringName（`PlantIds` / `ZombieIds` / `ZombieBossIds` / `BulletIds`），§3 的编号段配额对它们**不再适用**（见该节 2026-10-14 的补充说明）。
> 读 §2.2 / §3 时把 `*_NNN_*` 理解为「按单位各自独立的文件」，其余结论仍成立。
