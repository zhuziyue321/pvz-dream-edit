<!-- AGENT-DOC: index -->

# TODO 清单

> **[面向 AI Agent]** ｜ **触发条件**：被安排做清理 / 还债类任务；想找「还能做什么」；有人问「仓库里还剩哪些待办」；删代码前判断某条 TODO 是不是垃圾
> **读完你能**：① 知道代码里的 `TODO` 注释**已清零**（最后两条 T-01 / T-05 于 2026-10-22 转成正式注释，见 §4 —— 它们是**预留需求线索**，不是没写完）；② 列出当前「不统一实现 / 逻辑不全 / 可优化」的架构债（U / L / O 三系列，见 §3；**条数以 §3 各表实际行数为准，本文不再写死总数** —— 写死必然再次漂移，见 H-05 的教训；其中 U-35 / U-37 / U-40 / L-21 / L-22 来自 §3.7 子弹专项体检 2026-10-16，**U-41 ~ U-43 / L-23 / L-24 来自 §3.8 攻击逻辑专项体检 2026-10-17**；**U-45 ~ U-48 / L-26 ~ L-29 来自 §3.9 老旧代码专项体检 2026-10-22**（专扫「旧实现以注释 / 兼容分支 / 复制粘贴的形式留在现版本里」；**这 8 条已于当日全部销项，处置见 §4**）；同批的 U-36 / U-38 / U-39 / **U-44** 已销项；**U-22（存档键）已于 2026-10-22 销项**，L-25 为同轮新增；U-01~U-13 已于 2026-10-11 销项，见 §4）；③ 知道 **H 系列（仓库卫生与工程流程）H-01 ~ H-09 已于 2026-10-16 全部销项**（逐条处置见 §4），以及 **H-10 ~ H-23（2026-10-16 工程体检新增，含 §3.6 的 H-16；H-18 是 2026-10-22 老旧代码专项 §3.9 跑门禁时附带发现；H-19 ~ H-23 是 2026-10-22 优缺点复查新增，见 §3.10）** 的方向与前置条件；④ 判断某条 TODO 是「有效待办」还是「可删的痕迹」；⑤ 知道新增 / 销项一条时改哪里；⑥ 知道本轮整改的**分批顺序**与每批的验收口径（§6）
> **强制级别**：**参考**（本文件只是一张清单，不是硬约束） ｜ **不读的风险**：把「本实现与原版的差异线索」当垃圾注释删掉；或重复实现已经在某处 TODO 里记过的东西
> **关联**：[项目规范.md](项目规范.md) · [参考存档/未使用代码与资源清单.md](参考存档/未使用代码与资源清单.md) · [../架构总览.md](../架构总览.md)（§12 技术债清单）

---

## 1. 统计口径

> 本文是**全量快照**（2026-10-11 更新：销项 T-02 / T-03 / T-04 / T-06，剩 2 条；同日再销项
> U-19 / U-21 / U-28 / U-29 / U-30、L-01 / L-02 / L-03 / L-05 / L-06 / L-08 / L-11、O-01 / O-03；
> **2026-10-22 更新：T-01 / T-05 转为正式注释 → `TODO` 命中数归零**，同轮销项 U-22、新增 L-25），
> 不是抽样。再生成一次用同一套口径即可复现。

| 口径项 | 取值 | 理由 |
| --- | --- | --- |
| 检索词 | `TODO`（大小写敏感，含 `TODO:` / `TODO：` / `TODO ` 变体） | 项目里的待办习惯统一用 `TODO`；`FIXME` / `HACK` 在 `addons/` 之外无命中 |
| 纳入范围 | `src/` `test/` `data/` `animation/` `shaders/` `tools/` `project.godot` 等自研文件 | 自己写的代码才需要跟进 |
| 排除 `addons/` | ✅ 排除 | 第三方插件，不是本仓库的债。`addons/todo_controller/` 这个名字里带 todo 的插件会把 80+ 处假命中算进来 |
| 排除同名标识符 | ✅ 排除 | `minigame_07_..._star_overlay.gd` 的 `ALPHA_TODO` 常量、`test/scenarios/probe_netplay_session.gd` 的 `client_todo` 局部变量都只是命名，不是待办 |
| 排除 `docs/` | ✅ 排除（本文是它们的汇总） | 文档里提到 TODO 的地方已在 §3 记录，避免「清单套清单」 |

**结果：0 条有效 TODO**（2026-10-22 实测：剩余命中只有「指向本文的交叉引用注释」与 `ALPHA_TODO` 常量，均属上面的排除项）。
T-01 / T-05 两条**没有删**，而是照 T-06 的先例改写成了正式注释（见 §4）—— 它们记的是**预留需求**，删掉就没线索了。
（[架构总览.md](../架构总览.md) §12 第 14 项记的「约 12 处」是历史数字，其中 12 条已销项：历史 6 条 + 2026-10-11 的 4 条 + 2026-10-22 的 2 条。）

> **2026-10-11 第二轮全仓扫描**：本轮不看 `TODO` 关键字，专扫「同一件事多套写法 / 逻辑不全 / 可优化」，
> 新增 **U-14 ~ U-30（17 条）**、**L-01 ~ L-11（11 条）**、**O-01 ~ O-03（3 条）**，见 §3.1 / §3.2 / §3.3。
> 口径：`src/` + `test/` 全量 `.gd`，`addons/` 排除；每条都给了文件:行号，未逐处核实的已在现象里写明。

> **2026-10-16 定向体检（新增 H 系列，同日全部销项）**：本轮**不看玩法代码**，专扫「仓库本身」的健康度 ——
> 把文档里声称的数字 / 状态**逐条与实测对账**（`git status`、文件计数、`.github` 是否存在、根目录残留），
> 开出 **H-01 ~ H-08（8 条）**并**当日全部处理完毕**，逐条处置见 §4。口径：命令直出，不做估算；每条都写清「文档怎么说 vs 实测是多少」。
> 与前三系列不同，H 系列**与运行时行为无关**（唯一例外是 H-08 指向的两条回归探针）。

---

## 2. 待办清单（**0 条**，2026-10-22 清空）

代码里已经**搜不到** `TODO` 字样了。最后两条（T-01 / T-05）**没有删**，而是照 T-06 的先例改写成了正式注释
—— 它们记的是**预留需求**，不是「写崩了」；真删掉，下一个做小推车 / 敌人离场回收的人就没有任何线索了。
两条的去向与改写后的原文见 §4。

> ⚠️ **给后来者**：本节为空 ≠ 仓库没有待办。真正的债在 §3（U / L / O / H 四系列，代码里未必有 `TODO` 标记）。
> 另外别把「指向本文的交叉引用注释」（如 `见 docs/TODO清单.md 的 U-22`）当成待办 —— 那是**说明**，§1 已排除。

---

## 3. 待办清单补编：不统一实现与逻辑不全

> **与 §2 的区别**：§2 是代码里写着 `TODO` 字样的**注释**；本节是**同一件事存在多种写法**、或**逻辑没接完**的架构债，代码里未必有 TODO 标记，因此不会被 §1 的检索词命中。
> 档位 = 风险（**A** 会致数据/行为不一致 · **B** 违反硬约束或架构主线 · **C** 命名与表达 / 参考级）。
> 编号：`U-` = 不统一 / 重复实现，`L-` = 逻辑不全 / 未接线，`O-` = 可优化（性能）。
>
> **2026-10-22 优缺点复查新增 6 条（`U-49` / `H-19` ~ `H-23`）集中在 §3.10**；
> 其中 **H-19（人工回归账本）是后续所有批次的前置** —— 不解决「验过没有」，再改十条也只是把「待实测」越堆越高。

### 3.1 U 系列：不统一实现 / 重复实现（编号到 **U-59**，**U-49 见 §3.10**，**U-50 ~ U-59 见 §3.11**，**U-45 ~ U-48 见 §3.9，已于 2026-10-22 全部销项**；已销项：U-45 / U-46 / U-47 / U-48 /U-19 / U-21 / **U-22** / U-28 / U-29 / U-30 / U-33 / U-36 / U-38 / U-39 / U-44，逐条处置见 §4）

> 来源：2026-10-11 第二轮全仓扫描（U-01 ~ U-13 已销项，去向见 §4）。
> **U-31 来自 2026-10-13 亡语专项复核**（`character_base.gd` 的 `death_language()` 链 + 6 个重写点全量核对）。
> **U-32 来自 2026-10-16 工程体检**（`Global.` 引用面实测，口径 = `src/**/*.gd` 文件数）。
> **U-33 / U-34 来自 2026-10-16 伤害管线与防具专项复核**（同轮新增 L-16 ~ L-20 / O-04，见 §3.2 / §3.3）。

| 编号 | 档 | 位置 / 范围 | 不统一的现象 | 处理建议 |
| --- | --- | --- | --- | --- |
| **U-14** | B | `components/anim_component/component_anim_norm.gd:25`、`component_anim_player.gd:5`、`component_anim_bobsled.gd:4-8`、`attack_behavior_component/component_attack_bullet_base.gd:5`、`charred_component/component_charred_zombie_bobsled.gd:4`、`src/entities/bullet/component/movement/bullet_movement_track.gd:5` | 组件里直接拼宿主相对路径 `$"../AnimationTree"` / `$"../AnimationPlayer"` / `$"../Body"` / `$"../ZombieBobsled1"` —— 宿主结构一改就**静默取到 null**。`character_base.gd:422-439` 与 `bullet_base.gd:66-80` 已提供 `host_node_of(owner, ^"XXX")` 入口（注释原文就是「替代在组件里拼 `$"../XXX"`」），这 6 处没走 | 全部改走 `host_node_of()` |
| **U-15** | B | `attack_behavior_component/component_attack_zom_botany.gd:64`、`component_attack_zom_botany_pea.gd:137`、`zombie_plant_component/component_zombie_plant.gd:66` | 组件间硬编码**兄弟组件 / 宿主子节点名**：`owner.get_node_or_null(^"ZombiePlantComponent")`（2 处）、`owner.get_node_or_null(^"Body/BodyCorrect")`；违反「组件只通过 `owner` / 信号 / 场景配置通信」 | 改 `@export` 场景注入，或走宿主提供的访问器 |
| **U-16** | C | `component_norm_base.gd:90`（空实现）被 12 处各抄一份：`component_sleep.gd:53`、`component_move.gd:85`、`component_magnet.gd:98`、`component_create_sun.gd:76`、`component_create_coin.gd:55`、`bomb_component/component_bomb_jackbox.gd:41`、`attack_behavior_component/component_attack_zombie_norm.gd:27`、`_zombie_zamboni.gd:20`、`_zombie_gargantuar.gd:46` 等 | 「速度同步」12+ 份并行实现，各自算一遍乘积；`anim_component/` 下 `component_anim.gd:70,74` / `component_anim_norm.gd:100,104` / `component_anim_bobsled.gd:17,23` / `component_anim_empty.gd:7,12` 又是 4 份互为复制 | 倍率计算收敛到基类，组件只接收结果 |
| **U-17** | C | `components/zamboni/zamboni_death_bomb.gd:24-33` vs `components/zombie_death_bomb/zombie_death_bomb.gd:8-16` | 两份「死亡爆炸」：`activate_it()` 逐行相同（`reparent(get_sibling_layer())` → 两个 `GPUParticles2D.emitting = true` → `await finished` → `queue_free()`），仅 Zamboni 多一个 `explode()`；**且 Zamboni 只 `await gpu_particles_2d.finished`、漏了 `_2`**（Zombie 版 await 两个）→ 提前 `queue_free()` 会截断第二个粒子的尾巴 | 合并为一份，炸飞做可选开关；补上第二个 `await`。**2026-10-11 已补第二个 `await`**（已核实 `zombie_death_bomb.tscn` 里两个粒子都是 `one_shot = true` / `lifetime = 0.6`，`finished` 必来）。**合并未做** —— 没有 `zamboni_death_bomb.tscn`，两个脚本都挂在 `zombie_death_bomb.tscn` 的实例上由 `zombie_zamboni.tscn` / `zombie_catapult.tscn` 覆写脚本，改成继承要动 `.tscn` 里的脚本覆盖，且 `explode()` 依赖 `$Body`（需确认场景里有没有这个子节点），要开游戏确认 |
| **U-18** | B | `components/swim_box_component/component_swim_box.gd:1` | 放在 `components/` 下却是 `extends Node2D`（不继承 `ComponentNormBase`）—— **U-05 的漏网之鱼**（当时只清了 `drop_body/` `jackson/`）。同文件 `appear_splash()` / `appear_splash_special_pos()` 整段复制，只差一个取位节点 | 接不接入二选一，并在文件头写清理由（照 U-05 的先例）；两个水花函数抽公共 `appear_splash_at(pos_node)`。**2026-10-11：水花已抽公共 `appear_splash_at(pos_node)`（等价改写）；接入与否的理由已写进文件头** —— 关键更正：`ComponentNormBase` 自己就是 `extends Node2D`，所以「因为要 Node2D 才不能接入」这个理由**不成立**，真正的差别只有启用/禁用框架；是否接入属行为变更（走 `component_ready()` + 各路启用因素后，场景连的信号回调还在不在要重判），需开游戏确认 |
| **U-20** | A | `src/levels/core/level_data.gd:35` ↔ `src/core/autoload/global_game_state.gd:129-134` | 存档键**两套推导并存**：正推是 `str(game_mode)+"_"+str(level_page)+"_"+str(level_id)`（`level_id` 默认 `"test"`，`level_data.gd:18`），反推却硬编码 `"%d_%d_%04d"` 并 `int(parts[2])`。`level_id` 不是 4 位数字时两条路对不上 → 进度写进去读不出来 | 收敛成一组 `make_save_key()` / `parse_save_key()` 静态函数 + 一个格式常量，两边共用 |
| **U-23** | C | `src/levels/mode_survival/`（15 关） | 同一模式里场景设置**三套写法**：04/09/14 用 `scene_name = SceneSettingRegistry.SCENE_FOG`；泳池/屋顶/夜晚 9 关用旧字段 `game_BG + game_BGM`；01/06/11 三关**什么都没配**（`survival_flag_01_day.gd` 连 `_init()` 都没有） | 15 关统一改 `scene_name`（`apply_scene_setting()` 已支持覆盖），清掉手写 `game_BG` / `game_BGM` |
| **U-24** | C | `src/menus/start_menu/start_menu_option_dialog.gd:20-25,29-41` ↔ `src/ui/ui_main_game_menu/main_game_menu_option_dialog.gd:35-40,51-68` | 两个选项面板**逐行重复**：`music_sound_signal()` 一字不差，`appear_menu()` / `return_button_pressed()` 各写一份；灰色常量 `Color(0.687,0.687,0.687,1.0)` 在 `start_menu_root.gd:10` 与 `main_game_menu_option_dialog.gd:17` 各抄一遍，注释里还互相引用对方 | 抽 `OptionDialogBase`；灰色常量提到 `src/core/consts/` |
| **U-25** | A | `src/ui/card/card_slot/card_slot_norm/card_slot_battle.gd:15-18,26` ↔ `src/levels/mode_minigame/minigame_03_slot_machine_ui.gd:56,77,203,219` | 老虎机关**两本阳光账**：卡槽 `sun_value`(:26) 与老虎机 UI `_sun_value`(:77) **同时订阅 `ADD_SUN_VALUE`**，收阳光两边各加一遍；花钱只扣 UI 那份（:219），卡槽那份不扣 | 老虎机直接读写 `CardSlotController` 的阳光，删掉本地 `_sun_value` |
| **U-26** | C | `src/zombiquarium/zombiquarium_manager.gd:167-183`（`:209` 也是） | 同一个 getter 里两套阳光来源：`_card_slot_battle.sun_value`（挂主游戏）vs `_local_sun`（独立预览），花 / 赚各走一条 if 分支，口径会漂移 | 独立预览时也挂一份 wallet 适配器，删掉 `_local_sun` 分支 |
| **U-27** | C | `src/items/drop_body/zombie_arm1_drop.gd` ↔ `src/items/drop_body/zombie_hand_drop.gd` | 两个文件**逐字相同**（`x_v = randf_range(-15, 15)` / `velocity = Vector2(x_v, 0)` / 同一行注释掉的 `#rotation_speed=randf_range(1.3,2.1)`），复制粘贴产物 | 合并成一个脚本，另一处改参数或改名引用。**2026-10-11 复核后判定「不做」**：两个脚本内容相同但挂在不同节点上（各自的贴图/动画在场景里），合并要改 8 个 `.tscn` 的 `ext_resource` **uid + path 成对替换**（`arm1` = `uid://cj4hccewpwgyv`、`hand` = `uid://33sxeu6n870x`），其中 `zombie_paper` / `zombie_ladder` / `zombie_football` / `zombie_digger` 4 个场景**同时引用了两个脚本**。改错 uid 就是僵尸场景**静默丢脚本**，收益（少 10 行重复）< 风险，留作参考 |

