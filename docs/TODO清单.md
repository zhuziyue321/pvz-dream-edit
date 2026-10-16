<!-- AGENT-DOC: index -->

# TODO 清单

> **[面向 AI Agent]** ｜ **触发条件**：被安排做清理 / 还债类任务；想找「还能做什么」；有人问「仓库里还剩哪些待办」；删代码前判断某条 TODO 是不是垃圾
> **读完你能**：① 列出当前仓库全部 `TODO` 注释（2 条，§2）及其精确位置；② 列出当前「不统一实现 / 逻辑不全 / 可优化」的架构债（**22 条**：U 系列 13 + L 系列 8 + O 系列 1，见 §3；U-01~U-13 已于 2026-10-11 销项，见 §4）；③ 列出**仓库卫生与工程流程债**（**H 系列，现存 7 条**，见 §3.4：无 CI / 工作区未提交 / 文档漂移 / 根目录残留 / 已知红探针）；④ 判断某条 TODO 是「有效待办」还是「可删的痕迹」；⑤ 知道新增 / 销项一条时改哪里
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

> **2026-10-16 定向体检（新增 H 系列）**：本轮**不看玩法代码**，专扫「仓库本身」的健康度 ——
> 把文档里声称的数字 / 状态**逐条与实测对账**（`git status`、文件计数、`.github` 是否存在、根目录残留），
> 新增 **H-01 ~ H-08（8 条，其中 H-05 当轮即销项，现存 7 条）**，见 §3.4。口径：命令直出，不做估算；每条都写清「文档怎么说 vs 实测是多少」。
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

### 3.1 U 系列：不统一实现 / 重复实现（U-14 ~ U-31，现存 13 条；U-19 / U-21 / U-28 / U-29 / U-30 已销项）

> 来源：2026-10-11 第二轮全仓扫描（U-01 ~ U-13 已销项，去向见 §4）。
> **U-31 来自 2026-10-13 亡语专项复核**（`character_base.gd` 的 `death_language()` 链 + 6 个重写点全量核对）。

