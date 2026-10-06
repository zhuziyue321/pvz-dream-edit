# 2026-10-04 · 新增内容 · 实现僵尸迷阵 Beghouled（迷你游戏第 5 关三消）

> **任务类型**：新增内容（迷你游戏新玩法）
> **推荐度**：**推荐**（下次做「非草坪玩法」照这个走：独立子管理器 + 常量表 + 无头探针）
> **耗时与成本**：约 2 轮对话，跑了无头探针 `probe_beghouled`（18 断言 PASS），**未开窗口**（界面位置 / 手感需人工看一眼）
> **验证方式**：无头探针实测 + 已给出人工验证方法（见文末）
> **补充自**：无（第一次做三消类玩法；同类的非草坪玩法可对照
> [2026-10-04\_实现僵尸水族馆.md](2026-10-04_实现僵尸水族馆.md) 与 [2026-10-04\_实现观星SeeingStars.md](2026-10-04_实现观星SeeingStars.md)）

## 目标

把 `minigame_05_beghouled.gd` 从「空壳 TODO」做成可玩的**僵尸迷阵**：
草坪开局铺满植物，点两下相邻植物交换，凑三个及以上同类连线即消除并给阳光，
累计 75 次配对掉奖杯通关；植物被僵尸啃掉留弹坑（200 阳光填），阳光还能买三档升级与手动重置。

## 步骤

