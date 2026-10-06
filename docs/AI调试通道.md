# AI 调试通道（打开游戏调试）

> **[面向 AI Agent]** ｜ **触发条件**：需要运行期取证 —— 复现 / 排查「静态检查与无头跑批都看不出来」的游戏行为问题  
> **读完你能**：用**带窗口的真实游戏**取证（F5 开关注入 或 `-Windowed`），知道报告落在哪、怎么读，也知道无头跑批为什么不能用来回答「有没有问题」  
> **强制级别**：按需（取证时必读） ｜ **不读的风险**：把无头跑批的绿色结果当成「玩得通」，漏掉只在真窗口里才暴露的问题  
> **关联**：仓库入口 [../AGENTS.md](../AGENTS.md) ｜ 文档地图 [README.md](README.md)

给 AI/CI 用的「静默驾驶舱」：**自己打开游戏、模拟玩家操作、取回结构化状态**。  
游戏写出的文件与 stdout AI 直接读，不需要人工转交日志。

---

## 〇、第一原则：排查一律打开游戏（带窗口）

**只要是在排查游戏行为问题，一律带窗口启动真实游戏。**  
无头（`--headless`）跑批只作 CI 回归门禁，不是排查手段。

|       | **打开游戏（带窗口）** ← 本文件主力                   | 无头跑批（CI 回归）                                                                     |
| ----- | --------------------------------------- | ------------------------------------------------------------------------------- |
| 启动方式  | F5 开关注入 / `run_autopilot.ps1 -Windowed` | `run_autopilot.ps1 -Scenario xxx`（默认 `--headless`）                              |
| 视口    | 真实窗口尺寸                                  | **假视口**：根视口是 (0,0)，autopilot 只能强设 `800x600`（`autopilot.gd::HEADLESS_VIEWPORT`） |
| 画面    | 有。渲染层级 / 可见性 / 置灰 / 箭头 / 虚影都能看          | **没有任何画面**，只能读数字                                                                |
| 时序    | 垂直同步、真实帧率                               | 帧率不受限（fps 140+），按帧数写探针会跑得过短                                                     |
| 结论意义  | **「能玩」**                                | 「能跑完 + 探针断言过」                                                                   |
| 用来干什么 | **排查 / 复现 / 判定能不能交付**                   | 只输出 `[XXX] result=PASS` 给 CI 门禁                                                 |

### 为什么「原来的脚本很难发现问题」

1. **无头是假环境**：没有窗口，根视口 `(0,0)` 只能被强设成一个假尺寸，  
   帧率不受垂直同步约束，与真机不是同一套时序  
   （`DebugChannel` 的自动关卡就明确写着「用时间而不是帧数：无头帧率不受限，按帧数算会跑得太短」）。
2. **探针只回答它被问到的问题**：`result=PASS` 是脚本自己写的断言算出来的。  
   脚本没想到的事（点了但没生效、UI 被盖住、东西画到屏幕外、动画没播完、提示不弹）  
   全部**静默通过**，报告一片绿。
3. **只能读数字，不能看画面**：不少「不对」是**看出来的**，不是断言出来的。
4. **最容易坏的地方恰好是两边不一致的地方**：相机入场、坐标命中、渲染层级、  
   卡片与手持物的跟随 / 虚影 / 置灰反馈。

> 一句话：**无头证明「没崩」，打开游戏才能证明「能玩」。**

### 什么时候才允许用无头

只有一种场合：**CI 门禁里的自动回归标记**（`probe_*.gd` 输出的  
`[XXX] result=PASS`）。它的绿色结果**不能**用来回答「这次改动有没有问题」。

---

## 一、怎么「打开游戏」

三种方式，都**带窗口**，按用途选：

| 方式                            | 怎么起                                         | 窗口 | 跑完                    | 报告落哪                                              |
| ----------------------------- | ------------------------------------------- | -- | --------------------- | ------------------------------------------------- |
| **A. 编辑器 F5 + 开关文件**（首选：边看边调） | 让 `test/inject/scenario.gd` 就位，编辑器里按 F5     | 有  | **停止驾驶，窗口留着**，控制权交还玩家 | `res://test/inject/report.txt`                    |
| **B. 命令行带窗口**（脚本驱动的一遍过）       | `run_autopilot.ps1 -Windowed -Scenario xxx` | 有  | **自动退出**（除非脚本显式要求留窗口） | stdout（PS 打屏）+ `user://autopilot_reports/`        |
| **C. 只看不驱动**（纯人工上手玩）          | 双击 `test/debug_channel.bat`                 | 有  | 手动关窗口                 | `debug_channel_log.txt` + `user://debug_reports/` |

### 方式 A：编辑器 F5 + 开关文件（推荐）

游戏启动后由自动加载单例 `DebugChannel` 把 autopilot 挂进场景树执行  
`res://test/inject/scenario.gd`。**有窗口时跑完不关窗口**，可以直接接着玩 / 看现场。  
开关文件默认是收起来的状态，恢复见第二节。

