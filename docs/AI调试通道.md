# AI 调试通道（autopilot）

给 AI/CI 用的「静默驾驶舱」：**自己启动游戏、模拟玩家操作、取回结构化状态**。
游戏写出的文件 AI 直接读，不需要人工转交日志。

---

## 〇、当前状态（2026-09-30 收尾）

**注入已关闭，游戏恢复正常游玩。**
`test/inject/scenario.gd` 已改名成 **`scenario.gd.off`**（`.uid` 一起改成 `.off.uid`），
`DebugChannel` 启动时不再挂 autopilot —— 现在启动游戏就是正常游戏，没有任何测试脚本在跑。

**只是要跑批的话，不需要打开它**：命令行触发和开关文件是分开的（见第一节）。
要恢复编辑器里按 F5 自动跑，见第二节。

---

## 一、什么时候会注入（两个触发条件 + 一种不触发）

`DebugChannel` 注入 autopilot 有两个**互相独立**的条件，满足任意一个就注入：

### 1. 开关文件（编辑器里人工按 F5）

存在 **`test/inject/scenario.gd`** 时，游戏启动后由自动加载单例 `DebugChannel`
把 autopilot 挂进场景树执行它。报告写到 **`test/inject/report.txt`**。
**有窗口时**跑完不关窗口，控制权交还玩家；无头时跑完直接退出。
日常游玩请把它收起来（第二节）。**当前它就是收起来的状态。**

### 2. 命令行（全自动无头 / CI）

```bash
godot --headless --path <项目> -- --scenario=res://test/scenarios/probe_plant.gd --autopilot-max-seconds=200
```

命令行给了 `--scenario=` 就注入，**不依赖那个开关文件** ——
所以「注入关着」也能跑批，两者互不牵扯。

### 3. 都不触发（正常游玩）

没有开关文件、命令行也没有 `--scenario=` → `DebugChannel` 回到默认静默。

### ⚠️ 命令行模式最容易踩的坑

**不要**把 `res://test/autopilot.tscn` 当启动场景传进去。
那样启动的是 autopilot 场景本身，**主菜单/选关根本不存在**，
所有走菜单的场景脚本第一步就超时（2026-09-30 踩过，白跑一轮）。
正确做法就是上面这样：不指定场景，启动**真实主场景**，让 `DebugChannel` 注入。

---

## 二、启用 / 关闭

| 目的 | 操作 |
|---|---|
| **后台跑批（任何时候都能用）** | `run_autopilot.ps1 -Scenario <名字>`，**与开关文件无关** |
| 开启 F5 注入 | 把 `test/inject/scenario.gd.off` 改回 `scenario.gd`，`scenario.gd.off.uid` 改回 `scenario.gd.uid` |
| **关闭 F5 注入（恢复正常游玩）** | 两个文件一起改名成 `.off` / `.off.uid` ← **当前就是这个状态** |
| **本次不注入（脚本/检查用）** | 命令行加 `-- --no-autopilot` |
| 完全移除 | 删 `project.godot` 里 `DebugChannel=...` 那行 + 删 `scripts/autoload/debug_channel.gd` + 删 `test/autopilot.*`、`test/inject/` |

> `.uid` **必须跟着一起改名**。只改 `.gd` 会让 `scenario.gd.uid` 变成孤儿文件，
> `verify.ps1` 第 6 步（卫生检查）会直接报 FAIL，Godot 编辑器也可能把它删掉。

`--no-autopilot` 是给 `test/verify.ps1` 那种「启动场景但不是游戏」的步骤用的：
不加会把 autopilot 注进 `script_check.tscn`，两个东西互相打架，
`script_check` 直接崩（exit `0xC0000005`）。verify.ps1 的 1b / 5 两步已经带上了。

关闭后每次启动只做一次 `ResourceLoader.exists()` + 一次命令行扫描，无副作用。

---

## 三、API

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
a.finish()                      # 停止驾驶（有窗口时留窗口，无头时退出）
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

---

## 四、已探明的入口