| **U-32** | C | `src/**/*.gd`（**110 个文件**引用 `Global.`，2026-10-16 实测口径：`Get-ChildItem src -Recurse -Filter *.gd` 中内容命中 `\bGlobal\.` 的文件数） | `Global` 是**唯一**没有边界的单例：跨局持久状态（存档 / 用户 / 配置）与「这一局」的运行期对象（`game_para` / 各类 manager / registry）都从这里取。U-01 已把「当前这一局」的真相源迁到 `GameContext.curr_main_game`（473 处），但 `Global` 一侧**没有配套划边界** —— 于是同一个语义又有两条入口，且新代码默认还是写 `Global.` | 给 `Global` 定一条可判定的边界：**只放跨局持久状态 + 注册表引用**；凡「这一局」的对象一律从 `GameContext` 取。落地方式：① 先列出 `Global` 现有字段并逐个归类（持久 / 本局）；② 本局类字段标记 `@deprecated` 注释并给出 `GameContext` 对应写法；③ 新字段评审时按此判定。**不建议**一次性大改（473 处已有先例，得再开一轮） |
| **U-34** | C | `src/core/damage/damage_info.gd` + `src/core/consts/const_damage.gd` + `components/hp_component/component_hp.gd:73` / `component_hp_zombie.gd:51` | 伤害语汇**表达口径不统一**（四条小债打包）：① `amount` 与 `EFFECT_DAMAGE` 是同一个 key ⇒ `has_effect(EFFECT_DAMAGE)` **恒真**，「包里有没有伤害」与「伤害值是多少」读起来是一回事；② `get_all_hp()` **两处都没写返回类型**，调用方被迫写 `var x: int =`；③ `final_amount` 在「防具吸收并入 ②」（2026-10-16）后语义变糊 —— 现在 = **打本体那部分**（被防具吃光时为 0），而 `DamageResult.hp_loss` 含防具，调试打印容易误读；④ 同一件「本层挨打了」有 `is_hit_this_time`（判定用）与 `is_armor_absorbed`（包内标记）**两处表达** | ② **本轮已修**（两处补 `-> int`）。① ③ ④ 属重构级、**留档不推荐动**：① 拆 key 要动全部发起方；③ 改语义要动 `DamageResult` 消费方；④ 两个标记服务对象不同（一个给 ③ 末端的信号补发判定、一个给 ③ 的放行判定），合并反而互相耦合 |


> U-30 剩余部分（`zombie_boss/doctor/` 与 `zombie_boss/zb_doctor_objects/` 目录前缀不一致）判定**不动**：纯可读性收益、改动面是文件名与 100+ 处引用，与 U-11 的前缀缩写同一处理，留作参考。
>
> **U-14 复核（2026-10-11，未改）**：`host_node_of()` 全仓**只有定义与注释、0 处实际使用**（`character_base.gd:439` /
> `bullet_base.gd:75`），所以改这 6 处等于**首次落地**这套入口。风险点：`owner` 为空（运行期 `add_child()` 挂上去的
> 组件）时它返回 null，而原来的 `$"../X"` 在那个场景里是能取到的 —— 一旦踩中就是「这个角色不动了 / 不播动画了」的**静默 null**。
> → 要做的话**必须开游戏实测**，别当成纯机械替换。

### 3.2 L 系列：逻辑不全 / 未接线（编号到 L-33；**L-31 ~ L-33 来自 2026-10-24 迷你游戏对齐原版专项**，其中 **L-32 / L-33 已于 2026-10-24 未对齐项清零轮销项**，只剩 L-31（Last Stand 阶段间重选种子，结构变更）；**L-26 ~ L-29 见 §3.9，已于 2026-10-22 全部销项**；**L-30 于 2026-10-24 禅境花园全量对齐轮销项**；已销项：L-26 / L-27 / L-28 / L-29 / L-30 / L-32 / L-33 / L-01 / L-02 / L-03 / L-05 / L-06 / L-08 / L-09 / L-10 / L-11 / L-13 / L-14 / L-16 / L-17 / L-22① / L-23，逐条处置见 §4）

> 与 U 系列的区别：**不是「两种写法」，而是「只有一半」** —— 订阅了没人发、开关恒假、接口是空 `pass`、常量表里写了代码里没有。
>
> **L-12 ~ L-15 来自 2026-10-13 亡语专项复核**：`is_can_death_language` 的全部写入点已全量核对，这 4 条是「亡语该关没关 / 该同步没同步」的口子。
> **L-16 ~ L-20 来自 2026-10-16 伤害管线与防具专项复核**（同轮新增 U-33 / U-34 / O-04）。

| 编号 | 档 | 位置 / 范围 | 现象 | 处理建议 |
| --- | --- | --- | --- | --- |
| **L-04** | B | `src/managers/zombie_manager/zm_hammer_zombie_manager.gd:109,116,121,125,127,195` | 锤僵尸出怪**全用全局随机**：`randi()%3+1` / `idle_tombstones.shuffle()` / `.pick_random()` / `randi_range()` / `randf_range()`；而同类 `zm_zombie_wave_manager.gd:201,204` 走 `src/core/game_rng.gd`。两端随机序列必然岔开 → 联机不可复现 | 统一改 `GameRng.randi_range / pick_random / shuffle` |
| **L-07** | C | `attack_behavior_component/component_attack_bullet_base.gd:86-88`、`component_attack_bullet_split_pea.gd:12-15`、`bomb_component/component_bomb_base.gd:64-69`、`garden/component_garden.gd:132-136` + `component_garden_sprout.gd:7-10` | **空实现当接口**：两个 `set_cancel_attack()` 都是「注释掉两行 `animation_tree.set(...)` + `pass`」；`_start_bomb_fx()` / `_bomb_all_enemy()` 空实现；两个 garden 组件的 `update_growth_stage()` 在 `Sprout` 分支都是 `pass`（`component_garden.gd:135` 原本连 `Log.debug` 都被注释掉，2026-10-12 清理调试输出时把那行注释也删了） | 要么实现，要么删掉空钩子 —— 留着会让人以为「已经接完了」 |


| **L-12** | A | `character_base.gd` 基类 `character_death_disappear()`（铺路 / 小推车兜底等「直接消失」路径）原本**没关亡语** → 走基类的植物「直接消失」会跑亡语；不出事纯靠时序兜着（樱桃/毁灭菇种下即自爆、土豆雷未出土 `is_auto_bomb_in_death=false`） | ✅ 2026-10-17 已在基类 `character_death_disappear()` 置 `is_can_death_language = false`（`character_base.gd:369`；僵尸自身版本本已含该开关、未动）；`character_death_not_disappear()`（海草路径）按语义保留可触发亡语。⚠️ **待开游戏实测**（读档清理 `plant_cell.gd:876` / 手套兜底 `hand_component_glove.gd:230` / 爆炸植物自爆亡语） |


| **L-15** | B | `mods_builtin/netplay/`（全目录 0 命中 `death_language` / `is_can_death_language`） | 联机**完全没覆盖亡语**：`netplay_state_sync.gd:889` 用 `hp_loss_to_death(false)` 给客户端补死时，`is_can_death_language` 的状态无从同步。雪橇僵尸这种「死了还要生成单位」的亡语，两端可能对不上（客户端多放 / 少放 4 个雪橇兵） | 补死路径显式带一个「是否触发亡语」的标志，或让客户端补死一律走不触发亡语的分支（补兵改由主机快照下发） |
| **L-18** | C | `components/hp_component/component_hp_zombie.gd` `_collect_armors()` ↔ `entities/character/zombie/zombie_base.gd` `add_armor()` | 防具表是**隐式收集**（`component_ready()` 一次 + `add_armor()` 补一次）。**官方入口已兜住**：`add_armor()` 挂完会自动 `collect_armors()`（`zombie_base.gd:283-287`）。剩余口子只有「绕过 `add_armor()`、运行期自己 `add_child(ArmorComponent)`」—— 这种层**不进 `armor_list`、静默不参与伤害结算** | 低危，**不做**。若要收紧：`HpComponentZombie` 接 `child_entered_tree` 自动重收（引入每次挂节点的开销，收益不匹配）。留档同时**更正登记口径** —— 不是「每次挂防具都要人记得补」，官方入口已经补了 |
| **L-19** | C | `components/damage_modifier_component/component_damage_modifier.gd` ↔ `src/core/damage/damage_system.gd` `_run_modifiers()` | 修饰器链是**全局列表**（`_modifiers` 装全场所有角色的 `DamageModifierComponent`），每次伤害**全量遍历**、由各修饰器自己判 `info.target` 决定管不管 —— 缺「按目标过滤 / 索引」这一层；忘判 `target` 就会**误伤全场**。当前内置 **0 个**修饰器组件，所以既无性能问题也无实例 bug | 参考级，**不做**。要动的话按 `info.target` 在注册时分组建索引、由 `_run_modifiers()` 侧过滤；但「全局生效」本身可能是有意设计（如全局减速场），改前必须先确认语义 |
| **L-20** | C | `mods_builtin/netplay/netplay_state_sync.gd:207-209` | 联机僵尸快照的防具阶段**只带挨打顺序的前两层**（原文「超出的层数不进快照」）—— 三层及以上的防具（模组可叠）在客户端**看不到破损阶段** | 需改快照协议（定长 → 变长数组），涉及两端版本兼容，**留档不做**。本体防具最多两层（一类 + 二类），只有模组叠三层才会撞上 |
| **L-25** | C | `src/levels/core/level_data.gd:9`（`format_version`） | 关卡 V2 的**版本开关只有定义、0 处读取**（2026-10-22 实测：`src/**` 里只命中定义本身与注释）；`probe_save_key` 打印出「`format_version` = 2 的关卡 **0 关**」—— 那 4 关（`adventure_01_01`~`01_04`）的 V2 标记在 `.tres` → `.gd` 迁移时**没跟着迁过来**，而现在也没有代码按它分派 | **别只改数字**（没人读，改成 2 也是假象）。二选一：① 确认 V2 那批字段的读法不再需要版本分派 → **删字段**，连带 `level_data.gd` 顶部「关卡格式版本」那段注释一起处理；② 真要分派 → 先补读取点，再回填 2。2026-10-22 存档键专项（U-22）附带发现 |
| **L-31** | B | `src/levels/mode_minigame/minigame_16_last_stand.gd` | 原版 Last Stand 是「**5 个独立阶段、每撑过一旗（10 波）暂停并重选一次种子**」；本仓库做成一段连续 50 波、**无阶段间重选**。波数（50 / 5 旗）与胜利条件已对齐，但「重选种子」的策略体验缺失 | 若要还原，需波次管理器支持「到旗暂停 → 回选卡 → 带进下一阶段」；属结构变更，**需开游戏实测**坚不可摧。低优先级（当前连续 50 波已可玩） |

> **L-07 复核（2026-10-11，未改，登记时的描述需修正）**：这 5 处空实现**不都是死钩子** ——
> `component_bomb_base._start_bomb_fx()` / `_bomb_all_enemy()` 被 4 个子类重写（norm / jalapeno / jackbox / ice），
> `component_attack_bullet_base.set_cancel_attack()` 被 cactus 重写且有**真实实现**（`ONE_SHOT_REQUEST_FADE_OUT`）。
> 基类留空是**有意的抽象钩子**，删掉反而破坏扩展点。真正「空着没接」的只剩**两处**：
> `component_attack_bullet_split_pea.gd:12-15`（两行 `animation_tree.set(...)` 被注释掉 + `pass`，
> 同文件 `:8-9` 用的就是 `OneShot` / `OneShot 2` 这两个参数名，取消注释大概率能用，但属**视觉行为变更**，要开游戏确认）
> 与 garden 两组件的 `Sprout` 分支 `pass`。

### 3.3 O 系列：可优化（性能，O-01 ~ O-04，现存 1 条；O-01 / O-03 / O-04 已销项）

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

### 3.5 H 系列（续）：H-10 ~ H-23（2026-10-16 工程体检新增；**H-18 见 §3.9；H-19 ~ H-23 见 §3.10**）

> 来源：2026-10-16 一次「项目优缺点体检」——按「架构一致性 / 文档 / 自动化测试 / 内容扩展成本 / 工程流程」五个维度实测，
> **只登记新发现的缺口**；已登记过的（L-12~L-15、U-22、U-31、§12.3 第 9 / 15 项）不重复开条，只在 §6 排批次。
> 格式同 H 系列：**同时写「文档怎么说」与「实测是多少」**，口径一律可复现命令。
> **与 H-01~H-09 的区别**：那 9 条是「仓库卫生」（脏文件 / 数字漂移 / CI 缺位）；这 6 条是**防线与流程强度**（能证明什么、改起来多贵）。
>
> **2026-10-16 当日销项 4 条**：H-10（玩法链路探针）/ H-12（assets 口径 + 检查器新增断言 + 断链）/ H-13（E-09 提交粒度）/ H-15（工作记录主题入口）已做，逐条处置见 §4。
> 本节**只剩 2 条未完成**：H-11（CI 已写未在 runner 验证）/ H-14（接线检查器未写）。按 §5 约定，销项即从本表移走，不留已完成条目（H-17 于 2026-10-17 销项、**H-18 于 2026-10-22 销项**，均见 §4）。

| 编号 | 档 | 文档怎么说 | 实测是多少 | 方向（含前置条件） |
| --- | -- | --- | --- | --- |
| **H-11** | B | 硬约束 §1-7 要求交付前跑门禁；`test/README.md` 说「只做本地钩子（更快、无需 runner）」 | `Test-Path .github` 原为 **False**（无云端 CI）；`git ls-files assets` = **5339**（素材在版本控制内）→ H-01 已更正「assets 不入库所以跑不了 CI」的旧结论，**云端 CI 技术上可行**，当前只是没做 | **已落地一半**（2026-10-16）：新增 `.github/workflows/ci.yml`（编译门禁 + 快子集探针 `probe_init,probe_gameplay_core`；引擎按 `GODOT_VERSION` 从官方 release 下载，找不到 exe 直接抛错而不是静默假绿）。**⚠️ 未完成**：该文件**尚未在 GitHub runner 上实跑过**（本地无法验证 runner 环境）。首推后按文件头「验证方法」三步确认（① 两个 step 全绿；② 故意改坏一个 `.gd` 必须让门禁变红；③ 与本地同 filter 的跑批结果一致），确认后再摘掉文件头警告 + 把本条销项。本地 `pre-push` 保留做快反馈 |
| **H-18** | B | 顶层文档的规模数字（`AGENTS.md` §1、`架构总览.md` §1 / §13 / §15、`docs/README.md` §2.1）；E-08 要求「规模数字只写一处 + 带实测日期」，H-04 / H-17 两轮都对过账 | 2026-10-22 实跑 `tools/check_doc_facts.ps1`（口径 = `git ls-files`，与 H-17 同口径）：`result=FAIL problems=16 / checks=23` —— src `.gd` 643 → **700**、src `.tscn` 239 → **240**、data `.tres` 122 → **123**、docs `.md` 255 → **253**、`test/` `.gd` 127 → **136**、scenarios 119 → **128**、参考存档 43 → **44**、工作记录 202 → **201**；另 `AGENTS.md` 的 assets 计数 claimed=201 / actual=**0**（H-17 那轮为让脚本 PASS 保留的旧数字，现已与实测脱节） | 照 H-17 的做法**只改数字、不改结论**：按实测重写这几处；`AGENTS.md` §1 那句 assets 改成「已无入库文件，资源根已迁至 `pak/`」（**迁移事实别写丢**，那是 H-17 特意保下来的）。⚠️ 改完必须重跑脚本确认 `problems=0`。**本条是 2026-10-22 老旧代码专项（§3.9）跑门禁时顺带发现的**，与代码无关 |
| **H-14** | B | `架构总览.md` §14 列了「新增一个 X 要动哪几处」（植物 7 处 / 僵尸 5 处 / 关卡 4 处）；`levels/` 走 `LevelRegistry`（`src/levels/AGENTS.md`） | ① 选关页**仍是硬引用**：4 个选关页 ~105 条 `.tscn` 按钮引用，`LevelRegistry` 只做了「登记 + 名字校验」，未驱动生成（§12.3 第 9 项）；② `save_key` 覆盖不齐（U-22 重测：adventure 4/54、survival 0/15、minigame 20/25）；③ **漏登记的兜底只有评审** —— §14 是一张**人读的表**，没有任何检查器证明「新单位 7 处都登记了」 | **① 已完成（2026-10-16）**：`tools/check_content_wiring.ps1` 已写，遍历 `PlantIds.ALL` / `ZombieIds.ALL` 校验「注册表数值表有条目 + 场景 preload 文件存在」，缺一项即 exit 1（192 项校验 `result=PASS`）；**注入验证**：把 `plant_pea_shooter_single.tscn` 改名 → 报 `FAIL plant PEA_SHOOTER_SINGLE: scene missing`，改动已还原（`git status` 干净）。已知例外：植物 `WATER_BOWL`（运行期由模组注入的空槽位，故意不在数值表，脚本里显式放行）；僵尸 42 个 ALL id 全部在 `ZOMBIE_INFO` 中。⚠️ 原方向里的「**动画目录存在**」本次**未做** —— 动画目录命名与 id 非简单对应（`puff_shroom` → `plant_puff.tscn`），需先确认约定再补，避免写出假绿检查（H-09 教训）；② 选关页注册表化（视觉配置要靠开窗口比对，单开一轮，**未做**）；③ `save_key` 补齐归 U-22（✅ **2026-10-22 已完成**，155 关已写死，见 §4） |



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
| 缺点：存档键 | 覆盖不齐 + 迁移工具已失效 | **U-22 已销项**（2026-10-22，155 关补齐）；**U-20**（两套推导收敛）仍未做，批次 4 |
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

### 3.7 子弹子系统专项体检（2026-10-16 后续）

