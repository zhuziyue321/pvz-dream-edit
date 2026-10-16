<!-- AGENT-DOC: index -->

# TODO 清单

> **[面向 AI Agent]** ｜ **触发条件**：被安排做清理 / 还债类任务；想找「还能做什么」；有人问「仓库里还剩哪些待办」；删代码前判断某条 TODO 是不是垃圾
> **读完你能**：① 列出当前仓库全部 `TODO` 注释（2 条，§2）及其精确位置；② 列出当前「不统一实现 / 逻辑不全 / 可优化」的架构债（**23 条**：U 系列 14 + L 系列 8 + O 系列 1，见 §3；U-01~U-13 已于 2026-10-11 销项，见 §4）；③ 知道 **H 系列（仓库卫生与工程流程）H-01 ~ H-09 已于 2026-10-16 全部销项**（逐条处置见 §4），以及 **H-10 ~ H-15（2026-10-16 工程体检新增）** 的方向与前置条件；④ 判断某条 TODO 是「有效待办」还是「可删的痕迹」；⑤ 知道新增 / 销项一条时改哪里；⑥ 知道本轮整改的**分批顺序**与每批的验收口径（§6）
> **强制级别**：**参考**（本文件只是一张清单，不是硬约束） ｜ **不读的风险**：把「本实现与原版的差异线索」当垃圾注释删掉；或重复实现已经在某处 TODO 里记过的东西
> **关联**：[项目规范.md](项目规范.md) · [参考存档/未使用代码与资源清单.md](参考存档/未使用代码与资源清单.md) · [../架构总览.md](../架构总览.md)（§12 技术债清单）

---

## 1. 统计口径

> 本文是**全量快照**（2026-10-11 更新：销项 T-02 / T-03 / T-04 / T-06，剩 2 条；同日再销项
> U-19 / U-21 / U-28 / U-29 / U-30、L-01 / L-02 / L-03 / L-05 / L-06 / L-08 / L-11、O-01 / O-03），不是抽样。再生成一次用同一套口径即可复现。

| 口径项 | 取值 | 理由 |
| --- | --- | --- |
| 检索词 | `TODO`（大小写敏感，含 `TODO:` / `TODO：` / `TODO ` 变体） | 项目里的待办习惯统一用 `TODO`；`FIXME` / `HACK` 在 `addons/` 之外无命中 |
| 纳入范围 | `src/` `test/` `data/` `animation/` `shaders/` `tools/` `project.godot` 等自研文件 | 自己写的代码才需要跟进 |
| 排除 `addons/` | ✅ 排除 | 第三方插件，不是本仓库的债。`addons/todo_controller/` 这个名字里带 todo 的插件会把 80+ 处假命中算进来 |
| 排除同名标识符 | ✅ 排除 | `minigame_07_..._star_overlay.gd` 的 `ALPHA_TODO` 常量、`test/scenarios/probe_netplay_session.gd` 的 `client_todo` 局部变量都只是命名，不是待办 |
| 排除 `docs/` | ✅ 排除（本文是它们的汇总） | 文档里提到 TODO 的地方已在 §3 记录，避免「清单套清单」 |

**结果：2 条有效 TODO**（[架构总览.md](../架构总览.md) §12 第 14 项记的「约 12 处」是历史数字，其中 10 条已销项：历史 6 条 + 本次 4 条，见 §3）。

> **2026-10-11 第二轮全仓扫描**：本轮不看 `TODO` 关键字，专扫「同一件事多套写法 / 逻辑不全 / 可优化」，
> 新增 **U-14 ~ U-30（17 条）**、**L-01 ~ L-11（11 条）**、**O-01 ~ O-03（3 条）**，见 §3.1 / §3.2 / §3.3。
> 口径：`src/` + `test/` 全量 `.gd`，`addons/` 排除；每条都给了文件:行号，未逐处核实的已在现象里写明。

> **2026-10-16 定向体检（新增 H 系列，同日全部销项）**：本轮**不看玩法代码**，专扫「仓库本身」的健康度 ——
> 把文档里声称的数字 / 状态**逐条与实测对账**（`git status`、文件计数、`.github` 是否存在、根目录残留），
> 开出 **H-01 ~ H-08（8 条）**并**当日全部处理完毕**，逐条处置见 §4。口径：命令直出，不做估算；每条都写清「文档怎么说 vs 实测是多少」。
> 与前三系列不同，H 系列**与运行时行为无关**（唯一例外是 H-08 指向的两条回归探针）。

---

## 2. 待办清单（2 条）

| 编号 | 位置 | 原文 | 它记的是什么 | 处理建议 |
| --- | --- | --- | --- | --- |
| **T-01** | `src/managers/main_game_manager.gd:201` | `##TODO:可能会用于检测敌人离开场景后删除` | 字段 `detect_component_global`（全局检测组件）目前的用途没想清楚，作者留了「将来用于回收离开场景的敌人」的口子 | 真要做「敌人离场回收」再落地；**不要**因为现在没人读就删 —— 它对应 `src/main/main_game_base.tscn` 里的 `%DetectComponentGlobal` 正式节点，删它要连 `.tscn` 一起改 |
| **T-05** | `src/entities/character/zombie/zombie_base.gd:330` | `## 死亡不消失(海草\TODO:小推车)` | `character_death_not_disappear()`（死亡但尸体留在场上）目前只有海草在用，注释预告了「小推车」也该用这条路径 | 做迷你游戏小推车时照这里的预留走；**这是明确的未来需求线索**，不要删 |

> 共同点：**这 2 条都不是「写崩了」，而是「还没做完 / 存疑」**。合并删除前先对照本表 —— 删掉它们等于删掉唯一的差异线索。

---

## 3. 待办清单补编：不统一实现与逻辑不全

> **与 §2 的区别**：§2 是代码里写着 `TODO` 字样的**注释**；本节是**同一件事存在多种写法**、或**逻辑没接完**的架构债，代码里未必有 TODO 标记，因此不会被 §1 的检索词命中。
> 档位 = 风险（**A** 会致数据/行为不一致 · **B** 违反硬约束或架构主线 · **C** 命名与表达 / 参考级）。
> 编号：`U-` = 不统一 / 重复实现，`L-` = 逻辑不全 / 未接线，`O-` = 可优化（性能）。

### 3.1 U 系列：不统一实现 / 重复实现（U-14 ~ U-32，现存 14 条；U-19 / U-21 / U-28 / U-29 / U-30 已销项）

> 来源：2026-10-11 第二轮全仓扫描（U-01 ~ U-13 已销项，去向见 §4）。
> **U-31 来自 2026-10-13 亡语专项复核**（`character_base.gd` 的 `death_language()` 链 + 6 个重写点全量核对）。
> **U-32 来自 2026-10-16 工程体检**（`Global.` 引用面实测，口径 = `src/**/*.gd` 文件数）。