### 方式 B：命令行带窗口

```powershell
powershell -ExecutionPolicy Bypass -File test\run_autopilot.ps1 -Windowed -Scenario probe_plant
```

`-Windowed` 就是**去掉 `--headless`** —— 真实窗口打开、真实渲染、真实时序，  
autopilot 照样自动操作并把报告打屏（同时落 `user://autopilot_reports/`）。

> ⚠️ **`-Windowed` + `res://test/inject/scenario.gd` 会一直挂住 PowerShell**：  
> 那个路径属于「注入模式」，`_keep_window()` 为真 → 跑完只停止驾驶、**不退出**，  
> `cmd` 会阻塞到你手动关掉游戏窗口。要脚本驱动一遍过就用普通 `probe_*.gd`；  
> 想留窗口就用方式 A，或让脚本自己 `a.quit_game()`。

> ⚠️ **不要把 `res://test/autopilot.tscn` 当启动场景传进去**（也不要传 `-Scenario` 之外的场景参数）。  
> 那样启动的是 autopilot 场景本身，**主菜单 / 选关根本不存在**，  
> 所有走菜单的场景脚本第一步就超时（2026-09-30 踩过，白跑一轮）。  
> 正确做法是启动**真实主场景**，让 `DebugChannel` 注入。

### 方式 C：只看不驱动（纯人工玩）

双击 `test/debug_channel.bat`：游戏正常启动，你自己玩，想记录现场时按 **F10**  
写一份状态快照，玩完关窗口，`debug_channel_log.txt` 里同时有 Godot 全部输出与结构化报告。

### 标准调试动作

1. **打开游戏**（方式 A 或 B）。
2. 复现问题：让脚本走到那一步，或自己上手操作。
3. 取证：读报告行（`a.log` / `a.dump` / `a.observe` / `a.probe_hover`），  
   需要实时现场就按 **F10**。
4. 改场景脚本 → 重跑（A 方式按 F5，B 方式重发命令）。
5. 结论**必须能对上报告里的某一行**；对不上就说明还没取到证。

---

## 二、注入的两个触发条件

`DebugChannel` 注入 autopilot 有两个**互相独立**的条件，满足任意一个就注入：

### 1. 开关文件（编辑器里人工按 F5）

存在 **`test/inject/scenario.gd`** 时，游戏启动后由自动加载单例 `DebugChannel`  
把 autopilot 挂进场景树执行它。报告写到 **`test/inject/report.txt`**。  
**有窗口时**跑完不关窗口，控制权交还玩家；无头时跑完直接退出。

### 2. 命令行（`--scenario=`）

命令行给了 `--scenario=` 就注入，**不依赖那个开关文件** ——  
所以「注入关着」也能跑，两者互不牵扯。  
**排查请加 `-Windowed`**；不带就是无头回归。

### 3. 都不触发（正常游玩）

没有开关文件、命令行也没有 `--scenario=` → `DebugChannel` 回到默认静默。

---

## 三、启用 / 关闭

| 目的                   | 操作                                                                                                                                                             |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **打开游戏调试（推荐）**       | 把 `test/inject/scenario.gd.off` 改回 `scenario.gd`，`scenario.gd.off.uid` 改回 `scenario.gd.uid`，编辑器里按 F5                                                           |
| **关闭 F5 注入（恢复正常游玩）** | 两个文件一起改名成 `.off` / `.off.uid` ← **收工时回到这个状态**                                                                                                                  |
| **命令行驱动一次（窗口可见）**    | `run_autopilot.ps1 -Windowed -Scenario <名字>`，与开关文件无关                                                                                                           |
| **无头 CI 回归**         | `run_autopilot.ps1 -Scenario <名字>`（默认无头），**只作门禁，不作排查**                                                                                                         |
| **本次不注入（脚本/检查用）**    | 命令行加 `-- --no-autopilot`                                                                                                                                       |
| 完全移除                 | 删 `project.godot` 里 `DebugChannel=...` 那行 + 删 `src/core/autoload/debug_channel.gd` + 删 `test/autopilot*`(`autopilot.gd` 与 `autopilot_*.gd` 五个模块)、`test/inject/` |

> `.uid` **必须跟着一起改名**。只改 `.gd` 会让 `scenario.gd.uid` 变成孤儿文件，  
> Godot 编辑器可能把它当孤儿删掉（改名后自己确认一遍 `.uid` 还在）。

`--no-autopilot` 是给「启动场景但不是玩游戏」的场合用的：不加会把 autopilot 注进去，  
与被启动的场景互相打架（历史上曾因此直接崩，exit `0xC0000005`）。

关闭后每次启动只做一次 `ResourceLoader.exists()` + 一次命令行扫描，无副作用。

---

## 四、API

场景脚本是 `RefCounted`，实现 `func run(a) -> void`。