> 来源：2026-10-16 一次针对**子弹实现**的定向评审 —— 按「继承链 / 初始化 / 命中判定 / 伤害路径 / 组件化 / 数据驱动」六个面通读，
> 口径 = `src/entities/bullet/`（17 个 `.gd` + 24 个 `.tscn`）+ `bullet_registry.gd` / `bullet_camp_config.gd` /
> `component_attack_bullet_base.gd` 交叉核对。与 §3.6 的区别：§3.6 是**整个项目**的优缺点结论，本节是**子弹这一个子系统**的债。
> 与 §3.6 同样的登记纪律：**已登记过的条目不再重复开条**（`bullet_movement_track.gd:5` 拼宿主相对路径属 **U-14**；
> 子弹对象池暂缓属 `架构总览.md` §12.3 第 16 项），只在 §6 批次 7 排顺序。
>
> **先说清哪些不是债**（避免后来者重复评估）：① **数据驱动程度低**（`data/` 下无子弹 `.tres`，配置全在 `.tscn` 的 `@export`）
> 是**取舍不是缺陷** —— 改数值不用跳两层，代价是模组要改场景，已有 `set_runtime_bullet_stat()` 补口；
> ② **子弹阵营对称设计**（`BulletCampConfig` 全 static + `apply_camp_collision()` 保留额外层）是**做得好的部分**，不动；
> ③ **伤害汇入 `DamageSystem` 管线**（不自己扣血）也是做对的。
>
> **2026-10-16 当日已销项 3 条**（本节登记后立刻按批次 7 的顺序处理 —— 逐条处置见 §4）：U-38（溅射补 `source_node`）、
> U-39（接线检查器覆盖子弹，含注入验证）、U-36（两处重复实现去重）；另 **L-22 的第 ① 条已修**（初始化顺序契约被消除）。
> 按 §5 约定"销项即从原表移走"：L-21 已于 2026-10-24 销项（见 §4），**下表只剩 4 条**：U-35 / U-37 / U-40 / L-22（仅剩 ②）。
> 这 5 条的共同点是**都涉及行为变更**（结构改造 / 判定收口 / 语义确权），所以排在批次 7 尾部，**必须开游戏实测**。

| 编号 | 档 | 位置 / 范围 | 现象 | 处理建议 |
| --- | -- | --- | --- | --- |
| **U-35** | B | `bullet_norm_base.gd:11-37`（状态字段 + `attack_once` / `_attack_enemy`）、`component/spatter_component.gd:1,19-50`、`component/movement/bullet_movement_base.gd:1-9` | 子弹的状态（`attack_value` / `speed` / `direction` / `lane` / `curr_attack_num` / `is_activate_lane` / `max_attack_num`）与伤害结算**都住在宿主** `Bullet000NormBase` 上；子弹自己的两个「组件」`SpatterComponent` / `BulletMovement*` 都是 `extends Node2D` 并**自写 `_ready()`**，不走 `ComponentNormBase`（无 `component_ready()` / 无启用框架），阵营靠手工 `_sync_owner_bullet_camp()` 同步；组件缺失时**运行期 `new()` 补挂**，默认掩码 `9` / `1` 硬编码在 `spatter_component.gd:48-49`，与场景配置形成**两份来源** | 子弹不是角色，硬约束 §1 未覆盖，**可不动**。若要向主线靠分两步：① 掩码默认值收进 `ConstDamage` 级常量（照 U-33 的做法，纯机械）；② 溅射 / 移动组件接入 `ComponentNormBase` —— **属行为变更**，须先开游戏确认「启用框架后场景连的信号回调是否仍在」（同 U-18 的结论） |
| **U-37** | C | `bullet_norm_base.gd:143-164`、`bullet_linear_base.gd:38-48`、`bullet_track_base.gd:104-117`、`bullet_bowling.gd:76-103` | 「这一发能不能打它」的判定**分散在 4 处**：基类（阵营 → 可攻击状态 → 次数 → 行）、直线（先判 `Slope` 再 `super()`）、追踪（按 `target_enemy` 过滤 + 有限 / 无限穿透两分支）、保龄球（**整段重写** `_on_area_2d_attack_area_entered`，自己抄了一遍阵营 + `can_attack` + 行判定，还专门注释了「为何这里不能打 `Log.error`」） | 把「阵营 / 可攻击状态 / 次数 / 行」四连抽成基类 `can_hit_enemy(enemy) -> bool`，追踪与保龄球改成调用它 + 各自附加条件。**属重构**，需逐类型开游戏回归（豌豆 / 仙人掌 / 香蒲 / 保龄球 / 植物僵尸） |
| **U-40** | B | `bullet_base.gd:16-20`（注释自陈）、8 个重写 `_ready()` 的子类（`bowling` / `cactus` / `cob_cannon` / `norm_base` / `parabola_base` / `pea_fire` / `track_base` / `winter_melon`）、`bullet_cob_cannon.gd:13-45` | ① 基类**没有** `_ready()`，8 个子类各写一份 ⇒「入树时要做什么」没有统一入口，`entity_id` 领号因此被迫挪到 `create_bullet()`（L-06 只修过注释，结构未动）；② 演出型子弹把整条时间线（含 3 次 `await`、30+ 行）塞进 `_ready()`，玩法流程与生命周期入口混在一起 | ① 给 `Bullet000Base` 补一个**空 `_ready()`** 作统一入口（子类重写时 `super()` 才有意义），领号不动；② 玉米炮时间线抽成 `play_cannon_animation()` 协程，`_ready()` 只调用它。**① 属结构变更**，须开游戏确认 8 个子类行为不变 |
| **L-22** | B | `component_attack_bullet_base.gd:132-134`（`init_bullet` → `add_child` 顺序）、`attack_once` 覆写链（`pea_snow` / `melon` / `winter_melon` / `pea_fire` / `bowling_bomb` / `parabola` / `track` 共 7 处 `super()`） | 两条**无守卫的隐性契约**，① 已修、② 仍在：① ~~`init_bullet()` **必须早于入树**~~ —— **2026-10-16 已改为「谁用谁取」**（`Bullet000TrackBase._get_detect_component_global()` 懒取），两种顺序都能工作：**契约本身被消除**，而不是"加一道检测"；② `attack_once()` 是覆写链（7 处 `super()`），**漏调 / 顺序颠倒 = 静默少伤害或溅射重复结算**，与 L-17（`process_damage` 忘 `super()`）同类 —— **仍无任何守卫** | ② 的彻底防护依赖 **U-37**（把「阵营 / 可攻击状态 / 次数 / 行」判定与结算收口到基类唯一入口，子类绕不过去，而不是靠"记得调 `super()`"）；探针级验证（寒冰豌豆命中 ⇒ 掉血 + 减速；西瓜命中 ⇒ 溅射目标数）需要进关卡的探针基建（照 `probe_gameplay_core` 的模式另加一节），**单开一轮** |

> **判定不做 / 留档的理由**：U-35（结构改造）、U-37（判定收口）、U-40②（时间线抽取）都属**重构级** ——
> 收益是长期可维护性，风险是**行为变更**（子弹是每局最高频的实体），没有探针兜底前不建议动。
> 它们各自的前置条件见 §6 批次 7：**先补防线（U-39）与契约守卫（L-22），再去重（U-36 / U-38），最后才谈结构**。

### 3.8 攻击逻辑专项体检（2026-10-17）

> 来源：2026-10-17 一次针对**整条攻击链**的定向评审 —— 按「索敌 → 触发 → 结算」三段通读，
> 口径 = `DetectComponent` / `DetectTargetStrategy` + `AttackComponent*`（含子弹基类 / 发射组件 / 僵尸啃食）
> + `DamageSystem` 三步管线与 `Character000Base` 具名受击入口。
> 与 §3.7 的区别：§3.7 只看**子弹本身**；本节看**从索敌到掉血的整条链**（子弹只是其中一段）。
> 登记纪律同 §3.6 / §3.7：**已登记过的一律不重复开条**，只在 §6 批次 8 排顺序 ——
> 「组件拼宿主相对路径」属 **U-14 / U-15**（检查器 **H-16** 已暴露 14 处）；
> 「子弹子类各写 `_ready()` + 领号被迫挪到创建口」属 **U-40**；
> 「子弹内两处取植物重复」属 **U-36**（已销项，仅余「子弹 vs `DetectTargetStrategy` 两套顺序」，`detect_target_strategy.gd:11-13` 已注明刻意不合并）；
> 「伤害模式固定数值分散在两处 `match`」属 **U-33**（数值已集中，合并 `match` 判定不做）；
> 「`DAMAGE_APPLIED` 零订阅方仍付开销」属 **O-04**（已销项）；
> 「亡语链」属 **L-12 ~ L-15 / U-31**。
>
> **先说清哪些不是债**（避免后来者重复评估）：① **唯一伤害入口** `DamageSystem.apply()` +
> 效果包 / 便条模型（通用效果系统施加、特殊效果受击方翻译）是**做得好的部分**，不动；
> ② `AttackComponentBase` 的**攻击资格多因素门控**（`E_IsAttackFactors`）与 `DetectTargetStrategy`（纯 static 选目标策略）
> 也是对的；③ 两条发射触发路径（植物走动画轨道 / 植物僵尸走计时器）**已经由 `shoot_burst()` 收口**，不是债。
>
> **2026-10-17 当日已销项 1 条**：U-44（啃食魔法数，等价改写 —— 逐条处置见 §4）。
> 按 §5「销项即从原表移走」，**下表只剩 3 条**：U-41 / U-43 / L-24。

| 编号 | 档 | 位置 / 范围 | 现象 | 处理建议 |
| --- | -- | --- | --- | --- |
| **U-41** | C | `character_base.gd:387-427`（`be_attacked_bullet` / `be_attacked_hammer` / `be_zombie_eat`）、`zombie_base.gd`（`be_bomb` / `be_chomper_eat` / `be_rake_attack` / `be_squash`） | 「谁打了我」有 **7 个具名入口**，每个各手写一遍 `DamageInfo.create(...)` 与若干字段赋值；僵尸侧 `_apply_penetration_damage()` 只收口了**其中一部分**，另一半仍各自拼包 | 抽出「入口参数表 → 组装包」的一层（一个 `DamageInfo` 工厂 / 参数结构体），或把 cause+mode 的组合登记成表。**属重构**，需逐入口回归（子弹 / 锤子 / 啃食 / 爆炸 / 吞噬 / 碾压 / 钉耙） |

| **U-43** | C | `bullet_norm_base.gd:150,163,177-179`、`component_detect.gd:310-313`、`bullet_camp_config.gd:64-66` | 僵王 `ZB000Base` 的**特判散落在通用层三处**：阵营侧当僵尸（camp_config）、子弹命中**豁免同行限制**（norm_base）、检测侧**不查同行**（detect）—— 同一个「僵王无行概念」的事实写了三遍 | 把「僵尸阵营 + 无行概念 + 受击窗口由状态机控」收敛成 `ZB000Base` 自己的查询口（如 `is_lane_exempt()` / 受击资格方法），通用层只调它、不再 `is ZB000Base`。**属结构改造**，需开游戏回归僵王关 |

| **L-24** | C | `main_game_base.tscn` 的 `%DetectComponentGlobal`（`component_detect.gd:414-416` 注释自陈） | 全局检测组件**仍是植物视角**（只检测僵尸层），所以**僵尸方的追踪子弹索不到植物**；投手 / 直线类不受影响（目标来自发射方自己的 `DetectComponent`） | 真要做僵尸方追踪子弹，先补一个**僵尸视角**的全局检测组件。当前判定为「有需要再做」，**留档**避免后人当成已支持 |

> **判定不做 / 留档的理由**：U-41 / U-43 都属**重构级** —— 收益是长期可维护性，
> 风险是**行为变更**（这三处都是每局高频路径），没有探针兜底前不建议动；
> U-44 已在登记当日做掉（零风险等价改写，见 §4）；L-23 是**已存在的行为不一致**，必须先确权语义再改；
> L-24 是「半边支持」，按需再做。它们的前置条件与顺序见 §6 批次 8。

### 3.9 老旧代码专项体检（2026-10-22）

> **来源**：2026-10-22 一次针对「**老旧代码**」的定向扫描 —— 与前三轮专项的区别：§3.7 看**子弹本身**、§3.8 看**整条攻击链**，
> 本节看的是「**旧实现以注释 / 兼容分支 / 复制粘贴的形式留在现版本里**」 —— 这类东西代码里没有 `TODO` 标记、也不报错，
> 但会让读代码的人把**死掉的旧逻辑**当成现成的东西用（最典型：`zm_zombie_choose_row_system.gd:270-281` 那段注释掉的
> `get_row_probabilities()` **引用了已删除的枚举**，取消注释直接编译失败，可它看起来就像一个现成的工具函数）。
> 口径 = `src/**/*.gd` + 相关 `.tscn` 交叉核对（`addons/` 排除），每条都给了文件:行号并**逐条开文件核实过**。
> **登记纪律同前**：已登记的一律不重复开条（空实现钩子属 **L-07**、组件拼宿主路径属 **U-14 / U-15**、僵王存档三方法属 `架构总览.md` §12.3 第 13 项）。
> **✅ 本节 8 条已于 2026-10-22 当日全部销项**，逐条处置见 §4；下表保留登记时的原文与原难度判断，便于对照（`~~编号~~` = 已销项）。

| 编号 | 档 | 位置 / 范围 | 现象 | 处理建议 |
| --- | -- | --- | --- | --- |
| ~~U-45~~ ✅ | C | `src/entities/character/plant/plant_sun_flower.gd:1-27` ↔ `plant_twin_sun_flower.gd:1-27` | 两个文件**除 `class_name`（`Plant002SunFlower` / `Plant042TwinSunFlower`）外 27 行逐字相同** —— `ready_norm` / `ready_norm_signal_connect` / `_be_zombie_eat_once_special` / `character_death` 四段复制。两者真正的差异（产阳光节奏）**全在场景里 `CreateSunComponent` 的参数上**，脚本本身没做任何区分 | 抽 `PlantSunProducerBase`（或双子直接继承向日葵），子类只留 `class_name` + 差异参数。**等价改写、零行为变更**：编译门禁 + 开游戏确认双子产阳光节奏不变 |
| ~~U-46~~ ✅ | B | `src/garden/garden_manager.gd:152-157`（`const BgPageScenes`） | 「类型 ID → 场景」的映射表写在**业务管理器**里（4 条 `preload`：`bg_00_greenhouse` / `bg_01_mushroom_garden` / `bg_02_aquarium` / `bg_03_tree_of_wisdom`）；而 `SceneRegistry` 里**没有**这四个场景（实测只有 `PLANT_CELL_GARDEN` / `GARDEN_SPEECH_BUBBLE` / `GARDEN_FLOWER_POT` / `STINKY`）⇒ 加第五个花园背景要改这里，形成第二套场景注册入口，与硬约束 §1-4 相悖。**与 U-19（小推车场景表）是同一类问题的第二处** | 四条搬进 `SceneRegistry`（照 U-19 先例），`GardenManager` 只查表。注意 U-19 的坑：`SceneRegistry` 是单例节点、无 `class_name`，`const` 字典里不能写 `SceneRegistry.X`，需照 `goods_garden_tool.gd` 那样降级为 `var` |
| ~~U-47~~ ✅ | C | `src/store/`：`goods.gd:81-94`（基类）+ 9 个子类 | 「购买事务」模板复制 10 份：实测 `get_one_goods()` **10 处定义**、`_refresh_goods_state()` **8 处定义**，每个子类都在自己那份里重做「改全局状态 → `save` → 刷新按钮 → 重判是否售罄」四步。基类 `goods.gd:92-94` 的 `get_one_goods()` 是空 `pass`（有「子类重写」注释，属 L-07 同类的有意钩子）⇒ 漏重写 = 玩家付了钱拿不到东西且零报错 | 把四步收进基类 `get_one_goods()` 模板方法，子类只重写 `_on_goods_granted()`。**涉及存档写入与售罄判定**，需开游戏逐类买一遍（卡槽 / 耙子 / 小推车 / 花园 / 智慧树 / 植物卡 / 坚果急救 …）。顺手给 `src/garden/item/garden_item_base.gd:22` 的 `use_it()` 补一句「子类重写」（它有 8 个子类重写，是钩子，但**连一句注释都没有**） |
| ~~U-48~~ ✅ | C | `src/core/autoload/event_bus.gd:40`（读取点 `:71` / `:455-456`） | 项目里**已经有**一个「调试模式」：控制台 `debug_mode`（`ConsoleBuiltinEntries.DEBUG_MODE_KEY`）→ `GlobalGameState.is_debug_mode` → 解锁调试植物 / 开调试窗口（`global.gd:52` 启动时应用）。`EventBus.debug_mode` 是**另一个同名开关**，语义是「要不要记录被 push 过的事件名」；实测**全仓 0 处置 true**（`.gd` 无赋值、`.tscn` 无覆盖、控制台不写它）⇒ 恒 false ⇒ `get_never_pushed_subscribed_events()`（**死事件检测**，L-01 就是靠它找出来的）永远返回「所有有订阅的事件」，等于没信息 | 二选一：① 改名 `is_trace_pushed_events` 并接到全局调试模式（开调试模式即开，死事件检测重新可用）；② 删掉该开关与 `_pushed_event_names`，死事件检测改由探针在需要时手动开。**不建议放任** —— 同名不同义会让人以为「开了调试模式它就能用」 |
| ~~L-26~~ ✅ | C | 见下方「逐条清单」（7 处整函数级 + 8 处单行级） | **成块被注释掉的旧代码没删**。最危险的三处：① `zm_zombie_choose_row_system.gd:270-281` 整个 `get_row_probabilities()` 被注释，**里面还引用已删除的 `CharacterRegistry.ZombieRowType`**（旧枚举，见 `character_registry.gd:20`），取消注释直接编译失败；② `src/core/utils/image_combiner.gd:21-57` —— 57 行的文件里存着**另一个完整版本**（`extends Node` + `apply_mask_and_save()` + 第二个 `_ready()`，37 行），现版本只有前 20 行在跑，注释里引用的 `res://pak/reanim/CrazyDave_body1.jpg` / `_ .png` **仍在仓**（`.import` 在）⇒ 是旧版工具脚本被注释留下来，不是待实现的需求；③ `component_move.gd:196-197` 注释掉的 `_on_animation_tree_animation_started()`（含 `#_walking_start()`），而同文件 `:192` 的 `_on_animation_finished()` 是活的 ⇒ 走路起止动画的「起」那半边没了 | **逐条判定「删」还是「补注释说清为什么留」**。①②③ 与 `dialog_confirm.gd:22-30` / `zombie_dancer.gd:56-65` 建议**删**（零风险：`get_row_probabilities` 无调用点、image_combiner 那 37 行不参与运行）。⚠️ `ui_remind_word.gd:55-57` 删之前**先确认「红字不灭」是不是有意的**（失败画面可能本就该一直显示）—— 它现在的 `zombie_won_word_appear()` 只亮不灭 |
| ~~L-27~~ ✅ | B | `src/managers/plant_cell_manager/plant_cell_manager.gd:402-406` | 读档路径里 `#clear_all_plant_cell_data()` + 两个 `#await get_tree().process_frame` 被注释掉，但紧邻的 `:403-404` 留着 `### INFO: 等待两帧,queue_free()删除后 …… 若是等待一帧,一局游戏多次读档测试时稳定触发某次植物未删除,不知道为什么`。**即：当初那个 bug 的成因没搞清，补丁被撤了，bug 是否还在没人验证过** —— 本轮唯一一处「注释掉的旧代码可能对应一个未修复的活 bug」 | **先写探针再动注释**：同一局连续读档 N 次，断言「场上植物数 == 存档里格子数」。确认没有残留 → 把那三行 INFO 也删掉或改写成「已确认不再需要」；确认还有 → 恢复补丁并写清成因。**不要只删注释** |
| ~~L-28~~ ✅ | B | `src/entities/character/components/component_move.gd:174-177`（调用点 `zombie_base.gd:608`） | `start_ladder()` 整个函数体是 `if ladder_state != E_LadderState.None: #Log.error("正在爬梯子,无法继续爬梯子")` + `pass`。2026-10-12「清理调试输出」那轮把 `Log.error` 注释了，**没顺手处理 `pass`** ⇒ 这个分支从「报错并拒绝」退化成「**静默什么都不做**」；爬梯子的重复调用保护现在完全失效且零痕迹，调用方拿到的是「看起来成功了」。附带：它与 `zombie_ladder.gd:39` 的 `start_ladder(plant)`（僵尸侧、带参数）**同名不同义**，读代码极易混 | 二选一：① 恢复成 `Log.warn(...)` + `return`（最省，且把「重复调用被拒」这件事重新可见）；② 确认重复调用本就无害 ⇒ 删掉这个分支。**先查 `zombie_base.gd:608` 的调用时序再定**（可能连续触发两次） |
| ~~L-29~~ ✅ | C | `src/mods/mod_manager.gd:309`（`_install_damage_modifiers`）、`:424-425`（`get_mod_dependencies`）、`:546`（卸载修饰器） | 三处都在为 `user://mods/` 下**没跟着升级的旧版 `mod_base`** 做 `has_method()` 兜底。这不是注释垃圾，是**活着的旧实现痕迹** —— 意味着本体永远不能假设 `ModBase` 有新方法，每次给 `ModBase` 加能力都要多写一个兜底分支，且没人知道「还有多少个旧版模组在跑」 | 给旧版 `mod_base` 定一个**淘汰时间点**：先加一行 `Log.warn` 点名是哪个模组还在用旧版（限期升级），到期后整批删掉三个分支。**现在不建议删** —— 会直接让未升级模组崩 |