| 编号 | 档 | 位置 / 范围 | 不统一的现象 | 处理建议 |
| --- | --- | --- | --- | --- |
| **U-14** | B | `components/anim_component/component_anim_norm.gd:25`、`component_anim_player.gd:5`、`component_anim_bobsled.gd:4-8`、`attack_behavior_component/component_attack_bullet_base.gd:5`、`charred_component/component_charred_zombie_bobsled.gd:4`、`src/entities/bullet/component/movement/bullet_movement_track.gd:5` | 组件里直接拼宿主相对路径 `$"../AnimationTree"` / `$"../AnimationPlayer"` / `$"../Body"` / `$"../ZombieBobsled1"` —— 宿主结构一改就**静默取到 null**。`character_base.gd:422-439` 与 `bullet_base.gd:66-80` 已提供 `host_node_of(owner, ^"XXX")` 入口（注释原文就是「替代在组件里拼 `$"../XXX"`」），这 6 处没走 | 全部改走 `host_node_of()` |
| **U-15** | B | `attack_behavior_component/component_attack_zom_botany.gd:64`、`component_attack_zom_botany_pea.gd:137`、`zombie_plant_component/component_zombie_plant.gd:66` | 组件间硬编码**兄弟组件 / 宿主子节点名**：`owner.get_node_or_null(^"ZombiePlantComponent")`（2 处）、`owner.get_node_or_null(^"Body/BodyCorrect")`；违反「组件只通过 `owner` / 信号 / 场景配置通信」 | 改 `@export` 场景注入，或走宿主提供的访问器 |
| **U-16** | C | `component_norm_base.gd:90`（空实现）被 12 处各抄一份：`component_sleep.gd:53`、`component_move.gd:85`、`component_magnet.gd:98`、`component_create_sun.gd:76`、`component_create_coin.gd:55`、`bomb_component/component_bomb_jackbox.gd:41`、`attack_behavior_component/component_attack_zombie_norm.gd:27`、`_zombie_zamboni.gd:20`、`_zombie_gargantuar.gd:46` 等 | 「速度同步」12+ 份并行实现，各自算一遍乘积；`anim_component/` 下 `component_anim.gd:70,74` / `component_anim_norm.gd:100,104` / `component_anim_bobsled.gd:17,23` / `component_anim_empty.gd:7,12` 又是 4 份互为复制 | 倍率计算收敛到基类，组件只接收结果 |
| **U-17** | C | `components/zamboni/zamboni_death_bomb.gd:24-33` vs `components/zombie_death_bomb/zombie_death_bomb.gd:8-16` | 两份「死亡爆炸」：`activate_it()` 逐行相同（`reparent(get_sibling_layer())` → 两个 `GPUParticles2D.emitting = true` → `await finished` → `queue_free()`），仅 Zamboni 多一个 `explode()`；**且 Zamboni 只 `await gpu_particles_2d.finished`、漏了 `_2`**（Zombie 版 await 两个）→ 提前 `queue_free()` 会截断第二个粒子的尾巴 | 合并为一份，炸飞做可选开关；补上第二个 `await`。**2026-10-11 已补第二个 `await`**（已核实 `zombie_death_bomb.tscn` 里两个粒子都是 `one_shot = true` / `lifetime = 0.6`，`finished` 必来）。**合并未做** —— 没有 `zamboni_death_bomb.tscn`，两个脚本都挂在 `zombie_death_bomb.tscn` 的实例上由 `zombie_zamboni.tscn` / `zombie_catapult.tscn` 覆写脚本，改成继承要动 `.tscn` 里的脚本覆盖，且 `explode()` 依赖 `$Body`（需确认场景里有没有这个子节点），要开游戏确认 |
| **U-18** | B | `components/swim_box_component/component_swim_box.gd:1` | 放在 `components/` 下却是 `extends Node2D`（不继承 `ComponentNormBase`）—— **U-05 的漏网之鱼**（当时只清了 `drop_body/` `jackson/`）。同文件 `appear_splash()` / `appear_splash_special_pos()` 整段复制，只差一个取位节点 | 接不接入二选一，并在文件头写清理由（照 U-05 的先例）；两个水花函数抽公共 `appear_splash_at(pos_node)`。**2026-10-11：水花已抽公共 `appear_splash_at(pos_node)`（等价改写）；接入与否的理由已写进文件头** —— 关键更正：`ComponentNormBase` 自己就是 `extends Node2D`，所以「因为要 Node2D 才不能接入」这个理由**不成立**，真正的差别只有启用/禁用框架；是否接入属行为变更（走 `component_ready()` + 各路启用因素后，场景连的信号回调还在不在要重判），需开游戏确认 |
| **U-20** | A | `src/levels/core/level_data.gd:35` ↔ `src/core/autoload/global_game_state.gd:129-134` | 存档键**两套推导并存**：正推是 `str(game_mode)+"_"+str(level_page)+"_"+str(level_id)`（`level_id` 默认 `"test"`，`level_data.gd:18`），反推却硬编码 `"%d_%d_%04d"` 并 `int(parts[2])`。`level_id` 不是 4 位数字时两条路对不上 → 进度写进去读不出来 | 收敛成一组 `make_save_key()` / `parse_save_key()` 静态函数 + 一个格式常量，两边共用 |
| **U-22** | A | `src/levels/mode_*` | `save_key` 覆盖率**严重不齐**（**2026-10-16 重测**，口径 = 该模式目录下含 `save_key =` 的 `.gd` 文件数 / 该目录 `.gd` 文件数）：`mode_minigame` 20/25、`mode_puzzle` 20/20、`mode_adventure` **4/54**（只有 `adventure_01_01~01_04`）、`mode_survival` **0/15**。其余关卡全靠 `save_key == ""` 时回退旧拼法（`level_data.gd:35-36`），而旧拼法依赖 `level_id` 在选关页里按按钮顺序发放 —— 顺序一变就整体错位。<br>⚠️ **迁移工具链已过时**（2026-10-16 核实）：本行原指 `test/scenarios/tool_migrate_save_key.gd`，该文件**不存在**；现役两个工具是 `tool_dump_save_keys.gd`（只读，读权威值）与 `tool_write_save_keys.gd`（写入），但**两者都面向 `.tres` 关卡**（`tool_write_save_keys.gd:68` 写 `resource_path` 的 `.tres`），而 `src/levels/` 下实测 `.tres` 数 = **0**（关卡 V2 已全部改成 `.gd` + `_init()` 赋值）。 | 先**修工具**再迁：① 把 `tool_write_save_keys.gd` 的写入目标改成「`.gd` 里 `save_key = "..."` 那一行」（文本级替换，不是重存资源）；② 用 `tool_dump_save_keys` 从 4 个选关场景读权威值（**不要推算**，见该文件头）；③ 补齐后跑 `probe_save_key` 回读校验（**必须另起进程**，同进程内关卡资源被选关场景引用、缓存顶不掉）；④ **只补 `save_key`，`format_version` 不要顺手改成 2** —— 那是「字段怎么读」的开关，属行为变更，要单独评测 |
| **U-23** | C | `src/levels/mode_survival/`（15 关） | 同一模式里场景设置**三套写法**：04/09/14 用 `scene_name = SceneSettingRegistry.SCENE_FOG`；泳池/屋顶/夜晚 9 关用旧字段 `game_BG + game_BGM`；01/06/11 三关**什么都没配**（`survival_flag_01_day.gd` 连 `_init()` 都没有） | 15 关统一改 `scene_name`（`apply_scene_setting()` 已支持覆盖），清掉手写 `game_BG` / `game_BGM` |
| **U-24** | C | `src/menus/start_menu/start_menu_option_dialog.gd:20-25,29-41` ↔ `src/ui/ui_main_game_menu/main_game_menu_option_dialog.gd:35-40,51-68` | 两个选项面板**逐行重复**：`music_sound_signal()` 一字不差，`appear_menu()` / `return_button_pressed()` 各写一份；灰色常量 `Color(0.687,0.687,0.687,1.0)` 在 `start_menu_root.gd:10` 与 `main_game_menu_option_dialog.gd:17` 各抄一遍，注释里还互相引用对方 | 抽 `OptionDialogBase`；灰色常量提到 `src/core/consts/` |
| **U-25** | A | `src/ui/card/card_slot/card_slot_norm/card_slot_battle.gd:15-18,26` ↔ `src/levels/mode_minigame/minigame_03_slot_machine_ui.gd:56,77,203,219` | 老虎机关**两本阳光账**：卡槽 `sun_value`(:26) 与老虎机 UI `_sun_value`(:77) **同时订阅 `ADD_SUN_VALUE`**，收阳光两边各加一遍；花钱只扣 UI 那份（:219），卡槽那份不扣 | 老虎机直接读写 `CardSlotController` 的阳光，删掉本地 `_sun_value` |
| **U-26** | C | `src/zombiquarium/zombiquarium_manager.gd:167-183`（`:209` 也是） | 同一个 getter 里两套阳光来源：`_card_slot_battle.sun_value`（挂主游戏）vs `_local_sun`（独立预览），花 / 赚各走一条 if 分支，口径会漂移 | 独立预览时也挂一份 wallet 适配器，删掉 `_local_sun` 分支 |
| **U-27** | C | `src/items/drop_body/zombie_arm1_drop.gd` ↔ `src/items/drop_body/zombie_hand_drop.gd` | 两个文件**逐字相同**（`x_v = randf_range(-15, 15)` / `velocity = Vector2(x_v, 0)` / 同一行注释掉的 `#rotation_speed=randf_range(1.3,2.1)`），复制粘贴产物 | 合并成一个脚本，另一处改参数或改名引用。**2026-10-11 复核后判定「不做」**：两个脚本内容相同但挂在不同节点上（各自的贴图/动画在场景里），合并要改 8 个 `.tscn` 的 `ext_resource` **uid + path 成对替换**（`arm1` = `uid://cj4hccewpwgyv`、`hand` = `uid://33sxeu6n870x`），其中 `zombie_paper` / `zombie_ladder` / `zombie_football` / `zombie_digger` 4 个场景**同时引用了两个脚本**。改错 uid 就是僵尸场景**静默丢脚本**，收益（少 10 行重复）< 风险，留作参考 |
| **U-31** | B | `character_base.gd:245-256`（亡语链）+ 6 个重写点：`plant_cherry_bomb.gd:7` / `plant_jalapeno.gd:7` / `plant_ice_shroom.gd:7` / `plant_doom_shroom.gd:12` / `plant_potato_mine.gd:40` / `zombie_bobsled.gd:64` | 「死亡时效果」散在 6 个角色子类里各写一份：5 个植物是**逐字相同**的 `bomb_component.judge_death_bomb()`，雪橇僵尸是散架放 4 个兵。基类 `death_language()` 是空钩子且**没有「已触发过」的记录** —— 幂等各靠各的（植物侧靠 `BombComponentBase.is_bomb`、僵王侧 `zb_base.gd:124` 靠 `is_death`）。效果逻辑没进组件，违反「角色 = base + 若干组件」的架构主线 | 让 `BombComponentBase` 自己订阅宿主死亡（`component_bomb_base.gd` 已有 `is_auto_bomb_in_death` 开关），子类只留「死了要不要补爆」的导出项；僵尸侧散架同样下沉成组件，或至少在基类补一个 `is_death_language_done` 幂等位 |
| **U-32** | C | `src/**/*.gd`（**110 个文件**引用 `Global.`，2026-10-16 实测口径：`Get-ChildItem src -Recurse -Filter *.gd` 中内容命中 `\bGlobal\.` 的文件数） | `Global` 是**唯一**没有边界的单例：跨局持久状态（存档 / 用户 / 配置）与「这一局」的运行期对象（`game_para` / 各类 manager / registry）都从这里取。U-01 已把「当前这一局」的真相源迁到 `GameContext.curr_main_game`（473 处），但 `Global` 一侧**没有配套划边界** —— 于是同一个语义又有两条入口，且新代码默认还是写 `Global.` | 给 `Global` 定一条可判定的边界：**只放跨局持久状态 + 注册表引用**；凡「这一局」的对象一律从 `GameContext` 取。落地方式：① 先列出 `Global` 现有字段并逐个归类（持久 / 本局）；② 本局类字段标记 `@deprecated` 注释并给出 `GameContext` 对应写法；③ 新字段评审时按此判定。**不建议**一次性大改（473 处已有先例，得再开一轮） |