```gdscript
a.log("文本")                    # 一行日志
await a.dump("标签")             # 完整状态快照
await a.observe("标签", 格子路径) # 一行紧凑观测：僵尸行号/x/血量、目标格植物、节点数
await a.wait(秒) / await a.frames(n)
await a.nodes("名字", true)      # 按【节点名】列节点（侦察用）
await a.click_first("路径片段")   # 按【完整路径】点第一个可见可点控件
await a.press_first("路径片段")   # 直接触发 pressed（绕过命中测试，最可靠）
await a.wait_stable("路径")      # 等控件停止移动（动画播完）再继续
await a.click(x, y)             # 真实鼠标事件 + Input.warp_mouse
await a.click_node("路径")       # 点某个 Control 的【屏幕中心】
await a.click_plant_cell(row, col)  # 点草坪格子，row/col 与 PlantCell.row_col 一致
await a.wait_scene("关键字", 超时)
a.finish()                      # 停止驾驶（打开游戏时留窗口，无头时退出）
a.quit_game()                   # 真退出
```

### 坐标相关（排查必用）

```gdscript
a.screen_center(control)        # 控件在【屏幕上真正能点到】的中心  ← 所有点击都必须用它
a.canvas_origin()               # 画布变换原点；非 (0,0) 就说明有相机，rect 靠不住
await a.probe_hover(x, y)       # 鼠标挪过去，报告游戏认为压住了哪个控件/哪个格子
a.describe_plant_cells()        # 权威摘要：已种槽位、每个已种格子的 row_col + 屏幕中心
```

看门狗 `--autopilot-max-seconds`（默认 300）到点强制结束，绝不留野进程。

### 4.1 模块划分（2026-09-30 重构）

驾驶舱曾经是一个 682 行的 `test/autopilot.gd`，报告落盘、输入合成、坐标推算、  
状态采集、看门狗、场景脚本生命周期全在里面。现在按「一个文件只回答一个问题」拆开：

| 文件                         | 管什么                                                           | 依赖                     |
| -------------------------- | ------------------------------------------------------------- | ---------------------- |
| `test/autopilot.gd`        | **门面**：生命周期、看门狗、把 `a.xxx()` 转发给下面的模块                          | 全部                     |
| `test/autopilot_report.gd` | 报告正文缓冲 / 落盘 / 原样打屏；`res://` 与 `user://` 两种策略                  | 无                      |
| `test/autopilot_clock.gd`  | 游戏时间计时与所有等待（`wait` / `frames` / `wait_scene` / `wait_stable`） | report                 |
| `test/autopilot_probe.gd`  | 节点查询、屏幕坐标 `screen_center_of()`、悬停探测                           | clock                  |
| `test/autopilot_input.gd`  | 合成鼠标 / 键盘事件、直接触发 `pressed`                                    | clock + report + probe |
| `test/autopilot_state.gd`  | 状态采集（快照 / 观测 / 草坪 / 僵尸 / UI）                                  | 无                      |

依赖是**单向**的（`report ← clock ← probe ← input`，`state` 独立），  
所以模块之间可以标 `class_name` 互相引用而不会解析成环。

两条硬约束：

1. **`a.*` 的调用签名不许变**。`test/scenarios/*.gd` 和 `test/inject/scenario.gd`  
   里那些「第 1 关按钮没有编号后缀」「必须走 `choosed_card_start_game()`」的事实  
   是拿时间换来的，改签名等于把它们一起作废。
2. **`report` 与 `state` 是 DebugChannel 与 autopilot 共用的**。  
   `src/core/autoload/debug_channel.gd` 现在也用这两个模块写报告、采状态 ——  
   以前两边各写一份 `_line` / `_flush` / 格子统计，改一处必然漏另一处。

### 4.2 裸 print 的登记例外搬了家

报告正文要原样落进 stdout，不能带 `Log` 的级别前缀、也不能被 `Log.level` 截断，  
所以 `AutopilotReport.line()` 直连引擎 `print`。这是规范 S-02 的**登记例外**（已在  
`docs/项目规范.md` S-02 登记），例外从 `debug_channel.gd::_line()` 改成了 `autopilot_report.gd::line()`。  
autopilot 系列其它文件的控制台消息**一律走 `Log.info`**。

---

## 五、已探明的入口