| 用途 | 路径 / 调用 | 备注 |
|---|---|---|
| 主菜单·冒险 | `/root/StartMenu/BG_Right/Menu/Button1` | **按钮从右侧滑入，必须 `wait_stable` 后再点** |
| 选关·第 1 关 | `ChooseLevelButton` | **没有编号后缀** |
| 选关·第 2 关起 | `ChooseLevelButton2`、`3`… | `TextureButton.disabled` = 锁定 |
| 植物候选卡 | `.../CardSlotCandidate/AllCardPage/GridContainerPlant/CardPlaceholder<N>/CardCandidateContainer` | 内部卡片节点名是 `Card<植物ID>` |
| 战斗卡槽 | `.../CardSlotBattle/CardUiList/@TextureRect@N/Card<ID>` | `sun_cost` 是价格 |
| **开始游戏** | `Global.main_game.choosed_card_start_game()` | 见下方警告 |
| 主游戏阶段 | `main_game_progress`：1=CHOOSE_CARD，2=PREPARE，3=MAIN_GAME | |
| 草坪根 | `/root/MainGame/PlantCellsRoot` | 行 `PlantCellsRow1..5`，格 `PlantCell1..9` |
| 关卡相机 | `/root/MainGame/Camera2D` | 位置 (120,0)，**而且会移动** —— 就是它让 rect 坐标失效，见第五节 |

> ⚠️ **必须走 `choosed_card_start_game()`**（`main_game_manager.gd:340`）。
> 它会先 `card_slot_disappear_choose()` 收面板再 `main_game_start()`。
> 直接调 `main_game_start()` 是旁路，**选卡面板会残留在屏幕上**，
> 而且残留的面板会继续吃掉草坪中间那一大片点击。

---

## 五、草坪坐标（2026-09-30 已解决）

上一轮卡在「`PlantCell.global_position` / `Button` 的 rect ≠ 屏幕上真正可点的位置」。
结论：**rect 本身没错，错的是把它当成屏幕坐标。**

### 5.1 事实（探针实测，不是推断）

- 草坪 **5 行 × 9 列**。行节点 y = **82 / 182 / 282 / 381 / 478**，格高 96。
- **行内子节点是从右到左排的**：
  `child[0] = PlantCell1 = row_col.y 8`（最右）… `child[8] = PlantCell9 = row_col.y 0`（最左）。
  列间距 ≈ 80，canvas 横坐标 **x ≈ 45 + 80 × row_col.y**。
- `PlantCell.row_col` 与 `plant_cell_manager.all_plant_cells[row][col]` **完全一致**
  （col 0 = 最左）。两套索引不用再换算，别再做 `9-col` 之类的镜像。
- 小推车（canvas 坐标）：**x = 20**，y = 166 / 267 / 363 / 454 / 554，5 辆，在草坪左侧。

### 5.2 根因：rect ≠ 屏幕上能点到的位置

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

### 5.3 正确做法

```gdscript
func screen_center(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)
```

autopilot 的 `click_first` / `click_node` / `click_plant_cell` 已经全部换成它，
场景脚本不需要自己算。排查坐标问题时按这个顺序打事实：

1. `a.canvas_origin()` —— 非 (0,0) 就说明有相机，**任何从 rect 推断屏幕位置的做法都是错的**。
2. `await a.probe_hover(x, y)` —— 游戏认为鼠标压在哪个控件上（比反复点击快得多，也没有副作用）。
3. `a.describe_plant_cells()` —— 权威的「哪种了植物、屏幕中心在哪」。

### 5.4 证据

- 取 4 个格子（跨行跨列，含最左和最右）按 `screen_center` 悬停：
  `hovered` 与 `hand_manager.curr_plant_cell` **4/4 全部命中**。
- 种植：土豆地雷种到 `row_col=(1,1)`，**阳光 50 → 25**，`已种槽位=1`，植物类型 5，
  权威摘要给出 `数组[1][1] row_col=(1, 1) 植物5 屏幕中心(313,230)`。
- 完整流程 `test/inject/scenario.gd` 无头跑通，报告里自带两条证据：
  `STEP4b 进关卡后 canvas_origin=(150.0, 0.0)` 和 `[PLANT] result=PASS`。