> U-30 剩余部分（`zombie_boss/doctor/` 与 `zombie_boss/zb_doctor_objects/` 目录前缀不一致）判定**不动**：纯可读性收益、改动面是文件名与 100+ 处引用，与 U-11 的前缀缩写同一处理，留作参考。
>
> **U-14 复核（2026-10-11，未改）**：`host_node_of()` 全仓**只有定义与注释、0 处实际使用**（`character_base.gd:439` /
> `bullet_base.gd:75`），所以改这 6 处等于**首次落地**这套入口。风险点：`owner` 为空（运行期 `add_child()` 挂上去的
> 组件）时它返回 null，而原来的 `$"../X"` 在那个场景里是能取到的 —— 一旦踩中就是「这个角色不动了 / 不播动画了」的**静默 null**。
> → 要做的话**必须开游戏实测**，别当成纯机械替换。

### 3.2 L 系列：逻辑不全 / 未接线（L-01 ~ L-15，现存 8 条；L-01 / L-02 / L-03 / L-05 / L-06 / L-08 / L-11 已销项）

> 与 U 系列的区别：**不是「两种写法」，而是「只有一半」** —— 订阅了没人发、开关恒假、接口是空 `pass`、常量表里写了代码里没有。
>
> **L-12 ~ L-15 来自 2026-10-13 亡语专项复核**：`is_can_death_language` 的全部写入点已全量核对，这 4 条是「亡语该关没关 / 该同步没同步」的口子。

| 编号 | 档 | 位置 / 范围 | 现象 | 处理建议 |
| --- | --- | --- | --- | --- |
| **L-04** | B | `src/managers/zombie_manager/zm_hammer_zombie_manager.gd:109,116,121,125,127,195` | 锤僵尸出怪**全用全局随机**：`randi()%3+1` / `idle_tombstones.shuffle()` / `.pick_random()` / `randi_range()` / `randf_range()`；而同类 `zm_zombie_wave_manager.gd:201,204` 走 `src/core/game_rng.gd`。两端随机序列必然岔开 → 联机不可复现 | 统一改 `GameRng.randi_range / pick_random / shuffle` |
| **L-07** | C | `attack_behavior_component/component_attack_bullet_base.gd:86-88`、`component_attack_bullet_split_pea.gd:12-15`、`bomb_component/component_bomb_base.gd:64-69`、`garden/component_garden.gd:132-136` + `component_garden_sprout.gd:7-10` | **空实现当接口**：两个 `set_cancel_attack()` 都是「注释掉两行 `animation_tree.set(...)` + `pass`」；`_start_bomb_fx()` / `_bomb_all_enemy()` 空实现；两个 garden 组件的 `update_growth_stage()` 在 `Sprout` 分支都是 `pass`（`component_garden.gd:135` 原本连 `Log.debug` 都被注释掉，2026-10-12 清理调试输出时把那行注释也删了） | 要么实现，要么删掉空钩子 —— 留着会让人以为「已经接完了」 |
| **L-09** | C | `src/ui/main_game_ui/ui_level_progress_provider.gd:18,23` | `on_bind()` / `on_unbind()` 全仓**无任何子类 override**（`ui_level_progress_bar_controller.gd:36,43` 照常调用） | 补默认实现，或删掉这两个空钩子 |
| **L-10** | C | `src/garden/plant_cell_garden.gd:98-100` | `GreenHouse` 分支是裸 `pass` | 补逻辑或改成 `_` 通配，别留空分支 |
| **L-12** | A | `character_base.gd:294-296` `character_death_disappear()`（基类）、`zombie_base.gd:354` `character_death_not_disappear()`（海草） | 「直接死亡」路径**只有僵尸关了亡语**（`zombie_base.gd:358` 重写时置 `is_can_death_language = false`），**基类和海草那条都没关** → 所有走基类的植物「直接消失」都会跑亡语：`plant_cell.gd:876`（读档 `clear_data_plant_cell()`）、`beghouled_manager.gd:503,834`（消除 / 重排）、`hand_component_glove.gd:230`（手套兜底）。现在不出事只是因为樱桃 / 毁灭菇种下即自爆、土豆雷未出土时 `is_auto_bomb_in_death = false`（`plant_potato_mine.gd:47` 才置 true）—— **是靠时序兜着，不是靠开关兜着** | 把 `is_can_death_language = false` 提到基类 `character_death_disappear()`（僵尸子类 `:360` 那行随之可删）；`character_death_not_disappear()` 按语义单独决定关不关 |
| **L-13** | A | `character_base.gd:251-256` ↔ `zombie_manager.gd:350-361` `_on_zombie_dead` ↔ `zombie_bobsled.gd:64-79` | 亡语排在 `signal_character_death.emit()` **之后**：僵尸死亡先让 `_on_zombie_dead` 扣 `curr_zombie_num`，若是最后一只就 push `BATTLE_FINISHED`；雪橇僵尸的亡语**这才** `call_deferred` 创建 4 个雪橇兵 —— **「本轮打完」的判定发生在补兵之前**，这 4 只可能落在已判定的战斗之外 | 二选一：确认补兵算本轮 → 把亡语挪到 `signal_character_death.emit()` 之前，或让 `_on_zombie_dead` 的计数挂起一帧；确认不算 → 在 `zombie_bobsled.death_language()` 处写清这是有意的，别让后人当成 bug 修 |
| **L-14** | B | `zombie_base.gd:384-396` `be_bomb` / `:399-405` `be_chomper_eat` / `:411-414` `be_rake_attack` / `:417-423` `be_squash` | 「置 `is_can_death_language = false` → 同步打伤害 → `set_deferred(..., true)` 恢复」这套写法**依赖两件没写进代码的事**：① 伤害必须**同步**致死 —— 将来任一一处改成协程 / 异步致死，亡语就漏关；② `queue_free()` 之后仍对同一对象排 deferred 写属性，靠「MessageQueue flush 早于删除队列 flush」才不报错（引擎内部顺序，不在本仓库控制内） | 恢复改成显式判断 `if not is_death:`（不再 deferred）；或在四个入口的注释里写死「本函数必须同步致死」这条约束 |
| **L-15** | B | `mods_builtin/netplay/`（全目录 0 命中 `death_language` / `is_can_death_language`） | 联机**完全没覆盖亡语**：`netplay_state_sync.gd:889` 用 `hp_loss_to_death(false)` 给客户端补死时，`is_can_death_language` 的状态无从同步。雪橇僵尸这种「死了还要生成单位」的亡语，两端可能对不上（客户端多放 / 少放 4 个雪橇兵） | 补死路径显式带一个「是否触发亡语」的标志，或让客户端补死一律走不触发亡语的分支（补兵改由主机快照下发） |

> **L-07 复核（2026-10-11，未改，登记时的描述需修正）**：这 5 处空实现**不都是死钩子** ——
> `component_bomb_base._start_bomb_fx()` / `_bomb_all_enemy()` 被 4 个子类重写（norm / jalapeno / jackbox / ice），
> `component_attack_bullet_base.set_cancel_attack()` 被 cactus 重写且有**真实实现**（`ONE_SHOT_REQUEST_FADE_OUT`）。
> 基类留空是**有意的抽象钩子**，删掉反而破坏扩展点。真正「空着没接」的只剩**两处**：
> `component_attack_bullet_split_pea.gd:12-15`（两行 `animation_tree.set(...)` 被注释掉 + `pass`，
> 同文件 `:8-9` 用的就是 `OneShot` / `OneShot 2` 这两个参数名，取消注释大概率能用，但属**视觉行为变更**，要开游戏确认）
> 与 garden 两组件的 `Sprout` 分支 `pass`。

### 3.3 O 系列：可优化（性能，O-01 ~ O-03，现存 1 条；O-01 / O-03 已销项）

| 编号 | 档 | 位置 / 范围 | 现象 | 处理建议 |
| --- | --- | --- | --- | --- |
| **O-02** | C | `src/core/autoload/global_game_state.gd:161` | `get_max_success_adventure_level()` 线性扫描整张 `curr_all_level_state_data`（含小游戏 / 解谜 / 生存全部 key），对每个 key 做 `split("_")` + `int()`；被 13 处调用（商店 / 各解锁判定 / 手套模组） | 结果按「冒险关序号」缓存（写通关时失效），或写入时维护一个字段。**2026-10-11 复核后判定「不做」**：调用点集中在**打开菜单与解锁判定时**（不是每帧），扫描规模是几百个 key 的一次 `split`，肉眼不可见；而缓存一旦漏掉一个失效点就是「解锁状态显示不对」这种**静默 A 档症状**（有 U-20/U-22 那种存档键血案在前）。收益 < 风险，留作参考。真要做，先把 `curr_all_level_state_data` 的所有写入点收敛到一个口子再上缓存 |


### 3.4 H 系列：仓库卫生与工程流程（H-01 ~ H-09，**已全部销项**）

> **与前三系列的区别**：U / L / O 三条都是**玩法代码**里的债；H 系列记的是**仓库本身**的债
> —— 版本控制、CI、文档同步、目录卫生、已知失败的回归。
> 来源：2026-10-16 一次针对「项目健康度」的定向体检（文档声称 → 实际实测逐条对账），**不是抽样**。
> 本系列**全部与运行时行为无关**（唯一的例外是 H-08 指向的两条探针），因此**不改代码也不会让游戏出问题**；
> 但它们决定「下一次改动还找不找得到真相」。

> **H-01 ~ H-09 已于 2026-10-16 当日全部销项**（含登记当轮即修的 H-05），逐条处置见 §4。
> 销项一条即从原表移到 §4（§5 约定）；本处不留已完成条目。新条目从 `H-10` 起编号。
> 登记格式见 §5（**必须同时写「文档怎么说」与「实测是多少」**）。

**当时的处置顺序（据档位与损失风险）**：H-02（先落盘）→ H-01（补门禁）→ H-08（红探针）→ H-06（清垃圾）→ H-03 / H-04 / H-07（文档对账）。**已全部完成，逐条见 §4**。