| 编号 | 档 | 位置 / 范围 | 不统一的现象 | 处理建议 |
| --- | --- | --- | --- | --- |
| **U-14** | B | `components/anim_component/component_anim_norm.gd:25`、`component_anim_player.gd:5`、`component_anim_bobsled.gd:4-8`、`attack_behavior_component/component_attack_bullet_base.gd:5`、`charred_component/component_charred_zombie_bobsled.gd:4`、`src/entities/bullet/component/movement/bullet_movement_track.gd:5` | 组件里直接拼宿主相对路径 `$"../AnimationTree"` / `$"../AnimationPlayer"` / `$"../Body"` / `$"../ZombieBobsled1"` —— 宿主结构一改就**静默取到 null**。`character_base.gd:422-439` 与 `bullet_base.gd:66-80` 已提供 `host_node_of(owner, ^"XXX")` 入口（注释原文就是「替代在组件里拼 `$"../XXX"`」），这 6 处没走 | 全部改走 `host_node_of()` |
| **U-15** | B | `attack_behavior_component/component_attack_zom_botany.gd:64`、`component_attack_zom_botany_pea.gd:137`、`zombie_plant_component/component_zombie_plant.gd:66` | 组件间硬编码**兄弟组件 / 宿主子节点名**：`owner.get_node_or_null(^"ZombiePlantComponent")`（2 处）、`owner.get_node_or_null(^"Body/BodyCorrect")`；违反「组件只通过 `owner` / 信号 / 场景配置通信」 | 改 `@export` 场景注入，或走宿主提供的访问器 |
| **U-16** | C | `component_norm_base.gd:90`（空实现）被 12 处各抄一份：`component_sleep.gd:53`、`component_move.gd:85`、`component_magnet.gd:98`、`component_create_sun.gd:76`、`component_create_coin.gd:55`、`bomb_component/component_bomb_jackbox.gd:41`、`attack_behavior_component/component_attack_zombie_norm.gd:27`、`_zombie_zamboni.gd:20`、`_zombie_gargantuar.gd:46` 等 | 「速度同步」12+ 份并行实现，各自算一遍乘积；`anim_component/` 下 `component_anim.gd:70,74` / `component_anim_norm.gd:100,104` / `component_anim_bobsled.gd:17,23` / `component_anim_empty.gd:7,12` 又是 4 份互为复制 | 倍率计算收敛到基类，组件只接收结果 |
| **U-17** | C | `components/zamboni/zamboni_death_bomb.gd:24-33` vs `components/zombie_death_bomb/zombie_death_bomb.gd:8-16` | 两份「死亡爆炸」：`activate_it()` 逐行相同（`reparent(get_sibling_layer())` → 两个 `GPUParticles2D.emitting = true` → `await finished` → `queue_free()`），仅 Zamboni 多一个 `explode()`；**且 Zamboni 只 `await gpu_particles_2d.finished`、漏了 `_2`**（Zombie 版 await 两个）→ 提前 `queue_free()` 会截断第二个粒子的尾巴 | 合并为一份，炸飞做可选开关；补上第二个 `await`。**2026-10-11 已补第二个 `await`**（已核实 `zombie_death_bomb.tscn` 里两个粒子都是 `one_shot = true` / `lifetime = 0.6`，`finished` 必来）。**合并未做** —— 没有 `zamboni_death_bomb.tscn`，两个脚本都挂在 `zombie_death_bomb.tscn` 的实例上由 `zombie_zamboni.tscn` / `zombie_catapult.tscn` 覆写脚本，改成继承要动 `.tscn` 里的脚本覆盖，且 `explode()` 依赖 `$Body`（需确认场景里有没有这个子节点），要开游戏确认 |
| **U-18** | B | `components/swim_box_component/component_swim_box.gd:1` | 放在 `components/` 下却是 `extends Node2D`（不继承 `ComponentNormBase`）—— **U-05 的漏网之鱼**（当时只清了 `drop_body/` `jackson/`）。同文件 `appear_splash()` / `appear_splash_special_pos()` 整段复制，只差一个取位节点 | 接不接入二选一，并在文件头写清理由（照 U-05 的先例）；两个水花函数抽公共 `appear_splash_at(pos_node)`。**2026-10-11：水花已抽公共 `appear_splash_at(pos_node)`（等价改写）；接入与否的理由已写进文件头** —— 关键更正：`ComponentNormBase` 自己就是 `extends Node2D`，所以「因为要 Node2D 才不能接入」这个理由**不成立**，真正的差别只有启用/禁用框架；是否接入属行为变更（走 `component_ready()` + 各路启用因素后，场景连的信号回调还在不在要重判），需开游戏确认 |
| **U-20** | A | `src/levels/core/level_data.gd:35` ↔ `src/core/autoload/global_game_state.gd:129-134` | 存档键**两套推导并存**：正推是 `str(game_mode)+"_"+str(level_page)+"_"+str(level_id)`（`level_id` 默认 `"test"`，`level_data.gd:18`），反推却硬编码 `"%d_%d_%04d"` 并 `int(parts[2])`。`level_id` 不是 4 位数字时两条路对不上 → 进度写进去读不出来 | 收敛成一组 `make_save_key()` / `parse_save_key()` 静态函数 + 一个格式常量，两边共用 |
| **U-22** | A | `src/levels/mode_*` | `save_key` 覆盖率**严重不齐**：`mode_minigame` 20/20、`mode_puzzle` 20/20、`mode_adventure` **4/54**（只有 `adventure_01_01~01_04`）、`mode_survival` **0/15**。其余关卡全靠 `save_key == ""` 时回退旧拼法（`level_data.gd:24`），而旧拼法依赖 `level_id` 在选关页里按按钮顺序发放 —— 顺序一变就整体错位 | 用 `test/scenarios/tool_migrate_save_key.gd` 批量补齐写死，一次性解掉「存档键依赖选关顺序」这颗雷 |
| **U-23** | C | `src/levels/mode_survival/`（15 关） | 同一模式里场景设置**三套写法**：04/09/14 用 `scene_name = SceneSettingRegistry.SCENE_FOG`；泳池/屋顶/夜晚 9 关用旧字段 `game_BG + game_BGM`；01/06/11 三关**什么都没配**（`survival_flag_01_day.gd` 连 `_init()` 都没有） | 15 关统一改 `scene_name`（`apply_scene_setting()` 已支持覆盖），清掉手写 `game_BG` / `game_BGM` |
| **U-24** | C | `src/menus/start_menu/start_menu_option_dialog.gd:20-25,29-41` ↔ `src/ui/ui_main_game_menu/main_game_menu_option_dialog.gd:35-40,51-68` | 两个选项面板**逐行重复**：`music_sound_signal()` 一字不差，`appear_menu()` / `return_button_pressed()` 各写一份；灰色常量 `Color(0.687,0.687,0.687,1.0)` 在 `start_menu_root.gd:10` 与 `main_game_menu_option_dialog.gd:17` 各抄一遍，注释里还互相引用对方 | 抽 `OptionDialogBase`；灰色常量提到 `src/core/consts/` |
| **U-25** | A | `src/ui/card/card_slot/card_slot_norm/card_slot_battle.gd:15-18,26` ↔ `src/levels/mode_minigame/minigame_03_slot_machine_ui.gd:56,77,203,219` | 老虎机关**两本阳光账**：卡槽 `sun_value`(:26) 与老虎机 UI `_sun_value`(:77) **同时订阅 `ADD_SUN_VALUE`**，收阳光两边各加一遍；花钱只扣 UI 那份（:219），卡槽那份不扣 | 老虎机直接读写 `CardSlotController` 的阳光，删掉本地 `_sun_value` |
| **U-26** | C | `src/zombiquarium/zombiquarium_manager.gd:167-183`（`:209` 也是） | 同一个 getter 里两套阳光来源：`_card_slot_battle.sun_value`（挂主游戏）vs `_local_sun`（独立预览），花 / 赚各走一条 if 分支，口径会漂移 | 独立预览时也挂一份 wallet 适配器，删掉 `_local_sun` 分支 |
| **U-27** | C | `src/items/drop_body/zombie_arm1_drop.gd` ↔ `src/items/drop_body/zombie_hand_drop.gd` | 两个文件**逐字相同**（`x_v = randf_range(-15, 15)` / `velocity = Vector2(x_v, 0)` / 同一行注释掉的 `#rotation_speed=randf_range(1.3,2.1)`），复制粘贴产物 | 合并成一个脚本，另一处改参数或改名引用。**2026-10-11 复核后判定「不做」**：两个脚本内容相同但挂在不同节点上（各自的贴图/动画在场景里），合并要改 8 个 `.tscn` 的 `ext_resource` **uid + path 成对替换**（`arm1` = `uid://cj4hccewpwgyv`、`hand` = `uid://33sxeu6n870x`），其中 `zombie_paper` / `zombie_ladder` / `zombie_football` / `zombie_digger` 4 个场景**同时引用了两个脚本**。改错 uid 就是僵尸场景**静默丢脚本**，收益（少 10 行重复）< 风险，留作参考 |
| **U-31** | B | `character_base.gd:245-256`（亡语链）+ 6 个重写点：`plant_cherry_bomb.gd:7` / `plant_jalapeno.gd:7` / `plant_ice_shroom.gd:7` / `plant_doom_shroom.gd:12` / `plant_potato_mine.gd:40` / `zombie_bobsled.gd:64` | 「死亡时效果」散在 6 个角色子类里各写一份：5 个植物是**逐字相同**的 `bomb_component.judge_death_bomb()`，雪橇僵尸是散架放 4 个兵。基类 `death_language()` 是空钩子且**没有「已触发过」的记录** —— 幂等各靠各的（植物侧靠 `BombComponentBase.is_bomb`、僵王侧 `zb_base.gd:124` 靠 `is_death`）。效果逻辑没进组件，违反「角色 = base + 若干组件」的架构主线 | 让 `BombComponentBase` 自己订阅宿主死亡（`component_bomb_base.gd` 已有 `is_auto_bomb_in_death` 开关），子类只留「死了要不要补爆」的导出项；僵尸侧散架同样下沉成组件，或至少在基类补一个 `is_death_language_done` 幂等位 |


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