| 用途        | 路径 / 调用                                                                                          | 备注                                          |
| --------- | ------------------------------------------------------------------------------------------------ | ------------------------------------------- |
| 主菜单·冒险    | `/root/StartMenu/BG_Right/Menu/Button1`                                                          | **按钮从右侧滑入，必须 `wait_stable` 后再点**            |
| 选关·第 1 关  | `ChooseLevelButton`                                                                              | **没有编号后缀**                                  |
| 选关·第 2 关起 | `ChooseLevelButton2`、`3`…                                                                        | `TextureButton.disabled` = 锁定               |
| 植物候选卡     | `.../CardSlotCandidate/AllCardPage/GridContainerPlant/CardPlaceholder<N>/CardCandidateContainer` | 内部卡片节点名是 `Card<植物ID>`                       |
| 战斗卡槽      | `.../CardSlotBattle/CardUiList/@TextureRect@N/Card<ID>`                                          | `sun_cost` 是价格                              |
| **开始游戏**  | `Global.main_game.choosed_card_start_game()`                                                     | 见下方警告                                       |
| 主游戏阶段     | `main_game_progress`：1=CHOOSE_CARD，2=PREPARE，3=MAIN_GAME                                         |                                             |
| 草坪根       | `/root/MainGame/PlantCellsRoot`                                                                  | 行 `PlantCellsRow1..5`，格 `PlantCell1..9`     |
| 关卡相机      | `/root/MainGame/Camera2D`                                                                        | 位置 (120,0)，**而且会移动** —— 就是它让 rect 坐标失效，见第六节 |


> ⚠️ **必须走 `choosed_card_start_game()`**（`main_game_manager.gd:340`）。  
> 它会先 `card_slot_disappear_choose()` 收面板再 `main_game_start()`。  
> 直接调 `main_game_start()` 是旁路，**选卡面板会残留在屏幕上**，  
> 而且残留的面板会继续吃掉草坪中间那一大片点击。

