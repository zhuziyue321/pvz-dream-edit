# DLC 植物导入（并行作业手册：一株 = 一个交付单元）

> **[面向 AI Agent]** ｜ **触发条件**：往 `mods_builtin/dlc/` 接第 N 株 DLC 植物（动画已在 `mods_builtin/dlc/animation/` 下）；多 agent 并行接一批；改已接植物的场景 / 脚本 / 配方 / 图鉴 / 探针
>   
> **读完你能**：按 §5「角色卡」填空，产出 6 个文件 + 共享文件里 5 个槽位的追加改动，形状与已有 16 株一致；知道并行时哪些文件、哪些区域自己不能碰；用 §7 自检表判定「这一株做完了」
>   
> **强制级别**：参考 ｜ **多 agent 并行作业时，§1 的 6 条红线按必须执行**（2026-10-18 已因不遵守而混乱，见 §10）
>   
> **不读的风险**：并行时互相覆盖 `dlc_mod.gd`；同一批植物各写各的（命名 / 检测框 / 卡面 / 探针形状不同）；文档写「两株」而代码已 16 株
>   
> **关联**：动画怎么转 [动画导入.md](动画导入.md) §2 ｜ 运行期登记机制 [运行期植物.md](运行期植物.md) ｜ 挂组件 [创建新角色.md](创建新角色.md) ｜ 图鉴条目 [图鉴.md](图鉴.md) ｜ 取 wiki 数值 [AI查wiki避坑.md](AI查wiki避坑.md) ｜ 子弹基类 [子弹说明.md](子弹说明.md) ｜ 并行分工 [../Agent协作协议.md](../Agent协作协议.md)

> **一句话**：DLC 植物 = 把 `reanim` 转成 `AnimationPlayer` 动画 + 模组自己的 `plant_base` 子场景 + 一张 `PlantRuntimeRecipe`。

---

## 0. 三种读法（别从头读到尾）

| 你的情况                | 读哪几节                          |
| ------------------- | ----------------------------- |
| 单人接一株               | §5 角色卡（照卡填空）→ §6 技术要点 → §7 自检 |
| **多 agent 并行接 N 株** | **§1 并行契约（先读）** → §5 → §7     |
| 只改一株的数值 / 名字 / 文案   | §2.2 三处同步 → §8 登记表 → §7.2     |

本文件只管 **DLC 模组这条线**（`reanim/` → 动画 → 模组自己的场景 + 配方）。
  
通用部分不重复：动画转换参数在 [动画导入.md](动画导入.md) §2，配方字段与装 / 卸在 [运行期植物.md](运行期植物.md)。

---

## 1. 并行契约（本文件的核心，接一株之前先认这张表）

### 1.1 文件归属矩阵

| 文件 / 目录                                           | 谁写              | 并行策略                                               |
| ------------------------------------------------- | --------------- | -------------------------------------------------- |
| `mods_builtin/dlc/<小写>/`（场景 + 脚本 + 子弹 + 技能脚本）     | **该株 agent 独占** | 零冲突：目录归你，随便建文件                                     |
| `test/scenarios/probe_dlc_<小写>.gd`                | **该株 agent 独占** | 零冲突：文件名带角色名                                        |
| `mods_builtin/dlc/dlc_mod.gd`                     | **全体共享**        | 只往 §1.2 的 5 个代码槽位 + 2 处文案**追加自己那几行**；禁止重排、禁止重构公共函数 |
| `mods_builtin/dlc/animation/**`                   | 转换工具            | 只读；不手改（改名流程见 §3.3）                                 |
| `src/**`、`data/**`、`src/mods/mod_ids.gd`、其它模组 | **谁都不改**        | 一株植物不该改动本体；能力不够就报给 main，由 main 单独提交                |

### 1.2 `dlc_mod.gd` 的 5 个代码槽位 + 2 处文案（按 `#region` 定位，一律追加到末尾）

| #      | 槽位                                               | 追加什么                                                                           | 形式                            |
| ------ | ------------------------------------------------ | ------------------------------------------------------------------------------ | ----------------------------- |
| **S1** | `#region 常量` 末尾                                  | `<UPPER>_SCENE`（preload）+ id 常量 + 数值常量块（阳光 / 冷却 / 卡面动画 / 兜底脸 / 卡面缩放与落点；紫卡再加前置） | 一块连续的 `const`，块首一行 `##` 写数值来源 |
| **S2** | `install()` 里配方数组的末尾                             | `_build_<小写>_recipe()`                                                         | **一行一项**                      |
| **S3** | `install()` 里图鉴登记调用段的末尾                          | `_register_<小写>_almanac_entry()`                                               | **一行一项**                      |
| **S4** | `uninstall()` 里 `clear_extra_almanac_entry` 段的末尾 | `Global.global_read_data.clear_extra_almanac_entry(<ID>)`                      | **一行一项**                      |
| **S5** | `#region 图鉴条目` / `#region 配方` 各自末尾               | 两个函数：`_register_<小写>_almanac_entry()`、`_build_<小写>_recipe()`                   | 两个 region 各追加一个函数，函数之间空两行     |

**S6 / S7（文案，必须一起做，否则就是漂移源）**

