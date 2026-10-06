# 2026-10-02 · 新增内容 · 原版植物僵尸（ZomBotany）

> **任务类型**：新增内容（僵尸）
> **推荐度**：**推荐**
> **耗时与成本**：约 1 轮（承接上一轮 [子弹系统阵营对称重构](2026-10-02_子弹系统阵营对称重构.md)）；未开窗口，跑了无头探针
> **验证方式**：免验证 + 已给出人工验证方法（见「验证」一节）
> **补充自**：[2026-10-02\_子弹系统阵营对称重构.md](2026-10-02_子弹系统阵营对称重构.md)（本任务是它的下游）

## 目标

实现原版 ZomBotany 的 13 只植物僵尸：僵尸头顶插着一棵植物，这棵植物
① 有自己的耐久（先掉植物才掉本体），② 用原植物的能力攻击玩家的植物。

可判定：迷你游戏「植物僵尸」里能出这 13 只，豌豆僵尸会朝玩家的植物射豌豆，头顶植物打掉后僵尸变回普通僵尸。

## 步骤

1. 先摸现状：`CharacterRegistry` 的 ZombieType / ZombieInfo、僵尸基类与攻击组件、出怪表、
   迷你游戏选关怎么登记、`assets/reanim/` 里有哪些植物贴图可用。
2. 确认**没有**原版植物僵尸的 reanim 贴图 → 头顶植物改用植物部件 PNG 拼静态图（这条决定了后面所有取舍）。
3. 立数据层：`ZomBotanyConfig`（13 只的贴图 / 耐久 / 挂点 / 战力权重集中一处）。
4. 立表现层：`ZombiePlantComponent`（运行时拼头顶植物 + 防具掉光就隐藏）。
5. 立攻击层：`AttackComponentZomBotany`（不靠动画触发发射）+ 玉米炮变体。
6. 特殊 4 只各写一个小脚本：窝瓜 / 辣椒 / 火炬 / 磁力菇。
7. 用一次性 PowerShell 脚本生成 13 个继承场景（只改属性的 `.tscn`），跑生成后即删。
8. 注册：ZombieType 枚举 Z031–Z043 + ZombieInfo 13 条；出怪战力 / 权重改走配置表。
9. 建 `minigame_06_zom_botany.tres` + 选关界面第 2 页加按钮。
10. 写 `probe_zom_botany` 锁结构，写 [植物僵尸.md](../参考存档/植物僵尸.md)。

## 关键决策与理由

- **一份配置表 + 13 个只改属性的场景，而不是 13 份各写各的** ——
  差异全是数据（贴图 / 耐久 / 子弹 / 战力），散进 13 个场景必然漂移；场景里只留「属性覆盖」。
- **头顶植物耐久走 `HpComponent.max_hp_armor1`，组件不自己存一份** ——
  伤害结算与血条都在 HpComponent 里（K-01），自己另存会和它各演化各的。
- **不直接复用植物的 `AttackComponentBulletBase`** ——
  它的发射是**攻击动画里的 `_shoot_bullet()` 方法调用轨道**触发的，僵尸的攻击动画是「啃咬」没有这条轨道，
  直接套用 = 冷却一直在走、一颗子弹都不出。所以重写 timeout 直接发射，用 Tween 代替动画表现。
- **子弹方向写死 `Vector2.LEFT`，不用 `detect_component.ray_area_direction`** ——
  后者按检测区 `rotation` 算，僵尸的啃咬检测区 rotation 是 0（朝右），拿来用子弹会往僵尸身后飞。
- **出怪战力 / 权重只在 ZomBotanyConfig，不抄进 `zombie_power` / `zombie_weights_ori`** ——
  13 只各写一份会让两张表翻倍；改成 `get_zombie_power()` / `get_zombie_weight()` 先查配置表再回落。
- **没做冒险模式关卡** —— 原版 ZomBotany 是迷你游戏（冒险 4-5 是砸罐子），所以做成 `minigame_06_zom_botany`。
- **磁力菇僵尸只对「玩家种了磁力菇」生效** —— 原版就是这样，不是偷工。

## 踩坑

1. **`const C_ZOM_BOTANY_INFO = { ... ZomBotanyInfo.new(...) }` 编译不过**（`isn't a constant expression`）
   → GDScript 的 const 初始值里不允许 `new` 内部类实例
   → **正解**：改 `static var` + `static func _static_init()` 里赋值。
2. **生成的 `.tscn` 全部加载失败**（`Parse Error: Expected '['`）
   → PowerShell 的 `Set-Content -Encoding utf8` 在 Windows 会写 **UTF-8 BOM**，Godot 不认
   → **正解**：`[System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))`；
   排查用「读首字节是不是 239,187,191」（`[` 是 91）。
3. **`super()` 在 `ZombiePlantComponent._ready()` 里报 `Cannot call the parent class' virtual function`**
   → `ComponentNormBase` 根本没定义 `_ready()`
   → **正解**：组件里去掉 `super()`。
4. **`var all_plant_cells := Global.main_game.plant_cell_manager.all_plant_cells` 编译不过**（`Cannot infer the type`）
   → 动态属性推断不出类型
   → **正解**：显式写 `var all_plant_cells: Array = ...`。
5. **新建 `.gd` 后 Godot 认不到 class_name**
   → 缺 `.uid`（上一轮已踩过一次）
   → **正解**：跑一次 `godot --headless --path <项目> --editor --quit` 导入；仓库惯例每 `.gd` 带同名 `.uid`。