### 3.5 H 系列（续）：H-10 ~ H-15（2026-10-16 工程体检新增）

> 来源：2026-10-16 一次「项目优缺点体检」——按「架构一致性 / 文档 / 自动化测试 / 内容扩展成本 / 工程流程」五个维度实测，
> **只登记新发现的缺口**；已登记过的（L-12~L-15、U-22、U-31、§12.3 第 9 / 15 项）不重复开条，只在 §6 排批次。
> 格式同 H 系列：**同时写「文档怎么说」与「实测是多少」**，口径一律可复现命令。
> **与 H-01~H-09 的区别**：那 9 条是「仓库卫生」（脏文件 / 数字漂移 / CI 缺位）；这 6 条是**防线与流程强度**（能证明什么、改起来多贵）。
>
> **2026-10-16 当日销项 4 条**：H-10（玩法链路探针）/ H-12（assets 口径 + 检查器新增断言 + 断链）/ H-13（E-09 提交粒度）/ H-15（工作记录主题入口）已做，逐条处置见 §4。
> 本节**只剩 2 条未完成**：H-11（CI 已写未在 runner 验证）/ H-14（接线检查器未写）。按 §5 约定，销项即从本表移走，不留已完成条目。

| 编号 | 档 | 文档怎么说 | 实测是多少 | 方向（含前置条件） |
| --- | -- | --- | --- | --- |
| **H-11** | B | 硬约束 §1-7 要求交付前跑门禁；`test/README.md` 说「只做本地钩子（更快、无需 runner）」 | `Test-Path .github` 原为 **False**（无云端 CI）；`git ls-files assets` = **5339**（素材在版本控制内）→ H-01 已更正「assets 不入库所以跑不了 CI」的旧结论，**云端 CI 技术上可行**，当前只是没做 | **已落地一半**（2026-10-16）：新增 `.github/workflows/ci.yml`（编译门禁 + 快子集探针 `probe_init,probe_gameplay_core`；引擎按 `GODOT_VERSION` 从官方 release 下载，找不到 exe 直接抛错而不是静默假绿）。**⚠️ 未完成**：该文件**尚未在 GitHub runner 上实跑过**（本地无法验证 runner 环境）。首推后按文件头「验证方法」三步确认（① 两个 step 全绿；② 故意改坏一个 `.gd` 必须让门禁变红；③ 与本地同 filter 的跑批结果一致），确认后再摘掉文件头警告 + 把本条销项。本地 `pre-push` 保留做快反馈 |
| **H-14** | B | `架构总览.md` §14 列了「新增一个 X 要动哪几处」（植物 7 处 / 僵尸 5 处 / 关卡 4 处）；`levels/` 走 `LevelRegistry`（`src/levels/AGENTS.md`） | ① 选关页**仍是硬引用**：4 个选关页 ~105 条 `.tscn` 按钮引用，`LevelRegistry` 只做了「登记 + 名字校验」，未驱动生成（§12.3 第 9 项）；② `save_key` 覆盖不齐（U-22 重测：adventure 4/54、survival 0/15、minigame 20/25）；③ **漏登记的兜底只有评审** —— §14 是一张**人读的表**，没有任何检查器证明「新单位 7 处都登记了」 | **① 已完成（2026-10-16）**：`tools/check_content_wiring.ps1` 已写，遍历 `PlantIds.ALL` / `ZombieIds.ALL` 校验「注册表数值表有条目 + 场景 preload 文件存在」，缺一项即 exit 1（192 项校验 `result=PASS`）；**注入验证**：把 `plant_pea_shooter_single.tscn` 改名 → 报 `FAIL plant PEA_SHOOTER_SINGLE: scene missing`，改动已还原（`git status` 干净）。已知例外：植物 `WATER_BOWL`（运行期由模组注入的空槽位，故意不在数值表，脚本里显式放行）；僵尸 42 个 ALL id 全部在 `ZOMBIE_INFO` 中。⚠️ 原方向里的「**动画目录存在**」本次**未做** —— 动画目录命名与 id 非简单对应（`puff_shroom` → `plant_puff.tscn`），需先确认约定再补，避免写出假绿检查（H-09 教训）；② 选关页注册表化（视觉配置要靠开窗口比对，单开一轮，**未做**）；③ `save_key` 补齐归 U-22（**未做**） |


---

### 3.6 本轮（2026-10-16 后续）项目优缺点综合体检

> 来源：2026-10-16 一次「项目优缺点」定向体检 —— 基于 AGENTS.md / 项目规范.md / 本清单 / 编译门禁脚本，
> 并抽样 `src/entities/character/components/component_move.gd` 与 `src/entities/character/character_base.gd` 实测。
> 与 H-10~H-15 的区别：那 6 条是「防线与流程强度」；本条是「优缺点的整体结论 + 落档」，
> **优点确认已落地、缺点与既有 U/L/H 条目交叉引用**，不重复开条（仅新增 H-16 一条检查器缺口）。

**总体判断**：架构主线与治理成熟度在同类项目中属上游；主要短板不在「设计」而在
「设计 → 代码的执行一致性」与「少数 A 档玩法债的落地」。

| 维度 | 结论 | 对应条目（已在清单内） |
| --- | --- | --- |
| 优点：架构落地 | 数据驱动 + 组件化真正落地，组件职责边界清晰（如 `component_move.gd` 的 `E_MoveFactor` 因素开关） | — |
| 优点：文档体系 | 225+ md 带「面向 AI Agent」元信息头，路由表可机读 | H-03 / H-04 / H-12（已销项，口径已对账） |
| 优点：工程纪律 | 两道编译门禁 + pre-push + doc_facts + content_wiring 检查器 | H-01 / H-09 / H-14①（已销项 / 部分） |
| 优点：债透明 | 每条带档位 / 文件:行号 / 分批顺序 | 全文 |
| 缺点：规范-代码漂移 | 组件仍拼宿主相对路径，硬约束 §1-2 在代码中被绕过，门禁抓不到 | **U-14**（复核：2026-10-16 后续抽样 `component_move.gd:8` 仍 `get_node_or_null("../Body/BodyCorrect/_ground")`，`host_node_of()` 全仓 0 使用） |
| 缺点：A 档玩法债 | 亡语链靠时序侥幸兜着 | **L-12 / L-13 / L-14 / U-31**（批次 3，⬜ 未开始） |
| 缺点：存档键 | 覆盖不齐 + 迁移工具已失效 | **U-20 / U-22**（批次 4，⬜ 未开始） |
| 缺点：单例边界 | `Global.` 混用跨局 / 本局，无划界 | **U-32**（批次 5，参考级） |
| 缺点：重复实现 | 死亡爆炸 / 速度同步 / 选项面板 / 老虎机阳光账 | **U-16 / U-17 / U-24 / U-25**（批次 5，参考级） |
| 缺点：防线窄 | 118 探针仅 `probe_gameplay_core` 证明「打起来了」；选关页仍硬引用 | **H-10（已做）/ H-14②③（未做）** |
| 缺点：文档即负担 | 文档与代码双向漂移仍在发生 | H-03 / H-04 / H-12（已对账，但需持续维护） |

**本次新发现缺口（新增条目）**

| 编号 | 档 | 文档怎么说 | 实测是多少 | 方向 |
| --- | -- | --- | --- | --- |
| **H-16** | B | 硬约束 §1-2 要求组件只经 `owner` / 信号 / 配置通信；U-14 已记「组件拼 `$"../X"`」 | 抽样 `component_move.gd:8` 仍 `get_node_or_null("../Body/BodyCorrect/_ground")`；`host_node_of()` 全仓 0 使用；`check_content_wiring.ps1` / `check_scripts.ps1` 均**不检查**此类「组件内硬编码宿主相对路径」 | 新增 `tools/check_component_wiring.ps1`：扫 `components/` 下 `.gd`，命中 `get_node_or_null("../` / `$"../` / `owner.get_node` 即 exit 1（命中即在 `host_node_of` 白名单外的报红）；先把现有违规列出来，再逐条改走 `host_node_of()`。⚠️ 落地 `host_node_of()` 属行为变更，须开游戏实测（U-14 复核已注明），不在检查器本身范围内 |

**依次修复优先级（整合项目原 §6 批次 + 本次强调）**

| 顺序 | 条目 | 备注 |
| --- | --- | --- |
| 1 | **L-12** | 小改：基类 `character_death_disappear()` 置 `is_can_death_language = false`；改完跑编译门禁 + `probe_gameplay_core`，**需开游戏人工回归**（读档清理 / 手套兜底 / 樱桃自爆） |
| 2 | **H-16 检查器** | 先写静态检查器把违规暴露出来（不自动改代码），低风险 |
| 3 | **U-32** | 给 `Global` 加边界注释 + 字段分类（只加注释，低风险） |
| 4 | **L-13 / L-14 / U-31** | 亡语链其余，需设计决策 + 开游戏实测 |
| 5 | **U-22 / U-20** | 修工具 + 补 `save_key` + 收敛存档键推导，数据风险高，需另起进程回读 |
| 6 | **U-14 / U-16 / U-17 / U-24 / U-25 / H-14②③** | 参考级，按收益 / 风险逐条评估，多数需开游戏 |

> 说明：当前为无头环境，可机械验证的是「编译门禁 PASS + 无头探针 PASS（若适用）」；
> 凡涉及角色 / 死亡 / 存档 / 组件通信的改动，文档均要求开真实游戏实测（V-01 例外写法：附人工验证方法）。
> 因此「依次修复」在无头环境下只能交付到「编译 + 无头探针通过 + 代码注释标注需实测」，完整验证需人工开游戏。