| #      | 槽位                                  | 追加什么                                                                                |
| ------ | ----------------------------------- | ----------------------------------------------------------------------------------- |
| **S6** | `create_detail_control()` 的 label 段 | 一行 `ModBase.create_detail_label("已接植物：<中文名> —— <阳光> 阳光，<一句话机制>（冷却 …、伤害 …、攻击间隔 …）")` |
| **S7** | `get_mod_description()` 的长串         | 在「当前已接成能种的」后面补 `**<中文名>**（…）`，**并检查前面漏没漏别人的株**                                      |

> 历史坑：`_register_almanac_entry()`（**没有角色名**）是环轨仙人掌的遗留命名，别照抄。新株一律 `_register_<小写>_almanac_entry()`。
>
> **`#region 水盆：水生植物可以种进去` 不属于这 5 个槽位**：它是原「水盆」模组（2026-10-18 并入本模组）的
> 专用逻辑（`_open_water_plants_to_bowl()` / `_restore_water_plants()`）与 `waterbowl/` 目录，
> 接新的 DLC 植物时**不要动它**。

### 1.3 并行红线（6 条，违反即视为没交付）

1. **只追加、不重排**：不改别人株在数组 / 常量区里的顺序，不移动已有行。
2. **不抽公共函数**：别为了让 `install()` / `uninstall()` 少重复就改成数据表 —— 那是 main 的单独重构；混在植物提交里会和所有并行分支冲突。
3. **不碰本体**：`src/`、`data/`、`project.godot`、`mod_ids.gd` 一行都不改。
4. **不碰别人的角色**：只写自己 `<小写>/` 目录 + 自己那条探针 + 自己那 7 处追加。
5. **不动动画产物**：`animation/**` 由转换工具生成；确需改名按 §3.3 单独提交，不混进植物提交。
6. **一株一笔提交**：逐路径 `git add -- <文件>`，禁 `git add -A`（[Agent协作协议](../Agent协作协议.md) §1）。

### 1.4 谁验证、谁合并

- 每株 agent 自己跑：编译门禁（§7.2 命令 1）+ 自己那条探针。
- main 串行合并，合并后再跑一遍全量探针（`test/run_all_scenarios.ps1`，口径见 `test/README.md`）。
- 撞车时保留双方内容，按「一行一项」重新排好，**不删别人的行**。

### 1.5 派活模板（main 复制、填空、发给 agent）

```text
角色：<中文名>（美术资源名 <ArtName>）
id：dlc_<小写>；目录：mods_builtin/dlc/<小写>/
卡型：普通卡 / 紫卡（基座 PlantIds.<X>）
数值：阳光 <n> / 冷却 <n> 秒 / 伤害 <n> / 攻击间隔 <n> 秒 / 射程 <…>
攻击方式：直线 / 散射 / 抛射 / 近战 / AOE / 一次性 / 支援
允许改：mods_builtin/dlc/<小写>/**、test/scenarios/probe_dlc_<小写>.gd、dlc_mod.gd 的 S1~S7 槽位
禁止改：其它角色目录、install()/uninstall() 的结构、src/**、data/**、animation/**
交付：§7.1 自检表逐项打勾 + 探针 PASS 的最后一行
```

### 1.6 DoD：这一株算不算做完（6 项全过）

1. `test/check_scripts.ps1` 输出 `real compile errors = 0`。
2. `probe_dlc_<小写>.gd` 存在且 `result=PASS`（**没有探针 = 没做完**，§8 已有一株欠账）。
3. S1~S5 齐全，S6/S7 文案已同步。
4. 命名与 §2 口径一致（id / 目录 / 场景 / 脚本 / 常量 / 函数 / 探针）。
5. 摆放与卡面在探针里有**量化断言**（运行期内容矩形 + 底边对齐 + 卡面中心 ±4 px），不接受「看着差不多」。
6. §8 登记表补上自己那一行。

---

## 2. 命名口径（单一来源，照抄不改）

### 2.1 命名表

| 项       | 规则                                                                                                                                             | 例                                        |
| ------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| id      | `dlc_` + 全小写、无下划线                                                                                                                              | `dlc_kingcactus` / `dlc_shrinkingviolet` |
| 目录      | 角色全小写                                                                                                                                          | `kingcactus/` / `mortarshroom/`          |
| 场景      | `plant_<小写>.tscn`，继承本体 `plant_base.tscn`                                                                                                       | `plant_pultshroom.tscn`                  |
| 脚本      | `<小写>_plant.gd`，`extends Plant000Base`，**不写 `class_name`**                                                                                     | `pultshroom_plant.gd`                    |
| 子弹      | `bullet_<小写>_<名字>.tscn` + 需要时同名的 `.gd`                                                                                                         | `bullet_mortarshroom_shell.tscn`         |
| 技能 / 组件 | `<小写>_<名字>.gd`（如 `reed_lightning.gd`）                                                                                                          | `aloe_heal_area_component.gd`            |
| 常量      | `<UPPER>_SCENE` / `_SUN_COST` / `_COOL_TIME` / `_CARD_ANIM` / `_FALLBACK_PLANT` / `_CARD_FACE_SCALE` / `_CARD_FACE_POSITION` / 紫卡 `_PRE_PLANT` | `REED_COOL_TIME`                         |
| 函数      | `_build_<小写>_recipe()` / `_register_<小写>_almanac_entry()`                                                                                      | `_build_beeshooter_recipe()`             |
| 探针      | `test/scenarios/probe_dlc_<小写>.gd`，末行 `[DLC] result=PASS\|FAIL failed=<n>`                                                                     | `probe_dlc_aloe.gd`                      |
| 动画段     | **以 `animation/.../<ArtName>/` 里实际 `.tres` 名为准**；美术名 ≠ 中文名 ≠ id                                                                                | `BeeShooter_full_idle`                   |