> ⚠️ **冒险模式种子包不足时关卡会自己跳过选卡**（卡槽数 >= 已拥有植物卡数，  
> 见 [卡片与选卡流程.md](参考存档/卡片与选卡流程.md#种子包过少自动选卡并跳过选卡阶段)）。  
> 此时进关卡后 `main_game_progress` 已经不是 `CHOOSE_CARD`（1），  
> 再调 `choosed_card_start_game()` / `main_game_start()` 会**重复触发开始流程**。  
> 脚本里要写：`if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:` 再调。

---

## 六、草坪坐标（2026-09-30 已解决）

上一轮卡在「`PlantCell.global_position` / `Button` 的 rect ≠ 屏幕上真正可点的位置」。  
结论：**rect 本身没错，错的是把它当成屏幕坐标。**  
下面的事实全部来自**带窗口实机**的探针输出，不是从无头跑批推断的。

### 6.1 事实（探针实测，不是推断）

- 草坪 **5 行 × 9 列**。行节点 y = **82 / 182 / 282 / 381 / 478**，格高 96。
- **行内子节点是从右到左排的**：  
  `child[0] = PlantCell1 = row_col.y 8`（最右）… `child[8] = PlantCell9 = row_col.y 0`（最左）。  
  列间距 ≈ 80，canvas 横坐标 **x ≈ 45 + 80 × row_col.y**。
- `PlantCell.row_col` 与 `plant_cell_manager.all_plant_cells[row][col]` **完全一致**  
  （col 0 = 最左）。两套索引不用再换算，别再做 `9-col` 之类的镜像。
- 小推车（canvas 坐标）：**x = 20**，y = 166 / 267 / 363 / 454 / 554，5 辆，在草坪左侧。

### 6.2 根因：rect ≠ 屏幕上能点到的位置

关卡场景里有 **`Camera2D`，位置 (120, 0)**：

```
viewport.get_canvas_transform().origin = (-120, 0)   # 刚进关卡（入场镜头）
viewport.get_canvas_transform().origin = ( 150, 0)   # 关卡跑起来之后
```

`Control.get_global_rect()` / `global_position` 用的是**不含画布变换**的坐标，  
而鼠标命中测试走的是 **`get_global_transform_with_canvas()`**。  
1-1 运行期实测两者**差 150 像素**（行、列、各种格子都一致）。

> ⚠️ 这个偏移**不是常数**：相机在入场时会移动，所以「量一次偏移、到处减掉」一样会错。  
> 唯一正确的做法是**每次点击前现算** `screen_center()`。

所以「按 rect 中心点」必然点偏：rect 中心 (163,230) 实际落在第 2 行小推车的位置，  
点下去没有任何反应、阳光也不扣。

### 6.3 正确做法

```gdscript
func screen_center(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)
```

autopilot 的 `click_first` / `click_node` / `click_plant_cell` 已经全部换成它，  
场景脚本不需要自己算。排查坐标问题时按这个顺序打事实：

1. `a.canvas_origin()` —— 非 (0,0) 就说明有相机，**任何从 rect 推断屏幕位置的做法都是错的**。
2. `await a.probe_hover(x, y)` —— 游戏认为鼠标压在哪个控件上（比反复点击快得多，也没有副作用）。
3. `a.describe_plant_cells()` —— 权威的「哪种了植物、屏幕中心在哪」。

### 6.4 证据

- 取 4 个格子（跨行跨列，含最左和最右）按 `screen_center` 悬停：  
  `hovered` 与 `hand_manager.curr_plant_cell` **4/4 全部命中**。
- 种植：土豆地雷种到 `row_col=(1,1)`，**阳光 50 → 25**，`已种槽位=1`，植物类型 5，  
  权威摘要给出 `数组[1][1] row_col=(1, 1) 植物5 屏幕中心(313,230)`。
- `test/inject/scenario.gd` 在打开游戏模式下跑通，报告里自带两条证据：  
  `STEP4b 进关卡后 canvas_origin=(150.0, 0.0)` 和 `[PLANT] result=PASS`。

### 6.5 第二个坑：选卡面板压在草坪上

选卡阶段（`main_game_progress = 1`）时 `CardSlotCandidate` 面板覆盖  
**x∈[150,615]、y∈[89,602]**，正压在草坪中间。只要还没走  
`choosed_card_start_game()` 把面板收掉，落在它下面的点击全被它吃掉，  
表现为「悬停什么都没有、点了没反应」。

> 这个坑**在无头跑批里也一样会静默通过**（探针只看数值），  
> 打开游戏才看得见面板还挂在屏幕上。

---

## 七、踩坑表

### 游戏驱动

| 坑                                     | 症状                                              | 做法                                                                                                                                                           |
| ------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **`Control.get_global_rect()` 当屏幕坐标** | 点击稳定偏 150 像素，永远点到别的格子/小推车                       | 一律 `screen_center()`（`get_global_transform_with_canvas()`）                                                                                                   |
| **把 rect ≠ 屏幕位置归因成"坐标约定错了"**          | 连错 5 次（列方向、行列基准、PlantCell 类型…）                  | 先打 `canvas_origin()`，再谈坐标换算                                                                                                                                  |
| 选卡面板没关就点草坪                            | 草坪中间一大片点击全被面板吃掉                                 | 必须 `choosed_card_start_game()`                                                                                                                               |
| **只按节点名做断言/比较**                       | 每行都有 `PlantCell8`，"游戏认为 = PlantCell8" 根本无法判定    | 断言和打印一律用**完整路径**（这一条让上一轮的结论直接作废）                                                                                                                             |
| **用无头跑批下「没问题」的结论**                    | 报告全绿，真机上点了没反应 / UI 被盖住 / 东西画到屏幕外                | 排查一律打开游戏；无头只当 CI 门禁（见第〇节）                                                                                                                                    |
| **无头时根视口是 (0,0)**                     | 模拟点击全部失效（只在无头出现）                                | autopilot 启动时强设 `800x600`；**要排查就别用无头**                                                                                                                      |
| 场景脚本是 RefCounted                      | 只被局部变量持有 → 第一次 `await` 后对象被回收，协程永不恢复（曾空转 9 分钟）  | 用**成员变量**持有                                                                                                                                                  |
| 菜单按钮滑入动画                              | 动画未结束就点会落空/点错                                   | 先 `wait_stable`                                                                                                                                              |
| 第 1 关无编号后缀                            | 按编号反拼路径得到 `ChooseLevelButton0`（不存在）             | **记住真实节点名**，不要反拼                                                                                                                                             |
| 卡片点击 vs 格子点击                          | 卡片有音效但不种植                                       | 两者都走 GUI 命中测试（卡片 Button / 格子 Button）；但**手持物的跟随、虚影、能否种、点空白取消读的是真实鼠标位置**，所以点格子前先把鼠标真的挪过去（`warp_mouse` **且** 发 motion 事件），否则 `hand_manager.curr_plant_cell` 不更新 |
| `PlantCell` 类型                        | `(x as Node2D)` 返回 null → 崩在 `.global_position` | 是 `Control`                                                                                                                                                  |
| `nodes()` 按路径匹配                       | 深层 Sprite2D 全被卷进来（356 行噪音）                      | 侦察用名字，定位用路径                                                                                                                                                  |
| 选择器太宽                                 | 命中的是列表容器而非卡片                                    | 遍历子节点找真正带 `sun_cost` 的                                                                                                                                       |

### 工具链（都是我自己踩的）

| 坑                                                 | 症状                                                                       | 做法                                                                                                                                                            |
| ------------------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **PS 脚本里有中文**                                     | PS 5.1 按 ANSI 读无 BOM → **解析失败，脚本一行不执行**，错误只在 stderr                      | 辅助脚本**纯 ASCII**；**必须打印 stderr**                                                                                                                               |
| **`Start-Process` 被沙箱拒绝**                         | `Access is denied`，Godot 一次都没起来                                          | 用 `cmd.exe /c '"exe" args > out 2>&1'`                                                                                                                        |
| **Godot 在 Windows 是 GUI 子系统程序**                   | 直接 `& godot ...` 把输出丢进虚空，stdout 一个字都抓不到                                  | **必须重定向到文件**（`>` 给的是真实句柄）；带窗口跑同样适用                                                                                                                            |
| **`-Windowed` 配 `res://test/inject/scenario.gd`** | PowerShell 一直不返回（注入模式跑完不退出）                                              | 关掉游戏窗口，或改用方式 A / `a.quit_game()`                                                                                                                              |
| `$PSScriptRoot` 为空                                | `-File` 传相对路径时 `Split-Path $PSScriptRoot -Parent` 报错，脚本一行没跑              | 用绝对路径调用，或退到 `(Get-Location).Path`                                                                                                                             |
| **不验证改动是否落盘**                                     | 补丁静默 no-op，而编译检查照样全绿 → 连续 3 次"假成功"                                       | **写完自证**：`ANCHOR_FOUND=` / `NOW_HAS_WARP=` 之类标记                                                                                                               |
| `String.raw` 里的 `\t`                              | 不是真 Tab，`.Replace` 匹配不上                                                  | 用 `[char]9` / `[char]10` 构造                                                                                                                                   |
| `$args` 是保留变量                                     | `Start-Process` 静默失败                                                     | 换名字                                                                                                                                                           |
| `%TEMP%` 8.3 短路径                                  | `Remove-Item` 抛**终止性**错误，把 PASS 变成 exit 1                                | 先解析长路径 + `try/catch`                                                                                                                                          |
| 编辑器错误本地化                                          | 只 grep 英文会漏 `错误 (146, 53)`                                               | 同时匹配本地化词 + `(\d+,\s*\d+)`                                                                                                                                     |
| **新增 `class_name` 脚本后跑不起来**                       | `Parse Error: Could not find type "Xxx" in the current scope`，而编辑器扫描明明全绿 | 运行期的全局类表来自 `.godot/global_script_class_cache.cfg`，**新增 / 改名脚本后必须跑一次 `godot --headless --path . --import`** 重新生成它和 `.uid`；只跑 `--editor --quit` 在有编辑器实例开着时可能不刷新 |
| **测试场景被注入 autopilot**                             | 被检查的场景崩（`0xC0000005`）                                                    | 非游戏启动加 `-- --no-autopilot`                                                                                                                                    |
| GDScript 没有 `? :`                                 | `Unexpected "?"`                                                         | `a if cond else b`                                                                                                                                            |
| `a` 是无类型参数                                        | `Cannot infer the type of "x"`                                           | 显式标注 `var n: Node = a.get_node_or_null(...)`                                                                                                                  |


### 流程纪律（最重要）

1. **每一步都打 STEP 日志**。没有留痕的脚本，失败后只能靠猜——这一条我违反过很多次。
2. **改完必须自证改动落盘**。"能编译"只证明当前文件没坏，**不能证明你想改的东西改进去了**。
3. **先让脚本把事实打印出来，再读事实**。用"看起来合理的约定"推断，这个 session 里我因此错了 5 次  
   （列方向、阳光够不够、行列基准、PlantCell 类型、点击坐标）。
4. **打印要打印到能判定的粒度**。名字会重名，就一定要打完整路径；  
   坐标会骗人，就一定要打"游戏自己认为鼠标在哪"。
5. **结论要能对上报告里的某一行**。对不上，就等于没验证过。

---

## 八、验证只有一条路：打开游戏

|                          | 覆盖                        | 覆盖不到                     |
| ------------------------ | ------------------------- | ------------------------ |
| **打开游戏 + autopilot（主力）** | 真实对局，带窗口、带画面              | 需要有人按 F5 或发命令触发          |
| 无头 autopilot（CI 门禁）      | 探针断言（`[XXX] result=PASS`） | 画面、时序、真机视口 —— **不能用来排查** |

仓库**已无静态验证脚本**（原 `test/verify.ps1` 一套已删除）：静态检查只能证明"没坏"，  
**打开游戏**才能证明"能玩"。

改动较小 / 确定不会出问题 → **免验证**，不用开游戏（判定见 [验证流程.md](验证流程.md) §1）。

**验证过于艰难、非常耗时、不值得用脚本验证时** → 也允许不验证，但**必须在反馈里给出人工验证方法**  
（进哪关 / 怎么操作 / 什么现象算对），见 [验证流程.md §1.1](验证流程.md#11-验证成本过高时可以不验证但必须在反馈里给出人工验证方法)。

---

## 九、已验证可用的片段

```
主菜单（等按钮静止）→ 冒险模式 → 选关（无后缀那个 = 1-1 白天）
  → 选卡（遍历找 Card<ID>）→ choosed_card_start_game()（面板正确收起）
  → 点战斗卡槽卡片（手持类型变 1=Character，阳光不扣）
  → 点草坪格子种下植物（阳光扣掉买价，plant_in_cell 出现植物）
  → 僵尸出场并推进（observe 带行号）
```

已打通：关卡切换、选卡、开始游戏、卡片点击、**点击草坪种下植物**、状态观测、僵尸出场检测。

对应的可执行证据：

- `test/inject/scenario.gd` —— 全流程，打开游戏跑，报告里出 `[PLANT] result=PASS`
- `test/scenarios/probe_plant.gd` —— 坐标最小复现（rect 中心 vs 屏幕中心、悬停核对、种植）
- `test/scenarios/probe_map.gd` —— 坐标排查工具（画布变换 + 覆盖控件 + 扫描线）
- `test/scenarios/probe_hand.gd` —— 手持物组件（持卡/种植/铲子/取消全流程 + 节点不堆积回归），报告里出 `[HAND] result=PASS`
- `test/scenarios/probe_glove_unlock.gd` —— 手套解锁进度 + 冒险 4-6 戴夫赠礼（未通关 4-5 时组件禁用且卡槽不出现、通关后启用且出现；4-6 开场 8 句、念到「手套！」时戴夫手上举着物品、末句发疯），报告里出 `[GLOVEUNLOCK] result=PASS`
- `test/scenarios/probe_freed_plant.gd` —— 植物死亡后格子残留「已释放实例」的回归（`PlantCell.get_plant()` 兜底），报告里出 `[FREED] result=PASS`
- `test/scenarios/probe_puzzle_unlock.gd` —— 冒险 4-6 中途第 5 波掉礼盒解锁解谜模式（配置静态检查 + 真掉一次 + 点开弹出提示 + 掉落位置夹紧后仍在画面内 + 回头确认 3-2 那条没被改坏），报告里出 `[PUZZLEUNLOCK] result=PASS`
- `test/scenarios/probe_tutorial.gd` —— 1-1 新手教程全流程（原版提示顺序、第一波僵尸的启动时机、已通关不再播），报告里出 `[TUTORIAL] result=PASS`
- `test/scenarios/probe_tutorial_1_2.gd` —— 1-2 新手教程全流程（向日葵教学顺序、第一波僵尸的启动时机、已通关不再播），报告里出 `[TUTORIAL12] result=PASS`
- `test/scenarios/probe_tutorial_1_5.gd` —— 1-5 铲子教学全流程（教学提示共 3 句、**没有「干得漂亮」提示**；开场顺序：**戴夫 7 句开场对话 → 玩家铲光预置的 3 株豌豆射手 → 铲光后戴夫 6 句保龄球惊喜对话、念到「我们去玩保龄球！」的同时红线出现 → 戴夫说完即收尾 → 预览僵尸 → 正式开局**；开局后传送带启动 + 第一波僵尸出动；已通关不再播教学与戴夫对话且传送带照常自动启动、红线照样出现），报告里出 `[TUTORIAL15] result=PASS`
- `test/scenarios/probe_4_5.gd` —— 冒险 4-5 砸罐子关的**数据**（无头可跑）：三批罐子占 3 / 4 / 5 列且罐子数 15 / 20 / 25、绿罐 0 / 2 / 3、三段戴夫对话挂在对应轮次、不播「准备-安放-植物」红字、切换批次清空上一批的植物
- `test/scenarios/probe_4_5_no_round_save.gd` —— 冒险 4-5 **不按批次存档/读档**（无头可跑）：伪造一份「第 3 批已打完」的存档后进关，轮次仍是 1、场上是第 1 批（3 列 15 罐）、旧存档被删、切到第 2 批不写新存档
- `test/scenarios/probe_4_5_play.gd` —— 冒险 4-5 砸罐子关的**实机**（带窗口）：戴夫开场对话能点完 → 砸光第 1 批 → 戴夫说完「再给你一批」后摆上第 2 批，核对两批的罐子数 / 占列 / 绿罐、切换批次后临时卡片清零
- `test/scenarios/probe_4_5_flow.gd` —— 冒险 4-5 砸罐子关的**完整流程**（带窗口）：按真实胜利条件连打三批（砸光 → 打光僵尸 → 戴夫说话 → 下一批），每批打印罐子数 / 占列 / 绿罐数与棕罐数，并顺带验一遍切完轮次后第 1 批的配置没被后面几批顶掉
- `test/scenarios/probe_night.gd` —— 第二大关（夜晚 2-1 ~ 2-10）数据与流程（夜晚开关、开局墓碑、不掉阳光、墓碑种植判定、2-5 / 2-10 传送带、2-1 ~ 2-10 解锁表），报告里出 `[NIGHT] result=PASS`
- `test/scenarios/probe_bowling_redline.gd` —— 坚果保龄球红线（节点创建 / **画在背景之上** / 落在草坪范围内），报告里出 `[BOWLINGSTRIPE] result=PASS`
- `test/scenarios/probe_first_coin_advice.gd` —— 第一次掉落钱的一次性提示（弹出「存钱来买更酷的道具吧！」+ 只弹一次 + 停留结束自动消失），报告里出 `[FIRSTCOIN] result=PASS`
- `test/scenarios/probe_bobsled_bonanza.gd` —— 迷你游戏 13「全面冻结」的冰面机制（开局冰道的行数与覆盖列、冰面不可种植、雪橇队只落在有冰的行、融冰后改出洗冰车、洗冰车把冰铺回来），报告里出 `[BOBSLED] result=PASS`
- `test/scenarios/probe_x10_note_icon.gd` —— 冒险选关界面 x-10 的「本关看点」图标（1-10 ~ 5-10 都挂纸条 `ZombieNoteSmall.png` 的 `Sprite2D`，不再实例化僵尸），报告里出 `[X10NOTE] result=PASS`
- `test/scenarios/probe_invisi_ghoul.gd` —— 迷你游戏第 6 关「隐形战争」的隐形渲染（出场本体/影子 alpha=0、冰冻与黄油现形、状态结束后重新隐形，含 1-1 对照组），报告里出 `[INVISIGHOUL] result=PASS`
- `test/scenarios/probe_zombie_nimble.gd` —— 迷你游戏「僵尸快跑」的全场加速（关卡倍率字段、僵尸 `LevelSpeed` 因子与 2 秒实测位移、豌豆射手攻击 CD 减半，并拿 1-1 当倍率 1.0 的对照组），报告里出 `[NIMBLE] result=PASS`
- `test/scenarios/probe_slot_machine.gd` —— 迷你游戏第 3 关「拉霸」（UI 已挪到 `src/levels/mode_minigame/minigame_03_slot_machine_ui.gd`：开局状态、真点拉杆扣 25 阳光、转轮停下、两同/三同分别给免费植物与阳光、累计收集达标后掉奖杯 → 点奖杯进结算），报告里出 `[SLOT] result=PASS`
- `test/scenarios/probe_pogo_party.gd` —— 迷你游戏「蹦蹦舞会」（屋顶 / 30 波 3 旗帜 / 屋顶曲 / 55 秒超长开场 / 预置花盆 + 预览僵尸与第 0~29 波的构成逐波核对：非旗帜波全是蹦蹦僵尸，旗帜波以蹦蹦为主体），报告里出 `[POGOPARTY] result=PASS`
- `test/scenarios/probe_seed_rain.gd` —— 迷你游戏「种子雨」的天降种子卡（发卡器挂在卡片前景层且定时器在跑 / 12 秒内持续出卡 / 卡片能捡起并能种到草坪 / 走通关结算切出主游戏），报告里出 `[SEEDRAIN] result=PASS`

---

## 十、跑批命令（照着抄）

### 打开游戏（主力，带窗口）

```powershell
# 打开游戏 + 脚本驱动，跑完自动退出（窗口可见）
powershell -ExecutionPolicy Bypass -File test\run_autopilot.ps1 -Windowed -Scenario probe_plant

# 手持物组件（持卡 / 种植 / 铲子 / 取消 + 节点不堆积回归）
powershell -ExecutionPolicy Bypass -File test\run_autopilot.ps1 -Windowed -Scenario probe_hand

# 新手教程（1-1 全流程 + 原版提示顺序 + 已通关不再播）
powershell -ExecutionPolicy Bypass -File test\run_autopilot.ps1 -Windowed -Scenario probe_tutorial

# 新手教程（1-2 向日葵教学 + 原版提示顺序 + 已通关不再播）
powershell -ExecutionPolicy Bypass -File test\run_autopilot.ps1 -Windowed -Scenario probe_tutorial_1_2

# 新手教程（1-5 保龄球 / 传送带关：传送带取卡 + 红线限制 + 已通关不再播）
powershell -ExecutionPolicy Bypass -File test\run_autopilot.ps1 -Windowed -Scenario probe_tutorial_1_5

# 第二大关（夜晚 2-1 ~ 2-10：夜晚开关 + 开局墓碑 + 墓碑种植判定 + 传送带关 + 解锁表）
powershell -ExecutionPolicy Bypass -File test\run_autopilot.ps1 -Windowed -Scenario probe_night
```

想边看边调、跑完还留着现场：按第二节把开关文件放回去，编辑器里 **F5**。

### CI 回归（无头，**不用于排查**）

```powershell
# 无头跑一个场景，只取它的 [XXX] result=PASS 标记
powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_plant
```

不通过 `run_autopilot.ps1` 时，等价的打开游戏命令是：

```powershell
cmd /c '"<godot.exe>" --path "<项目>" -- --scenario=res://test/scenarios/probe_plant.gd > out.txt 2>&1'
```

（去掉 `--headless` 就是打开游戏；加回 `--headless` 就是无头回归。）

用户目录默认被重定向到临时目录，**不会污染真实存档**。

---

## 十一、三条红线

1. **不许拿无头跑批的结果回答「有没有问题」** —— 排查一律打开游戏（第〇节）。
2. **不许用探针没想到的事去找借口**：`result=PASS` 只代表探针问过的那几件事过了；  
   需要验证时必须按 [验证流程.md](验证流程.md) 的人工回归清单**在真窗口里过一遍**。
3. **每条结论都要能对上报告里的某一行**（`a.log` / `a.dump` / `a.observe` / F10 快照）；  
   对不上就重跑，别靠推断。