### 本轮（2026-10-16 后续）已执行（低风险可机械验证三项）

| 条目 | 状态 | 验证方式 |
| --- | --- | --- |
| **L-12** | ✅ 代码已改：基类 `character_death_disappear()` 置 `is_can_death_language = false`（`src/entities/character/character_base.gd:351`）；僵尸自身版本已含该开关、未动 | 编译门禁 PASS（`real compile errors = 0`，scenarios 119 PASS）；**⚠️ 行为变更，需开游戏实测**（爆炸植物自爆亡语 / 读档清理 `plant_cell.gd` / 手套兜底 `hand_component_glove.gd`），验证方法见代码注释 |
| **U-32** | ✅ 已完成：Global 顶部补「字段边界约定」+ `game_para` / `time_scale` 标 `@本局` 并给出 `GameContext` 迁移去向（纯注释，零行为变更） | 编译门禁 PASS；文档与代码同步 |
| **H-16** | ✅ 检查器已写：`tools/check_component_wiring.ps1`（默认报告模式 exit 0，`-Strict` 可接门禁 exit 1）；首跑暴露 **14 处**违规（对应 U-14 / U-15 全部存量：`component_move.gd:8`、`component_anim_norm.gd:25`、`component_attack_bullet_base.gd:5`、`bullet_movement_track.gd:5`、`component_armor_plant_head.gd:13`、`component_zombie_plant.gd:43` 等） | 运行验证：插入 `get_node_or_null("../Foo")` 必出现一条 VIOLATION（自证拦得住）；exit 0 报告模式符合「先暴露后严格」路线 |

> 待办（留待开游戏环境 / 后续轮次）：① L-12 的游戏实测回归；② H-16 暴露的 14 处违规逐条改走 `host_node_of()`（每条属行为变更，需开游戏）；③ §3.6 批次 4~6 的 A 档玩法债（L-13 / L-14 / U-31 亡语链、U-20 / U-22 存档键、U-14 落地、U-16 / U-17 / U-24 / U-25 重复实现、H-14②③）按原 §6 分批顺序推进；④ H-16 待违规清空后再传 `-Strict` 接入 `check_scripts.ps1` / pre-push。

## 4. 已销项的历史 TODO（不要按旧文档去找）

这几条曾被 [架构总览.md](../架构总览.md) §12 与 [参考存档/特殊关卡.md](参考存档/特殊关卡.md) 点名，当前代码里**已经没有 `TODO` 字样**（要么实现了，要么改写成了正式注释）：

