<!-- AGENT-DOC: index -->

# TODO 清单

> **[面向 AI Agent]** ｜ **触发条件**：被安排做清理 / 还债类任务；想找「还能做什么」；有人问「仓库里还剩哪些待办」；删代码前判断某条 TODO 是不是垃圾
> **读完你能**：① 列出当前仓库全部 `TODO` 注释（2 条，§2）及其精确位置；② 列出当前「不统一实现 / 逻辑不全 / 可优化」的架构债（**17 条**：U 系列 12 + L 系列 4 + O 系列 1，见 §3；U-01~U-13 已于 2026-10-11 销项，见 §4）；③ 判断某条 TODO 是「有效待办」还是「可删的痕迹」；④ 知道新增 / 销项一条时改哪里
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

---

## 2. 待办清单（3 条）

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

### 3.1 U 系列：不统一实现 / 重复实现（U-14 ~ U-30，现存 12 条；U-19 / U-21 / U-28 / U-29 / U-30 已销项）

> 来源：2026-10-11 第二轮全仓扫描（U-01 ~ U-13 已销项，去向见 §4）。

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


> U-30 剩余部分（`zombie_boss/doctor/` 与 `zombie_boss/zb_doctor_objects/` 目录前缀不一致）判定**不动**：纯可读性收益、改动面是文件名与 100+ 处引用，与 U-11 的前缀缩写同一处理，留作参考。
>
> **U-14 复核（2026-10-11，未改）**：`host_node_of()` 全仓**只有定义与注释、0 处实际使用**（`character_base.gd:439` /
> `bullet_base.gd:75`），所以改这 6 处等于**首次落地**这套入口。风险点：`owner` 为空（运行期 `add_child()` 挂上去的
> 组件）时它返回 null，而原来的 `$"../X"` 在那个场景里是能取到的 —— 一旦踩中就是「这个角色不动了 / 不播动画了」的**静默 null**。
> → 要做的话**必须开游戏实测**，别当成纯机械替换。

### 3.2 L 系列：逻辑不全 / 未接线（L-01 ~ L-11，现存 4 条；L-01 / L-02 / L-03 / L-05 / L-06 / L-08 / L-11 已销项）

> 与 U 系列的区别：**不是「两种写法」，而是「只有一半」** —— 订阅了没人发、开关恒假、接口是空 `pass`、常量表里写了代码里没有。

| 编号 | 档 | 位置 / 范围 | 现象 | 处理建议 |
| --- | --- | --- | --- | --- |
| **L-04** | B | `src/managers/zombie_manager/zm_hammer_zombie_manager.gd:109,116,121,125,127,195` | 锤僵尸出怪**全用全局随机**：`randi()%3+1` / `idle_tombstones.shuffle()` / `.pick_random()` / `randi_range()` / `randf_range()`；而同类 `zm_zombie_wave_manager.gd:201,204` 走 `src/core/game_rng.gd`。两端随机序列必然岔开 → 联机不可复现 | 统一改 `GameRng.randi_range / pick_random / shuffle` |
| **L-07** | C | `attack_behavior_component/component_attack_bullet_base.gd:86-88`、`component_attack_bullet_split_pea.gd:12-15`、`bomb_component/component_bomb_base.gd:64-69`、`garden/component_garden.gd:132-136` + `component_garden_sprout.gd:7-10` | **空实现当接口**：两个 `set_cancel_attack()` 都是「注释掉两行 `animation_tree.set(...)` + `pass`」；`_start_bomb_fx()` / `_bomb_all_enemy()` 空实现；两个 garden 组件的 `update_growth_stage()` 在 `Sprout` 分支都是 `pass`（`component_garden.gd:135` 连 `Log.debug` 都被注释掉） | 要么实现，要么删掉空钩子 —— 留着会让人以为「已经接完了」 |
| **L-09** | C | `src/ui/main_game_ui/ui_level_progress_provider.gd:18,23` | `on_bind()` / `on_unbind()` 全仓**无任何子类 override**（`ui_level_progress_bar_controller.gd:36,43` 照常调用） | 补默认实现，或删掉这两个空钩子 |
| **L-10** | C | `src/garden/plant_cell_garden.gd:98-100` | `GreenHouse` 分支是裸 `pass` | 补逻辑或改成 `_` 通配，别留空分支 |

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

> 教训：**TODO 销项后记得把指向它的文档也改掉**，否则后来的人会按旧索引去一条不存在的注释（“文档与代码漂移等同 bug”，见 [docs/README.md](./README.md) §6）。

---

## 5. 维护约定

- **新增一条**：
  - **T 系列**（§2，代码注释类）：在 §2 表末尾追加一行，编号顺延（`T-07`…），并把同样的信息写在**代码注释里**（清单与注释双向可见）。
  - **U 系列**（§3.1，不统一 / 重复实现类）：在 §3.1 表末尾追加一行，编号顺延（`U-31`…），写明**两（多）种写法各自的位置**——只写「不统一」不写「在哪两种」等于没记。
  - **L 系列**（§3.2，逻辑不全 / 未接线类）：编号顺延（`L-12`…）。典型形态：只有订阅没有发布的死事件、恒假的开关、空 `pass` 接口、文档里有代码里没有的常量。
  - **O 系列**（§3.3，性能可优化类）：编号顺延（`O-04`…）。只记**有量化理由**的（每帧空转 / 全表线性扫描 / 重复拼接），不要记「看着不顺眼」。
- **销项一条**：T 系列要把代码注释里的 `TODO` 删掉；三个系列都要从原表移到 §4，写清「怎么解决的」。只改代码不改本文 = 清单变脏。
- **重新体检**：每过一段时间（或一次大清理之前）用 §1 的口径全仓库搜一次 `TODO`，命中数与本文不符时以代码为准更新本文。U 系列靠「同一件事搜两种写法、比较命中数」来体检；L 系列靠「搜订阅点与发布点、比较命中数」来体检。