**L-26 逐条清单**（整函数级 7 处 + 单行级 8 处，均已开文件核实）

| 位置 | 是什么 | 建议 |
| --- | --- | --- |
| `src/managers/zombie_manager/zm_zombie_choose_row_system.gd:270-281` | 整个 `get_row_probabilities()`（12 行），引用已删除的 `CharacterRegistry.ZombieRowType` | 删（无调用点） |
| `src/core/utils/image_combiner.gd:21-57` | 另一个完整版本的脚本（`extends Node` + `apply_mask_and_save()` + 第二个 `_ready()`） | 删（不参与运行，文件本身就是开发用工具） |
| `src/entities/character/components/component_move.gd:196-197` | `_on_animation_tree_animation_started()` + `#_walking_start()` | 删前确认走路动画是否真的不需要「起」事件；不需要就删 |
| `src/ui/dialog_confirm.gd:22-30` | `_center_panel()` 整个 + `#await` / `#_center_panel()` 两行调用 | 删（面板居中已废弃，函数壳无意义） |
| `src/ui/main_game_ui/ui_remind_word.gd:55-57` | 「僵尸获胜」红字的淡出收尾三行 | ⚠️ **先确权**「红字不灭」是否故意，再定删 / 恢复 |
| `src/entities/character/zombie/zombie_dancer.gd:56-65` | 伴舞僵尸「从地下升起」的旧 tween + body/mask 显隐（现只剩 `await zombie_up_from_ground()`） | 删（已被 `zombie_up_from_ground()` 取代） |
| `src/managers/zombie_manager/zm_zombie_wave_create_manager.gd:335` / `src/entities/character/components/component_hurt_box.gd:18` / `src/entities/character/zombie/zombie_gargantuar.gd:74` | 三处**被注释掉的调试打印**（`#prints` / `#print_debug`） | 删（硬约束 §1-6 已生效，不需要留着） |
| 单行残留（风险低，顺手处理即可） | `character_base.gd:346`（旧式 `call_deferred("emit_signal", …)`）、`plant_cell.gd:871-874`（旧 `_input` 鼠标检测，已改用 `get_plant_place_from_mouse_pos()`）、`plant_cell.gd:234` / `:246`、`zombie_base.gd:129` / `:216`、`component_attack_base.gd:10`、`sound_manager.gd:16`、`global_utils.gd:68` | 逐条看一眼，删或改成「为什么留」的正式注释（照 T-01 / T-05 的先例） |

#### 按处理难度排序（从简到难，2026-10-22）

> 与 §6 批次 9 的区别：**批次 9 是依赖顺序**（先做哪条才会让后一条更安全），**本表是难度顺序**（哪条最省力）。
> 想「先拿几个 quick win」就照本表从上往下做；想「不踩坑」就照 §6 批次 9。两条顺序**不一致**是刻意的 ——
> 例如 L-29 技术上最简单，但它被「`user://mods/` 下的旧版模组什么时候升级」这个**外部条件**卡住，排在最后。

| 档 | 编号 | 难度来自哪里 | 验收方式 | 状态 |
| -- | --- | --- | --- | --- |
| **1** | **L-26（整函数级 6 处 + 3 处注释掉的调试打印）** | 纯删注释，**不参与运行**，零行为变更 | 编译门禁 | ✅ **本轮已做**（2026-10-22）：`zm_zombie_choose_row_system` / `image_combiner` / `component_move` / `dialog_confirm` / `zombie_dancer` / `zm_zombie_wave_create_manager` / `component_hurt_box` / `zombie_gargantuar`。删前已确认 `get_row_probabilities` / `_center_panel` **全仓 0 活引用**，且 `.tscn` 里**没有** `animation_started` 信号连到 `component_move` 那个被注释的函数。编译门禁 `real compile errors = 0`（scenarios 150 PASS） |
| **1** | L-26（单行级 8 处 + `ui_remind_word` 确权） | 同样是删注释，但 `ui_remind_word.gd:55-57` 要先确权「红字不灭」是不是故意的 | 编译门禁 | ✅ **完成**：单行级 8 处已删；`ui_remind_word.gd:55-57` 改写成正式注释（写清「红字常亮是刻意的，别照着旧注释加回淡出」） |
| **2** | **U-45** | **等价改写**：两文件除 `class_name` 外逐字相同，抽基类后子类只留 `class_name`；`class_name` 保留所以外部引用不断 | 编译门禁 + 开游戏确认双子产阳光节奏 | ✅ **完成**：新增 `plant_sun_producer_base.gd`，两子类只剩 `class_name`；编译门禁 PASS + 新探针 `probe_sun_producer` `[SUNPRODUCER] result=PASS failed=0`（两株都 `is PlantSunProducerBase`、组件已挂上并启用） |
| **3** | **U-48** | 代码只动 3~5 行，但**先要决策**：接管到全局调试模式，还是删掉开关 | 编译门禁 + 开调试模式看死事件检测有没有数据 | ✅ **完成**：改名 `is_trace_pushed_events` 并跟随 `GlobalGameState.is_debug_mode`；编译门禁 PASS + 新探针 `probe_event_trace` `[EVENTTRACE] result=PASS failed=0` |
| **3** | **L-28** | 代码只动 1~3 行，但**先要查** `zombie_base.gd:608` 的调用时序（会不会连续触发两次）再决定「恢复报错」还是「删分支」 | 编译门禁 + 梯子僵尸关实测 | ✅ **完成**：改成幂等 `return` + 注释说明「重复进入是 Area 多碰撞体的正常现象」；编译门禁 PASS（**梯子僵尸关未开游戏回归**） |
| **4** | **U-46** | 结构收敛：4 条 `preload` 搬进 `SceneRegistry`；有 U-19 的坑（`const` 字典不能引用单例节点，要降级 `var`） | 编译门禁 + 开花园切 4 种背景 | ✅ **完成**：4 条搬进 `SceneRegistry.GARDEN_BG_PAGE_SCENES`；编译门禁 PASS + `probe_garden_bg` `[GARDENBG] result=PASS failed=0` |
| **5** | **U-47** | **改动面最大**：10 个子类改签名，涉及存档写入与售罄判定，漏一个就是「付了钱不发货」 | 编译门禁 + 商店逐类买一遍 | ✅ **完成**：基类新增 `_finish_goods_granted()`，7 个子类收口（2 个差异化子类留原样并写清理由）；编译门禁 PASS + `probe_store_rules` `[STORERULES] result=PASS failed=0`（**顺手修掉该探针一条过时断言**，见 §4） |
| **6** | **L-27** | **先建探针**（同一局连续读档 N 次、断言场上植物数 == 存档格子数），再确权那个 bug 还在不在；成因（`queue_free` 时序）至今没搞清 | 探针 + 编译门禁 | ✅ **完成**：新增 `probe_reload_plant_cells`（同一局连续读档 3 次）`[RELOAD] result=PASS failed=0` ⇒ 那份补丁当前不需要，注释已改写成「线索 + 指探针」 |
| **7** | **L-29** | 技术上是加一行 `Log.warn` 的事，但**被外部阻塞** —— 要等 `user://mods/` 下的旧版模组升级，本体不能单方面删兼容分支 | 先交 `Log.warn` 统计，不删 | ✅ **完成**：`_warn_legacy_mod()` 每个模组只告警一次，两处兜底分支接上；兼容分支保留（等日志清零再删） |

> **本轮已核实「不是债」的部分**（写在这里是为了**下一个人不必重新评估一遍**）：
> ① **裸 `print()` / `printerr()`**：`src/` 下（排除 `logger.gd`、排除 `test/`）**0 处** —— 2026-10-12 那轮清理得很干净，剩下的全是「打印语句被注释掉但没删」（已并入 L-26）。
> ② **Godot 3 风格残留**：`yield(` / `setget` / `export(...)` / `onready var` / `KinematicBody2D` / `Spatial` / `Pool*Array` / `File.new()` / 字符串式 `.connect("signal", …)` 全部 **0 命中**。
> ③ **`uid://`**：`.gd` 里的 `load/preload("uid://…")` **0 处**、`.tscn` 里 `path="uid://…"` **0 处**；但 `.tscn` 的 `metadata/_custom_type_script = "uid://…"` 约 **132 处 / 56 个场景** —— 那是 **Godot 编辑器保存自定义类型脚本引用的标准形式**，不是人写的代码，手工改成 `res://` 也会被编辑器在下一次保存时改回 ⇒ **判定非债**（硬约束 §1-5 管的是业务代码里写的引用）。
> ④ **角色数值写在角色脚本**（如 `zombie_squash.gd:8` 的 `1800`、`zombie_magnet_shroom.gd:14` 的 `9999`）：都是 `@export` **默认值**（可在 `.tscn` 里覆盖），与「写死在逻辑里的魔法数」不同 ⇒ 不登记。
> ⑤ **空实现钩子 40+ 处**（`goods.get_one_goods` / `garden_item_base.use_it` / `component_norm_base.component_ready` / 三个 `init_manager()` / 6 个手持组件钩子 …）：绝大多数是**有意的抽象钩子**（`use_it()` 有 8 个子类重写），与 L-07 同类；唯一值得提的是 `garden_item_base.gd:22` 缺「子类重写」注释，已并入 U-47，**不单开条**。
> ⑥ **关卡目录 158 份 `_init()` / 159 份 `run_flow()`**：是**刻意设计**（关卡脚本承载关卡数据，见 D-07 与 `level_script_base.gd`），不是复制粘贴的债；同一模式内写法不统一的那部分已记在 **U-23**。
> ⑦ **大文件**：`plant_cell.gd`（971 行）已由 `架构总览.md` §12.3 第 15 项评估为「别拆」；`main_game_manager.gd`（821 行）/ `zombie_manager.gd`（754 行）本轮**未评估**，行数大本身不构成债，**留待单开一轮**（不在本节开条）。

---

### 3.10 项目优缺点复查新增（2026-10-22 第三轮）

> **来源**：2026-10-22 一次「项目优缺点」复查，三个输入 —— ① [../架构总览.md](../架构总览.md)；
> ② 本清单 §3.6（2026-10-16 同题体检）；③ 抽样代码（`component_norm_base.gd` / `component_move.gd` /
> `levels/mode_adventure/adventure_01_01.gd`）+ `git ls-files` / `git status` 实测。
> **登记纪律同前**：§3.6 ~ §3.9 已登记过的一律**不重复开条**，只在下方「归属已有条目」表里列一行说明。
> **本轮新增 6 条**：`U-49` / `H-19` / `H-20` / `H-21` / `H-22` / `H-23`（编号按各系列顺延）。

#### 3.10.1 新增条目

| 编号 | 档 | 位置 / 范围 | 现象 | 处理建议 |
| --- | --- | --- | --- | --- |
| **U-49** | C | `src/levels/mode_adventure/adventure_01_01.gd:43` | 注释残留打字：`## 初始化小推车：本关新手教程不走「准备安放植物aaaa」` —— 末尾 `aaaa` 是输入残留。同文件其余注释质量很高（写了「为什么两个信号都接」），属个例 | 删掉 `aaaa`。顺手扫一遍关卡脚本注释里的「重复字符 / 输入法残留」（C 档，纯可读性，不改行为） |
| **H-19** | B | 本清单 §4 与 §6.1 的「⚠️ 需开游戏实测」标记（`L-12` / `L-13` / `L-14` / `U-31` / `L-23` / `L-28` / `U-45` 等） | **「代码改完」与「验证完」之间没有可查询的载体**：销项进 §4 时只写「编译门禁 PASS + 需开游戏实测」，人工回归结论（开没开过、看到什么）没有固定字段 ⇒ 半年后无法判断某条到底验过没有。批次 3（死亡 / 亡语链）自 2026-10-17 起就停在这个状态 | §4 每条加一个固定字段：`人工回归=` 未做 / 已做（日期 + 现象）。或在 `docs/工作记录/` 建一份「待人工回归清单」，销项时必填；本清单只留链接 |
| **H-20** | B | `tools/`（入库 26 个文件，其中 `tmp_*` **17 个**） | ① 一次性脚本与输出**已入库**：`tmp_dump1..7.txt`、`tmp_survey_out.txt`、`tmp_probe_out.txt`、`tmp_unify_anim_tree.py`、`tmp_make_manifest.py` 等 17 个；② `tools/` 下另有 **5 个未跟踪的孤儿 `.uid`**（`_api_test.gd.uid` 等，对应 `.gd` 已不存在）；③ `架构总览.md` §11.2 仍写「3 个离线资源加工脚本」，与实测 26 个入库文件不符 | ① `tmp_*` 全删并补 `.gitignore`（`/tools/tmp_*`）；② 孤儿 `.uid` 删掉（`pre-commit` 已拦入库，但磁盘上还留着）；③ 同步 `架构总览.md` §11.2 口径（改成「离线脚本若干，一次性产物不入库」） |
| **H-21** | B | 当前工作区（2026-10-22 快照） | `git status --short` = **438 项**（289 `M` / 134 `??` / 15 `D`）。E-09 要求「一个逻辑单元一笔」，H-02 曾把 948 个文件切成 4 笔，本轮又回到大块未提交 | 先按「代码 / 文档 / 资源」分堆看 `??` 里有没有该 ignore 的产物，再按逻辑单元提交。**不要 `git add -A`** —— `pre-commit` 只拦危险文件，不拦「一大坨」 |
| **H-22** | C | `docs/` 全部规模数字（E-08 的适用范围） | E-08 要求「规模数字只写一处 + 带实测日期」，但 H-04 → H-17 → H-18 **三轮**都在修同一类漂移（最近一轮 16 处）。根因不是笔误，是**数字靠人抄**；`check_doc_facts.ps1` 只能事后对账，不能生成 | 把顶层文档里的计数改成**脚本生成 / 替换**（`check_doc_facts.ps1` 加 `-Fix`，默认仍是只报不改），人只维护「哪一处该放哪个数」的映射表；映射表本身带日期 |
| **H-23** | C | `pak/`（`git ls-files pak` = **5915**，2026-10-22 实测）+ `mods_builtin/`（入库 270 / 磁盘 2112） | ① 资源根迁到 `pak/` 后仓体量大（近 6 千文件，含大量 `.import` / PNG），clone 与首次 import 成本高；`assets/` / `pak/` 的口径已在 H-17 / H-18 两轮改过；② `mods_builtin/` 磁盘 2112 但**入库仅 270**，差额主要在 `dlc/`（1745 个文件）—— 是「故意不入库」还是「漏提交」目前无说明，clone 后该模组可能缺素材 | ① 先量成本（clone 体积、首次 import 耗时），再决定是否需要 Git LFS 或发布包 / 源码仓分离 —— **没有量化前不要动**，拆仓会改变所有 `res://` 路径语义；② 先确认 `mods_builtin/dlc` 的入库策略，若是有意，补一份「素材来源说明」，否则 clone 即坏 |