| 曾经的位置 | 当时记的事 | 现状 |
| --- | --- | --- |
| `src/levels/mode_minigame/minigame_13_bobsled_bonanza.gd` | 冰面全融后**提高出怪密度**（文档写作 `TODO(全面冻结)`） | 密度机制已作为通用能力实现并被线索记录移走，检索不到 TODO |
| `src/levels/mode_minigame/minigame_20_zomboss_revenge.gd` | 僵王血量是原版的 1.5x（**不是** 2 倍） | 已落成正式注释（`minigame_20_zomboss_revenge.gd:34`），并明确写了「不要照'翻倍'的直觉改成 80000」 |
| **T-02** `component_attack_bullet_base.gd` | 子弹伤害由攻击组件指定（注释掉的 `attack_value_bullet`） | 已落地：子弹初始化参数新增 `E_InitParasAttr.AttackValue`，`attack_value_bullet`（默认 `-1`）取消注释并随 `get_bullet_paras()` 下发给子弹；`-1` 时沿用子弹场景自身的 `attack_value`，**现有玩法零变化**。`bullet_norm_base.get_bullet_paras()` 同步带上该值，保证再生成的子弹不掉伤害 |
| **T-03** `bullet_track_base.gd` | 无限穿透的追踪子弹可能对同一敌人反复造成伤害 | 已修：合并两个重复分支，无限穿透时按「同一个敌人只结算一次」去重（`_attacked_enemies_on_infinite`）。已核实数据层 `-1` 只出现在 `bullet_fume` / `bullet_bowling` / `bullet_bowling_big` 三张**非追踪**子弹上，改动不触及现有玩法 |
| **T-04** `plant_down_base.gd` | 荷叶走 tween、花盆走动画，想统一成动画一套 | 已统一：基类新增 `FloatAnimationPlayer` + `is_float_anim` 开关，起伏改为 AnimationPlayer 循环动画（运行时按当前 `position.y` 构建，幅度 5px 与原 tween 一致，随机起始相位防同步）；荷叶脚本里的 `tween_up_and_down()` 删除。花盆本来就在 `pot_idle` 里带 `DownPlantContainer:position` 轨道，两套机制已并为一套。回归见 `test/scenarios/probe_init.gd`（新增「起伏动画改到了本体 y」断言） |
| **U-01** `src/`+`test/`+`data/` 共 117 个文件 | 「当前这一局」两条访问路径并存：`Global.main_game`（转发）vs `GameContext.curr_main_game`（真相源） | 已统一（2026-10-11）：473 处直连全量迁到 `GameContext.curr_main_game`；`Global.main_game` 转发属性**一并删除** —— 留着它就会不停有人再写，双轨永远消不掉。删除前已确认全仓非注释行 0 处引用、无 `Global.get("main_game")` 动态访问。验证：编译门禁 PASS + `probe_init` 无头冒烟 PASS |
| **U-02** `zm_zombie_wave_create_manager.gd` | 僵尸战力 / 出怪权重**两份拷贝** | 已统一（2026-10-11）：先逐行比对确认两份**同值**，再删掉本地 `zombie_power` / `zombie_weights_ori`，`zombie_weights` 改从 `CharacterRegistry.ZombieSpawnWeights.duplicate_deep()` 取；4 处裸索引改走 `get_zombie_power()`；`zom_botany_config.gd` 里指向旧表的注释同步更新 |
| **U-03** `character_registry.gd` + 4 处业务裸索引 | 注册表读取**三种口径** | 已统一：`get_plant_info` / `get_zombie_info` 补 `.has()` 判存在 + `Log.error` + `return null`，与原有 `get_zombie_boss_info` 一致；业务侧 `ZombieInfo[t][attr]` 4 处（含 test 2 处）改走访问器。**坑**：访问器是实例方法，写 `CharacterRegistry.get_zombie_info()` 会编译报错「Cannot call non-static function」，必须 `Global.character_registry.` |
| **U-04** 5 个文件 7 处 `uid://` | 违反硬约束 1-5「一律 `res://`」 | 已改回 `res://` 绝对路径（`map_bg_anim_pool.gd` 3 处、`user.gd`、`scary_pot.gd`、`plant_cell.gd`、`sound_manager.gd`）。uid → 路径靠 `.tscn` 头部的 `uid=` 与 `.import` 的 `uid=` 反查。`sound_manager` 那处顺带把运行期 `load()` 改成 `const RAIN_SFX = preload(...)`，与相邻的 `THUNDER_SFX` 一致 |
| **U-05** `components/drop_body/`、`components/jackson/` | 放在 `components/` 下却不继承 `ComponentNormBase` | 已**移出** `components/`（`drop_body/` → `items/drop_body/`，`jackson/` → `entities/character/zombie/jackson/`），22 个文件 44 处路径同步更新。**没有选「接入」**：`drop_body` 激活后会 `reparent()` 走并自我销毁，2026-10-08 已判定不接入；两处文件头补了「为什么不是组件」。顺带发现 `charred_component` 同类但适合接入，已改 `extends ComponentNormBase` |
| **U-06** 组件拿宿主**四种写法** | 含最危险的 `owner = owner as Zombie000Base`（回写引擎属性） | 已统一：基类新增 `owner_character` 访问器（只转类型、**绝不回写**）；删掉 jackbox 的回写；`component_hp` / `component_critical_value` / `component_hp_stage_change` 各自重复的 `@onready var owner_character` 一并删除（会遮蔽基类同名成员 → 编译报错）；jalapeno 改成 getter 收窄 |
| **U-07** 状态机「两代并存」 | —— | **判定误报，销项**：`ZB001DoctorStateMachine` 是 `extends CharacterStateMachine`（继承扩展，正是通用机文档说的「专用状态机扩展」，不是另起一套）。真正没继承的是 `JacksonStateMachine`（`extends Node`），但那是**有意**的 —— 5 个伴舞共用一份 `JacksonManager`，切换夹着大量联动，作者注释已写明；已在文件头补注释澄清与通用机的关系 |
| **U-08** registry 泛滥 / 空壳 / 缺访问器 | —— | **部分处理**：新增 `get_scene_path()`（带 `fallback`）+ `set_scene_path()`，全仓 **75 个文件 97 处** `MainScenesMap[...]` 裸索引改走访问器（实际数量远超登记时估计的 16 处）。**`ItemRegistry` 空壳保留**：`global.gd` 用 `%ItemRegistry` 引用、`global.tscn` 有对应节点，删脚本要连场景改，2026-10-07 已判定收益 < 风险，已补注释说明。其余 registry（`loot_registry` / `zm_boss_registry` / `console_registry` …）各管各的领域，判定为**不是重复** |
| **U-09** `level_data.gd` 三字段 | 「场景/背景是哪一套」三套并行表达 | **判定为三个不同粒度，不收敛**：`game_sences` = 用哪个主场景文件（3 槽位）、`game_BG` = 用哪套背景视觉（比前者多出「夜」「雾」）、`scene_name` = 套用哪套预设组合（展开后覆写前两者）。合成一个字段反而表达不了「前院 + 夜」这种组合。已在 `level_data.gd` 的「关卡背景」region 补注释写明三者区别与**单向优先级**（先按 `scene_name` 展开预设，再由关卡脚本覆写） |
| **U-10** `zombie_boss/` 僵王 | 数字编号前缀只清理了一半 | 已重命名（2026-10-11）：`001_doctor/` → `doctor/`、`z_b_001_doctor_*` → `zb_doctor_*`、`z_b_000_base.gd` → `zb_base.gd`、两个 `.tscn` 去数字。**104 个文件 + 4 个目录**重命名，168 处路径引用同步（`src/` `animation/` `data/` `addons/` 配置 + 5 份现行文档），含数字文件归零。类名 `ZB001Doctor*` **未改** —— 那是角色编号语义而非目录编号，且要动 100+ 处引用，收益 < 风险。验证：编译门禁 PASS + `probe_zomboss_layout` 博士正常出场 |
| **U-11** 命名风格 / 枚举撞车 | `E_PotMode` vs `E_PotType` 语义撞车；`z_b_` 等缩写前缀 | **撞车那对已用注释澄清、没有改名**：两者语义本就不同（一个是关卡级「罐子怎么生成」，一个是单个罐子「装的是植物还是僵尸」），已在两处枚举定义上互相指名。不改名的理由：改了会让 2026-10-04 那批工作记录里的旧名对不上代码，而歧义风险本身很低。**前缀缩写（`zm_` `mgm_` `z_b_`…）判定不动** —— 纯可读性收益、改动面是全仓文件名，留作参考 |
| **U-12** 暂停机制多套并存 | `TreePauseManager` 单例形同虚设 | **判定误报**：实际有 **10 处调用**（菜单 / 游戏结束 / 重新选卡三个因素，分布在 6 个文件），架构总览 §792 也记着它。`process_mode = PROCESS_MODE_ALWAYS` 全仓只有 5 处，且每处都是「全场暂停时仍要跑」的**豁免**（相机 / 卡槽 / 联机准备按钮 / 调试通道）—— 两者**互补**而非重复：一个停全场，一个把个别节点摘出去。已在 `tree_pause_manager.gd` 补注释说明分工 |
| **U-13** 音效未收口 | 89+ 文件出现裸 `.play()` | **判定误报**：登记时把 `AnimationPlayer.play()` 当成了音频播放。实际 `SoundManager.` 被 **87+ 个文件**调用（它有 `play_sfx_with_pool` 等 15 个方法），而 `AudioStreamPlayer` 在 `src/` 下只出现在 2 个文件（`sound_manager.gd` 自身 + `zombie_base.gd` 的入场音效）。音效**已收口**，无需处理 |
| **T-06** `sound_manager.gd` | `siren` / `awooga` 是不是同一条汽笛 | **澄清后销项**（2026-10-11）：两条是原版 `progress/` 下**两个不同的音频文件**（`siren` = 汽笛，`awooga` = 一大波逼近的警报音），不是重复登记；且二者在 `src/` 里**都还没有播放点**，是留着待接线的库存音效。已把 `TODO` 换成写清两者口径 + 「别当冗余删」的正式注释。**没有合并** —— 合并会丢掉一条音效 |
| **U-28** 蜗牛场景两条入口 | 商店图标 `preload` 路径 vs 花园侧 `SceneRegistry.STINKY` | 已统一（2026-10-11）：`goods_garden_tool.gd` 的 `FRAME_ICON_SCENE` 改取 `SceneRegistry.STINKY`。**坑**：`SceneRegistry` 是**单例节点**（无 `class_name`），`const` 右值必须是编译期常量，写 `SceneRegistry.STINKY` 会报「Cannot use a non-constant value in a constant expression」—— 字典因此从 `const` 降级为 `var`（只读不写，行为一致），已在文件头写明原因 |
| **U-30** 架构总览文档漂移 | 僵王重命名后文档仍写 `z_b_000_base.gd` | 已改（2026-10-11）：`架构总览.md:254` → `zb_base.gd`；§12 第 14 项的「约 12 处 TODO」改为指向本文并更新为 2 条。**剩余部分不动**：`doctor/` 与 `zb_doctor_objects/` 目录前缀不一致属纯可读性收益，与 U-11 的前缀缩写同一处理 |
| **L-02** `consts/readme.md` 说有 `GLOVE_ENABLED` | 文档里有、代码里没有 | 已改（2026-10-11）：readme 里删掉 `GLOVE_ENABLED`，并补一句「已随手套模组化删除，开关在 `data/mods/mod_config.tres`；原版没有的玩法一律做成模组，不要在这里加开关」—— 顺便把这条容易再犯的规矩写进了文档 |
| **L-06** `bullet_base.gd` 注释自相矛盾 | 写 7 个子类却列 8 个；描述的陷阱并不存在 | 已修正（2026-10-11）：数字改 **8**（实查 `src/entities/bullet` 下重写 `_ready()` 的 8 个：`bowling` `cactus` `cob_cannon` `norm_base` `parabola_base` `pea_fire` `track_base` `winter_melon`），并写明「基类自己**没有** `_ready()`」，删掉不存在的「静默失效」描述，保留真正理由（领号在唯一创建口上，子类不必记得调 `super()`） |
| **L-11** `garden_manager.gd:184` 裸 `0` | 同文件别处写的是 `E_GardenBgType.GreenHouse` | 已改（2026-10-11）：`if curr_bg_type == 0` → `if curr_bg_type == E_GardenBgType.GreenHouse`（枚举首项本就是 0，纯等价改写） |
| **O-03** 花园存档键读写各拼一遍 | `"第N类背景"` / `"第N页"` / `"第N个植物格子"` | 已收敛（2026-10-11）：`GardenManager` 新增 `make_bg_save_key()` / `make_page_save_key()` / `make_cell_save_key()` 三个静态函数（`%d` 拼装，**与原字符串逐字一致**，老存档不受影响），4 个文件 11 处拼接全量改走它们：`garden_manager.gd`（4 处）、`garden_bg_page.gd`、`garden_water_flag.gd`（3 处）、`global_garden_state.gd`（3 处） |
| **U-29** 探针绕开切场景入口 | `test/scenarios/` 70 个文件、81 处 `a.get_tree().change_scene_to_file(...)` | 已统一（2026-10-11）：全量改成 `GlobalUtils.change_scene(...)` —— **没有**新建测试专用入口，那样只会多出第二套写法（正是 U 系列要清的东西）。改法是**纯记号替换**（连 `(` 一起换，参数表不动），所以单行 / 多行两种写法都不用改参数。**验证**：编译门禁 PASS（含 scenarios 那道，108 个脚本）+ 实跑两个探针：`boot_level`（走 `a.wait()`）与 `probe_garden_bg`（走 `a.wait_scene()`），均 PASS、场景切到位。**配套**：E-02 补了第 5 条，写明「探针切场景走 `GlobalUtils.change_scene`，且切换是延迟的、后面必须给帧边界」 |
| **U-21** 「总波数」四份同名状态 | `level_data.max_wave` / `ZombieWaveManager.max_wave` / `max_wave_one_round` / `HammerZombieManager.max_wave` | 已按「或在字段注释里写明」这条路销项（2026-10-11）：`level_data.gd:183` 加了注释，写清三份波数的区别与「其余 100+ 关运行时**不读**本字段（波数由「开战」事件带进来）」。**顺带订正登记口径**：原写「只有 5 个小游戏关赋值（05/07/09/15/16）」，实查是 **3 关直接赋值**（05 / 07 / 09），15 关走 `max_wave_hammer_zombie`、16 关把波数当 `start_battle()` 的入参。**没拆名** —— 改名要动 `.tres` 关卡资源与多处引用，收益不如注释 |
| **U-19** 小推车场景映射绕开注册表 | `gim_lawn_mover.gd` 的 `LawnMoverSecneMap`（原文拼错）3 条 `preload` | 已搬进 `SceneRegistry.LAWN_MOVER_MAP`（2026-10-11），管理器只查表；`Secne` 拼写随旧常量一起消失。**注意**：`const` 字典里写 `GIM_LawnMover.E_LawnMoverType.X` 是合法的（`class_name` 枚举成员是编译期常量），编译门禁已证 |
| **L-01** 两个死事件 | `WIN_MAIN_GAME` / `REPLENISH_LAWN_MOVER` 只有订阅、0 处 push | 已删（2026-10-11）：两个常量 + 签名表两条 + 两处 `EventBus.subscribe`。**没走「补 push 点」那条路** —— 补了就是新增一条会真的触发的链路，属行为变更；删掉反而让「胜利只有 `shortcut_win_main_game()` 一个入口、补车只有时间轴事件一个入口」变成事实。顺带删掉只为该事件存在的 `GIM_LawnMover.replenish_lawn_mover()`（已核实 0 调用点，`init_or_replenish_lawn_movers()` 才是流程入口） |
| **L-03** 恒 false 的收旗开关 | `zm_hammer_zombie_manager._is_flag_reset_pending` 只被读、从不置 true | 已删（2026-10-11）：连字段带 `take_flag_reset()` 覆写一起删 —— 该类直接 `extends ZombieWaveSourceBase`，基类 `:54` 本来就 `return false`，覆写是多余的。改为注释说明「本玩法单轮，不收旗」 |
| **L-05** 占位枚举暴露成开关位 | `E_ItemType.Other = 4` + `@export_flags(... "4 占位")` | 已删（2026-10-11），并在枚举上加注释「加新道具要枚举与 `is_detect_items` 两处一起加」。**删前先查了 4 个 `.tscn` 的 `is_detect_items` 取值**（`zombie_base`=1、`zombie_gargantuar`=3、`zombie_catapult`=0/1）—— 没人勾过第 4 位，删了不影响任何场景 |
| **L-08** 没人读的 `@export var is_fade` | `reminder_information.gd:4` | 已删（2026-10-11）。**没实现淡出** —— 那会让提示条的消失方式发生变化，属视觉行为变更；删掉一个 0 读取点的开关是零风险的 |
| **O-01** 选行系统每帧空转 | `zm_zombie_choose_row_system._ready()` 无条件 `set_process(true)` | 已改（2026-10-11）：新增 `_refresh_process()`（只要有任一行 `lane_protect_time_left > 0` 才开），在 init 末尾、`on_lawn_mover_triggered()` 置位后、`_process` 末尾各调一次。**等价性**：`lane_protect_time_left` 的三个写入点已全查（init 全 0 / 每帧自减 / 丢车时置位），全 0 时 `_process` 本就什么也不做。注意 `_process` 里归零后再关一次，否则会多空转一帧 |