### 3.4 H 系列：仓库卫生与工程流程（H-01 ~ H-08，现存 7 条；H-05 登记当轮即销项）

> **与前三系列的区别**：U / L / O 三条都是**玩法代码**里的债；H 系列记的是**仓库本身**的债
> —— 版本控制、CI、文档同步、目录卫生、已知失败的回归。
> 来源：2026-10-16 一次针对「项目健康度」的定向体检（文档声称 → 实际实测逐条对账），**不是抽样**。
> 本系列**全部与运行时行为无关**（唯一的例外是 H-08 指向的两条探针），因此**不改代码也不会让游戏出问题**；
> 但它们决定「下一次改动还找不找得到真相」。

| 编号 | 档 | 位置 / 范围 | 现象 | 处理建议 |
| --- | --- | --- | --- | --- |
| **H-01** | B | 仓库根 `.github/`（**不存在**）、`test/check_scripts.ps1`、`test/run_all_scenarios.ps1` | **全仓没有任何 CI 配置**。硬约束 §1-7 要求「交付前跑一次编译门禁」，但没有任何机制保证它真的跑过 —— 唯一的自动化门禁全靠人记得手跑 | 加一条最小 CI（GitHub Actions 或本地 `pre-push` hook）：跑 `check_scripts.ps1`，退出码非 0 即失败。**先只上编译门禁**（秒级、无需窗口）；`run_all_scenarios.ps1` 依赖带窗口的真实 Godot 与用户目录，不适合直接上云端 CI |
| **H-02** | B | git 工作区（2026-10-16 实测快照） | **597 个已跟踪文件被改**（+7272 / −11580）+ **351 个未跟踪文件**（含 90 个新 `.gd`、58 张 png、94 个 `.uid`、10 个 `.tscn`）。未提交内容包含 `mods_builtin/` 下 `netplay` / `pvz2` / `zhaoxiao` / `water_bowl` / `purple_direct_plant` 五个模组，以及整套伤害系统（`src/core/damage/`）。**一次误操作即可能丢失大量进行中的重构** | **本条是唯一「不做就会造成实际损失」的条目**：按主题切分提交（伤害系统 / 各模组 / 文档），先落盘再继续开发。**切分建议**：① 「伤害系统」一笔 = `src/core/damage/` + `src/core/consts/` + 受影响的子弹/炸弹/僵尸实体；② 每个 `mods_builtin/<模组名>` 各一笔（五个模组互不依赖）；③ 文档改动单独一笔。三类之间无互相依赖，可分三次 `git add -p` 完成 |
| **H-03** | C | `AGENTS.md` §1、`架构总览.md` §1 与 §4.1、`project.godot:19-31` | autoload 数量**三处口径不一**：`AGENTS.md` 写 9 个、`架构总览.md` 写 10 个、实际 `project.godot` 是 **11 个**。多出来的 `DamageSystem`（`src/core/damage/damage_system.gd`，全场唯一伤害入口）在两份文档里**完全未记载** | 两份文档统一改为 **11 个**，并把 `DamageSystem` 补进 `架构总览.md` §4.1 单例表；§5 实体层「一帧链路」里补一行伤害管线入口 |
| **H-04** | C | `AGENTS.md` §1、`README.md`、`架构总览.md` §1 与 §15 | 规模数字与实测系统性不符：`src/` 实测 **643 `.gd` + 239 `.tscn`**，文档分别写 615 / 618 / 240；`data/` 实测 **122 `.tres`**，文档写 116；`docs/参考存档/` 实测 **41 份**，`docs/README.md` 写 23、`架构总览.md` 写 29；`test/scenarios/` 实测 **118 个**，文档写 95 / 97 | 写一段脚本按 **§1 统一口径**重新生成后整体替换，并在 §5 加一条「规模数字一律生成、不手写」 |
| **H-06** | C | 仓库根：`'`、`' + $e + '')`、`error_log.txt`、`package.json`、`package-lock.json` | 5 个残留文件：两个终端 stderr 重定向产物（**文件名含非法字符**，连 PowerShell 的 `[IO.Path]::GetExtension()` 都会抛「路径中具有非法字符」，会持续干扰自动化脚本）；`error_log.txt` 1.5 KB；`package.json` 内容就是 `{}`、`package-lock.json` 110 B —— Godot 项目不需要 npm。且 `架构总览.md` §12 第 11 项把 `'` 记为「**已删（2026-10-07）**」，实际仍在（属 H-04 同类漂移） | 删文件 + 把这几条模式加进 `.gitignore`；同步修正 `架构总览.md` §12 第 11 项与 §2 目录树注释 |
| **H-07** | C | `project.godot:15`、`README.md:12`、`架构总览.md:37` | Godot 版本**三处口径不一**：`project.godot` 声明 features `"4.6"`、README 写 4.5.1、架构总览记测试脚本指向 `Godot_v4.6.2-stable_win64.exe` | 统一到实际使用版本，README 写明「需要 Godot 4.6+」；`架构总览.md` 里的历史数字改为指向 `project.godot` |
| **H-08** | A | `test/scenarios/probe_bullet_camp.gd`、`test/scenarios/probe_plant.gd`（现象另见 `架构总览.md` §11.3） | 两条**已知失败**的回归探针长期挂账：① `probe_bullet_camp` 报「僵尸方子弹 `collision_mask = 769`，期望 1281」—— 差的那一位是植物层（1024），**植物僵尸的子弹可能打不到玩家的植物**；② `probe_plant` 在无头下种植未生效（阳光未扣、已种槽位 0，可能只是无头环境限制）。两条都被登记为「已知红探针，非本次改动引入」，此后无人跟进 | ① 先判 `probe_bullet_camp` 是**真 bug 还是探针期望值写错**（对照 `BulletCampConfig` 运行期写层逻辑），若是真 bug 按 A 档修；② `probe_plant` 若确系无头限制，就在探针里写明豁免理由或改成可跑通的判据。**红着的探针会训练人忽略红色**，比没有探针更糟 |

**优先级（据档位与损失风险）**：H-02（先落盘）→ H-01（补门禁）→ H-08（红探针）→ H-06（5 分钟清垃圾）→ H-03 / H-04 / H-07（文档对账，可一轮做完）。

---

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

> 教训：**TODO 销项后记得把指向它的文档也改掉**，否则后来的人会按旧索引去一条不存在的注释（“文档与代码漂移等同 bug”，见 [docs/README.md](./README.md) §6）。

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