### 2.2 三处文案必须同一次改完

`get_mod_description()`（S7）、`create_detail_control()`（S6）、图鉴条目（S5）—— 改名字 / 价格 / 机制时最容易只改一处。

---

## 3. 前置：动画从哪来

### 3.1 转换（编辑器里做，不是 agent 自动做）

1. 插件 `addons/R2Ga_PVZ/` 已于 2026-10-18 移出仓库，需从 [上游](https://github.com/hsk-dream/PVZ_reanim2godot_animation) 取回并在「项目设置 → 插件」启用。
2. 底部面板 `R2Ga_PVZ`（路线 A，见 [动画导入.md](动画导入.md) §2），对每个角色：
   - 文件：`res://mods_builtin/dlc/reanim/<ArtName>/*.reanim`
   - 动画输出目录：`res://mods_builtin/dlc/animation/character/plant/<ArtName>/`
   - 图片输出目录：`res://mods_builtin/dlc/reanim/<ArtName>/`
3. 产物：每段一个 `.tres` + 一个 `<ArtName>.tscn` + 每部件一张 PNG（自包含，路径已在模组目录内）。

### 3.2 选段规则

- 必备：`idle` +（攻击类）`shooting` / `attack` / `blow` / `explode`。没有可用的动作段就先别接，等 main 定。
- **换色 / 变体只挑一套**：`PultShroomC1_*`、`BonkChoyF_*`、`*Legacy_*` 是第二套贴图，别把两套挂进同一个库；优先无后缀的正式套。
- 记下每段 `length`：**`attack_cd` 必须长于动作段**，出弹时机取动作峰值帧（§6.3）。
- `sleep` 段只有蘑菇类用；`*_idle2` / `*_rotate` 这类是额外状态，按需取。

### 3.3 已知产物缺陷：文件名乱码

转换工具可能把含「复制」的段写成乱码名（如 `澶嶅埗`），而 `<ArtName>.tscn` 里引用的是正常名 → 该 `.tscn` 整份加载失败，连带植物场景 / 卡面全崩。
  
做法：按 `.tscn` 里的引用把文件重命名回来，**用 Python `os.rename` 保 UTF-8**，别用 PowerShell 命令行（控制台编码会把「复制」再写坏）。`VoltShroom_face 复制.tres` 就是踩过的例子。

---

## 4. 数值：先有数据再写代码

```
# 总表（能看到每株的阳光 / 冷却 / 伤害，但很多格子是空的）
https://pvz-dlc-edition.fandom.com/wiki/Plants?action=raw
# 单页（完整字段；?action=raw 对单页返回 403，必须走 API）
https://pvz-dlc-edition.fandom.com/api.php?action=parse&page=Pult-shroom&prop=wikitext&format=json
```

- 页面标题先用 `api.php?action=search&list=search&srsearch=<关键词>&format=json` 确认大小写（是 `Pult-shroom`，不是 `PultShroom`）。
- 取数姿势与坑见 [AI查wiki避坑.md](AI查wiki避坑.md)；**数值口径以本仓为准**，把「对齐的是 wiki 哪一项」写进常量注释。
- wiki 缺字段就自己定值，并在注释里写明「模组自定」，别留空让人以为是抄漏。

---

## 5. 角色卡（填空模板：一张卡 = 一株）

### 5.1 数据卡

| 字段                    | 写进哪                                      | 备注                                                      |
| --------------------- | ---------------------------------------- | ------------------------------------------------------- |
| 中文名 / 美术名 / id / 小写目录 | S1 注释 + §8 表                             | 三个名字可能都不同（环轨仙人掌 = KingCactus = `dlc_kingcactus`）        |
| 阳光 / 冷却               | S1 常量 → 配方                               | 冷却必须 ≥ 卡面动画时长                                           |
| 生命 / 伤害 / 攻击间隔 / 射程   | 场景导出值 + 脚本常量                             | 探针要断言                                                   |
| 卡型                    | 配方 `is_purple_card` + `purple_pre_plant` | 紫卡登记由 `PlantRuntimeKit` 自己做，**别手写 `AllPrePlantPurple`** |
| 攻击方式                  | §5.2 检测框口径表                              | 决定 `is_lane` 与框尺寸                                       |
| 特殊状态                  | §5.3                                     | 睡眠 / 一次性 / 支援 / 加速                                      |

### 5.2 场景卡（继承本体 `plant_base.tscn`）

```text
根节点（plant_base.tscn 继承）+ 自己的脚本
  ├── AnimComponent            → 换 component_anim_empty.gd（DLC 动画没有 AnimationTree）
  ├── Body
  │     ├── <ArtName>Anim      → 实例化 animation/.../<ArtName>.tscn，只设 position（不设 scale）
  │     │     └── AnimLib      → 覆盖 libraries：把要用的几段 .tres 合成一个库
  │     └── Marker2D           → 子弹出生点（按画布上的嘴 / 篮子 / 刺座换算成节点坐标）
  ├── SleepComponent           → 蘑菇类：is_sleep_in_day = true，并把 DetectComponent 放进 sleep_influence_components
  ├── AttackCdTimer            → wait_time 写数值（脚本里再按导出值设一次）
  ├── ShootTimer (one_shot)    → 从开火到出弹的延迟
  └── DetectComponent (Area2D + CollisionShape2D)
```

**必须覆盖 `AnimLib` 的库**：转换工具把每段动画各放进一个独立 `AnimationPlayer`（`Anim_<ArtName>_idle` …），而 `AnimLib` 里只有一条 `ALL_ANIMS` 合并动画 —— 既不是分段名、也没法按段播；卡面取帧找的偏偏是它。
  
`AnimLib` 在动画场景里的 `index` 要照实际数（KingCactus `20`、PultShroom `11`）。

**检测框口径**：

| 攻击方式            | `is_lane`  | 形状                               | 位置                                            |
| --------------- | ---------- | -------------------------------- | --------------------------------------------- |
| 本行射手 / 投手       | `true`（默认） | 一行宽矩形（投手按射程，如 6 格 = 456 px，高 60） | `Area2D (0,-25)` + `CollisionShape2D (半宽, 0)` |
| 全屏（环轨仙人掌）       | `false`    | 2400×1600（比视口大，种在角落也罩住全场）        | `Area2D (0,-200)`                             |
| 近战（拳击白菜 / 甜菜守卫） | `true`     | 本行左右各约一格                         | 以根节点为基准，形状写场景                                 |
| AOE（电击蘑菇）       | `false`    | 3×3（228×285 量级）                  | 以自身格为中心                                       |

### 5.3 脚本卡

统一走「**自己挂检测组件 + 计时器**」这条路，**不要**用 `AttackComponentBulletBase` / `AttackComponentBulletPultBase`：它们写死 `@onready var animation_tree: AnimationTree = $"../AnimationTree"`，DLC 动画只有 `AnimationPlayer`，场景加载就报 `Node not found`。

**必填钩子**（`extends Plant000Base`，不写 `class_name`）：

| 钩子                                                 | 必做                                                                                                                                                                                            |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ready_norm_signal_connect()`                      | `super()` 后设两个 Timer 的 `wait_time`；连 `DetectComponent.signal_can_attack` / `signal_not_can_attack`；连两个计时器与 `_anim_player.animation_finished`；连 `sleep_component` 两个信号；连 `signal_update_speed` |
| `ready_norm()` / `ready_show()` / `ready_garden()` | `super()` 后播待机；**睡眠中别用待机盖掉睡眠姿势**（`if not is_sleeping`）                                                                                                                                        |
| `_on_animation_finished()`                         | 动作段播完回待机；一次性植物在这里 `character_death()`                                                                                                                                                         |

**四种形态的分支**：

| 形态                            | 关键点                                                                                                                                                                             |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 直线子弹                          | `Direction` 传发射方向，`IsActivateLane = true`                                                                                                                                       |
| 多方向散射                         | `IsActivateLane = false`（否则 45°/90° 那几根过不了行判定），行号仍传（只用于 `z_index`）                                                                                                              |
| 抛射（投手）                        | 出弹前**重新** `detect.update_first_enemy()`；`init_bullet` 必须带 `Enemy` + `EnemyGloPos`，缺这两个键贝塞尔曲线落在原点                                                                                |
| 一次性（血橙 / 柠檬榴弹 / 缩小紫罗兰 / 飓衣甘蓝） | 引信或动画结束 → 触发 → 动作段播完 `character_death()` 自毁；**不要**自己 `queue_free()`（死亡链路要清格子 / 补位）                                                                                              |
| 支援（芦荟 / 增幅鹅河菊）                | 不挂攻击检测，自己写范围组件（`Area2D`，`collision_layer = 0`、`collision_mask = 2` 只听「植物受击框检测层」），定时给范围内植物回血 / 加速；回血走 `HpComponent.hp_heal(amount)`，不是负向伤害、不走 `DamageSystem`；形状 / 位置写在场景里，脚本不自己造 |
| 近战（拳击白菜 / 甜菜守卫）               | 不出子弹，检测到就播动作段 + 直接对 `can_attack` 通过的目标结算（击退 / 斩杀），结算时机取动作峰值帧                                                                                                                    |

**全场加速（必做，漏了就是「暂停时它还在打」）**：

```gdscript
func _on_update_speed(speed_product: float) -> void:
	if speed_product == 0:
		_timer.paused = true
		_anim_player.speed_scale = 0.0
		return
	_timer.paused = false
	_anim_player.speed_scale = speed_product
	if not _timer.is_stopped():
		_timer.start(_timer.time_left / speed_product)
	_timer.wait_time = base_wait / speed_product
```


### 5.4 子弹卡

- 复用本体基类：`res://src/entities/bullet/bullet_parabola_base.tscn`（抛物线）/ `bullet_cactus.tscn`（直线）等，只换贴图与数值。
- **抛物线高度是 `MovementComponent` 的字段，不是子弹根的字段**：

```text
[node name="MovementComponent" parent="." index="4"]
parabola_height = -260.0
```

  写在根节点上会被**静默忽略**（一直吃基类的 -300）。
- 直接 `instantiate()` 而不走 `BulletRegistry` 时，补三件事（与 `create_bullet()` 同口径）：
  `bullet.entity_id = Character000Base.take_next_entity_id()`、读 `GlobalUtils.bullet_spawn_gate`、再 `add_child`。
- 抛物线子弹 `_ready()` 会读主场景（斜坡 / 行基准 y）—— **探针里别把孢子挂进空场景**，只检查字段即可。

### 5.5 注册卡

```gdscript
func _build_reference_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = REED                       ## S1 的 id 常量
	recipe.plant_name = &"Reed"                    ## 美术名，与动画目录一致
	recipe.plant_scene = REED_SCENE
	recipe.cool_time = REED_COOL_TIME
	recipe.sun_cost = REED_SUN_COST
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM   ## 普通陆生：草地 / 花盆 / 睡莲
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 紫卡才写这两行；AllPrePlantPurple 的登记 / 撤销由 PlantRuntimeKit 自己做
	# recipe.is_purple_card = true
	# recipe.purple_pre_plant = XXX_PRE_PLANT
	recipe.card_face_anim = REED_CARD_ANIM
	recipe.card_face_fallback_plant = REED_FALLBACK_PLANT      ## 取帧失败时的兜底脸
	recipe.card_face_scale = REED_CARD_FACE_SCALE
	recipe.card_face_position = REED_CARD_FACE_POSITION
	return recipe
```

- 图鉴：`Global.global_read_data.register_extra_almanac_entry(id, {...})`，`uninstall()` 里 `clear_extra_almanac_entry(id)`；字段口径见 [图鉴.md](图鉴.md)。紫卡的「只能种在 X 上」写进 `参数.特点`（本体紫卡同口径）。
- `install()` 里一株失败只 `Log.error` + `continue`，别让整包模组起不来。
- 新增株**不进** `PlantIds` 枚举（id 是 StringName，模组自己起）。

### 5.6 探针卡（一株一份，12 条断言，按类型裁剪）

1. 注册：场景 / 阳光 / 冷却 / 条件位 / 已解锁（紫卡再加 `is_purple_card` + `AllPrePlantPurple`）
2. 卡位：`AllCards.plant_card_ids` 有它、排在普通植物之后
3. 图鉴：名字 / 关键参数
4. 种下去：根节点脚本正确、`Body/<ArtName>Anim/AnimLib` 在
5. 动画：要用的段都在、当前在播待机且在跑、动画根 `scale == ONE`
6. 摆放：`get_content_rect()` 量尺寸与底边，与本体同类植物比（投手对齐小喷菇）
7. 战斗零件：`is_lane`、检测框尺寸、计时器 `wait_time`、导出数值
8. 子弹（若有）：基类、伤害、速度、`MovementComponent.parabola_height`、贴图
9. 有敌人 → 播动作段 → 播完回待机
10. 特殊状态：睡眠换姿势 / 全场加速暂停 / 一次性自毁 / 支援回血
11. 卡面：整株内容中心（含 `Anim.position`）落在挂点 ±4 px
12. 关模组：注册 / 解锁 / 卡位 / 图鉴（紫卡再加前置登记）全撤

写法：复制最近一株的探针改常量即可，**别新造一套断言辅助函数**（`_check` / `_finish` 保持同名同形）。

---

## 6. 技术要点（按主题查，不按流程读）

### 6.1 动画与卡面

- 转换产物的 `Sprite2D` 全是 `centered = false`，节点 `position` 是部件**左上角**，画布原点在左上。
- **不要给动画根节点加 scale** —— 每部件的原版缩放已在动画的 `scale` 轨道里（这批 0.6~0.76），再叠一层整株就缩小。
- 卡面空白 / 手持报「卡片静态角色为空」：取帧失败且没配 `card_face_fallback_plant`，配一张同类的兜底脸。

### 6.2 摆放（最容易错的一步）

⚠️ **陷阱：有些部件的贴图是动画 `texture` 轨道在运行期塞进去的，场景里那个 Sprite 没有 texture。**
`PultShroom_eyes` 就是这样（40×28 @ `(25,45.6)` × 0.6）—— 只按场景 / PNG 清单量会少 9.5 px，整株偏高约 10 px。

做法：**以运行期 `AnimationFrameUtil.get_content_rect(动画根节点)` 为准**（探针里量），静态估算只当预估。对齐口径是**拿本体同类植物当基准**，让内容底边落在同一高度。

卡面落点：取运行期**整株**（含 `Anim.position`）内容中心 `c`，`card_face_position = -c × scale`；探针断言内容中心落在挂点 ±4 px。

> 📌 **2026-10-20 现状：16 株的偏移已重设，等待逐株微调**（`dlc_mod.gd` 常量区文件头有同一条说明）：
> 各株 `plant_*.tscn` 里 `Body/<角色>Anim.position` 都是 `Vector2(-38, -57.5)`
> （先归零再整体**左移半格 / 上移半格 + 再上移 10 px**；格子基准是 `plant_cell.tscn` 的 76×95，半格 = 38 / 47.5），
> `dlc_mod.gd` 里 15 株的 `*_CARD_FACE_SCALE` / `*_CARD_FACE_POSITION` 都是配方默认 `0.4` / `(1, 11)`
> （环轨仙人掌本来就没写这两项）。因此 `probe_dlc_*.gd` 的**摆放 / 卡面两条断言现在必然 FAIL**，
> 这不是回归 —— 重调完别忘了把新值同步回常量与探针。
> 各株注释里留的「实测内容中心 ≈ …」是归零前的旧值，可作重调起点。

### 6.3 攻击节奏

- `attack_cd` **长于**动作段时长，否则 CD 到点 `play()` 从头重置，看着像「动画和发射对不上」。
- 出弹延迟取**动作峰值帧**（`PultShroom_shooting` 篮子最高在 t≈0.5 s，`KingCactus_shooting` 蹲到最低在第 12 帧 = 1.0 s），写进 `ShootTimer.wait_time`，并在探针里断言。
- 待机循环：已经在播就不打断（`if current_animation == IDLE and is_playing(): return`），否则每帧重置。

### 6.4 表现层素材（音效 / 特效）怎么接

> DLC 的 `.ogg` 与特效 PNG **不是** reanim 产物，接线口子都在各自植物目录里，
> 规格 / 帧数 / 哪株用哪一条音效的完整表见 [dlc/README.md](../../mods_builtin/dlc/README.md) §7（单一来源，别在本文档另抄一份）。

三条口径：

1. **音效**放 `mods_builtin/dlc/audio/`，播放走 `SoundManager.play_sfx_with_pool(preload 的 AudioStream)`；
   `play_character_SFX()` 只认本体 `SFXCharacterMap`，模组的 `.ogg` 用它会打「未登记音效」的 warn。
2. **一次性 / 循环特效**用 `dlc_sprite_fx.gd`：`new()` → `add_child()` → `setup(贴图, 帧数, fps)`。
   **顺序不能反**（离树时 `play()` 跑不动）；素材是横向单行序列帧。
3. **子弹命中特效**不写脚本：`BulletEffect` 节点换成 `bullet_effect_norm.gd` + `is_bullet_effect = true`，
   再在 `BulletEffect/AllParticles2D` 下挂一个 `GPUParticles2D`（`CanvasItemMaterial.particles_animation`
   设横向帧数、`ParticleProcessMaterial` 初速度 / 重力归零让它停在命中点）。
   ⚠️ 继承链上 `bullet_cactus.tscn` 写死了 `is_bullet_effect = false`，而基类的
   `activate_bullet_effect()` 只 reparent、不释放 —— 只打开开关不换脚本会漏节点。

### 6.5 静默失败清单（写错了不报错，只是「没效果」）

| 现象 | 写错的地方 |
|---|---|
| 抛物线高度不生效 | 写到子弹根节点（应在 `MovementComponent`） |
| 紫卡登记没生效 | 手写 `AllPrePlantPurple`（应由 `PlantRuntimeKit` 按 recipe 字段做） |
| 白天蘑菇照样打人 | 只设了条件位，没连睡眠信号换姿势 |
| 卡面偏出卡槽 | `card_face_position` 用画布坐标算，漏了 `Anim.position` |
| 检测不到僵尸 | `is_lane = true` 却让散射出了行；或框没覆盖射程 |

---

## 7. 收工自检

### 7.1 勾选表（全部为「是」才算交付）

- [ ] `mods_builtin/dlc/<小写>/` 下：`plant_<小写>.tscn` + `<小写>_plant.gd`（+ 子弹 / 技能脚本）
- [ ] 场景：继承 `plant_base.tscn`、`AnimComponent` 已换 `component_anim_empty.gd`、`AnimLib` 库已覆盖、动画根无 `scale`、`Marker2D` 位置换算过
- [ ] 脚本：四个钩子齐全、无 `class_name`、无裸 `print()`、用 `Log.*`、加速分支已写
- [ ] `dlc_mod.gd`：S1~S5 齐全（+ S6 / S7 文案）
- [ ] `probe_dlc_<小写>.gd`：12 条断言按类型裁剪后齐全，末行机器可读
- [ ] 探针 PASS（贴回 `[DLC] result=PASS` 那行）
- [ ] §8 登记表加一行
- [ ] 提交只含自己的路径（`git status --short` 自查过）

### 7.2 命令

```powershell
# 1) 编译门禁（必过；real compile errors = 0）
powershell -ExecutionPolicy Bypass -File test/check_scripts.ps1

# 2) 自己的探针
powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_dlc_<小写>
```

用户开着 Godot 时跑批会直接 `result=STALE_PROCESS` 退出 —— **不要 `-KillStale`、不要 `Stop-Process *godot*`**（可能是用户未保存的编辑器窗口），改用自己的临时输出目录手跑：

```powershell
$tmp = Join-Path $env:TEMP 'pvz_ap_x'
New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'userdir') | Out-Null
$old = $env:APPDATA; $env:APPDATA = Join-Path $tmp 'userdir'
cmd.exe /c '"C:\Users\a a\Desktop\godot.exe" --headless --path "<仓库根>" -- --scenario=res://test/scenarios/probe_dlc_<小写>.gd --autopilot-max-seconds=180 > "<tmp>\out.txt" 2> "<tmp>\err.txt"'
$env:APPDATA = $old
```

人工验证（合并后抽查）：进游戏 → 选卡页能看到卡 → 种下不悬空 → 有僵尸时动作与出弹对得上 → 铲掉 / 关模组后卡片与图鉴消失。

---

## 8. 现状登记表（单一来源；接一株加一行，别在别的文档里另抄一份）

| 中文名 | 美术名 | id | 阳光 | 冷却 | 卡型 | 机制 | 探针 |
|---|---|---|---|---|---|---|---|
| 环轨仙人掌 | KingCactus | `dlc_kingcactus` | 225 | **50 s**（wiki：very slow） | **紫卡**（基座 本体仙人掌） | 全屏索敌 + 八方向散射 | `probe_dlc_kingcactus` |
| 投掷蘑菇 | PultShroom | `dlc_pultshroom` | 0 | 7.5 s | 普通 | 本行 6 格抛射孢子，白天睡觉 | `probe_dlc_pultshroom` |
| 拳击白菜 | BonkChoy | `dlc_bonkchoy` | 150 | 7.5 s | 普通 | 近战连打：直拳 20 / 斩杀换上勾拳 40，**0.36 s 一拳**（动作段按倍率加速） | `probe_dlc_bonkchoy` |
| 芦荟 | AloeVera | `dlc_aloe` | 50 | 7.5 s | 普通 | 支援：3×3 每 3 秒回血 | `probe_dlc_aloe` |
| 臼炮蘑菇 | MortarShroom | `dlc_mortarshroom` | 75 | 7.5 s | 普通 | 抛射 + 溅射（**近身也打得到**，非盲点），白天睡觉 | `probe_dlc_mortarshroom` |
| 闪电芦苇 | Reed | `dlc_reed` | 125 | **7.5 s** | 普通 | 短距链状闪电，**跨三行**索敌、自动连锁 | `probe_dlc_reed` |
| 血橙 | BloodOrange | `dlc_bloodorange` | **75** | **50 s**（very slow） | 普通 | **飞行**（裸水 / 裸屋顶直接种）；一次性：引爆 3×3 造成 900，没炸死的僵尸吃血月加速 | `probe_dlc_bloodorange` |
| 电击蘑菇 | VoltShroom | `dlc_voltshroom` | **225** | 7.5 s | 普通 | 周围 **3×5 持续放电**（约 40/秒，在目标间**均分**），白天睡觉 | `probe_dlc_voltshroom` |
| 光照蘑菇 | GlowShroom | `dlc_glowshroom` | 50 | 30 s | 普通 | **临时植物**（亮满 10 s 播离场动画自毁）；光域内击杀掉小阳光，白天睡觉 | `probe_dlc_glowshroom` |
| 橡木弓箭手 | OakArcher | `dlc_oakarcher` | 200 | 7.5 s | 普通 | 本行直线射箭，射程 9 格 | `probe_dlc_oakarcher` |
| 蜜蜂射手 | BeeShooter | `dlc_beeshooter` | 100 | 7.5 s | 普通 | **前后双向**吐蜜蜂（朝最近的那只） | `probe_dlc_beeshooter` |
| 飓衣甘蓝 | Hurrikale | `dlc_hurrikale` | 100 | 30 s | 普通 | 一次性：**本行**击退 3 格 + 冰冻，吹走本行空中僵尸，然后自毁 | `probe_dlc_hurrikale` |
| 甜菜守卫 | ChardGuard | `dlc_chardguard` | **75** | **30 s**（slow） | 普通 | 高血量 **1500** + 近战击退 3 格 / 3 次 | `probe_dlc_chardguard` |
| 缩小紫罗兰 | ShrinkingViolet | `dlc_shrinkingviolet` | **100** | **30 s**（slow） | 普通 | 一次性：**周围 3×3** 缩小 5 秒，施法期间无敌，然后自毁 | `probe_dlc_shrinkingviolet` |
| 增幅鹅河菊 | Ampliflower | `dlc_ampliflower` | 200 | 30 s | 普通 | 支援：**每 8 s** 给周围 3×3 提速 2 倍、**持续 4.25 s**（间歇，非常驻） | `probe_dlc_ampliflower` |
| 柠檬榴弹 | Lemonade | `dlc_lemonade` | 200 | 50 s | 普通 | 一次性：本格炸 + 随机弹跳两炸 | `probe_dlc_lemonade` |

> 16 株的探针都已就位（2026-10-18 全量回归：16/16 PASS）。
>
> ⚠️ **2026-10-19 按 DLC Edition wiki 全量对齐**：上表里**加粗**的项都是这次改过的（旧值是模组自定的）。
> 与 wiki 仍然不同的只剩 2 处**刻意保留**的偏差，各有原因：
> ① **飓衣甘蓝 / 光照蘑菇的临时时长** —— wiki 只写 temporary / single use，没给秒数，取模组自定；
> ② **橡木弓箭手的暴击** —— wiki 自标 `160(?)` 带问号，无交叉源，暂不实装。
>
> 📌 同日修掉一个**误读造成的 bug**：臼炮蘑菇原本按「Lobbed = 只轰远处」把检测框左边缘设到
> +114 px（1.5 格），贴脸的僵尸进不了框 → 打不到近处。wiki 正文写的是
> 「Changes target when the enemy is close」（近身**换目标继续打**），不是打不到。
> 现改为左边缘压到自己脚下再往左留 20 px（宽 480 / 中心 220）。探针加了一条
> 「左边缘 ≤ 0」的断言专门防这个回归。
>
> wiki 侧有个**本体没有**的东西因此新增了一处本体代码：`Character000Base.E_Influence_Speed_Factor`
> 加了 `BloodMoon` 一项（血橙副作用要的加速档；与 `Ampliflower` 同为模组专用档）。

---

## 9. 踩坑速查

| 症状 | 原因 | 做法 |
|---|---|---|
| 整株悬在格子上半部 / 陷进下半部 | 只按静态部件量包围盒，漏了靠动画 `texture` 轨道画出来的部件 | 以运行期 `get_content_rect()` 为准，对齐本体同类植物底边 |
| 整株莫名缩小 | 给动画根节点又加了 `scale` | 只设 `position`，缩放交动画轨道 |
| `Animation not found: "X_idle"` | 没覆盖 `AnimLib` 的库（只剩 `ALL_ANIMS`） | 在自己的场景里合成 `AnimationLibrary` |
| 卡面空白 / 手持报「卡片静态角色为空」 | 取帧失败且没配 `card_face_fallback_plant` | 配一张同类的兜底脸 |
| 卡面上的植物偏到左上 / 偏出卡槽 | `card_face_position` 拿画布坐标算的中心 | 用运行期整株内容中心 `c`，取 `-c × scale` |
| 投手打不出抛物线 / 子弹落在原点 | 没传 `Enemy` / `EnemyGloPos` | 出弹前 `update_first_enemy()` 并一起传 |
| 抛物线高度改了没反应 | 写在子弹根节点（是 `MovementComponent` 的字段） | 覆盖 `MovementComponent` 节点再写 |
| 开火动画播不完就被重置 | `attack_cd` 短于动作段时长 | `attack_cd` > 动画时长，出弹延迟取峰值帧 |
| 白天蘑菇照样打人 | 没设 `is_sleep_in_day` / 没连睡眠信号 | 两处都补：条件位 + 姿势 |
| 改完发现探针还在断言旧名字 / 旧价格 | 只改了配方没改探针 | 数值 / 名字改动一律连带探针一起改 |
| 动画场景加载报「referenced non-existent resource」 | 转换工具把含「复制」的段写成乱码名 | 按 `.tscn` 引用重命名，**用 Python `os.rename`**（§3.3） |
| 启动报 `The scene unique ID must contain only letters, numbers, and underscores`（栈指向 `mod_manager.gd` 的 `load()`，看不出是哪个场景） | 同批转换产物把**重复段**的 `sub_resource id="...复制"` 写成带空格 / 中文 —— `Resource::set_scene_unique_id()` 只收 ASCII 字母数字下划线，整块场景随之加载失败 | 把该 id 换成纯 ASCII 下划线名（如 `AnimationLibrary_X_copy`），并同步所有 `SubResource("旧名")`；全仓自查：搜 `\bid="[^"]*[^A-Za-z0-9_][^"]*"`（`uid="..."` 不算，别误报）。⚠️ **编译门禁抓不到**：没被脚本 `preload` 的场景 `--import` 不解析，只有运行期装载模组时才炸 |
| 并行后 `dlc_mod.gd` 少了几株的登记 | 有人重排 / 覆盖了别人的数组段 | 只追加不重排；合并时保留双方，按一行一项重排 |
| 同一批植物风格各异（CD 口径 / 检测框 / 卡面） | 每株自由发挥 | 照 §5 角色卡填空，量化断言写进探针 |
| 文案说「两株」实际已 16 株 | 描述串 / 面板没跟着加 | S6 / S7 与配方同一次改完 |

---

## 10. 复盘：2026-10-18 十五 agent 并行为什么会乱

| 现象 | 根因 | 现在的对策 |
|---|---|---|
| `dlc_mod.gd` 里 16 株的常量 / 图鉴 / 配方穿插交错，顺序和命名不一致（`FALLBACK_PLANT` 与 `*_FALLBACK_PLANT` 并存，`_register_almanac_entry()` 无角色名） | 文档没规定共享文件的「槽位」与命名，agent 各自找位置插 | §1.2 五个槽位 + §2 命名口径 |
| 有人往 `install()` / `uninstall()` 里改结构 | 文档只说「照 `_build_*` 抄」，没说「别重构公共函数」 | §1.3 第 2 条红线 |
| 15 份探针形状不一（有的 200 行、有的 290 行，辅助函数各不相同） | 文档写「照 `probe_dlc_pultshroom.gd` 抄」——照抄的是某一株，不是契约 | §5.6 固定 12 条断言 + §7.1 勾选表 |
| 光照蘑菇有配方、没探针 | 没有「没探针 = 没做完」的判定 | §1.6 DoD + §8 欠账列 |
| 描述串 / 面板漏株（光照蘑菇、增幅鹅河菊） | 文案三处分散、无同步要求 | §2.3 + S6 / S7 |
| 文档本身写着「已接两株」，实际已 16 株 | 文档把「现状」写进了正文，没有登记表 | §8 单一登记表 |

**推荐（可选，不强制）**：把每株的登记数据收敛成一张 `DlcPlantSpec` 数组（一株一条 spec + 一个 `_build_*`），`install()` / `uninstall()` / 面板文案都从 spec 生成 —— 但这是 **main 单独一笔**的重构，别混进任何单株提交。