6. **`Get-ChildItem -LiteralPath ... -Include` 不生效**（`-Include` 只对 `-Path` 的通配符起作用），
   结果匹配到一堆目录疯狂报「访问被拒绝」
   → **正解**：要过滤文件名就用 `Get-ChildItem -Path '<含通配符>' -File`。

## 验证

- 全项目编译：`godot --headless --path <项目> --editor --quit` → 无 `SCRIPT ERROR` / `Parse Error`。
- `probe_zom_botany` → `[ZOMBOTANY] result=PASS failed=0`
  （13 只配置自洽 + 场景属性落地：zombie_type、头顶植物耐久、发射组件类型、机枪 4 连发）。
- 上一轮的 `probe_bullet_camp` / `probe_bowling_redline` 未回归（仍 PASS）。
- 未覆盖：头顶植物贴图位置、发射手感、窝瓜 / 辣椒 / 火炬 / 磁力菇的实际效果 —— 都要开窗口看。

**人工验证方法**（开窗口 → 迷你游戏第 2 页「植物僵尸」）：

1. 开局观察是否有头顶带植物的僵尸进场，且**头顶植物先掉耐久**（血条先掉防具）；
2. 把豌豆僵尸那行的植物放了，看它是否**朝左（朝房子）**持续射豌豆、豌豆能否打掉玩家的植物；
3. 打掉头顶植物 → 僵尸应变成普通僵尸外观且不再发射；
4. 机枪僵尸应一次 4 连发；寒冰僵尸射出的豌豆应带减速；
5. 卷心菜 / 西瓜 / 冰瓜 / 玉米炮僵尸应投出抛物线弹（注意玉米炮要能炸到植物）；
6. 坚果 / 南瓜僵尸应明显更耐打；
7. 窝瓜僵尸碰到植物应把植物压死并**自己消失**；辣椒僵尸应烧掉**整行**并自己消失；
8. 火炬僵尸：玩家豌豆打中它之后应变成火豌豆继续飞；
9. 磁力菇僵尸：种一棵磁力菇在同行，约 15 秒后应被吸走。

## 给后来者的最简路径

1. 改数值 / 贴图 → 只动 `src/entities/character/components/zombie_plant_component/zom_botany_config.gd`。
2. 新增第 14 只 → 照 [植物僵尸.md](../参考存档/植物僵尸.md) §5：枚举 + 配置表 + ZombieInfo + **继承 `zombie_norm.tscn` 的场景**（节点索引照现成的抄）。
3. 验证：`godot --headless --path <项目> -- --scenario=res://test/scenarios/probe_zom_botany.gd --autopilot-max-seconds=60`，
   再开窗口跑一遍上面 9 条。
4. 想给僵尸也做「追踪类」植物僵尸（比如香蒲僵尸）→ 先补一个**僵尸视角的全局检测组件**，
   现在的 `DetectComponentGlobal` 只检测僵尸层（见 [子弹说明](../参考存档/子弹说明.md) §3 的已知边界）。

---

## 补充 / 评价（2026-10-03 · 把本关挪成迷你游戏第 1 关）

> **本次记录**：[2026-10-03\_迷你游戏第一关改植物僵尸.md](2026-10-03_迷你游戏第一关改植物僵尸.md) ←→ 被补充：本文件
> **索引推荐度**：**推荐** → **推荐**（未改）

- **补充**：第 9 步「选关界面第 2 页加按钮」已漂移 —— 本关现在是**迷你游戏第 1 关**
  （第 1 页第 1 位），对齐原版 ZomBotany 的 1 号位；文件名 `minigame_06_zom_botany.gd` 没改（`06` 只是编号）。
  **挪位前先给关卡写死 `save_key`**（本关是 `102_1_0022`），否则存档键跟着按钮顺序漂、老存档会串关。
- **评价**：本次照「改选关 `.tscn` 按钮 `index`」这条路径做，一次到位；装饰子树不用动，比搬节点省事得多。
- **更省的做法**：建关时就一次性写死 `save_key`，后面重排顺序就完全不用管存档键。

---

## 补充 / 评价（2026-10-04 · 收尾两关：补高坚果僵尸 + 修三处关卡设置）

> **本次记录**：[2026-10-04\_完成植物僵尸两关.md](2026-10-04_完成植物僵尸两关.md) ←→ 被补充：本文件
> **索引推荐度**：**推荐** → **推荐**（未改）

- **补充 1（原记录没写的口径）**：本记录第 11 步做的 13 只里，**只有 2 只是原版 ZomBotany 真有的**
  （豌豆僵尸 + 坚果僵尸），ZomBotany 2 再加窝瓜 / 火爆辣椒 / 机枪 / **高坚果** —— 原版没有南瓜头僵尸，
  本仓库当时是拿它顶替了高坚果的位置。高坚果僵尸已在 2026-10-04 补成 `Z044TallNutZombie`（耐久 2200）。
- **补充 2（静态探针查不到的坑）**：本记录第 10 步建的关卡里写了 `card_mode = Null`，
  会被 `_apply_card_mode_constraints()` 压成「不能选卡」，而关卡又没预选卡 —— **玩家一张植物都带不进去**，
  这关一直到 2026-10-04 才被修掉。新建关卡时卡槽模式留默认 `Norm` 就没事。
- **评价**：照本记录 §最简路径加第 14 只（枚举 → 配置表 → ZombieInfo → 继承场景）一次到位，四步都不用改基类。
- **更省的做法**：新增一只之后**顺手跑一次进关卡的一次性探针**（`create_norm_zombie` 造一只出来看头顶植物有没有拼上）——
  静态探针只查得到场景属性，查不到「组件在真实关卡里有没有跑起来」。