#### 3.10.2 归属已有条目（本轮复查确认，**不新开条**）

| 复查到的问题 | 归属 | 为什么不再开条 |
| --- | --- | --- |
| 硬约束 §1-2 在代码里被绕过：`component_move.gd:8` 仍 `get_node_or_null("../Body/BodyCorrect/_ground")`；`host_node_of()` 全仓 0 使用 | **U-14** + 检查器 **H-16** | 两处已登记，H-16 已写「违规清空后再传 `-Strict`」。本轮唯一增量：**实测确认 `check_component_wiring.ps1` 默认仍是报告模式（`exit 0`）**，未接门禁 —— 补进 H-16 状态即可 |
| 隐性契约：`attack_once()` 7 处 `super()`、`process_damage()` 忘 `super()` 会静默不掉血 | **L-22② / L-17** | 已登记；L-22② 的彻底解明确依赖 U-37 |
| 子弹 8 个子类各写一份 `_ready()` | **U-40** | 已登记（结构变更，需开游戏） |
| 速度同步 12+ 份 / 受击入口 7 个 / 命中判定散 4 处 / 僵王特判 3 处 | **U-16 / U-41 / U-37 / U-43** | 均已登记为重构级 |
| `Global` 混装跨局与本局状态（110 个文件引用） | **U-32** | 已登记（参考级） |
| 选关页约 105 条 `.tscn` 硬引用，`LevelRegistry` 只登记不生成 | **H-14②** | 已登记，且写明「需开窗口比对视觉配置，单开一轮」 |
| 探针多但只有 `probe_gameplay_core` 证明「打起来了」；`check_scripts.ps1` 只编译可达脚本 | **H-10**（已销项，边界写在 §4） | 属已知边界，不是新缺口。**但要落一句**：H-19 的「待人工回归」正是这条边界的下游后果 |
| CI 已写但未在 runner 上验证 | **H-11** | 仍在 §3.5 表内 |
| 联机只同步防具两层 / 亡语未覆盖 / 锤僵尸随机不走 `GameRng` | **L-20 / L-15 / L-04** | 均已登记（联机是模组，属参考级） |
| `plant_cell.gd` 921 行 / `main_game_manager.gd` 821 行 / `zombie_manager.gd` 725 行 | `架构总览.md` §12.3 第 15 项（已判定不拆）+ §3.9 附注⑦（后两者「未评估，留待单开一轮」） | 按既有判定**不开条**：行数本身不构成债。要做的是单独一轮评估，不是清单里挂一条 |

---

### 3.11 僵尸 / 植物架构对标专项体检（2026-10-23）

> **来源**：一次「僵尸相对植物在架构上落后在哪」的对标复查。口径 = 只读比对 `src/entities/character/plant/`
> 与 `src/entities/character/zombie/` 两侧的**用法**（框架本身是同一套 `Character000Base` + `ComponentNormBase` + 共享 `components/`，不构成差距）。
> **本轮新增 10 条**：`U-50` ~ `U-59`（编号按 U 系列顺延）；其中 **U-59 是 U-51 的硬前置**（见条目内说明）。
> **2026-10-23 已落地一轮**：**U-50 / U-52 / U-53 / U-56 / U-57 已销项（去向见 §4）**；
> U-51 / U-54 / U-55 部分完成，U-58 判定不动 —— 逐条状态见 **§3.11.1 落地记录**（下方表格保留登记时的原始描述）。
>
> **体检结论（一句话）**：基础设施对称，差异全在**使用方式** —— 植物把能力下沉到组件、宿主只做转发；
> 僵尸把能力留在子类与宿主字段里，于是「按类型特判 / 逐帧轮询 / 直连 manager」三者互相喂养。
>
> **根因（本条最该记住的）**：僵尸的**动画状态仍由 AnimationTree 的 `advance_expression` 每帧读宿主字段自推导**，
> 植物已改成 `anim_component.request_state()` 点名（迁移步骤原样记在 `component_anim_norm.gd:106-113`）。
> 表达式绑着 `is_attack` / `is_swimming` / `is_jumping` ⇒ 这些字段**只能留在宿主** ⇒ 组件拿不到状态 ⇒ 只能靠派生字段与特判兜。
> 所以 **U-59 是 U-51 的前置**，其余条目大多在它下游。
>
> **不登记（判定非债）**，避免后来者重复评估：
> ① **防具系统僵尸反而领先**（`component_armor.gd` 已支持任意层叠挂 + `absorb_priority` + 运行期 `add_armor()`），植物侧才没有这一层，差距方向相反；
> ② **实例化入口僵尸更统一**（`CharacterRegistry.instantiate_zombie():501-514` 是唯一创建口，植物侧走 `PlantCell.create_plant`，无对等物）；
> ③ **热注册两边对称**（`register_runtime_plant` ↔ `register_runtime_zombie`，recipe / kit 头注释互为镜像）；
> ④ **伤害与暂停链路对称**（都走 `apply_damage() → DamageSystem.apply()`，防具在 ② 加工阶段）；
> ⑤ **僵尸子类胖本身**不构成债 —— 载具 / 飞行 / 入水 / 召唤伴舞 / 蹦极抓植物本就没有植物对应物（与 §3.9 附注④⑦ 同一处理）。

| 编号 | 档 | 位置 / 范围 | 现象 | 处理建议 |
| --- | --- | --- | --- | --- |
| **U-51** | B | `zombie_base.gd:69-72`（`curr_be_attack_status`）、`:120-137`（`is_walk` / `is_attack` / `is_bomb_death` / `_judge_is_walk`）、`:40-44`、`:60`、`:125-127`、`:154-156` ↔ `plant_base.gd:52-66` | 状态**本体在宿主**而非组件（违反硬约束 §1-1「状态本体在组件」）。僵尸基类只对 3 个后期补的免疫判断做了只读转发（`:16-31`），其余全是宿主字段 + 就地 setter。三处连带症状：① **双份状态** —— `zombie/zombie_pole_vaulter.gd:7-12` 的 `is_jumping / is_jump_stop / jump_stop_postion` 与 `components/component_jump.gd:24-28` 各存一份；② **抓父结构** —— `zombie_bobsled.gd:69` `var zombie_row: ZombieRow = get_parent()`（基类已提供 `get_sibling_layer()`，`character_base.gd:688-695`）；③ **共享组件被迫读僵尸宿主字段** —— `components/detect_component/detect_target_strategy.gd:66-69,100-101` 出现 `enemy is Zombie000Base and enemy.curr_be_attack_status == ...IsSky` 的单边分支（植物没有「空中」状态，所以这条只对僵尸生效）。植物侧对照：三个状态全是 getter 转发，宿主不存副本 | 状态逐个迁进对应组件（走路 / 攻击 / 跳跃 / 游泳 / 铁器），宿主只留 getter；`get_parent()` 改 `get_sibling_layer()`；`IsSky` 判定改为策略可配置而非 `is Zombie000Base`。**逐组迁移、一组一验**，不要一次改完（每局高频路径） |
| **U-52** | B | `src/entities/character/plant/`（50 个 `plant_*.gd`）↔ `src/entities/character/zombie/`（约 26 个 `zombie_*.gd`） | 能力落点不同：植物把攻击 / 爆炸 / 产阳光 / 掉落 / 检测下沉到共享组件（`attack_behavior_component` 15 个、`bomb_component` 5 个），子类只剩接线 —— 5~15 行的薄子类约 **30 个**（`plant_sun_flower.gd` 5 行、`plant_cherry_bomb.gd` 6 行、`plant_jalapeno.gd` 6 行）；僵尸把载具 / 跳跃 / 投掷 / 蹦极写在子类里，**≥90 行的子类 9 个**（`zombie_bungi_drop.gd` 207、`zombie_jackson.gd` 170、`zombie_catapult.gd` 146、`zombie_bungi.gd` 129、`zombie_zamboni.gd` 111、`zombie_pogo.gd` 109、`zombie_gargantuar.gd` 94、`zombie_dolphinrider.gd` 90、`zombie_bobsled.gd` 90），20 行以下只有 1 个（`zombie_paper.gd` 9） | 按「同一套机制出现第 2 次就抽组件」处理，优先抽 `jump`（已有 `component_jump`，`pogo` / `pole_vaulter` 都该用它）与 `vehicle`（`zamboni` / `catapult` / `bobsled` 共性）。**只在有第 2 个使用者时抽**，不要为单例僵尸造组件 |
| **U-53** | C | `zombie_balloon.gd:14`、`zombie_digger.gd:37`、`zombie_catapult.gd:50`、`zombie_bungi_drop.gd:99`、`zombie_zamboni.gd:39`、`zombie_pogo.gd:38` | 6 个僵尸子类自写 `_process` **逐帧轮询坐标比较**（`global_position.x < digger_target_pos_x` / `<= global_pos_x_can_attack`）来触发状态切换；植物子类目录 `_process` / `_physics_process` **0 处**（全靠 Timer / 信号 / 检测组件） | 换成「到了才发信号」的触发（Timer / `Area2D` / 一次性 tween 回调）。轮询本身不报错，但每帧对全部实例生效，且与 U-51 的宿主状态互相纠缠 |
| **U-54** | C | `src/entities/character/zombie/`（`EventBus.*` **0 命中**）↔ `plant_blover.gd`、`plant_gold_magnet.gd` + 若干共享组件 | 僵尸侧跨系统动作**全部直连 manager**：`zombie_gargantuar.gd:62-68`、`zombie_bobsled.gd:76-82` 等写 `get_main_game().zombie_manager.xxx`。植物侧有 `EventBus` 使用先例。直连让僵尸脚本与 `ZombieManager` 的方法签名强绑，换管理器 / 加联机回放时无中间层 | 只对「跨系统且非本帧时序敏感」的动作（砸车 / 破冰 / 生成伴舞）改走 `EventBus`；**纯父子协作仍走直接调用**（`EventBus` 不是万能胶，见 U-48 的教训） |
| **U-55** | B | `items/lawn_mower/lawn_mower.gd:57`、`items/rake/rake.gd:61`、`components/armor_component/component_armor_newspaper.gd:12`、`_balloon.gd:12`、`zombie/jackson/jackson_manager.gd:78,82,98,134,246`、`jackson_state_machine.gd:18,46`、`managers/zombie_manager/zombie_manager.gd:609`、`zombie_boss/doctor/skills/zb_doctor_skill_bungee.gd:206`、`zombiquarium/zombiquarium_pet.gd:82`；另有 `src/core/autoload/global_utils.gd:218-222`、`zm_zombie_wave_create_manager.gd:168-174`、`zb_doctor_skill_spawn.gd:147,304,320,392` | 按类型特判 **10 文件 / 17 处** `(is|as) Zombie0XX`（植物侧同类 **2 文件 / 3 处**）；外加**注册表外溢的按类型回调表** `get_special_zombie_callable()`（只为蹦极开）+ `ZombieIds.BOBSLED` 独占选行「无冰道则改成生成 ZAMBONI」+ 僵王技能里 4 处冰道特判 —— 这些都是「类型 ID → 行为」的散落映射，与硬约束 §1-4 冲突 | 一处一处收：① 蹦极的 `drop_start_delay` / `bungee_target` 改成僵尸自己的 `@export` / 组件字段（消掉 `zombie_manager.gd:609` 的 `as Zombie021Bungi`）；② 冰道前置条件改成选行策略的**声明式字段**（僵尸声明「我要冰道」）；③ `jackson_manager` 的 5 处随 U-58 一起处理。**别一次全改** —— 每处都要开游戏验 |
| **U-56** | C | `data/character/registry_data/zombie_info_data.gd:7-14`、`src/core/autoload/character_registry.gd:63-68,99-103`、`zombie_base.gd:300-319` ↔ `data/character/plant_condition/condition_plant_base.gd:28-57` + `common_plant_land.tres` | 缺一层**可多态的规则资源**：植物有 `ResourcePlantCondition`（`.tres` 里配 22 位地形掩码等字段、`judge_is_can_plant()` 方法可被子类重写，已有 `condition_lily_pad` / `condition_grave_buster` / `condition_cob_cannon` 等）；僵尸只有 4 值枚举 `ZombieRowType{Land, Pool, Both, None}`，水陆换皮靠 `zombie_base.gd:300-319` **手写遍历**，出怪战力 / 权重另起两张 const 表（`character_registry.gd:99-103`） | 新建 `ResourceZombieCondition`（行规则 / 是否需冰道 / 换皮资源），把枚举 + 手写换皮换成资源字段。**属数据层变更**，要与 `zombie_info_data.gd` 的 123 个既有 `.tres` 口径一起迁，单独一轮 |
| **U-57** | C | `zombie_gargantuar.gd:12,19,21,23,43`、`zombie_digger.gd:7`、`zombie_catapult.gd:9,88` | 不是 `@export` 的**逻辑魔法数**写死在脚本里：`curr_hp <= 1500`（丢小鬼阈值，改不了配置）、投掷 `400 / 200,360 / 350 / -50,50`、`digger_target_pos_x := 88`、`global_pos_x_can_attack := 730`、`update_speed_factor(0.5, ...)`。植物侧对照：`plant_cob_cannon.gd:20` 这类走 `@export`。**另**：同类需求在僵尸侧有**两套写法** —— 防具血量阶段走数据驱动（`ResourceBodyChange` 数组，见 `zombie_cone.tscn:10-26`），冰车 / 投石车走脚本 `match curr_hp_stage`（`zombie_zamboni.gd:52-56`、`zombie_catapult.gd:81-95`） | 阈值改 `@export`（默认值保持现值，**零行为变更**）；血量阶段行为统一到一个落点（照防具那条路）。纯等价改写，适合当本轮第一批 |
| **U-58** | C | `entities/character/state_machine/base/character_state_machine.gd`、`zombie/jackson/jackson_state_machine.gd`、`zombie/jackson/jackson_manager.gd`、`components/dancer_manager_component/component_dancer_manager.gd` | `JacksonStateMachine` `extends Node`（**不是** `extends CharacterStateMachine`），配一份 249 行的 `JacksonManager`，构成舞王 / 伴舞专属的**第二套状态机 + 管理器**；组件层只有一个 315 B 的转发。它是 U-55 里 5 处 `is Zombie009Jackson` 的根源。**注**：U-07 曾判定「有意为之」并补了注释 —— 本条不推翻该判定，只登记**代价**：任何舞王改动都要动这一整套，且它不认识通用机的契约 | **最后做**，且先确权「5 个伴舞共用一份 manager」是否仍然必要。改造量最大、收益最间接；在 U-51 / U-55 落地前不动它 |
| **U-59** | B | 僵尸侧：`zombie_*.tscn` **17 个场景 / 54 处** `advance_expression` 绑定角色字段（`is_attack` 最多，另有 `is_swimming` / `is_jumping` / `is_fail_ladder`，如 `zombie_norm.tscn:1241,1264`、`zombie_pole_vaulter.tscn:1145,1171`、`zombie_ladder.tscn:1211,1277`）；植物侧：`components/anim_component/component_anim_norm.gd:106-113` 的 `request_state()` 点名 | **动画状态驱动差一代 —— 这是 U-51 卡住的真正原因**。植物已把「AnimationTree 表达式每帧读字段自行推导」改成「角色脚本 `request_state()` 点名」（迁移做法原样记在 `component_anim_norm.gd:106-113`：把目标状态那条转换的 `advance_expression` 置空），所以植物宿主**可以完全不存**睡眠 / 受击状态（`plant_base.gd:52-66` 纯 getter 转发）。僵尸仍停在表达式驱动 ⇒ `is_attack` / `is_swimming` / `is_jumping` **必须是宿主属性**，搬进组件则动画机取不到值 ⇒ 状态归位长期被当成「不能做」。**2026-10-23 复核更正**：其实**可以退化成只读 getter 转发** —— 表达式读的是**属性名**，不关心值从哪来（植物侧 `is_sleeping` 就是 getter 转组件）。所以真正的卡点不是「迁不了」，而是「没人做 + 值有多个写入方」 | **两条路，优先级从高到低**：① **只读 getter 转发**（低风险，不动 `.tscn`）—— 在 `zombie_base` 把 `is_attack` / `is_swimming` 改成 `get:` 转发到组件、写入方改成写组件，表达式照旧读同名属性；② 彻底解才是 `component_anim_norm.gd:106-113` 记录的「清空 `<State>` 转换的 `advance_expression` → `request_state()` 点名」，要开游戏逐个看动画（53 处）。**先做 ①，② 按需**。同轮已删掉的 `is_walk` / `_judge_is_walk()` 属于第三条路：**根本没人读，直接删**（全仓 0 读取点，`component_move.gd:4-5` 只在注释里提过它） |