### 5.5 第二个坑：选卡面板压在草坪上

选卡阶段（`main_game_progress = 1`）时 `CardSlotCandidate` 面板覆盖
**x∈[150,615]、y∈[89,602]**，正压在草坪中间。只要还没走
`choosed_card_start_game()` 把面板收掉，落在它下面的点击全被它吃掉，
表现为「悬停什么都没有、点了没反应」。

---

## 六、踩坑表

### 游戏驱动

| 坑 | 症状 | 做法 |
|---|---|---|
| **`Control.get_global_rect()` 当屏幕坐标** | 点击稳定偏 150 像素，永远点到别的格子/小推车 | 一律 `screen_center()`（`get_global_transform_with_canvas()`） |
| **把 rect ≠ 屏幕位置归因成"坐标约定错了"** | 连错 5 次（列方向、行列基准、PlantCell 类型…） | 先打 `canvas_origin()`，再谈坐标换算 |
| 选卡面板没关就点草坪 | 草坪中间一大片点击全被面板吃掉 | 必须 `choosed_card_start_game()` |
| **只按节点名做断言/比较** | 每行都有 `PlantCell8`，"游戏认为 = PlantCell8" 根本无法判定 | 断言和打印一律用**完整路径**（这一条让上一轮的结论直接作废） |
| **无头根视口是 (0,0)** | 模拟点击全部失效 | 启动时把 `get_tree().root.size` 设为 1066x600 |
| 场景脚本是 RefCounted | 只被局部变量持有 → 第一次 `await` 后对象被回收，协程永不恢复（曾空转 9 分钟） | 用**成员变量**持有 |
| 菜单按钮滑入动画 | 动画未结束就点会落空/点错 | 先 `wait_stable` |
| 第 1 关无编号后缀 | 按编号反拼路径得到 `ChooseLevelButton0`（不存在） | **记住真实节点名**，不要反拼 |
| 卡片点击 vs 格子点击 | 卡片有音效但不种植 | 两者都走 GUI 命中测试（卡片 Button / 格子 Button）；但**手持物的跟随、虚影、能否种、点空白取消读的是真实鼠标位置**，所以点格子前先把鼠标真的挪过去（`warp_mouse` **且** 发 motion 事件），否则 `hand_manager.curr_plant_cell` 不更新 |
| `PlantCell` 类型 | `(x as Node2D)` 返回 null → 崩在 `.global_position` | 是 `Control` |
| `nodes()` 按路径匹配 | 深层 Sprite2D 全被卷进来（356 行噪音） | 侦察用名字，定位用路径 |
| 选择器太宽 | 命中的是列表容器而非卡片 | 遍历子节点找真正带 `sun_cost` 的 |

### 工具链（都是我自己踩的）

| 坑 | 症状 | 做法 |
|---|---|---|
| **PS 脚本里有中文** | PS 5.1 按 ANSI 读无 BOM → **解析失败，脚本一行不执行**，错误只在 stderr | 辅助脚本**纯 ASCII**；**必须打印 stderr** |
| **`Start-Process` 被沙箱拒绝** | `Access is denied`，Godot 一次都没起来 | 用 `cmd.exe /c '"exe" args > out 2>&1'` |
| **Godot 在 Windows 是 GUI 子系统程序** | 直接 `& godot ...` 把输出丢进虚空，stdout 一个字都抓不到 | **必须重定向到文件**（`>` 给的是真实句柄） |
| `$PSScriptRoot` 为空 | `-File` 传相对路径时 `Split-Path $PSScriptRoot -Parent` 报错，脚本一行没跑 | 用绝对路径调用，或退到 `(Get-Location).Path` |
| **不验证改动是否落盘** | 补丁静默 no-op，而编译检查照样全绿 → 连续 3 次"假成功" | **写完自证**：`ANCHOR_FOUND=` / `NOW_HAS_WARP=` 之类标记 |
| `String.raw` 里的 `\t` | 不是真 Tab，`.Replace` 匹配不上 | 用 `[char]9` / `[char]10` 构造 |
| `$args` 是保留变量 | `Start-Process` 静默失败 | 换名字 |
| `%TEMP%` 8.3 短路径 | `Remove-Item` 抛**终止性**错误，把 PASS 变成 exit 1 | 先解析长路径 + `try/catch` |
| 编辑器错误本地化 | 只 grep 英文会漏 `错误 (146, 53)` | 同时匹配本地化词 + `(\d+,\s*\d+)` |
| 无头扫描不编译字符串引用的脚本 | `load("res://x.gd")` 的语法错误被静默漏过 | `test/script_check.gd` 显式编译全部 .gd |
| **测试场景被注入 autopilot** | `script_check` 崩（`0xC0000005`） | 非游戏启动加 `-- --no-autopilot` |
| GDScript 没有 `? :` | `Unexpected "?"` | `a if cond else b` |
| `a` 是无类型参数 | `Cannot infer the type of "x"` | 显式标注 `var n: Node = a.get_node_or_null(...)` |