1. 先查原版规则：wiki.gg 的 [Beghouled](https://plantsvszombies.wiki.gg/wiki/Beghouled) 页
   （fandom 的 `?action=raw` 抓取超时，换 wiki.gg 成功）→ 把数值落成 `src/core/consts/const_beghouled.gd`，
   每条都带「数据来源 / 待核实」注释（照 [AI查wiki避坑.md](../参考存档/AI查wiki避坑.md) 的来源分级写法）。
2. 新增 `src/managers/beghouled_manager.gd`（`MainGameSubManager` 子类），挂到 `MainGameManager.Manager` 下，
   由 `game_para.is_beghouled` 决定是否创建 —— 与 `MgmRewardManager` / `MgmSaveManager` 同一套路。
3. 复用 `PlantCell` 的**手套搬运 API** 做交换与下落（`glove_take_plant` / `glove_put_plant`），
   不销毁植物实例，血量 / 冷却跟着走。
4. 弹坑：`PlantCell` 加 `create_crater_permanent()` / `remove_crater()`；
   `DoomShroomCrater.init_crater()` 加可选 `duration` 参数（传 0 = 永久）。
5. 关卡脚本只写配置 + 一段 `run_flow()`（摆场 → 开战 → 等达标）。
6. 写 `test/scenarios/probe_beghouled.gd` 无头回归，跑通后归档本记录与
   [特殊关卡.md](../参考存档/特殊关卡.md) 的一节。

## 关键决策与理由

- **玩法整体放进一个独立子管理器，不散到各系统** —— 三消状态（棋盘、选中、连锁）自成一体，
  只通过格子 API 与 `EventBus` 跟外界打交道，符合项目「数据驱动 + 组件化」主线。
- **通关不走时间轴的「开战」事件** —— 本关结束条件是配对次数而不是「最后一波刷完 + 僵尸清空」，
  `LevelTimelineEventStartBattle` 的判定用不上；改为 `BeghouledManager.start_beghouled()` 自己开战并 `await` 达标信号。
- **界面纯代码建节点，不做 .tscn** —— 就一行进度文字 + 五个按钮、没有美术资源，
  做场景文件反而多一个没内容要维护的 `.tscn`（主题沿用 `pvz_theme.tres` 以拿到中文字体）。
- **阳光直接进账而不是掉一颗让玩家点** —— 原版配对完立刻进计数器。

## 踩坑

1. **横向连线的坐标列表参数传反了**：`_make_coord_list(起点行, 起点列, 长度, 步长)` 被写成
   `(row, col, 0, len)` → 长度 0、步长 len，于是**横向组是空数组**：不消除、也拿不到阳光
   （现象：连锁跑 7 轮、阳光纹丝不动；纵向正常）。
   → **正解**：`(row, col, len, 0)`；顺手在调用处补一行注释写清参数顺序。
   排查手法：在 `_resolve_board` 的日志里把 `sun_sum` 一起打出来，配合「手动推 `add_sun_value` 有效」
   确认事件链路没问题，从而锁定是 `sun_sum = 0`（组长度算错），而不是 EventBus 或卡槽的问题。
2. **`setup_board()` 里有 `await`，关卡脚本却没等它** —— 摆场内部要等两帧让格子槽位空出来，
   不等就会和 `main_game_start()` 抢跑：探针里时好时坏，坏的时候**棋盘整个是空的**。
   → **正解**：关卡脚本写 `await mg.beghouled_manager.setup_board()`。
   凡是「内部有 await 的玩法初始化」，调用侧一律加 `await`。
3. **GDScript 类型推断**：`for offset in [Vector2i(0, 1), Vector2i(1, 0)]` 里 `offset` 是 Variant，
   下一行 `var row2 := row + offset.x` 直接 `Cannot infer the type` → 脚本解析失败，
   **连带 `MainGameManager` 起不来**（它引用了这个类），表现是探针卡在开始菜单。
   → **正解**：改成 `var neighbor_offsets: Array[Vector2i] = [...]` 再 `for offset in neighbor_offsets`。
   同理探针里 `var grid := mgr._build_type_grid()`（mgr 是 Variant）也要写成 `var grid: Array[Array] = ...`。
4. **新增 `class_name` 脚本后要跑一次导入**：`& Godot --headless --path . --import`
   （再补一次 `--editor --quit` 让新脚本拿到 `.uid`）；不跑的话全局类表里没有 `BeghouledManager`。
   验证方法：`Select-String` 查 `.godot/global_script_class_cache.cfg` 里有没有新类名 ——
   有就说明脚本解析通过，这本身就是一次便宜的语法 / 类型检查。
5. **探针自己阳光不够也会报 NG**：填一个坑要 200 阳光，STEP3 只消了一组（25 阳光），
   于是不加判断就以为「填坑坏了」。→ **正解**：断言前先把前置条件（阳光）补足再断言功能。

## 给后来者的最简路径

1. 数值写进 `src/core/consts/const_beghouled.gd` 这类常量文件（带来源注释），玩法写进一个
   `MainGameSubManager` 子类，挂到 `MainGameManager` 下、由关卡字段决定是否创建。
2. 关卡脚本只留「配置 + `run_flow()`」；结束条件不是波次的关，**不要用 `prefab.start_battle()`**，
   自己开战 + `await` 自定义达标信号。
3. 搬植物就用 `glove_take_plant` / `glove_put_plant`；要清空格子再种新的，**必须等两帧**
   （`queue_free` 与死亡回调都在这两帧里跑完，同 `PlantCellManager` 的清场写法）。
4. 写完直接上无头探针：照 `probe_beghouled.gd` 的骨架（进关 → 等阶段 → 断言 → 机器可读汇总行），
   `powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_xxx`。
5. 收尾：在 [特殊关卡.md](../参考存档/特殊关卡.md) 追加一节（含「数据来源 / 口径」尾注）+ 本目录归档一条。

## 人工验证方法（本次没开窗口的部分）

- 选关进「迷你游戏」第 5 关：草坪应已铺满植物、最右一列空着、屏幕顶部显示 `配对 0 / 75`、
  底部一排五个按钮（三档升级 / 重置 / 填坑，钱不够时置灰）。
- 点一株植物会出现黄色高亮框，再点相邻一株：凑成连线就消除并涨阳光、上方植物落下来补位；
  凑不成连线会换回去。

---

## 补充 / 评价（2026-10-04 · 三消已整包搬出本体）

> 后续任务[2026-10-04\_僵尸迷阵三消整包搬出本体.md](2026-10-04_僵尸迷阵三消整包搬出本体.md)：
> 本关三消只服务这一关，按硬约束 §1-8 把玩法搬出了本体。

- **本文「最简路径」第 1 条已过时**：「挂到 `MainGameManager` 下、由关卡字段决定是否创建」
  正是硬约束 §1-8 要避免的写法。现在的口径是：**一关专属玩法由关卡脚本自己创建并持有**，
  本体只给通用口子 `MainGameManager.register_level_init_callback()`，关卡数据上不留玩法开关字段。
- 玩法文件已搬到 `src/levels/script/mini_game/beghouled/`（连 `.uid`，搬前先关编辑器），
  `is_beghouled` 字段已删；`PlantCell.create_crater_permanent()` / `remove_crater()` 作为通用能力保留。
- 本文其余内容（ glove 搬运 API 要等两帧、结束条件不用 `prefab.start_battle()`、探针骨架）**仍然成立**。
- 故意放一只僵尸吃掉一株植物：原地留坑，攒够 200 阳光点「填坑」后该格长出新植物。
- 攒够阳光点升级按钮：场上同类植物全部换成升级版，按钮变「已购买」。
- 配对到 75 次掉奖杯通关；放任意一只僵尸进屋则判负（本关没有小推车）。

---

## 补充 / 评价（2026-10-05 · 补全植物升级逻辑）

> **本次记录**：[2026-10-05\_补全僵尸迷阵植物升级逻辑.md](2026-10-05_补全僵尸迷阵植物升级逻辑.md) ←→ 被补充：本文件
> **索引推荐度**：**推荐** → **推荐**（未改）

- **补充**：本文「踩坑」没写到的一处 —— 凡「遍历同步杀死植物 → `await` 两帧 → 重新 `create_plant`」的流程
  （买升级换场、换局摆场都是），那两帧里棋盘是**半空**的：
  ① 必须有一把锁把所有玩家入口挡住（现在统一收在 `BeghouledManager._can_operate()`）；
  ② 「这是我自己拿走的」标志 `_self_removing` 要覆盖到整个异步区间，不能被 await 切成两段，
  否则中间的 `_on_plant_free` 会被当成「被僵尸啃掉」，原地留一个不该有的弹坑；
  ③ 换场收尾要调 `_ensure_board_playable()`，不然可能买完升级就死局，还得再花 100 阳光洗牌。
- **补充**：`beghouled_ui.gd` 原来写死 `for i in range(5)`、parse 按钮用 `match 0,1,2 / 3 / 4`，
  加减一档升级要连 UI 一起改；现在按钮数与下标判断都跟 `ConstBeghouled.UPGRADE_LIST.size()` 走。
- **评价**：本文的 5 步（常量表 + 独立子管理器 + 手套搬运 API + await 两帧 + 探针骨架）**仍然成立**，
  这次只是在第 3 / 4 步外面补了锁与收尾；第 5 步的探针骨架依然好用（本次往 STEP5 加了 4 条断言即覆盖新逻辑）。
- **更省的做法**：无。