> **U-51 复核（2026-10-23，落地前必读）**：`is_jumping` 的「双份状态」**不是死代码**，而是分层 ——
> 宿主那份是 **AnimationTree 表达式绑定的属性**（`zombie_pole_vaulter.tscn:1171,1183`、
> `zombie_dolphinrider.tscn:1160,1164` 的 `advance_expression = "is_jumping"` / `"not is_jumping"`），
> 逻辑那份在 `component_jump.gd:28`，两者靠 `signal_jump_start` / `signal_jump_end` 同步。
> ⇒ **`is_jumping` 不能搬进组件**，只能在字段注释里写清分工（已在 `zombie_pole_vaulter.gd` 补注）。
> 同轮已删的真死字段：`zombie_pole_vaulter.gd` 的 `is_jump_stop` / `jump_stop_postion`（宿主持有但**全仓 0 读 0 写**，
> 高坚果拦停的真实状态在 `component_jump.gd:24-26`）。**因此 U-51 的剩余范围收窄成两类**：
> ① **真死链条** —— `is_walk` 全仓**只被 `_judge_is_walk()` 写、0 处读取**（`component_move.gd:4-5` 只在注释里提到它），
> 连同 `_judge_is_walk()` 可整体删除，删前确认模组不读；② **被动画表达式绑定的**（`is_attack` / `is_swimming` / `is_jumping`）——
> 搬不了，**必须先做 U-59** 把表达式换成 `request_state()` 点名。`iron_type` / `is_seaweed` 暂无绑定，可直接迁。

#### 3.11.1 落地记录（2026-10-23 第一轮）

| 条目 | 状态 | 落地内容 / 为什么停在这 |
| --- | --- | --- |
| **U-50** | ✅ 完成（销项见 §4） | `zombie_base` 新增 `character_ready()`；`ready_show()` 去重 |
| **U-59** | 🔶 结论更正（**最重要**） | 原判「必须改 54 处 `.tscn`」**是错的**：`advance_expression` 读的是**属性名**，宿主保留同名 getter 就能兼容。真正可行的路是「状态搬进组件 + 宿主只读 getter 转发」（植物 `is_sleeping` 就是这个写法）。同轮删掉了 `is_walk` / `_judge_is_walk()` —— 全仓 0 读取点，纯死链条 |
| **U-51** | 🔶 部分（受阻部分已解除） | 已删：`zombie_pole_vaulter` / `zombie_dolphinrider` 的 `is_jump_stop` / `jump_stop_postion`（0 读 0 写）、`is_walk` 链条。剩余 `is_attack` / `is_swimming` 的 getter 转发未做 —— 需改所有写入方（`change_is_attack` / `change_is_swimming` / 各僵尸子类），属逐字段手术 |
| **U-52** | ✅ 完成 | 新增 `zombie/zombie_jump_base.gd`（`class_name ZombieJumpBase`），撑杆 / 海豚骑士的 `ready_norm` + 4 个跳跃方法 + 信号接线收进基类，子类只留 `_on_jump_start_extra()` / `_on_jump_end_extra()` 两个钩子。**vehicle 组件不抽**：洗冰车 / 投石车 / 雪橇只共用「有 `DeathBomb`」，其余无同构，按「有第 2 个使用者才抽」判定不做 |
| **U-53** | ✅ 完成 | 6 处 `_process` 全部消掉：`MoveComponent` 新增 `watch_position_x()` / `signal_body_x_moved` / `clear_position_watches()`，矿工 / 投石车 / 气球 / 跳跳改注册监听，洗冰车改订阅位移信号扩张冰道；`zombie_bungi_drop` 的 `_process` 改为「有东西要跟才开」（`set_process(false)` 自关） |
| **U-54** | 🔶 部分 | 新增 `ConstEventName.ZOMBIE_SUMMON_REQUESTED`（含 payload 签名）+ `ZombieManager._on_zombie_summon_requested()` 订阅；巨人丢小鬼改走事件。**其余保留直连是刻意的**：`create_skill_bungi` 需要返回实例、砸车 / 破冰是父子协作，按 U-48 的教训不硬套事件总线 |
| **U-55** | 🔶 部分 | ① 蹦极：`ZombieManager._initialize_skill_bungi()` 不再 cast 成 `Zombie021Bungi` 直接改 `plant_cell` / `drop_start_delay` / `bungee_target`，改调僵尸自己的 `apply_skill_summon()`；② 冰道：`zm_zombie_wave_create_manager` 的 `zombie_type == ZombieIds.BOBSLED` 改读 `is_zombie_need_ice_road()`。**剩 jackson 5 处随 U-58**；**防具 2 处（报纸 / 气球）判定保留** —— 防具自己定义特效是本项目既定设计（`component_armor.gd` 文件头），它需要宿主的具体表现字段（`is_gasp` / `is_pop`），强行抽象比 cast 更贵 |
| **U-56** | ✅ 框架完成 | 新增 `data/character/zombie_condition/resource_zombie_condition.gd`（`ResourceZombieCondition`：`row_type` / `require_ice_road` / `body_change_on_pool`）+ `zombie_bobsled_condition.tres`；`CharacterRegistry` 新增 `ZombieInfoAttribute.ZombieCondition`、`get_zombie_condition()`（缺省 null 不报错）、`is_zombie_need_ice_road()`。**未做**：把 `row_type` 从枚举迁到资源（要动 20+ 条 `ZOMBIE_INFO` 与选行系统，单独一轮） |
| **U-57** | ✅ 完成，**登记有误已更正** | 真魔法数只有 3 处，`zombie_gargantuar.gd:43` 的 `1500` → `hp_threshold_throw_imp`、`zombie_catapult` / `zombie_zamboni` 的 `0.5` / `0` → `speed_factor_hp_stage_*`，默认值全部不变。**更正**：登记里写的 `400 / 200,360 / 350 / -50,50`（巨人投掷）、`88`（矿工）、`730`（投石车）**本来就是 `@export`**，按 §3.9 附注④「`@export` 默认值不算债」**不成立**，已从现象里删除 |
| **U-58** | ⏸ 判定不动 | `JacksonStateMachine` 不继承通用机是 U-07 已判定的「有意为之」（5 个伴舞共用一份 manager）。本条只记代价、不要求改；**再动它之前先确权「共用一份 manager 是否仍然必要」** |

> **本轮确实没做的两件**，留在这里而不是含糊过去：① `is_attack` / `is_swimming` 的 getter 转发（U-51 剩余）；② `row_type` 数据化（U-56 剩余）。两者都要动每局高频路径 / 全部僵尸数据，且本轮要求「不开游戏验证」，按 [验证流程](../docs/验证流程.md) 属「必须开游戏」的那一档。

---

## 4. 已销项的历史 TODO（不要按旧文档去找）

这几条曾被 [架构总览.md](../架构总览.md) §12 与 [参考存档/特殊关卡.md](参考存档/特殊关卡.md) 点名，当前代码里**已经没有 `TODO` 字样**（要么实现了，要么改写成了正式注释）：

| 曾经的位置 | 当时记的事 | 现状 |
| --- | --- | --- |
| **L-21** 冰瓜不判 `is_slow_immune` | 寒冰豌豆判了、冰瓜直击 / 溅射都没判（同一个「冰冻减速」三种写法） | 已销项（2026-10-24）：先确权原版 —— `TakeShieldDamage()` 里**不调** `ApplyChill()`，二类防具还举着时不吃减速；据此把冰瓜两处补成与寒冰豌豆同一条判据（判定在伤害结算之后，本发破门会正常上减速）。实测 `probe_winter_melon_slow`：铁门在 → 不减速；打掉门 → 减速 |
| **L-32** 迷阵级联没有额外阳光 | 原版 `mBeghouledMatchesThisMove`：同一次移动第 2 组起每组 +1 颗（clamp 1..5） | 已销项（2026-10-24）：`get_sun_by_chain_len(chain_len, matches_this_move)` 按原版公式实现，`_resolve_matches()` 跨级联累计组数；`probe_beghouled` 新增 STEP2.6 公式断言（3/4/5 连 + 第 2 组 + 封顶） |
| **L-33** 隐形关行限制没实现 | 原版 `INVISIGHOUL && mCurrentWave <= 3 && aRow == 5` 权重归零 | 已销项（2026-10-24）：新增关卡级行限制（`set_banned_spawn_rows()` / 选行系统 `banned_lanes`，兜底也会避开），关卡脚本 `before_wave_spawn()` 按波设置；原版 `<= 3`（0 起算 = 第 1~4 波，C++ 注释写「前 3 波」与代码差一，以代码为准）。实测 `probe_invisi_ghoul_rows`：波 0 禁 / 波 3 仍禁 / 波 4 解除，且实际刷怪最下行 0 只 |
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
| **L-30** 花园植物需求模型 | 会话内计时器，未照原版真实时间戳 / 跨天刷新 | 已销项（2026-10-24 禅境花园全量对齐轮）：`GardenComponent` 改成原版 `GetPlantsNeed` 的实时求值（`last_watered_time` 等四个 unix 时间戳 + `times_fed` / `feedings_per_grow` + 日界字符串比较），成长改回 4 阶（`Large` / `Perfect` 并到 `Full`），满级不再降级、药/留声机改成日常维护。存档新增键与老键兼容见 [参考存档/禅境花园.md](参考存档/禅境花园.md) §8.2 |
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
| **U-33** 伤害模式的固定数值分散在两处 | `ArmorComponent.get_absorb_rule()` 与 `HpComponentZombie.get_body_damage()` 两处 `match`；保龄球 / 锤子固定值硬编码在两边 | 已做（2026-10-16）：① 六个固定值集中到 `ConstDamage.BOWLING_FRONT_ARMOR2` / `BOWLING_FRONT_ARMOR1` / `BOWLING_SIDE_ARMOR2` / `BOWLING_SIDE_ARMOR1` / `BOWLING_BODY` / `HAMMER_ARMOR1`（**逐值等价**，两处 `match` 只改成引用常量）；② `probe_armor_component` 新增 `_check_all_modes_do_damage()` —— 遍历**全部** `E_DamageMode` 打 400 点，断言「总血确实减少」+「`hp_loss` 与实测一致」，漏改任一处即变红（实跑新增 12 项断言全绿）。**未做**：合并两处 `match`（会引入 core → entities 反向依赖） |
| **L-16** 取消整包时结果丢掉防具掉血 | 防具取消 → `DamageResult.canceled()` 不填血量快照 ⇒ 调用方看到的 `hp_loss = 0` | 已修（2026-10-16）：`DamageResult` 新增 `canceled_with_hp(reason, hp_before, hp_after)`；`DamageSystem.apply()` 新增 `_canceled_after_processing()`，把 **Armor / Target / Modifier / ZeroAmount / NoEffect 五处**取消分支统一改成回填血量快照（`NoTarget` / `NoHpComponent` 两处那时还没有血量可读，仍用 `canceled()`）。**探针新增 `_check_cancel_keeps_absorbed_hp()`**：外层普通防具 + 内层免疫爆炸防具，打 Bomb ⇒ `cancel_reason=Armor`、外层 100→70、`result.hp_loss == 30`，实跑全绿 |
| **L-17** 「重写 `process_damage()` 必须 `super()`」没有机制保证 | 防具忘调 `super()` ⇒ 那层**永久不掉血且零报错** | 已做（2026-10-16）：`HpComponentZombie` 新增 `_verify_armor_absorbed()`，在 `process_damage_armors()` 每层调用后做 **debug 期自检**（`OS.is_debug_build()` 门槛）：本层活着 + `amount > 0` + 规则不是 `None`，却 `is_hit_this_time == false` ⇒ `Log.error` 点名宿主与防具。**只报不改**（自动补吸收会双重结算）。实跑两个探针均无该报错（探针内无假阳性）。**据实补正（2026-10-16）**：秒杀路径（`be_attack_to_death()` / `hp_loss_to_death()`，`is_instant_kill`）上该护栏会稳定误报，已加 `if info.is_instant_kill: return`（见 [2026-10-16_防具自检排除秒杀假阳性](工作记录/2026-10-16_防具自检排除秒杀假阳性.md)）。彻底解（模板方法）留待单开一轮 |
| **O-04** 零订阅方仍付事件开销 | 每次伤害无条件 `push_event(DAMAGE_APPLIED)`（含 payload 签名校验 + `event_pushed` 广播），而该事件 **0 订阅方** | 已做（2026-10-16）：`DamageSystem.apply()` 广播前加 `EventBus.has_signal(DAMAGE_APPLIED)` 判断，零订阅方时直接跳过。**零语义变化**（原来也是「发下去没人接」，唯一差别是开 `enable_history` 时看不到这条 —— 已写进代码注释）。实跑 `probe_armor_component`（覆盖伤害链路）确认无回归 |