### 流程纪律（最重要）

1. **每一步都打 STEP 日志**。没有留痕的脚本，失败后只能靠猜——这一条我违反过很多次。
2. **改完必须自证改动落盘**。`verify.ps1` 全绿只证明"当前文件能编译"，**不能证明你想改的东西改进去了**。
3. **先让脚本把事实打印出来，再读事实**。用"看起来合理的约定"推断，这个 session 里我因此错了 5 次
   （列方向、阳光够不够、行列基准、PlantCell 类型、点击坐标）。
4. **打印要打印到能判定的粒度**。名字会重名，就一定要打完整路径；
   坐标会骗人，就一定要打"游戏自己认为鼠标在哪"。

---

## 七、和 `test/verify.ps1` 的分工

| | 覆盖 | 覆盖不到 |
|---|---|---|
| `verify.ps1`（7 步） | 编译、资源引用、uid、工具类运行、卫生 | **游戏行为** |
| autopilot | 真实对局 | 需要有人按 F5 或 CI 触发 |

静态检查证明"没坏"，autopilot 才能证明"能玩"。

---

## 八、已验证可用的片段

```
主菜单（等按钮静止）→ 冒险模式 → 选关（无后缀那个 = 1-1 白天）
  → 选卡（遍历找 Card<ID>）→ choosed_card_start_game()（面板正确收起）
  → 点战斗卡槽卡片（手持类型变 1=Character，阳光不扣）
  → 点草坪格子种下植物（阳光扣掉买价，plant_in_cell 出现植物）
  → 僵尸出场并推进（observe 带行号）
```

已打通：关卡切换、选卡、开始游戏、卡片点击、**点击草坪种下植物**、状态观测、僵尸出场检测。

对应的可执行证据：
- `test/inject/scenario.gd` —— 全流程，报告里出 `[PLANT] result=PASS`
- `test/scenarios/probe_plant.gd` —— 坐标最小复现（rect 中心 vs 屏幕中心、悬停核对、种植）
- `test/scenarios/probe_map.gd` —— 坐标排查工具（画布变换 + 覆盖控件 + 扫描线）
- `test/scenarios/probe_hand.gd` —— 手持物组件（持卡/种植/铲子/取消全流程 + 节点不堆积回归），报告里出 `[HAND] result=PASS`

---

## 九、跑批命令（照着抄）

```powershell
# 静态检查（编译 / 资源 / uid / 卫生）
powershell -ExecutionPolicy Bypass -File test/verify.ps1

# 跑一个场景，无头，自动退出，输出直接打屏
powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_plant

# 手持物组件（持卡 / 种植 / 铲子 / 取消 + 节点不堆积回归）
powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_hand

# 跑注入那个全流程脚本（报告写到 test/inject/report.txt）
powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario res://test/inject/scenario.gd
```

不通过 `run_autopilot.ps1` 时，等价的手工命令是：

```powershell
cmd /c '"<godot.exe>" --headless --path "<项目>" -- --scenario=res://test/scenarios/probe_plant.gd > out.txt 2>&1'
```

用户目录默认被重定向到临时目录，**不会污染真实存档**。