| **H-05** 清单条数三处不一 | `docs/README.md` 说「全部 6 条 TODO」，本文 §2 标题写「3 条」，表内与代码实测都是 **2 条** | 已修（2026-10-16）：按「不写死数字」的原则改 —— `docs/README.md` §2.1 那行改为「条数以 `TODO清单.md` §1 口径为准」，本文 §2 标题改 2 条。**选择改描述、而不是把 6/3 更新成 2**：写死数字必然再次漂移（H-03 / H-04 就是同一病根） |
| **H-01** 无 CI，编译门禁靠人记 | 全仓无 `.github/`，硬约束 §1-7 的「必跑门禁」没有任何机制保证 | 已做（2026-10-16）：落地**本地 pre-push 钩子** —— 新增 `test/git_hooks/pre-push`（入库）+ 复制到 `.git/hooks/pre-push`（本机即时生效，实测 `HOOK_EXIT=0`）。**云端 CI 的理由已更正**：原先记的是「`assets/` 不入库会导致假红」，但实测 `git ls-files assets` 有 **5339** 个文件（素材**在版本控制内**），CI 技术上可行 —— 当前只是选择本地钩子（更快、无需 runner）。同轮另加 `pre-commit`：拦危险文件名（终端产物 / `*.tmp` / `error_log.txt` / `package*.json` / 跑批临时物）、孤儿 `.uid`、单文件 > 5 MB，并提示暂存规模；实测「空暂存区放行、危险文件拦截」。启用方式写在钩子文件头 + `test/README.md` |
| **H-02** 597 个已改 + 351 个未跟踪文件未提交 | git 工作区 2026-10-16 快照 | 已做：切成 **4 笔提交**（`chore(repo)` 清残留 → 本体重构 → `feat(mods)` 模组 → `docs`），工作区归零。提交前先跑编译门禁 PASS（118 个 scenarios）。**顺序上把 H-06 提前了**：那两个含引号的残留文件是**未跟踪**的，不先删掉会被 `git add -A` 一并提交进去 |
| **H-03** autoload 数量三处不一（9 / 10 / 实际 11） | 缺 `DamageSystem` 的记载 | 已做：两份文档统一为 **11**（并列全名单）；`DamageSystem` 补进 `架构总览.md` §4.1 单例表（含三段式、效果注册表、「刻意不写 `class_name`」的理由），§12.1 启动流程改「11 个 autoload 就绪」 |
| **H-04** 规模数字与实测系统性不符 | 脚本数 / 数据数 / 文档份数 / 场景数 | 已做：按 2026-10-16 实测重写 `AGENTS.md` §1、`README.md`、`架构总览.md` §1 / §2 目录树 / §11.3 / §13 / §15（整表）/ §15.1（行数表，另补 `level_script_base.gd` 一行），以及 `docs/README.md`。口径统一为「命令直出 + 写明日期」；§5 已加「规模数字一律生成、不手写」 |
| **H-06** 根目录 5 个残留文件 | `'` / `' + $e + '')` / `error_log.txt` / `package.json` / `package-lock.json` | 已做：5 个全删，另删孤儿 `test/_tmp_b.gd.uid`；`.gitignore` 补 5 条模式（`/*'*`、`/error_log.txt`、`/package*.json`、`/test/_tmp_*`）。顺带印证 `架构总览.md` §12 第 11 项原先记的「已删」与实际不符 |
| **H-07** Godot 版本口径不一 | `project.godot` 4.6 / README 4.5.1 / 测试脚本 4.6.2 | 已做：**以 `project.godot` 的 `config/features`（`"4.6"`）为唯一口径**，README 与架构总览照此改写。**顺带修掉一个真问题**：`run_autopilot.ps1` 的默认引擎路径指向**不存在**的 `Godot_v4.6.2-stable_win64.exe`（`check_scripts.ps1` 早已改成 `godot.exe`），已统一为同一份并补「找不到引擎即 `exit 2`」，不再静默假绿 |
| **H-08** 两条红探针长期挂账 | `probe_bullet_camp` / `probe_plant` | 已做：① `probe_bullet_camp` 经运行期取证判定**错在探针**（期望值误用已废弃的 layer 11 = 1024），改为 `256 + 512` 并写明数字口径 → `result=PASS failed=0`；② `probe_plant` 的种植环节**带窗口也失效**（合成 `Input.parse_input_event` 的限制，非游戏 bug），改为按可靠的坐标换算判 `result=PASS`，种植单独记 `plant_result=SKIP`。同步修正 `架构总览.md` §11.3 原先「差的那一位是 1024 层（植物层）」的错误结论。**附带踩坑**：跑批前若有残留 Godot 进程，会读到陈旧输出、表现为「传 A 却跑了 B」的假象 —— **先杀进程再跑** |
| **H-09** 文档事实没有自动比对 | 文档里的规模数字与「已删 / 不存在」类断言全靠人肉体检 | 已做（2026-10-16）：新增 `tools/check_doc_facts.ps1` —— 按**已入库文件**口径把文档声称的数字与实测对账（autoload 数、`src/` `data/` `docs/` `test/` 的计数、架构总览 §15 表、`docs/README` 份数），并校验顶层文档之间的 `.md` 链接；有差异即 exit 1。**首跑就抓出 4 处真实漂移**（2 个计数、架构总览 §13 表、以及 `docs/验证流程.md` 里一个断链 `../项目规范.md`），全部已修 → 现 `result=PASS`。**注意**：该脚本必须存为 **UTF-8 with BOM**（PS 5.1 读无 BOM 脚本按 ANSI，中文字面量会变乱码 —— 本轮实测踩过） |
| **H-10** 玩法链路没有自动防线 | 118 个探针里**没有一条**证明「打起来了」；`probe_plant` 的种植环节判 `plant_result=SKIP`；门禁自陈抓不到语义错误（`portal_manager.gd` 调 `get_world_2d()` 仍 PASS） | 已做（2026-10-16）：新增 `test/scenarios/probe_gameplay_core.gd` —— 豌豆射手种下（走游戏内同一个入口 `PlantCell.create_plant()`）→ 索敌开火 → 子弹命中掉血 → 死亡信号 + 尸体离场，全部落成机器可读断言（`[GAMEPLAY] result=PASS\|FAIL`）。**并做了注入验证**：把 `bullet_registry.create_bullet()` 临时改成 `return null` 重跑 → 探针报 `血量 270 -> 270（掉 0）` 且 `result=FAIL`，改动已还原（`git status` 该文件干净）。健康代码下无头约 40s，`result=PASS failed=0`。探针文件头写明了边界（只覆盖「豌豆 × 普僵」这条最常用链路；不碰 UI 点击；掉落物有随机性只打印不判定）与**自证方法**。**遗留 1**：「改动触达角色 / 子弹 / 伤害管线时必须跑它」这条口径还没写进硬约束 §1-7，本轮只落在 `test/README.md`。**遗留 2**：跑批仍为手动（未接 CI 日常） |
| **H-12** 文档事实漂移：assets 口径 + 断链 | `AGENTS.md` §1 与 `架构总览.md` §1 / §2 都写 assets「不入 git，需自备」；`level_data.gd:24` 与 U-22 指向**不存在**的 `tool_migrate_save_key.gd` | 已做（2026-10-16）：① 三处口径改为「**在版本控制内**」并带实测数（`git ls-files assets` = 5339）；② `tools/check_doc_facts.ps1` 新增 **E 组检查**（扫三份顶层文档的「不入 git」「自行准备」措辞 + 校验数字），检查数 19 → 23 且 `PASS`；③ **注入验证**：临时给 `README.md` 加一行「assets（不入 git）」→ 脚本报 `FAIL README.md still claims assets/ is not in git`（已还原，`result=PASS`）；④ `level_data.gd` 注释改指真实工具链（`tool_dump_save_keys` → `tool_write_save_keys` → `probe_save_key`）并写明写入工具当前仍面向**已不存在**的 `.tres`（该部分归 U-22 处理）。**踩坑**：`check_doc_facts.ps1` 是 ASCII-only 文件（PS 5.1 读无 BOM 脚本按 ANSI），新增检查里的中文**必须**写成 `\uXXXX` 转义 |
| **H-13** 提交粒度粗、bisect 不可用 | 全库 33 条提交；H-02 一轮把 948 个文件压成 4 笔 | 已做（2026-10-16）：新增 [E-09 提交粒度：一个逻辑单元一笔](参考存档/规范细则存档.md#e-09-提交粒度一个逻辑单元一笔)（参考级），并在 `docs/项目规范.md` §2 目录补行。内容包括「一个逻辑单元一笔 / 先清残留再提交主体 / 跑批产物不入库 / 与 `pre-commit` 的 >30 文件提醒保持一致（只提醒不硬拦）」。**遗留**：历史 33 条提交**不重写**（重写公共历史的代价 > 收益） |
| **H-15** 工作记录索引难查同类任务 | `docs/` 226 份 `.md`（其中工作记录 170+）vs `src/` 643 个 `.gd`；索引按日期线性排，同类任务散在各处 | 已做（2026-10-16）：`docs/工作记录/README.md` 新增 **§2.1「常用主题入口」** —— 9 个跨日期主题簇各给一条入口 + 「为什么是这几条」（id 去编号 / 工具模组 / 模组加载源与素材 / 联机 / 探针与验证 / 存档与进度 / 组件生命周期 bug / 资源改名 / 文档规范），并写明「写记录只写结论 / 最简路径 / 踩坑，过程流水不写」。物理文件与主表**不动**（历史记录是资产），主表仍按日期排） |

> 教训：**TODO 销项后记得把指向它的文档也改掉**，否则后来的人会按旧索引去一条不存在的注释（文档同步现已放宽，见 [docs/README.md](./README.md) §6，仅硬约束与机制文档需优先同步）。

---

## 5. 维护约定

- **新增一条**：
  - **T 系列**（§2，代码注释类）：在 §2 表末尾追加一行，编号顺延（`T-07`…），并把同样的信息写在**代码注释里**（清单与注释双向可见）。
  - **U 系列**（§3.1，不统一 / 重复实现类）：在 §3.1 表末尾追加一行，编号顺延（`U-31`…），写明**两（多）种写法各自的位置**——只写「不统一」不写「在哪两种」等于没记。
  - **L 系列**（§3.2，逻辑不全 / 未接线类）：编号顺延（`L-12`…）。典型形态：只有订阅没有发布的死事件、恒假的开关、空 `pass` 接口、文档里有代码里没有的常量。
  - **O 系列**（§3.3，性能可优化类）：编号顺延（`O-04`…）。只记**有量化理由**的（每帧空转 / 全表线性扫描 / 重复拼接），不要记「看着不顺眼」。
  - **H 系列**（§3.4，仓库卫生 / 工程流程类）：编号顺延（`H-09`…）。登记格式与其他系列不同：**必须同时写「文档怎么说」和「实测是多少」**（只写一边等于没记，下次体检无法复现）；口径一律用可复现命令（`git status` / 文件计数 / `Test-Path`），不做估算。**H 系列不写进代码注释**（它们不在代码里）。
- **销项一条**：T 系列要把代码注释里的 `TODO` 删掉；四个系列都要从原表移到 §4，写清「怎么解决的」。只改代码（或文档）不改本文 = 清单变脏。
- **重新体检**：每过一段时间（或一次大清理之前）用 §1 的口径全仓库搜一次 `TODO`，命中数与本文不符时以代码为准更新本文。U 系列靠「同一件事搜两种写法、比较命中数」来体检；L 系列靠「搜订阅点与发布点、比较命中数」来体检。

---

## 6. 本轮整体整改方向（2026-10-16 体检 → 分批）

> **为什么要有这一节**：§2 / §3 是**清单**（有什么债），本节是**顺序**（先做哪条、做到什么算完）。
> 债不是并列的：批次 1 是批次 3 的**前置**（没有可靠的自动防线，动死亡链等于盲改），所以顺序本身是结论。
> 编号互相引用；**每批做完把条目从 §3 表移到 §4 并写清怎么解决的**（§5 约定）。

| 批次 | 主题 | 含条目 | 为什么不先做别的 / 前置条件 | 验收口径 |
| -- | -- | --- | --- | --- |
| **1** | **零运行时风险的文档与流程**（改完不影响游戏） | H-12（文档口径与断链）、H-13（提交粒度 → E-09）、H-15（索引主题分组） | 成本以分钟计、零回归风险；且 H-12 是「文档可信度」的地基 —— 文档里既有「assets 不入库」这种错断言，也有「三处已更正」这种**假完成**，不先修，后面所有结论都要打折 | 跑 `tools/check_doc_facts.ps1`（**新增的 assets 检查必须真的能拦住**：故意改坏一次看它 FAIL）+ 编译门禁 PASS + 无断链 |
| **2** | **防线：把纪律变成可执行的检查** | H-10（`probe_gameplay_core` 玩法链路探针）、H-14①（`check_content_wiring.ps1`）、H-11（云端 CI） | 批次 3 要动的是**角色 / 子弹 / 伤害管线**，而现有 118 个探针**证明不了这条链路**（H-10）。先有防线再改代码，否则「改完靠感觉」 | 每条都要**注入一次错误看它报红**（探针把伤害改 0 要 FAIL；接线检查删掉一条注册表条目要 exit 1）；CI 需先在 runner 上确认引擎获取方式，**未验证前不写「CI 可用」** |
| **3** | **A 档死亡 / 亡语链**（本轮唯一「靠时序侥幸」的一簇，四条互相咬合） | L-12 → L-13 → L-14 → U-31（顺序即依赖顺序） | L-12 是**开关位置**（把 `is_can_death_language = false` 提到基类），L-13 是**触发时机**（亡语排在 `signal_character_death.emit()` 之前还是之后），L-14 是**前提显式化**（「本函数必须同步致死」），U-31 才是**结构下沉**（散在 6 个子类 → 组件）。前三条各自都会改变行为，**必须逐条开游戏实测**（V-01 的例外写法：附人工验证方法） | 每条：编译门禁 + `probe_gameplay_core` + 至少一条相关探针（`probe_zomboss_layout` / 雪橇关）+ 人工回归（种樱桃 / 读档清理 / 手套兜底 / 雪橇僵尸补兵）逐项勾 |
| **4** | **存档键与存档语义**（数据迁移，错一处就是玩家进度丢失） | U-22（`save_key` 补齐，**先修工具**）、U-20（两套推导收敛成 `make_save_key()` / `parse_save_key()`） | 必须先有「读权威值 → 写入 → 另一进程回读」的闭环（工具现在面向已不存在的 `.tres`，见 U-22），且 U-20 的收敛要在补齐**之后**做，否则两件事一起改时无法判断是哪边错位 | `tool_dump_save_keys` 权威值表 + `probe_save_key` 另一进进程回读一致；老存档（含 `LEGACY_INT_TO_ID` 那批）仍能读出来 |
| **5** | **参考级 / 判定暂缓**（**不做也不打回**，列出来是为了「别当没看见」） | U-14（组件里拼 `$"../X"`：`host_node_of()` 全仓 0 使用，首次落地=行为变更）、U-16（速度同步 12+ 份并存）、U-25（老虎机两本阳光账）、U-32（`Global` 边界）、§12.3 第 9 项（选关页注册表化，需开窗口比对视觉配置）、§12.3 第 15 项（`plant_cell.gd` 不拆）、§12.3 第 16 项（子弹对象池暂缓） | 收益 / 风险比不划算或需单开一轮；**留档是为了下一个人不必重新评估一遍** | 只要求：动手前读本条与对应 U 条目的「判定不做」理由，不要按直觉反向改 |

**收尾（每批都做）**：编译门禁（`real compile errors = 0`）→ `tools/check_doc_facts.ps1` → 按 [E-05](参考存档/规范细则存档.md#e-05-工作流程归档每次任务结束必做) **建议**在 `docs/工作记录/` 补一条记录（索引由 `tools/gen_worklog_index.ps1` 自动生成，无需补行）→ 本文件把已完成的条目移到 §4。

**批次 1 / 2 的已知成本**：批次 2 的三条都要**新写检查脚本或探针**（不是改代码），写完必须自己先注入错误验证一遍 —— 「写了检查但检查不报错」比没写更糟（H-09 的 `check_doc_facts.ps1` 就是这样才发现它漏了 assets 这一项）。

### 6.1 本轮（2026-10-16）已执行到哪一步

> 供后来者判断「哪些结论已经被验证过、哪些还只是方向」。

| 条目 | 状态 | 验证方式（本次实跑过） |
| --- | --- | --- |
| H-10 玩法链路探针 | ✅ **完成**（销项见 §4） | 新增 `test/scenarios/probe_gameplay_core.gd`；健康代码 `result=PASS failed=0`（掉血 `270 → 250`，耗时 1.0s；尸体离场 4.5s）；**注入 `create_bullet() → return null` 后 `result=FAIL`**，改动已还原 |
| H-12 文档口径 + 检查器 | ✅ **完成**（销项见 §4） | `tools/check_doc_facts.ps1` 检查数 19 → 23 且 `PASS`；**注入「assets（不入 git）」一行后 `FAIL README.md still claims assets/ is not in git`**，已还原 |
| H-13 提交粒度细则 | ✅ **完成**（销项见 §4） | 新增 E-09 + `docs/项目规范.md` §2 目录行（文档改动，无需跑游戏） |
| H-15 工作记录主题入口 | ✅ **完成**（销项见 §4） | 新增 `docs/工作记录/README.md` §2.1；新增链接已逐个核对文件存在（脚本扫 0 断链） |
| H-11 云端 CI | 🟡 **半完成**（留 §3.5） | `.github/workflows/ci.yml` 已写；**未在 runner 上验证**（本地无法验证），首推后按文件头三步确认 |
| H-14 接线检查器 | ✅ **完成 ①**（②③ 未做，留 §3.5） | `tools/check_content_wiring.ps1` 已写；健康树 `result=PASS checks=192`；**注入验证**：改坏场景 preload → `FAIL plant PEA_SHOOTER_SINGLE: scene missing`，已还原（②③ 见 §3.5） |
| U-22 存档键补齐 | ⬜ **未开始**（方向已更新） | 已实测：`src/levels/` 下 `.tres` = **0**，现役写入工具仍面向 `.tres` ⇒ **必须先修工具**；覆盖数已重测（adventure 4/54、survival 0/15、minigame 20/25） |
| 批次 3（L-12 → L-13 → L-14 → U-31 死亡链） | ⬜ **未开始** | 依赖批次 2 的探针做回归；改的是角色 / 死亡管线，必须开游戏实测（V-01 例外写法） |