| **U-38** | 溅射伤害不传 `source_node`（`spatter_component.gd` / `spatter_component_winter_melon.gd`） | 已做（2026-10-16）：两处 `attack_enemy()` 补传 `owner`（= 所属子弹）作伤害载体，与子弹本体 `_attack_zombie` / `_attack_plant` 一致。**零数值变化** —— 已全仓核实 `DamageInfo.source` 当前**无业务读取方**（另一处同名 `source` 在 `console_registry.gd`，无关）。回归：编译门禁 PASS + `probe_gameplay_core` `result=PASS` |
| **U-39** | 子弹「id → 场景」的表手工同步，漏登记只在真的发射时才暴露 | 已做（2026-10-16）：`tools/check_content_wiring.ps1` 新增**子弹段** —— 遍历 `BulletIds.ALL` 校验 `BULLET_SCENE_PATHS` 有条目 + `res://` 场景文件存在，并**反向**校验「表里有、`ALL` 里没有」的孤儿（漏加 `ALL` 常量时 `get_bullet_scenes()` 照常能取，但自检 / 预热扫不到）。健康树 `result=PASS checks=230`（原 192 + 子弹 38 项）。**注入验证**：把表里 `BulletIds.STAR` 改成未定义的 `BulletIds.STARZZ` → 同时报 `FAIL bullet STAR: not registered in data table` 与 `FAIL bullet STARZZ: in BULLET_SCENE_PATHS but not in BulletIds.ALL`、`EXIT=1`，已还原（`git diff` 该文件为空）。**踩坑**：编辑脚本后**立刻**执行会读到尚未落盘的旧内容，表现为 `checks=0` 的假象（与 H-08「跑批前先杀残留进程」同类）；跑前 `Start-Sleep` 或先 `Get-FileHash` 对一次即可排除 |
| **U-36** | `get_first_be_hit_plant_in_cell()` 两份逐行同构 + `z_index = lane * 50 + 45` 两处硬编码 | 已做（2026-10-16）：① 取法合并到 `Bullet000NormBase.get_plant_in_cell_by_order(plant, order)`，直线 / 抛物线各留一个 `const BE_HIT_PLANT_ORDER`（**顺序逐项保持原样**：直线 Shell→Norm→Down、抛物线 Norm→Shell→Down）；② 公式抽成 `Bullet000Base.z_index_of_lane(lane)`（static），`norm_base.init_bullet()` 与 `bowling.update_z_index_and_lane()` 改为引用。**等价改写**，验证：编译门禁 `real compile errors = 0` + `probe_gameplay_core`（豌豆掉血 270 → 250，`result=PASS`） |
| **L-22 ①** | 「`init_bullet()` 必须早于入树」这条隐性契约（先 `add_child` 再 init 就静默索不到敌） | 已做（2026-10-16）：**没有**照 L-17 加"检测违反"的自检，而是**消除契约** —— `Bullet000TrackBase` 新增 `_get_detect_component_global()` 懒取（谁用谁取），`init_bullet()` 与 `_ready()` 都走它，两种顺序都能工作。零误报（自检方案会误伤"直接实例化子弹场景"的探针，如 `probe_bullet_camp`）。回归：编译门禁 PASS + `probe_bullet_camp`（17 项 OK）+ `probe_gameplay_core` PASS。**② 仍在表内**（`attack_once` 覆写链无守卫，彻底解依赖 U-37） |
| **U-44** | 啃食结算的魔法数 `8`（`component_attack_zombie_norm.gd`，2026-10-17 攻击逻辑专项体检 / §3.8） | 已做（2026-10-17）：把 `wrapi(frame_counter + 1, 0, 8)` 与 `curr_attack_value_per_min * delta * 8`（该字段 2026-10-23 已改名 `curr_attack_value_per_sec`）两个裸 `8` 提成 `const EAT_SETTLE_FRAME_INTERVAL := 8`，并写清「每 N 帧把这 N 帧累积的伤害一次性结算、`wrapi` 周期与 `delta * N` 必须同源」。**等价改写**（数值与帧序不变）。验证：编译门禁 `real compile errors = 0`（scenarios 120 PASS） |
| **H-17** | ✅ 已完成（2026-10-17）：顶层文档数字对账——`tools/check_doc_facts.ps1` 原 8 项 FAIL（assets 计数、AGENTS.md / 架构总览 docs .md、scenarios、§15 test .gd、§13 标题 / 工作记录、docs/README 参考存档）全部按 `git ls-files` 实测值重写；`AGENTS.md` §1 写清「资源根已迁至 `pak/`（5883），`assets/` 仅残留 201」，保留 `git ls-files assets` = 201 使脚本仍 PASS，未把迁移事实写丢 | 重跑脚本 `result=PASS`（checks=23 problems=0） |
| **L-09** | ✅ 已完成（2026-10-17）：删除 `ui_level_progress_provider.gd` 无子类 override 的两个空钩子 `on_bind()` / `on_unbind()` 及 `ui_level_progress_bar_controller.gd` 两处调用；全仓搜索确认无第三方调用点 | 编译门禁 `real compile errors = 0`（scenarios 120 PASS） |
| **L-10** | ✅ 已完成（2026-10-17）：删除 `plant_cell_garden.gd` 禅境花园 `GreenHouse` 裸 `pass` 分支（温室本就无特殊花盆处理，删后等价；`match` 仍有 MushroomGraden / Aquarium 两分支处理水陆） | 编译门禁 `real compile errors = 0`（scenarios 120 PASS） |
| **U-42** | ✅ 已完成（2026-10-17）：`component_detect.gd` 的 `judge_is_have_enemy` / `update_first_enemy` / `get_all_enemy_can_be_attacked` 三段同构遍历抽成公共迭代器 `_for_each_overlapping_area(cb)` + 三个具名回调（避开高频路径每帧分配 lambda），可攻击判定仍集中在 `_judge_enemy_is_can_be_attack`，语义不变 | 编译门禁 `real compile errors = 0`（scenarios 120 PASS）+ `probe_gameplay_core` `[GAMEPLAY] result=PASS failed=0`（豌豆×普僵索敌→开火→掉血 270→250→死亡信号→尸体离场）+ `probe_bullet_camp` `[BULLETCAMP] result=PASS failed=0` |
| **L-23** | ✅ 已完成（2026-10-17）：`character_base.gd` 的 `be_attacked_bullet()` 改成 `if result.is_applied: be_hit_light()` —— 被防具 / 修饰器 / 本体整包取消（`result.is_applied == false`）时不闪受击白光，表现落在「确实造成伤害」之后，符合 §5「表现放③末端」 | 编译门禁 `real compile errors = 0`（scenarios 120 PASS）；⚠️ **行为变更**，需开游戏回归（举起防具的僵尸被豌豆打，确认白光消失符合预期） |
| **L-13** | ✅ 已完成（2026-10-17）：`character_base.gd` `character_death()` 把 `death_language()` 挪到 `signal_character_death.emit()` **之前**；`zombie_manager.gd` `_on_zombie_dead()` 把 `BATTLE_FINISHED` 判定改 `call_deferred` 到帧末（新增 `_check_end_wave_finished`），让亡语 `call_deferred` 创建的衍生单位（雪橇补兵）先入列再判本轮清空 | 编译门禁 `real compile errors = 0`（scenarios 120 PASS）+ `probe_gameplay_core` `[GAMEPLAY] result=PASS failed=0`（基础死亡链不回归）；⚠️ **时序变更**，需开游戏回归雪橇关，确认补兵被算入本轮战斗 |
| **L-14** | ✅ 已完成（2026-10-17）：`zombie_base.gd` 四个必杀入口（`be_bomb` / `be_chomper_eat` / `be_rake_attack` / `be_squash`）的 `set_deferred("is_can_death_language", true)` 改为显式 `if not is_death: is_can_death_language = true`，消除「对已 `queue_free` 对象写属性」所依赖的「MessageQueue flush 早于删除队列」脆弱假设 | 编译门禁 `real compile errors = 0`（scenarios 120 PASS）；⚠️ 需开游戏回归确认必杀类死亡（樱桃/毁灭菇/倭瓜/大嘴花）亡语表现正常 |
| **U-31** | ✅ 已完成（2026-10-17）：爆炸植物的「死亡引爆」从 5 个子类各自的 `death_language()` 下沉到 `character_base.gd` 默认实现（按唯一名 `^"BombComponent"` 取组件并 `judge_death_bomb()`）；删除 `plant_cherry_bomb / jalapeno / ice_shroom / doom_shroom / potato_mine` 的重复重写，雪橇僵尸保留自己的散架逻辑。仍受 `is_can_death_language` 守卫（`judge_death_bomb` 自带 `is_auto_bomb_in_death` 检查，如土豆雷未出土不炸），行为等价 | 编译门禁 `real compile errors = 0`（scenarios 120 PASS）；⚠️ 需开游戏回归（种樱桃/毁灭菇/土豆雷出土自爆/寒冰菇）确认爆炸触发与 `signal_bomb_once` 下游（如毁灭菇 crater）仍正常 |
| **T-01** | ✅ 已销项（2026-10-22）：`main_game_manager.gd:203` 的 `##TODO:可能会用于检测敌人离开场景后删除` 改写成正式注释 —— 写明「预留**将来**用它检测敌人离开场景并回收，**现在没有**这个逻辑」+「它对应 `main_game_base.tscn` 里的 `%DetectComponentGlobal`，删字段要连场景一起改」。**没删字段、也没去实现** —— 它记的是预留需求，不是没写完 | 纯注释改写，零行为变更；编译门禁 PASS |
| **T-05** | ✅ 已销项（2026-10-22）：`zombie_base.gd:424` 的 `## 死亡不消失(海草\TODO:小推车)` 改写成正式注释 —— 写明「当前只有**海草**走这条路径，**小推车（迷你游戏）将来也该走这里**，这是明确的预留需求，不是没接完」 | 纯注释改写，零行为变更；编译门禁 PASS |
| **U-22** | ✅ 已完成（2026-10-22）：**先修工具、再迁数据**。① `tool_write_save_keys.gd` 的两处硬伤修好：写入目标从 `.tres` 的 `[resource]` 段改成 `.gd` 里 `save_key = "..."` 那一行（有则替换 / 有 `_init()` 则插入 / 都没有则新建 `_init()`）；路径来源从 `para.resource_path` 改成 `ChooseLevelButton.level_script.resource_path` —— 按钮上的关卡数据是 `level_script.new()` 出来的**实例**，它的 `resource_path` 恒为**空串**，旧写法一列路径都取不到。② **冒险模式没有选关界面**（`MainSceneRegistry.MainScenesMap` 里 101 是「故意不登记场景」的 id），工具照原样跑对它 0 覆盖 —— 新增一段走 `GlobalGameState.get_adventure_save_game_name(序号)`（正是运行时那条式子，不依赖遍历顺序）。③ 补齐 **155 关**（冒险 50 关 × 正本 / 二周目变体 + 迷你 / 解密 / 生存 55 关），**只写 `save_key`，没动 `format_version`** | 编译门禁 `real compile errors = 0`；`probe_save_key` 另起进程回读 `result=PASS failed=0`；`probe_level_registry_order` / `probe_gameplay_core` 均 PASS。**两个踩坑**：① 新建 `_init()` 时插在 `@warning_ignore` 之后会把原函数的注解抢走（`survival_flag_01_day.gd` 中招）→ 改成**跨过紧邻的 `@` 注解行**再插；② **迷你 / 解密有 28 关的写死值与「当前遍历顺序拼出的值」本来就不一致** —— 那是既有事实，**写死值才是权威**（玩家存档里用的就是它），探针拿当前拼法去比对会误报，已改成只查非空 + 记 INFO。同轮发现的新债见 **L-25** |
| **L-26** | ✅ 已完成（2026-10-22）：**整函数级 6 处**（`zm_zombie_choose_row_system` 的 `get_row_probabilities` / `image_combiner` 的 37 行旧脚本 / `component_move` 的 `_on_animation_tree_animation_started` / `dialog_confirm` 的 `_center_panel` / `zombie_dancer` 的旧 tween / `ui_remind_word` 的淡出三行）+ **3 处注释掉的调试打印**（`zm_zombie_wave_create_manager:335` / `component_hurt_box:18` / `zombie_gargantuar:74`）+ **单行级 8 处**（`character_base:346`、`plant_cell` 4 处、`zombie_base:129/216`、`component_attack_base:10`、`sound_manager:16`、`global_utils:68`、`ui_flag_progress_bar:35`、`fog:5`、`pool_cleaner:15/17`、`garden_item_08_wheel_barrow:8`、`plant_cell_garden:70/84`、`zombie_drop_base:89-91`、`brain_on_zombie_mode:29`、`jackson_state_machine:150`、`component_create_sun:49`、`component_create_coin:23`、`bullet_linear_base:41`、`roof_cleaner:11`）全部删除或改写成正式注释。**删前逐个核实**：`get_row_probabilities` / `_center_panel` 全仓 0 活引用，`.tscn` 里没有 `animation_started` 信号连到 `component_move` 那个被注释的函数 | 编译门禁 `real compile errors = 0`（scenarios 153 PASS）；纯删注释，零行为变更 |
| **U-45** | ✅ 已完成（2026-10-22）：新增 `src/entities/character/plant/plant_sun_producer_base.gd`（`class_name PlantSunProducerBase extends Plant000Base`），`plant_sun_flower.gd` / `plant_twin_sun_flower.gd` 从「27 行逐字相同的两份」缩成只剩 `class_name` + 说明注释 | 编译门禁 PASS + **新探针 `probe_sun_producer`** `[SUNPRODUCER] result=PASS failed=0`（向日葵 / 双子都 `is PlantSunProducerBase`、`create_sun_component` 挂上且 `is_enabling=true` —— 这正是「`@onready` 挪到基类」唯一的真实风险）。⚠️ 产阳光**节奏**未变（在场景参数里），未开游戏看画面 |
| **U-46** | ✅ 已完成（2026-10-22）：4 条 `preload` 从 `GardenManager.BgPageScenes` 搬进 `SceneRegistry.GARDEN_BG_PAGE_SCENES`（`const` 字典，键写 `GardenManager.E_GardenBgType.X` —— `class_name` 枚举成员是编译期常量，编译门禁已验证），`GardenManager` 只查表 | 编译门禁 PASS + `probe_garden_bg` `[GARDENBG] result=PASS failed=0`（拥有 / 未拥有翻页、自动纠正 3 步全绿） |
| **U-47** | ✅ 已完成（2026-10-22）：基类 `Goods` 新增 `_finish_goods_granted(is_save)`（落盘 → 刷新售罄态 → 重判能否购买）+ `_refresh_goods_state()` 空钩子（有注释）；**7 个子类**收口成一行调用（`garden_tree` / `garden_bg` / `garden_tool` / `lawn_mover` / `rake` / `plant_card` / `wall_nut_first_aid`），失败分支传 `false`。**2 个不套模板**并写清理由：`goods_card_slot`（中间要重建戴夫台词）、`goods_garden_sprout`（售罄态由 `judge_can_get_goods()` 双向刷新，不该再调 refresh）| 编译门禁 PASS + `probe_store_rules` `[STORERULES] result=PASS failed=0`（售价 / 售罄 / 存档 / 限购 / 分页全绿）。**同轮修掉该探针一条过时断言**：原写「花园行只有 3 件」，蜗牛挪进这一行后变成 4 件 → 假红；改为「花园行里没有 `GreenHouse` 背景商品」，不再写死件数（E-07 归因：探针过时，不是代码 bug） |
| **U-48** | ✅ 已完成（2026-10-22）：`EventBus.debug_mode` → `is_trace_pushed_events`（getter 跟随 `GlobalGameState.is_debug_mode`，零额外开销，只多一次字段读 + null 判断）；注释写清「同名不同义」为什么危险。**语义变更**：以前恒 false，现在开控制台「调试模式」就真的开始记录，`get_never_pushed_subscribed_events()`（死事件检测）重新可用 | 编译门禁 PASS + **新探针 `probe_event_trace`** `[EVENTTRACE] result=PASS failed=0`（初值跟随 / 开则记录 / 关则停 / 结束还原） |
| **L-27** | ✅ 已完成（2026-10-22）：**先建探针再定**。新增 `test/scenarios/probe_reload_plant_cells.gd`（种 3 株 → 取内存快照 → 同一局连续读档 3 次 → 每次断言场上植物数恒为 3）→ `[RELOAD] result=PASS failed=0`（无残留、无丢失）⇒ 那份「先 clear + 等两帧」的补丁**当前不需要**。代码里把它改写成正式说明（含「探针只覆盖普通植物 × 前院白天」的边界 + 「将来出问题先跑探针」），不再是一段被注释掉的代码 | 探针 `[RELOAD] result=PASS failed=0` + 编译门禁 PASS |
| **L-28** | ✅ 已完成（2026-10-22）：`component_move.start_ladder()` 的「注释掉的 `Log.error` + `pass`」改成幂等 `return` + 注释说明「僵尸身上多个受击 Area 会让梯子检测区对同一只僵尸多次触发，重复进入是正常现象，不能报错刷屏、也不能重置已累计的爬升偏移」 | 编译门禁 PASS。⚠️ **梯子僵尸关未开游戏回归**（行为等价：原来也是忽略，只多了注释） |
| **L-29** | ✅ 已完成（2026-10-22）：新增 `_legacy_mod_warned` + `_warn_legacy_mod()`（每个模组只告警一次，点名模组 id / 名字），接在 `_install` 与卸载两处 `has_method()` 兜底分支的 else 上。**兼容分支本身保留** —— 等日志里这条 warn 不再出现，才能整批删（现在删会让未升级模组崩）| 编译门禁 PASS；本地无 `user://mods/` 旧版模组，未触发告警（属预期） |
| **H-18** | ✅ 已完成（2026-10-22）：按 `tools/check_doc_facts.ps1` 的实测值（口径 = `git ls-files`）重写顶层文档数字 —— `AGENTS.md` §1（src 700 `.gd` / 240 `.tscn`、data 123 `.tres`、docs 253 `.md`）、`架构总览.md` §1 / §2 目录树 / §11.3 / §13 标题 + 表 / §15 整表、`docs/README.md` §2.1 参考存档 44。**assets 口径**：`git ls-files assets` 实测已是 **0**，`AGENTS.md` 原写 201，改成「已无入库文件，资源根已全部迁至 `pak/`」—— 迁移事实保留（H-17 的教训） | `tools/check_doc_facts.ps1` → `checks=23 problems=0 result=PASS` |
| **U-50** | ✅ 已完成（2026-10-23）：`zombie_base.gd` 新增 `character_ready()`，把「与 `character_init_type` 无关」的 6 件初始化从 `ready_norm()` 上提 —— 小僵尸缩放 / 隐形、`ZombieButterUtil.find_head_node`、`curr_be_attack_status = init_be_attack_status`、`is_attack_ladder_plant` 赋值、`build_runtime_parts()`、`activate_armor_effects()`；`ready_norm()` 只留「斜面 Y 修正」（依赖 `main_game`，出战态语义）与「两栖换皮」（依赖 `init_zombie` 设好的行，展示态没有「行」）；`ready_show()` 里重复的 `build_runtime_parts()` 删除（重复调会把热注册防具挂两遍） | 编译门禁 `real compile errors = 0`（scenarios 154 PASS）。**行为变化**：展示态（图鉴 / 开局预览）现在也有 `head_node` 与初始受击状态，且热注册防具会在展示态触发 `on_armor_equip`（原来只挂不激活）。⚠️ **人工回归=未做**（跑批被占用：`run_autopilot.ps1` 检出 1 个运行中的 godot 进程 pid 2124，未强杀）：需开游戏看图鉴 / 开局预览的僵尸外观正常、热注册防具在展示态可见，以及普通出战僵尸入场（隐形 / 小僵尸 / 两栖换皮 / 入场音效）无回归 |
| **U-51（部分）** | 🔶 部分完成（2026-10-23）：删掉 `zombie_base` 的 `is_walk` / `_judge_is_walk()`（全仓 **0 读取点**，纯死链条，连 `zombie_base.tscn` 的序列化值一起删）、`zombie_pole_vaulter` / `zombie_dolphinrider` 的 `is_jump_stop` / `jump_stop_postion`（0 读 0 写）；给 `is_jumping` / `is_attack` / `is_swimming` 补注释写清「AnimationTree 表达式绑定，**不许挪进组件**」。剩余（`is_attack` / `is_swimming` 的 getter 转发）见 §3.11.1 | 编译门禁 `real compile errors = 0`（scenarios 154 PASS）；删的都是无引用字段，零行为变更 |
| **U-52** | ✅ 已完成（2026-10-23）：新增 `src/entities/character/zombie/zombie_jump_base.gd`（`class_name ZombieJumpBase extends Zombie000Base`），撑杆僵尸 / 海豚骑士僵尸的 `ready_norm` / `ready_norm_signal_connect` / `jump_start` / `jump_end` / `jump_end_end` / `jump_be_stop` 收进基类，子类只剩 `_on_jump_start_extra()` / `_on_jump_end_extra()` 两个钩子；`zombie_pole_vaulter.gd` 从 58 行降到 21 行、`zombie_dolphinrider.gd` 从 90 行降到 46 行。**没抽 vehicle 组件**：洗冰车 / 投石车 / 雪橇只共用「带 `DeathBomb`」，其余无同构，按「有第 2 个使用者才抽」判定不做 | 编译门禁 `real compile errors = 0`；跳跃时序逐句对照原实现（`jump_end_end` 的 `signal_status_update` 只在撑杆僵尸补、海豚骑士补 `update_move_mode`，语义等价） |
| **U-53** | ✅ 已完成（2026-10-23）：`MoveComponent` 新增 `watch_position_x(target_x, on_reach, direction)` / `clear_position_watches()` / `signal_body_x_moved(delta_x)`，在 `_process` 末尾统一 `_check_body_x_moved()`；**6 处子类 `_process` 全部消掉** —— 矿工 / 投石车 / 气球 / 跳跳改注册位置监听，洗冰车改订阅位移信号扩张冰道，`zombie_bungi_drop` 的 `_process` 改成「有东西要跟才开」（无携带僵尸时自己 `set_process(false)`） | 编译门禁 `real compile errors = 0`；位置判定语义逐条对照（向左越过 `x <= target`、冰道扩张量取 `-delta_x`，与原 `last - curr` 等价） |
| **U-56** | ✅ 框架完成（2026-10-23）：新增 `data/character/zombie_condition/resource_zombie_condition.gd`（`ResourceZombieCondition`，字段 `row_type` / `require_ice_road` / `body_change_on_pool`）+ `zombie_bobsled_condition.tres`；`CharacterRegistry` 加 `ZombieInfoAttribute.ZombieCondition` 与两个访问器（`get_zombie_condition()` 缺省返回 null **不报错** —— 不走 `get_zombie_info()` 是因为它缺键会刷 `Log.error`；`is_zombie_need_ice_road()`）；`zombie_info_data.gd` 的雪橇条目挂上资源。**未做**：`row_type` 从枚举迁到资源（要动 20+ 条数据与选行系统） | 编译门禁 `real compile errors = 0`；`.tres` 的 `script_class` 与 `ext_resource` 路径按现有 `.tres` 格式对齐 |
| **U-57** | ✅ 已完成（2026-10-23，**登记口径已更正**）：真魔法数只有 3 处 —— `zombie_gargantuar.gd` 丢小鬼阈值 `1500` → `@export var hp_threshold_throw_imp`、`zombie_catapult` / `zombie_zamboni` 的血量阶段速度系数 `0.5` / `0` → `@export var speed_factor_hp_stage_1/2`，**默认值全部不变**。原登记里的 `400 / 350 / -50,50`（巨人投掷）、`88`（矿工目标 x）、`730`（投石车攻击位）**本来就是 `@export`**，按 §3.9 附注④ 不构成债，已从现象里删掉 | 编译门禁 `real compile errors = 0`；纯提字段，数值与调用点不变 |

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
| **4** | **存档键与存档语义**（数据迁移，错一处就是玩家进度丢失） | U-22（`save_key` 补齐，**✅ 2026-10-22 已完成**，见 §4）、U-20（两套推导收敛成 `make_save_key()` / `parse_save_key()`，**仍未做**） | U-22 已走通「读权威值 → 写入 → 另一进程回读」的闭环；U-20 的收敛要在补齐**之后**做，否则两件事一起改时无法判断是哪边错位。**⚠️ 动 U-20 前必读**：迷你 / 解密有 28 关的写死值与「当前遍历顺序拼出的值」不一致（既有事实），写死值才是权威，别拿当前拼法去纠正 | `tool_dump_save_keys` 权威值表 + `probe_save_key` 另一进进程回读一致；老存档（含 `LEGACY_INT_TO_ID` 那批）仍能读出来 |
| **5** | **参考级 / 判定暂缓**（**不做也不打回**，列出来是为了「别当没看见」） | U-14（组件里拼 `$"../X"`：`host_node_of()` 全仓 0 使用，首次落地=行为变更）、U-16（速度同步 12+ 份并存）、U-25（老虎机两本阳光账）、U-32（`Global` 边界）、§12.3 第 9 项（选关页注册表化，需开窗口比对视觉配置）、§12.3 第 15 项（`plant_cell.gd` 不拆）、§12.3 第 16 项（子弹对象池暂缓） | 收益 / 风险比不划算或需单开一轮；**留档是为了下一个人不必重新评估一遍** | 只要求：动手前读本条与对应 U 条目的「判定不做」理由，不要按直觉反向改 |
| **6** | **伤害管线与防具的记账 / 静默面**（2026-10-16 伤害与防具专项复核，**已全部完成**） | U-33（数值分散）、L-16（取消丢记账）、L-17（忘 `super()` 无守卫）、O-04（零订阅方付事件开销）；同轮登记但**判定不做**的：U-34（①③④ 重构级）、L-18 / L-19 / L-20 | 前三条都是「防具吸收并入 ② 加工阶段」（2026-10-16）带来的**记账与静默**问题 —— 不解决就会在下一次改动里以「伤害突然不生效」的形式爆出来，而不是报错。三条都不改玩法数值，可机械验证 | 编译门禁 + `probe_armor_component`（含新增的 `_check_all_modes_do_damage` / `_check_cancel_keeps_absorbed_hp`）+ `probe_more_armor_mod` 全 PASS；L-17 的自检还要**确认不误报**（实跑两个探针均无该报错） |
| **7** | **子弹子系统：先锁契约与防线，再去重，最后才谈结构**（2026-10-16 子弹专项体检，见 §3.7） | U-38（补 `source_node`）→ U-39（接线检查器覆盖子弹）→ U-36（两处去重）→ L-22（两条隐性契约加守卫 / 探针）→ L-21（减速语义，先确权）→ U-37 / U-35 / U-40（重构级，最后） | **顺序本身是结论**：① U-38 / U-36 是**等价改写**（不动数值、不动时序），先用它们证明「改子弹不会崩」；② U-39 加的是**防线**（漏登记一条子弹即报红），防线就位后才敢动注册表；③ L-22 的两条契约属**静默失效**类（漏 `super()` / 初始化顺序错都不报错）—— 没有守卫与探针，U-37 的重构就没有安全网；④ L-21 是**已存在的行为不一致**，必须先确权原版语义再改；⑤ U-35 / U-37 / U-40 风险最大（子弹是每局最高频实体）、收益是长期可维护性，排最后 | 前四步：编译门禁 `real compile errors = 0` + `probe_gameplay_core` + `probe_bullet_camp` + `probe_armor_component` 全 PASS；U-39 额外要**注入一次错误看它 exit 1**。L-21 / U-37 / U-35 / U-40 涉及行为变更，**必须开游戏实测**（V-01 例外写法：附人工验证方法） |
| **8** | **攻击逻辑：先等价改写与确权，再收索敌，最后才动角色/僵王**（2026-10-17 攻击逻辑专项体检，见 §3.8） | U-44（啃食魔法数，**已销项 / §4**）→ L-23（受击白光按结果，先确权）→ U-42（索敌三段合并）→ U-43（僵王特判收敛）→ U-41（受击入口统一）→ L-24（僵尸视角全局检测，按需） | **顺序本身是结论**：① U-44 是**零风险等价改写**（只提常量、不动数值与帧序），先拿它证明「改攻击链不崩」；② L-23 是**已存在的行为不一致**，必须先确权「被免疫时该不该闪」再改，否则只是把一种错换成另一种；③ U-42 是纯内部重构、有 `probe_gameplay_core` 的索敌链路兜底，风险中等；④ U-43 / U-41 风险最大（僵王与**全角色**受击入口，牵动每局高频路径），放最后且必须开游戏；⑤ L-24 是「半边支持、按需再做」，留档最末。**前置**：批次 7 的 U-37（子弹命中判定收口）与 U-41 / U-43 有交叠 —— 动 U-41 前先确认 U-37 是否已做，避免两轮改同一处判定 | U-44 / U-42：编译门禁 `real compile errors = 0` + `probe_gameplay_core` PASS（U-42 额外 `probe_bullet_camp`）；L-23 / U-43 / U-41 涉及行为变更，**必须开游戏实测**（V-01 例外写法：附人工验证方法）；L-24 只登记方向，不要求实现 |
| **9** ✅ | ~~**老旧代码清理：先删死代码，再收重复，最后才谈兼容分支**（2026-10-22 老旧代码专项体检，见 §3.9）~~ **—— 2026-10-22 当日 8 条全部完成，逐条处置见 §4** | L-26（注释掉的旧代码，批量删）→ U-45（双子向日葵去重，等价改写）→ U-46（花园背景表进 `SceneRegistry`）→ U-47（商店购买事务收模板）→ U-48（`EventBus.debug_mode` 改名 / 接管 / 删）→ L-27（读档补丁：先写探针再定）→ L-28（`start_ladder` 死分支）→ L-29（旧版 mod_base 定淘汰时间点） | **顺序本身是结论**：① L-26 全是**零风险删除**（注释不参与运行），先用它消掉最大危害 —— 「读代码的人把死掉的旧逻辑当成现成工具函数」（`zm_zombie_choose_row_system.gd:270-281` 那段取消注释直接编译失败）；② U-45 是等价改写（两文件逐字相同、差异在场景参数），用来证明「动这类复制粘贴不崩」；③ U-46 / U-47 是**结构收敛**（照 U-19 先例搬注册表 / 抽模板方法），涉及存档与售罄判定，需开游戏；④ U-48 / L-27 / L-28 都要求**先确权语义再改**（调试模式到底想给谁用 / 那个读档 bug 还在不在 / 重复爬梯本就无害吗），确权前不许直接删；⑤ L-29 排最后 —— 删旧版兼容分支会**直接让未升级模组崩**，得先把「还有谁在用旧版」测出来 | L-26 / U-45：编译门禁 `real compile errors = 0` + `probe_gameplay_core` PASS 即可（零行为变更）；U-46 / U-47 / U-48 / L-28：**必须开游戏实测**（花园切背景 / 商店逐类购买 / 梯子僵尸）；L-27 先交探针（同一局连续读档 N 次、断言场上植物数 == 存档格子数），再按探针结果决定删注释还是恢复补丁；L-29 只交 `Log.warn` 统计，不删（**实际结果**：8 条全部完成；验收 = 编译门禁 + `probe_sun_producer` / `probe_garden_bg` / `probe_store_rules` / `probe_event_trace` / `probe_reload_plant_cells` 五条探针全绿） |
| **10** | **复查新增：先立验证账本，再清工作区噪音，最后断根文档数字**（2026-10-22 优缺点复查，见 §3.10） | H-19（人工回归载体）→ H-20（`tools/tmp_*` + 孤儿 `.uid` + §11.2 口径）→ H-21（438 项未提交分笔）→ H-22（数字生成化）→ U-49（注释毛刺）→ H-23（仓体量量化，只量不动） | **顺序本身是结论**：① H-19 是所有后续批次的前置 —— 现在 §4 里「编译门禁 PASS + 需开游戏实测」的条目已积了 7 条以上，不先立账本，下一轮体检仍分不清「验过」与「没验」；② H-20 / H-21 与代码无关、成本以分钟计，先清掉工作区噪音，才能看清「这次改动到底是哪几笔」；③ H-22 把 H-04 / H-17 / H-18 三轮同类返工断根（数字由脚本写，不再靠人抄）；④ U-49 纯可读性，顺手；⑤ H-23 只交量化数据、**不承诺任何动作** —— 拆仓会改所有 `res://` 语义，必须单开一轮 | H-19：§4 每条能回答「开没开过游戏、看到什么」，抽查 3 条无「未做」即算立住；H-20 / H-21 / U-49：命令直出（`git ls-files tools` / `git status --short` / 编译门禁 `real compile errors = 0`）；H-22：`-Fix` 先 dry-run 对一遍再写，写后 `check_doc_facts.ps1` 必须 `problems=0`；H-23：只交 clone 体积 + 首次 import 耗时两项数字 |
| **11** | **僵尸 / 植物架构对齐：先补入口与状态归属，再收轮询与特判，最后才动舞王**（2026-10-23 对标体检，见 §3.11） | U-50（`character_ready()` 补位）→ U-59（动画状态改 `request_state()` 点名）→ U-51（状态迁进组件）→ U-53（6 处 `_process` 轮询）→ U-54（僵尸侧 `EventBus`）→ U-55（按类型特判 17 处 + 蹦极回调表）→ U-56（`ResourceZombieCondition`）→ U-57（魔法数改 `@export`）→ U-52（能力抽组件）→ U-58（`jackson/` 第二套状态机） | **顺序本身是结论**：① U-50 是**入口补位**，不补它，后面每加一处通用初始化都要在 `ready_norm` / `ready_show` 各写一遍（现在已经在重复）；② U-59 是**动画驱动迁移**（`advance_expression` → `request_state()` 点名）—— 54 处转换绑着 `is_attack` / `is_swimming` / `is_jumping`，不先解锁，U-51 一步都搬不动；③ U-51 是**状态归位**，`is_walk` / `is_attack` 这些一天在宿主上，U-53 的轮询就永远有东西可读、永远改不动；④ U-53 / U-54 是**写法收敛**，依赖 ③ 已把状态挪走；⑤ U-55 是**散落映射**，每处都要开游戏验，排在状态稳定之后；⑥ U-56 是**数据层变更**（要迁既有僵尸数据口径），⑦ U-57 是零风险等价改写但收益最小，放在能用 ① ② 的成熟度之后更安全；⑧ U-52 抽组件**必须有第 2 个使用者**，否则只是把单例代码搬个家；⑨ U-58 排最后 —— U-07 已判定「有意为之」，本条只记代价，且它不认识通用机契约，先动它会波及 5 个伴舞 | U-50 / U-51 / U-53 / U-57：编译门禁 `real compile errors = 0` + `probe_gameplay_core` PASS；U-50 额外要验**展示态**（图鉴 / 开局预览的僵尸有 `head_node`、热注册防具在展示态可见）；U-51 / U-53 / U-55 涉及每局高频路径，**逐组开游戏实测**（V-01 例外写法：附人工验证方法）：走路 / 啃食 / 跳跃僵尸 / 冰车 / 蹦极 / 舞王；U-56：数据迁移同 U-22 口径（权威值 → 写入 → 另一进程回读）；U-54 只要求「改了的那几条动作」不回归 |

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
| U-22 存档键补齐 | ✅ **完成**（2026-10-22，销项见 §4） | 工具两处硬伤已修（写入目标改 `.gd`、路径来源改 `level_script.resource_path`）+ 冒险模式新增「走序号式子」一段（它**没有**选关界面，旧工具对它 0 覆盖）；**155 关已补齐**（写入 108 / 跳过 47 / 失败 0，只写 `save_key`）；`probe_save_key` 另起进程回读 `result=PASS failed=0`；`probe_level_registry_order` / `probe_gameplay_core` 均 PASS。**遗留**：mini 25 关里有 5 关没挂在选关按钮上（工具读不到权威值），仍未补 `save_key`；`format_version` 未动（同轮发现的新债 **L-25**） |
| 批次 3（L-12 → L-13 → L-14 → U-31 死亡链） | 🟡 **代码已改完（2026-10-17），待开游戏实测** | L-12 基类 `character_death_disappear()` 置 `is_can_death_language=false`；L-13 亡语前移 + 战斗判定延迟到帧末；L-14 必杀入口用显式判断恢复亡语开关；U-31 爆炸逻辑下沉基类、删 5 植物重复。编译门禁 `real compile errors = 0` + `probe_gameplay_core` `result=PASS`；**⚠️ 均必开游戏实测**（雪橇补兵算本轮、必杀/爆炸亡语表现、土豆雷出土自爆、读档清理、手套兜底） |
| 批次 6（伤害管线与防具：U-33 → L-16 → L-17 → O-04） | ✅ **完成**（销项见 §4） | ① 编译门禁 `real compile errors = 0`；② `probe_armor_component -Windowed -KillStale` → `[ARMOR] result=PASS failed=0`（新增护栏覆盖全部 6 种 `E_DamageMode` + 靠里取消的钱账）；③ `probe_more_armor_mod -Windowed -KillStale` → `[MORE_ARMOR] result=PASS failed=0`（模组重写 `absorb_damage()` 的路径未被自检误伤） |
| 批次 7（子弹子系统：U-38 → U-39 → U-36 → L-22 → L-21 → U-37 / U-35 / U-40） | 🟡 **前 4 步已做，后 2 步未开始** | ① **U-38 / U-39 / U-36 已销项**（见 §4）：编译门禁 `real compile errors = 0`；`tools/check_content_wiring.ps1` `PASS checks=230`（**含注入验证**：改坏一条即两条 FAIL + `EXIT=1`，已还原）；`probe_gameplay_core` `[GAMEPLAY] result=PASS failed=0`（掉血 270 → 250）；`probe_bullet_camp` `[BULLETCAMP] result=PASS failed=0`（17 项）。② **L-22 第 ① 条已修**（`init_bullet` 早于入树的契约被消除，探针同上）。③ **未开始**：L-22②（`attack_once` 覆写链守卫，彻底解依赖 U-37）、L-21（冰瓜减速免疫语义，需先确权原版）、U-37 / U-35 / U-40（重构级）—— 四者都涉及行为变更，**必须开游戏实测**（V-01 例外写法） |
| 批次 9（老旧代码：L-26 → U-45 → U-46 → U-47 → U-48 → L-27 → L-28 → L-29） | ✅ **全部完成**（2026-10-22） | 编译门禁 `real compile errors = 0`（scenarios 153 PASS）+ 五条探针全绿：`probe_sun_producer`（U-45）/ `probe_garden_bg`（U-46）/ `probe_store_rules`（U-47，同轮修掉其一条过时断言）/ `probe_event_trace`（U-48）/ `probe_reload_plant_cells`（L-27，新增）；L-26 纯删注释。逐条处置见 §4。⚠️ 仍需人工开游戏的只有：梯子僵尸（L-28）、双子产阳光观感（U-45）—— 属视觉/节奏确认，不阻塞交付 |
| 批次 8（攻击逻辑：U-44 → L-23 → U-42 → U-43 → U-41 → L-24） | 🟡 **第 1、2、3 步已做**（U-44、L-23、U-42 已销项 / §4，其余未开始） | U-44 / U-42 / L-23：编译门禁 `real compile errors = 0`（scenarios 120 PASS）；U-42 + `probe_gameplay_core` / `probe_bullet_camp` 均 `result=PASS`（抽公共迭代器，语义不变）；L-23 是行为变更（被整包免疫取消时不闪白光，符合 §5 表现放③末端），**需开游戏回归**（举起防具僵尸被豌豆打）；U-43 / U-41 涉及重构，需开游戏实测 |

