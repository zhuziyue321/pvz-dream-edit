extends Node
## 联机的**状态广播**：主机每帧把"场上现在长什么样"整份广播出去，客户端照着对齐
##
## 这是继命令同步（`NetplayBattleSync`）与波次下发（`NetplayWaveSync`）之后的第三层，
## 也是兜底的那一层：命令同步保证"**做了什么**"一致，但两端各自的本地模拟
## （僵尸 AI、啃食、减速、掉血）仍会慢慢分叉 —— 这一层每隔一小会儿就用主机的真相
## 把分叉抹平，两端看到的才是同一局。
##
##   host   `_physics_process` ──▶ 采一份快照 ──▶ `state_snapshot`（unreliable）广播
##   client 收到 ──▶ 按 `entity_id` 对齐：缺的补、多的（连续缺席的）删、属性覆盖
##
## ★ **阳光也进快照**（第二包）：`NetplaySunSync` 用**离散命令**管"多了一颗 / 少了一颗"，
##   但命令只管事件、不管"现在场上到底有几颗" —— 哪一包在乱序里晚到、或者客户端本地
##   多长了一颗，命令这条路上没有东西能把它纠正回来。快照是**兜底**：每帧把"场上这几颗"
##   整份报一遍，客户端照着补 / 删，任何遗漏都能自愈。
##   ⚠️ 早先这里写着"故意不管阳光"，理由是"僵尸掉的阳光两端各自生成、编号不同，
##   对齐会把玩家的阳光误删"。**这条已经不成立**：实测 `component_drop_item.gd` 里
##   **只有金币 / 花园植物 / 巧克力，没有阳光**，阳光的 5 个生成点全都过
##   `GlobalUtils.sun_spawn_gate` 且都推 `SUN_SPAWNED` ⇒ 客户端的每一颗都有主机编号。
##
## ★ **玩家阳光总量也进快照**（第二包的 `sv`）：钱包里那个数不是"场上飘着的那一颗"，
##   一颗阳光谁捡到都是**各自那份钱包各加一次**（`Sun.collect()` 在两端各跑一遍），
##   所以两端的钱包本该始终相等；可它是靠一条条 `pick_sun` 命令堆出来的，丢一条就**永久分叉**。
##
## ★ **僵王单独一类**：它**不在** `all_zombies_1d` 里 —— 挂在独立的 `%ZombieBossRoot` 下
##   （`ZombieManager` 明确"僵王不加入普通僵尸列表"），照僵尸那套遍历**一只都采不到**。
##   少这一类，僵王关（5-10 / 迷你 20）就等于完全没同步。
##
## ★ **出战卡槽（卡列表 + 每张卡的冷却）也进快照**（第二包的 `cd_*`）：主机那一侧会改卡槽
##   （关卡脚本中途加 / 撤一张、戴夫卖出卡槽扩充）也会改冷却（`card_change_cool_time()` /
##   `set_card_cool_time_start_cool()`），而客户端那一局读的是**自己**的卡槽 ——
##   主机改完了它不会跟着改，两端手里的卡就不一样了（后面每一步都对不上）。
##   ⚠️ **选卡阶段不对齐**：那两个阶段两端**各挑各的卡**（§4.2.2 只保证不重复），
##   卡槽正被玩家自己摆弄，照主机覆盖等于把他刚挑好的卡冲掉 —— 只在开打之后才以主机为准。
##   （同一个判据下阳光总量属于**战斗域**：一颗阳光两端都加钱，所以它必须一致。）
##
## ★ **对齐靠 `entity_id`**，而编号不是各端自增就能对上的（谁先多生一颗阳光就整体错位），
##   所以客户端**一个实体都不自己造**：僵尸 / 子弹 / 阳光 / 掉落物全是照主机下发的编号补出来的
##   （客户端不出怪、不掉阳光、不掉战利品、不造子弹 —— 见 `NetplayWaveSync` 与各生成闸门）。
##
## ★ **渲染所需要的信息也进快照**（`z_render` / `p_render`，见文件里「渲染状态」那一节）：
##   客户端的僵尸已经是"只渲染"了（判定组件整体禁用），而**渲染**这件事本身还差几样 ——
##   断手 / 掉头、受击变亮、动画播到第几帧、向日葵准备产出那一下发光。
##   这几样都**不能**靠客户端自己推：血量是直接赋值拉齐的（setter 不发掉血信号），
##   发光是瞬时脉冲（读不出"又闪了一下"），两端的动画相位与产阳光间隔各走各的。
##
## ★ **只有主机喊得动**：客户端自己发的快照一律丢掉（与 `enter_level` / `battle_op` 同一条纪律）。
## ★ **用 unreliable**：快照是"最新真相"，丢一帧下一帧就补上，不值得为它重传（重传只会带来旧数据）。
##
## ⚠️ **包体与 MTU**：ENet 的不可靠包不分片，超 MTU（约 1400 字节）会**整包丢弃**。
## 所以快照用 `Packed*Array` 紧凑编码（不用字典数组），并给每类实体设了上限；
## 场上实体特别多时按上限截断（先保僵尸）。真遇到丢包就把控制台的「快照频率」调小。
##
## 关联：[联机模组](../../docs/参考存档/联机模组.md) ｜ [联机模组规范](../../docs/参考存档/联机模组规范.md)

const SELF_NODE_NAME := "NetplayStateSync"

## ★ 广播频率：**每秒多少次**（控制台「快照频率」那一栏可调，见 `NetplayMod`）
##
## 为什么按"次 / 秒"而不是"每几帧"：物理帧率是可改的（`physics_ticks_per_second`），
## 按帧算的话同一个数字在不同机器上意味着完全不同的频率 —— 60 帧的机器上"每 2 帧"
## 是 30 次/秒，30 帧的机器上就成了 15 次/秒。
const SEND_RATE_DEFAULT := 60.0
const SEND_RATE_MIN := 1.0
## ⚠️ 上限就是**物理帧率**：`_physics_process` 一帧最多发一次，调到 120 也还是 60
const SEND_RATE_MAX := 60.0

## 当前广播频率（次/秒）
var send_rate := SEND_RATE_DEFAULT
## 距离下一次广播还攒着多少秒（按时间而不是按帧数，见 `SEND_RATE_DEFAULT` 那段）
var _send_accum := 0.0
## 单帧快照的实体上限（MTU 保护，见文件头）
const MAX_ZOMBIES := 40
const MAX_PLANTS := 64
const MAX_SUNS := 24
const MAX_BULLETS := 32
const MAX_BOSSES := 2
## 出战卡槽里的卡（选卡槽位最多十来格，12 足够）
const MAX_CARDS := 12
## 字节预算：ENet 的不可靠包超过 MTU（约 1400B）会**整包丢弃**（见文件头）。
##
## ⚠️ 为什么非要算字节：光靠上面那三个"条数上限"**算不出真实体积** ——
## 40 只僵尸（24B）+ 64 株植物（8B）就已经 1472B，超了；再加子弹只会更超。
## 所以改成"先到先得填预算"，并且给后面的类留保底，免得僵尸一多植物就一条都发不出去
## （植物发不出去 ⇒ 客户端的植物永远死不了）。
## ⚠️ 这是**每一包**的预算，两包各自独立（见 `NetplaySession` 的 `state_snapshot_extra`）
const BYTE_BUDGET := 1300
## ★ 各加了 4B 的**渲染状态**（`z_render` / `p_render`，位布局见「渲染状态」那一节）
## ⚠️ `z_anim` / `p_anim` 是**单字节**的动画下标（`PackedByteArray`，见「动画」那一节）
const BYTES_PER_ZOMBIE := 29	## id / type / lane / render / x / y / hp + anim(1B)
const BYTES_PER_BULLET := 16	## id / type / x / y
## 植物补了类型与格子（16B）：只发血量时客户端**没法补种** —— 命令丢了 / 晚到就永远少一株，
## 而快照这一层的价值恰恰就是"能把少的补回来"。
## ⚠️ `place`（槽位）**不用发**：它由植物自己的种植条件决定，`create_plant(type)` 会放对
const BYTES_PER_PLANT := 21		## id / type / cell / hp / render + anim(1B)
const BYTES_PER_SUN := 16		## id / value / x / y
## 僵王：id / 类型 / 位置 / 血量 / 死亡
## ⚠️ 类型**必须**发：`ZB000Base` 上没有任何类型字段（实测 `zb_base.gd` 里没有），
## 客户端补种时无从知道"该造哪一种"，只能由主机随快照告诉它。
const BYTES_PER_BOSS := 24
## 出战卡槽里的一张卡：类别(4) / 编号(4) / 是否模仿者(1) + 剩余冷却(4)
##
## ⚠️ **冷却总长（`cool_time`）故意不发**：它几乎全程不变，而每发一条就要从**植物名册**
##   的预算里扣 4B × 卡数 —— 满盘 45 株 + 12 张卡 + 阳光预留刚好卡在 1300B 上，多这 4B
##   就把名册挤到 43 株。少了它，客户端画遮罩用的还是自己那份总长：能改总长的只有
##   罐子模式那类零冷却卡（`card_change_cool_time()`），而那种卡主机报的"还剩几秒"本来
##   就是 0 —— 客户端照样判就绪，**能不能点不受影响**，差的只是遮罩的填充比例。
const BYTES_PER_CARD := 13
## 传送带上的卡（只发每张卡的 x，用来把两端跑岔开的位移拨回来；**不发名单**，理由见 `_align_conveyor_x`）
const BYTES_PER_CONVEYOR := 4
## 传送带上同时流着的卡（与出战卡槽同量级，12 足够；超了就少报几张，不截断标记）
const MAX_CONVEYOR := 12
## 卡身份压成一个 int 时的**类别进位**（编号只到三位数量级，10^6 足够）
## 见 `_card_sig_of`：只用来比"这一批卡变没变"，不参与任何判定
const CARD_SIG_TYPE_BASE := 1000000
const RESERVE_BULLETS := 320	## 20 颗
const RESERVE_SUNS := 160		## 10 颗
const RESERVE_BOSSES := 48		## 2 只
## 战斗进度条的预留（一条 float + 一条 bool，见 `collect_snapshot_extra` 的 `pr` / `ws`）
const RESERVE_PROGRESS := 8
## 玩家阳光总量的预留（一条 int，见 `collect_snapshot_extra` 的 `sv`）
const RESERVE_SUN_VALUE := 8
## 位置对齐的平滑系数：1.0 = 直接吸附，越小越平滑但越滞后
const POS_LERP := 0.5
## 本地有、主机没有的实体要**连续缺席**这么多帧才删 ——
## 差一两帧多半只是"主机还没采到 / 包还没到"，立刻删会让刚出生的僵尸闪一下
const MISS_FRAMES_BEFORE_DELETE := 90
## 子弹的缺席阈值要短得多：它活得就那么几秒，照僵尸那 90 帧（1.5 秒）等下去，
## 主机那颗早就命中消失了，客户端这颗还在原地飘着
const MISS_FRAMES_BEFORE_DELETE_BULLET := 6
## 阳光的缺席阈值取中间：比子弹长（它落地后要停留十几秒，不能 6 帧就判没了），
## 又比僵尸短（被捡走是**命令**驱动的，客户端收到就立刻摘掉，快照只兜底 ——
## 兜底拖 1.5 秒会让"已经被捡走的那一颗"还挂在画面上）
const MISS_FRAMES_BEFORE_DELETE_SUN := 30

#region 动画（★ 由主机下发"播哪一条、播到第几秒"，客户端照播）
##
## ★★ **统一口径：主机直接说"正在播哪条动画 + 播到第几秒"，客户端照播。**
##
## 早先的做法是发 7 个**状态字段**（`is_death` / `is_attack` / `is_swimming` / `is_idle` /
## `walk_status` / `idle_status` / `death_status`），客户端写回本体字段，再让本体的
## AnimationTree（`advance_expression`）**自己推导出**该播哪一条。
##
## 那条路是**补丁叠补丁**：推导链断在哪儿就要往哪儿补 —— 补一次 `hp_loss_to_death()` 才能触发
## 死亡流程、补阶段号才能触发掉头、给一次性动画开"不对表"的特例才不会跳过倒地……
## 而且客户端始终在**用自己的逻辑猜**主机那边发生了什么，猜错了就是画面不一致。
##
## 现在只发两个数：
##
##   - `z_anim` / `p_anim`：当前动画在 `AnimationPlayer.get_animation_list()` 里的**下标**
##   - `z_render` / `p_render` 里的 phase：播到第几秒（`current_animation_position`）
##
## 客户端：名字不一样就 `play()`，偏得多了就 `seek()`。**没有推导、没有补触发。**
##
## ★ **下标为什么天然对齐**：两端实例化的是**同一份 .tscn**，动画列表与插入顺序完全一致
## ⇒ 同一个下标就是同一条动画，**不需要任何"动画名 → 编号"的硬编码表**
## （硬约束 §1-4 说的正是别散落这类映射）。
##
## ⚠️ 前提是客户端**接管**动画：普僵那条路是 AnimationTree 每帧按 `is_death` 等字段
## **自己挑**动画，会把我们 `play()` 的那一条下一帧就换掉 —— 结果"发了等于没发"。
## 所以客户端第一次见到一个角色就把它关掉（`_take_over_anim()`），动画完全由快照驱动。
##
## ⚠️ **动画名只能问动画组件**（`AnimComponentBase.update_current_anim()`），**不能**读
## `AnimationPlayer.current_animation`：动画树驱动角色时那个字段**恒为空**（树走自己的
## playback、从不调 `play()`，实测 `cur=[]`）。照播放器采的结果是下标恒为 255、
## 客户端从不接管 —— 整条动画同步**静默空转**，3 倍速下就是"客户端纹丝不动地原速播"。
##
## ⚠️ 唯一例外是**僵王**：它的死亡是"编排式"的（播完死亡动画还要 `start_death_remain()`
## 撑住一段时间才淡出、还要发奖杯），光播对一条动画**撑不起**整套流程，
## 所以僵王仍走 `zb_death` 触发本地死亡流程（见 `_align_bosses`）。
const ANIM_NONE := 255	## 下标占位：拿不到播放器 / 没在播 / 下标越界 ⇒ 本次不接管
#endregion

#region 渲染状态（★ 由主机下发，客户端照着演）
##
## 与上面那段 `z_anim`（**在播哪一条动画**）互补 —— 这一段管"**播到第几秒 / 画面上长什么样**"：
##
## | 项 | 主机侧读 | 客户端侧写回 |
## |---|---|---|
## | 断手 / 掉头 / 防具破损 | `HpStageChangeComponent.curr_hp_stage`（+ 两个防具阶段） | 把目标阶段的临界值喂回 `judge_body_change()` |
## | 受击变亮 | `BodyCharacter.body_light_count`（每闪一次 +1） | 值变了 ⇒ 补一次 `body_light()` |
## | 动画播到第几帧 | `AnimationPlayer.current_animation_position` | 偏得多了才 `seek()` 一次 |
## | 向日葵准备产出 | `CreateSunComponent.create_sun_timer.time_left` | 把计时器对到主机的剩余时间 |
##
## ★ **为什么"断手"不能让客户端照血量自己推**：`HpComponent.curr_hp` 的 setter **不**发
## `signal_hp_loss`（只有 `Hp_loss()` 才发），而客户端是**直接赋值**把血量拉齐的
## （`_align_zombies()`）⇒ 客户端永远走不到 `judge_body_change()`，掉手 / 掉头一次都不演。
## 再加一层：关卡会改临界值（小僵尸大麻烦把它砍半），两端的阈值未必一样 —— 发阶段号最稳。
##
## ★ **为什么受击变亮要发"计数"而不是"当前亮度"**：发光是一次**瞬时脉冲**
## （立刻调到 2 倍亮，再 0.5 秒 tween 回白），读 `modulate` 只能读到 tween 途中的某个值，
## 读不出"此刻又闪了一下"。计数是**可比较的整数**：值变了就说明又挨了一下。
##
## ★ **为什么向日葵发的是"还剩多久"而不是"正在发光"**：那一下发光是 `CreateSunTimer`
## 到点后 `create_sun()` 自己 tween 出来的，两端各自 `randf_range(3, 12.5)` 抽的间隔
## **必然不同** ⇒ 客户端会在错误的时间点自己亮一次（产阳光本身已被 `sun_spawn_gate`
## 拦掉，只剩发光对不上）。把计时器对到主机的剩余时间，发光就落在同一刻，
## 不必另发明一条"发光命令"。
##
## 每类实体挤成**一个 int**（各一条 4 字节数组），理由同 `z_anim`：快照贴着 ENet 的 MTU。
##
## ⚠️ 已知还没进快照的：**僵王**的技能状态机与动画、`Zombie001Norm._random_sprit_appear()`
## 的随机贴图、冰冻 / 魅惑染色、隐形。前两样在 §4.9 的待办里单列。

## 僵尸 `z_render` 的位布局
const RENDER_Z_STAGE_SHIFT := 0		## 本体血量阶段（掉手 / 掉头）
## 防具阶段：**按挨打顺序（`HpComponentZombie.armor_list`）的前两层**，不再是"一类 / 二类"
## —— 防具改成组件后一个僵尸可以戴多层、也可以叠同类，按类别分槽表达不了。
## 两端场景同源 ⇒ `armor_list` 的下标一致，对号入座即可。超出的层数不进快照。
const RENDER_Z_ARMOR_SLOT0_SHIFT := 3
const RENDER_Z_ARMOR_SLOT1_SHIFT := 6
const RENDER_Z_ARMOR_SLOT_COUNT := 2
const RENDER_Z_LIGHT_SHIFT := 9		## 受击变亮计数（mod 8）
const RENDER_Z_PHASE_SHIFT := 12	## 动画播放进度
## 植物 `p_render` 的位布局
const RENDER_P_STAGE_SHIFT := 0		## 本体血量阶段（坚果裂纹 / 南瓜头）
const RENDER_P_LIGHT_SHIFT := 3		## 受击变亮计数（mod 8）
const RENDER_P_SUN_TIME_SHIFT := 7	## 产阳光剩余时间
const RENDER_P_SUN_RUNNING := 1 << 6	## 产阳光计时器是否在跑
## ★ 植物的**动画播放进度**：与僵尸同一套量化口径（`PHASE_STEP` / `PHASE_NONE`）。
## 挤在产阳光计时器那 11 位之后（bit 18~27）—— 加起来 28 位，仍在 int32 里。
##
## ⚠️ 这一位是"完全把主机的动画给客户端"的**关键**：只发 `p_anim`（播哪一条）不发相位，
## 植物的播放速度就永远是自己那份 —— 主机开 3 倍速时植物慢放。
const RENDER_P_PHASE_SHIFT := 18

## 血量阶段的位宽（3 位）：-1（未受损）编码成 0，实际阶段 n 编码成 n+1
## ⇒ 0 同时表示"这个角色没有血量阶段组件"，够编到 6 个阶段
const RENDER_STAGE_MASK := 0b111
## 一个阶段占几位（= RENDER_STAGE_MASK 的位宽），防具槽位按它顺延
const RENDER_STAGE_BITS := 3
const RENDER_LIGHT_MASK := 0b111
## 植物与僵尸的相位同宽同刻度 ⇒ `PHASE_NONE` 两边通用
const RENDER_Z_PHASE_MASK := 0b11_1111_1111
const RENDER_P_PHASE_MASK := 0b11_1111_1111
const RENDER_P_SUN_TIME_MASK := 0b111_1111_1111

## 动画进度的量化步长（秒）：1/64 ≈ 15.6ms，约等于一帧；10 位可表示到 15.98 秒
## （走路 / 啃食 / 倒地都在 2 秒以内，量程绰绰有余）
const PHASE_STEP := 1.0 / 64.0
## 相位占位：主机那边**没有正在播的动画**（此时读播放头会刷 ERROR，见 `_anim_has_head`）
##
## ★ 为什么不能发 0：0 是个合法的相位（"播放头在开头"），客户端照 0 去 `seek()`
## 会把本地正在播的动画**拽回第一帧**；而"主机没在播"是另一回事 —— 客户端该做的是**不动**。
## 取量程最大值 1023（15.98 秒）：现行动画都在 2 秒以内，正常永远到不了这一格。
const PHASE_NONE := RENDER_Z_PHASE_MASK
## 产阳光剩余时间的量化步长（秒）：1/16 = 62.5ms；11 位可表示到 127.9 秒
## （生产间隔 23.5~25 秒，量程绰绰有余；62.5ms 远小于 0.5 秒的发光时长）
const SUN_TIME_STEP := 1.0 / 16.0
## 偏差超过这么多秒才把动画播放头拉回主机的位置（见 `_apply_anim_phase`）
##
## ⚠️ 下限由**量化噪声**决定，别再往下调：`z_render` 里的 phase 是按 `PHASE_STEP`（1/64 秒）
## 四舍五入后投过来的，两端比对时天然带着最多半个步长（≈7.8ms）的误差 —— 阈值压到这个量级，
## 纠偏就会在噪声里反复触发，表现为动画抖动（这正是 `_apply_anim_phase` 开头那段说的"打架"）。
## 0.05 秒 ≈ 3 个物理帧，留了约 6 倍噪声裕量。
const PHASE_RESYNC_EPS := 0.05
## 偏差超过这么多秒才把产阳光计时器对到主机的剩余时间（见 `_apply_create_sun`）
const SUN_TIME_RESYNC_EPS := 0.3
## 客户端记住"主机上一次报的发光计数"用的 meta 键（按角色存，随节点一起没）
const LIGHT_COUNT_META := &"netplay_light_count"
#endregion

var _session = null
var _main_game: MainGameManager = null
var _notice: Callable = Callable()
var _frame := 0
## 僵尸采集的**轮转游标**：快照截断时下一帧从这一帧没采到的那一只接着采 ——
## 理由见 `collect_snapshot`（不轮转的话，排在后面那批僵尸会**永远收不到位置**）
var _z_cursor := 0
## 本地有而快照里没有的实体（entity_id → 连续缺席帧数）
var _missing: Dictionary = {}
## 动画变体属性的探测缓存：类 → {属性名: 有没有}（见 `_has_prop`）
var _anim_prop_cache: Dictionary = {}
## 上一次照着对齐过的那批卡的身份（`_card_sig_of` 压出来的数字序列）——
## 没变就只刷冷却，别每帧都去动卡槽（见 `_align_cards`）
var _last_card_ids := PackedInt32Array()


## 挂上来之后要先接线：[param notice] `func(text: String) -> void`
func setup(session, main_game: MainGameManager, notice: Callable = Callable()) -> void:
	_session = session
	_main_game = main_game
	_notice = notice
	if _session == null or not _session.is_linked():
		return
	## 只有主机需要每帧采集（客户端是收的一方，靠信号驱动）
	if _session.is_host():
		set_physics_process(true)
	if _session.is_client():
		if not _session.state_snapshot_received.is_connected(_on_state_snapshot_received):
			_session.state_snapshot_received.connect(_on_state_snapshot_received)
		if not _session.state_snapshot_extra_received.is_connected(_on_state_snapshot_extra_received):
			_session.state_snapshot_extra_received.connect(_on_state_snapshot_extra_received)
		## 客户端不自己造子弹：开火动画照旧本地播，但那颗子弹由主机随快照下发 ——
		## 再造一份就是"一发豌豆两颗"（见 `GlobalUtils.bullet_spawn_gate`）
		GlobalUtils.bullet_spawn_gate = _on_local_bullet_spawn


func _physics_process(delta: float) -> void:
	if _session == null or not _session.is_linked() or not _session.is_host():
		return
	var mg := _resolve_main_game()
	if mg == null:
		return
	_frame += 1
	if not _tick_send(delta):
		return
	## 两包各装一类，各自都在 MTU 以内（见 `NetplaySession` 的 `state_snapshot_extra`）
	_session.send_state_snapshot(collect_snapshot(mg))
	_session.send_state_snapshot_extra(collect_snapshot_extra(mg))


## 攒够一个间隔没有（**按时间**，不是按帧数取模 —— 那样"次 / 秒"名不副实）
##
## ⚠️ 归零而不是减掉一个间隔：快照是"现在长什么样"，卡顿攒下的那几次**补发没有意义**
## —— 补发只会把已经过时的真相送过去，还可能在一帧里连发好几包顶爆带宽。
func _tick_send(delta: float) -> bool:
	_send_accum += delta
	if _send_accum < 1.0 / max(SEND_RATE_MIN, send_rate):
		return false
	_send_accum = 0.0
	return true


func _exit_tree() -> void:
	## 换关时旧节点会先灭：闸门要还回去，别把下一局的子弹也锁住
	if GlobalUtils.bullet_spawn_gate == _on_local_bullet_spawn:
		GlobalUtils.bullet_spawn_gate = Callable()
	if _session != null and _session.state_snapshot_received.is_connected(_on_state_snapshot_received):
		_session.state_snapshot_received.disconnect(_on_state_snapshot_received)
	if _session != null and _session.state_snapshot_extra_received.is_connected(_on_state_snapshot_extra_received):
		_session.state_snapshot_extra_received.disconnect(_on_state_snapshot_extra_received)


## 改广播频率（控制台滑条那一头调它；新开一局由 `NetplayMod` 带上）
func set_send_rate(value: float) -> void:
	send_rate = clampf(value, SEND_RATE_MIN, SEND_RATE_MAX)
	_send_accum = 0.0


## 生成闸门：客户端一颗子弹都不自己造（都由快照下发）
func _on_local_bullet_spawn() -> bool:
	return _session != null and _session.is_linked() and _session.is_client()


#region 采集（主机）
## 采一份"场上现在长什么样"
##
## 编码刻意用 `Packed*Array` 而不是字典数组：每只僵尸一个字典的话，30 只就 3KB，
## 超过 ENet 不可靠包的 MTU 会被整包丢掉（见文件头）。现在是每只 7 个数字，约 28 字节
## （**动画只占 1 个字节**：发的是动画在列表里的下标，见文件头「动画」那一节）。
func collect_snapshot(mg: MainGameManager) -> Dictionary:
	var snap: Dictionary = {}
	if mg == null:
		return snap
	snap[&"f"] = _frame

	## 按字节预算排上限：第一包只有僵尸 ▶ 子弹（植物与阳光在第二包，见 `collect_snapshot_extra`）
	var z_cap := _cap_for(BYTES_PER_ZOMBIE, MAX_ZOMBIES,
		BYTE_BUDGET - RESERVE_BULLETS - RESERVE_BOSSES)
	var left := BYTE_BUDGET

	## 僵尸：id / 类型 / 行 / **当前动画** / 位置 / 血量
	var z_id := PackedInt32Array()
	## 角色 id 现在是字符串（植物 / 僵尸 / 僵王 / 卡牌 content_id 都是），
	## 快照里的 `*_type` 与 `cd_id` 一律用 PackedStringArray 传，不再打包成 int
	var z_type := PackedStringArray()
	var z_lane := PackedInt32Array()
	var z_anim := PackedByteArray()
	var z_render := PackedInt32Array()
	var z_x := PackedFloat32Array()
	var z_y := PackedFloat32Array()
	var z_hp := PackedFloat32Array()
	if mg.zombie_manager != null:
		## 一边遍历一边可能被删（`character_death_disappear()`），先复制一份
		var zombies: Array[Zombie000Base] = []
		for z in mg.zombie_manager.all_zombies_1d.duplicate():
			if is_instance_valid(z) and z.entity_id != 0:
				zombies.append(z)
		## ★ **轮转**：这一帧装不下的那些，**下一帧从它们接着采**（游标停在断点上）。
		## 不轮转的话每帧都从头采、被截断的永远是排在后面那同一批 —— 那几只在客户端
		## **永远收不到位置**。而客户端的僵尸现在连移动都关掉了（见 `_make_zombie_render_only`），
		## 收不到位置 = 彻底僵在原地，再没有"自己走一点"能把破绽盖住。
		## 轮转之后，每只最多隔 `ceil(总数 / z_cap)` 帧必被采到一次。
		var total := zombies.size()
		var take := mini(total, z_cap)
		if total > take:
			snap[&"z_cut"] = true
		for i in range(take):
			var z: Zombie000Base = zombies[(_z_cursor + i) % total]
			z_id.append(z.entity_id)
			z_type.append(str(z.zombie_type))
			z_lane.append(z.lane)
			z_anim.append(_anim_index_of(z))
			z_render.append(_pack_zombie_render(z))
			z_x.append(z.global_position.x)
			z_y.append(z.global_position.y)
			z_hp.append(_hp_of(z))
		if total > 0:
			_z_cursor = (_z_cursor + take) % total
	snap[&"z_id"] = z_id
	snap[&"z_type"] = z_type
	snap[&"z_lane"] = z_lane
	snap[&"z_anim"] = z_anim
	snap[&"z_render"] = z_render
	snap[&"z_x"] = z_x
	snap[&"z_y"] = z_y
	snap[&"z_hp"] = z_hp
	left -= z_id.size() * BYTES_PER_ZOMBIE

	## 子弹：id / 类型 / 位置（客户端不自己造子弹，场上飞着的由主机下发）
	var b_cap := _cap_for(BYTES_PER_BULLET, MAX_BULLETS, left)
	var b_id := PackedInt32Array()
	## 子弹类型是 StringName id（见 `BulletIds`），用字符串数组传；
	## 比 int 编号多几个字节，换来的是客户端不必再维护一份「编号 → 类型」的对照表
	var b_type := PackedStringArray()
	var b_x := PackedFloat32Array()
	var b_y := PackedFloat32Array()
	if mg.bullets != null:
		for child in mg.bullets.get_children():
			var bullet := child as Bullet000Base
			if bullet == null or not is_instance_valid(bullet) or bullet.entity_id == 0:
				continue
			if b_id.size() >= b_cap:
				snap[&"b_cut"] = true
				break
			b_id.append(bullet.entity_id)
			b_type.append(String(bullet.bullet_type))
			b_x.append(bullet.global_position.x)
			b_y.append(bullet.global_position.y)
	snap[&"b_id"] = b_id
	snap[&"b_type"] = b_type
	snap[&"b_x"] = b_x
	snap[&"b_y"] = b_y
	left -= b_id.size() * BYTES_PER_BULLET

	## 僵王：**不在** `all_zombies_1d` 里 —— 它挂在独立的 `%ZombieBossRoot` 下
	## （`ZombieManager` 明确"僵王不加入普通僵尸列表"），所以上面那一轮遍历**采不到它**，
	## 必须单开一类。少这一类，僵王关（5-10 / 迷你 20）就等于完全没同步。
	##
	## ⚠️ 为什么走 `_boss_list()`（遍历根节点）而不是 `get_living_bosses()`：
	## 后者会把**已经死了的**过滤掉，于是主机那只正在演死亡动画的僵王一条都发不出来 ——
	## 客户端永远收不到"它死了"，只能等缺席 90 帧把它凭空删掉，死亡演出整个丢掉。
	var zb_cap := _cap_for(BYTES_PER_BOSS, MAX_BOSSES, left)
	var zb_id := PackedInt32Array()
	var zb_type := PackedStringArray()
	var zb_x := PackedFloat32Array()
	var zb_y := PackedFloat32Array()
	var zb_hp := PackedFloat32Array()
	var zb_death := PackedInt32Array()
	for boss in _boss_list(mg):
		if zb_id.size() >= zb_cap:
			snap[&"zb_cut"] = true
			break
		zb_id.append(boss.entity_id)
		zb_type.append(str(_boss_type_of(mg)))
		zb_x.append(boss.global_position.x)
		zb_y.append(boss.global_position.y)
		zb_hp.append(_hp_of(boss))
		zb_death.append(1 if boss.is_death else 0)
	snap[&"zb_id"] = zb_id
	snap[&"zb_type"] = zb_type
	snap[&"zb_x"] = zb_x
	snap[&"zb_y"] = zb_y
	snap[&"zb_hp"] = zb_hp
	snap[&"zb_death"] = zb_death

	return snap


## 本关的僵王类型（补种时要告诉客户端"造哪一种"）
##
## ⚠️ 已知限制：取的是**关卡参数** `game_para.boss_type`（自动出场那一只的类型），
## 而僵王实例上没有任何类型字段可反查。由**僵王卡牌**召唤出来的那一只，本关若没配
## 自动出场（`boss_type == Null`），这里就拿不到它的类型 ⇒ 客户端补种不了。
## 宁可造不出来（这只僵王在客户端不显示），也不能造错一种 —— 见 `_spawn_boss()`。
static func _boss_type_of(mg: MainGameManager) -> StringName:
	if mg == null or mg.game_para == null:
		return ZombieBossIds.NULL
	return mg.game_para.boss_type


## 场上所有僵王（含**正在演死亡动画**的，理由见 `collect_snapshot` 里那一处）
static func _boss_list(mg: MainGameManager) -> Array[ZB000Base]:
	var out: Array[ZB000Base] = []
	if mg == null or mg.zombie_manager == null:
		return out
	var root := mg.zombie_manager.zombie_boss_root
	if root == null:
		return out
	for child in root.get_children():
		var boss := child as ZB000Base
		if boss != null and is_instance_valid(boss) and boss.entity_id != 0:
			out.append(boss)
	return out


## 第二包：植物名册 + 场上阳光（为什么要单独一包，见 `NetplaySession` 那个信号的注释）
func collect_snapshot_extra(mg: MainGameManager) -> Dictionary:
	var snap: Dictionary = {}
	if mg == null:
		return snap
	snap[&"f"] = _frame
	## ★ **战斗进度条**为什么在这里发，而不是跟着 `wave_next` 命令：
	## 进度条是**连续量** —— 开波跳一次之后，波次之间还按秒慢慢爬（见
	## `ZombieWaveManager.battle_progress` 每秒 `+= progress_bar_segment_mini_every_sec`），
	## 命令只在开波那一刻发一次，爬升那一段永远差着。快照每帧都发，跳变与爬升一并覆盖。
	## ⚠️ 采的是 `ZombieManager.get_battle_progress()`（**通用口径**）而不是直接读波次管理器的
	## 字段：进度条的口径可以被关卡脚本换掉（外部出怪器 / 僵王血量），走通用入口才不会采错。
	snap[&"pr"] = mg.zombie_manager.get_battle_progress() if mg.zombie_manager != null else 0.0
	## 第一波是否已开打（开打前进度条不显示）—— 它是**状态**而不是事件，同样归快照
	var wave_manager: ZombieWaveManager = mg.zombie_manager.zombie_wave_manager if mg.zombie_manager != null else null
	snap[&"ws"] = wave_manager != null and wave_manager.is_wave_started
	## ★ **玩家阳光总量**（钱包里那个数，不是场上飘着的那一颗）为什么也进快照：
	## 一颗阳光谁捡到都是**屋里每个人各自的钱包各加一次**（`Sun.collect()` 在各自那份里跑），
	## 所以两端的钱包本来就该始终相等；可这个数是靠一条条 `pick_sun` 命令堆出来的，
	## 丢一条就**永久分叉** —— 命令只管事件，不管"现在到底有多少钱"。快照每帧报一遍，分叉自愈。
	## ⚠️ 只有本关真有出战卡槽时才有钱包（没有卡槽就不发，免得客户端被 0 清零）
	var battle_slot: CardSlotBattle = mg.card_manager.card_slot_battle if mg.card_manager != null else null
	if battle_slot != null:
		snap[&"sv"] = int(battle_slot.sun_value)

	## ★ **出战卡槽里的卡**（`cd_type` / `cd_id` / `cd_imit` / `cd_cool`）：
	## 主机那一侧会改卡槽（关卡脚本中途加 / 撤一张、戴夫卖出卡槽扩充）也会改冷却 ——
	## 客户端那一局读的是**自己**的卡槽，主机改完了它不会跟着变 ⇒ 两端手里的卡就不一样了，
	## 后面"拿起哪一张 / 花多少阳光 / 还有几秒能用"每一步都对不上。
	## ⚠️ 身份照 `ResourceCardReference` 拆成三个数字发，不走 `to_dict()` 的字典数组 ——
	##   十来个字典塞进一个包，光键名就顶掉小半截预算（见文件头「包体与 MTU」）。
	## ⚠️ 本关没有出战卡槽时（传送带关）整组都不发，客户端照 `has()` 判空跳过（同 `sv`）。
	var cd_type := PackedInt32Array()
	var cd_id := PackedStringArray()
	var cd_imit := PackedByteArray()
	var cd_cool := PackedFloat32Array()
	if battle_slot != null:
		for card: Card in battle_slot.curr_cards:
			if card == null or not is_instance_valid(card):
				continue
			if card.card_reference == null or not card.card_reference.is_valid():
				continue
			if cd_id.size() >= MAX_CARDS:
				snap[&"cd_cut"] = true
				break
			cd_type.append(int(card.card_reference.card_type))
			cd_id.append(str(card.card_reference.content_id))
			cd_imit.append(1 if card.card_reference.is_imitater else 0)
			cd_cool.append(card.cool_remain)
		snap[&"cd_type"] = cd_type
		snap[&"cd_id"] = cd_id
		snap[&"cd_imit"] = cd_imit
		snap[&"cd_cool"] = cd_cool

	## ★ **传送带上每一张卡的 x**（`cv_x`）：只拨位置，**不动卡数**
	##
	## 为什么连位置都要发：两端各自在 `_process()` 里按 `conveyor_velocity` 推卡片位移，
	## 帧率与起跑时刻都不同 ⇒ 跑一会儿位置就岔开了（同一张卡两端不在同一处）。
	## ⚠️ **有意不发名单**："有哪几张卡"由 `OP_CARD_SPAWN` 逐条下发（reliable，不会丢），
	## 而名单纠偏会与种植消耗打架（客户端种成即消耗、主机要等 op，这一来一回会让客户端
	## 每拿一张就多补一张）—— 那份偏差不值得用抖动去换，见 `_align_conveyor_x()`。
	var cv_x := PackedFloat32Array()
	var belt: CardSlotConveyorBelt = mg.card_manager.card_slot_conveyor_belt if mg.card_manager != null else null
	if belt != null and is_instance_valid(belt):
		for card: Card in belt.curr_cards:
			if card == null or not is_instance_valid(card):
				continue
			if cv_x.size() >= MAX_CONVEYOR:
				break
			cv_x.append(card.position.x)
		snap[&"cv_x"] = cv_x

	var left := BYTE_BUDGET - RESERVE_PROGRESS - RESERVE_SUN_VALUE \
			- cd_id.size() * BYTES_PER_CARD - cv_x.size() * BYTES_PER_CONVEYOR

	## 植物：id / 类型 / 格子 / 血量
	##
	## ★ 为什么连类型与格子都要发：只发血量的话，客户端**没法补种** ——
	## 一条种植命令在路上丢了 / 晚到，客户端就永远少这一株，而快照这一层存在的意义
	## 恰恰是"能把少的补回来"。带上类型与格子，客户端就能照名册自己种出来。
	var p_cap := _cap_for(BYTES_PER_PLANT, MAX_PLANTS, left - RESERVE_SUNS)
	var p_id := PackedInt32Array()
	var p_type := PackedStringArray()
	var p_cell := PackedInt32Array()
	var p_hp := PackedFloat32Array()
	var p_render := PackedInt32Array()
	var p_anim := PackedByteArray()
	if mg.plant_cell_manager != null:
		for row in mg.plant_cell_manager.all_plant_cells:
			for cell in row:
				if not is_instance_valid(cell):
					continue
				for place in cell.plant_in_cell:
					if p_id.size() >= p_cap:
						snap[&"p_cut"] = true
						break
					## ⚠️ 只能走 `get_plant()`：植物死了槽位不清，直接下标会拿到已释放实例
					## （`get_plant()` 没标返回类型，`var x :=` 推断不出来，必须写明类型）
					var plant: Plant000Base = cell.get_plant(place)
					if not is_instance_valid(plant) or plant.entity_id == 0:
						continue
					p_id.append(plant.entity_id)
					p_type.append(str(plant.plant_type))
					p_cell.append(_pack_cell(cell))
					p_hp.append(_hp_of(plant))
					p_render.append(_pack_plant_render(plant))
					p_anim.append(_anim_index_of(plant))
					snap[&"p_id"] = p_id
					snap[&"p_type"] = p_type
					snap[&"p_cell"] = p_cell
					snap[&"p_hp"] = p_hp
					snap[&"p_render"] = p_render
					snap[&"p_anim"] = p_anim
	left -= p_id.size() * BYTES_PER_PLANT

	## 阳光：id / 面值 / 位置（场上飘着的每一颗，客户端照着补 / 删）
	var s_cap := _cap_for(BYTES_PER_SUN, MAX_SUNS, left)
	var s_id := PackedInt32Array()
	var s_value := PackedInt32Array()
	var s_x := PackedFloat32Array()
	var s_y := PackedFloat32Array()
	if mg.suns != null:
		for child in mg.suns.get_children():
			var sun := child as Sun
			if sun == null or not is_instance_valid(sun) or sun.entity_id == 0:
				continue
			if s_id.size() >= s_cap:
				snap[&"s_cut"] = true
				break
			s_id.append(sun.entity_id)
			s_value.append(sun.sun_value)
			s_x.append(sun.position.x)
			s_y.append(sun.position.y)
	snap[&"s_id"] = s_id
	snap[&"s_value"] = s_value
	snap[&"s_x"] = s_x
	snap[&"s_y"] = s_y

	return snap


## 格子的二维下标压成一个 int（行 × 100 + 列，列不会到 100）
static func _pack_cell(cell: PlantCell) -> int:
	var rc: Vector2i = cell.row_col
	return rc.x * 100 + rc.y


static func _unpack_cell(packed: int) -> Vector2i:
	## 与打包那边的 ×100 配对，这里要的就是整除取整，小数部分本就该丢掉
	@warning_ignore("integer_division")
	var row := packed / 100
	return Vector2i(row, packed % 100)


## 还剩 `bytes` 字节时，这一类最多能装几条
static func _cap_for(bytes_per_entry: int, hard_cap: int, bytes: int) -> int:
	if bytes_per_entry <= 0:
		return 0
	## 「还剩这么多字节够装几条」本来就该向下取整，小数部分丢掉是对的
	@warning_ignore("integer_division")
	var count := maxi(bytes, 0) / bytes_per_entry
	return mini(hard_cap, count)


## 当前血量（组件被摘掉时按 0 算，别让快照炸在这一行）
func _hp_of(character: Character000Base) -> float:
	if character == null or character.hp_component == null:
		return 0.0
	return float(character.hp_component.curr_hp)
#endregion


#region 对齐（客户端）
## 收到主机那份真相 ⇒ 照着把本地摆成同一副样子
func _on_state_snapshot_received(snap: Dictionary) -> void:
	if _session == null or _session.is_host():
		return
	var mg := _resolve_main_game()
	if mg == null:
		return
	_apply_snapshot(mg, snap)


func _apply_snapshot(mg: MainGameManager, snap: Dictionary) -> void:
	_align_zombies(mg, snap)
	_align_bullets(mg, snap)
	_align_bosses(mg, snap)


func _on_state_snapshot_extra_received(snap: Dictionary) -> void:
	if _session == null or _session.is_host():
		return
	var mg := _resolve_main_game()
	if mg == null:
		return
	_apply_snapshot_extra(mg, snap)


## 第二包：植物名册 + 场上阳光 + 战斗进度条 + 出战卡槽（两包独立，丢了谁都不影响另一类）
func _apply_snapshot_extra(mg: MainGameManager, snap: Dictionary) -> void:
	_align_plants(mg, snap)
	_align_suns(mg, snap)
	_apply_progress(mg, snap)
	_apply_sun_value(mg, snap)
	_align_cards(mg, snap)
	_align_conveyor_x(mg, snap)


## 战斗进度条：主机说几成就是几成，客户端**不自己算**
##
## 为什么不自己算：进度是从 `curr_wave` 推出来的，而客户端已经不维护波次了
## （波次归主机、出怪归快照，见 `NetplayWaveSync`）；而且关卡脚本可以换掉进度口径，
## 自己照波次算出来的那份未必是本关真正在用的那份。
func _apply_progress(mg: MainGameManager, snap: Dictionary) -> void:
	if mg.zombie_manager == null:
		return
	var wave_manager: ZombieWaveManager = mg.zombie_manager.zombie_wave_manager
	if wave_manager == null:
		return
	wave_manager.battle_progress = float(snap.get(&"pr", 0.0))
	wave_manager.is_wave_started = bool(snap.get(&"ws", false))


## 玩家阳光总量：主机说有多少就是多少，客户端**不自己记账**
##
## ⚠️ 只在**不一样**时才写回去：`sun_value` 的 setter 会遍历每一张卡重判"阳光够不够"
## （`judge_sun_enough`），每帧白跑一遍不值当。
func _apply_sun_value(mg: MainGameManager, snap: Dictionary) -> void:
	## ⚠️ 必须判 `has`：主机这一关没有出战卡槽时压根不发这一条，照默认 `0` 取值会把钱包清零
	if not snap.has(&"sv"):
		return
	if mg.card_manager == null:
		return
	var battle_slot: CardSlotBattle = mg.card_manager.card_slot_battle
	if battle_slot == null:
		return
	var value := int(snap[&"sv"])
	if int(battle_slot.sun_value) != value:
		battle_slot.sun_value = value


## 出战卡槽：**有哪几张卡 + 每张还剩几秒冷却**都以主机为准
##
## ★ 为什么要整体对齐而不只是对冷却：主机那一侧会改卡槽（关卡脚本中途加 / 撤一张、
##   戴夫卖出卡槽扩充），客户端照自己那份跑就不会跟着变 ⇒ 手里拿的卡与主机不是同一副。
## ⚠️ **选卡阶段一律不动**（`CHOOSE_CARD` / `RE_CHOOSE_CARD`）：那两个阶段两端**各挑各的卡**
##   （§4.2.2 只保证不重复），卡槽正被玩家自己摆弄 —— 照主机覆盖等于把他刚挑好的卡冲掉。
func _align_cards(mg: MainGameManager, snap: Dictionary) -> void:
	## ⚠️ 必须判 `has`：主机这一关没有出战卡槽时（传送带关）压根不发这一组
	if not snap.has(&"cd_id"):
		return
	## ⚠️ 主机这一帧**没把卡槽报全**（超过 `MAX_CARDS` 被截断）⇒ 这一帧**整个不动**：
	## 截断下来的那份是一个**残缺的名单**，照它对齐会把没报上来的那几张当成"主机撤掉了"
	## 给删掉 —— 宁可这一帧不同步，也不能把玩家的卡删错。
	if bool(snap.get(&"cd_cut", false)):
		return
	if mg.card_manager == null:
		return
	var battle_slot: CardSlotBattle = mg.card_manager.card_slot_battle
	if battle_slot == null or not is_instance_valid(battle_slot):
		return
	if mg.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
		return
	var cards := _cards_of(snap)
	## 身份序列没变就**只刷冷却**：动卡槽会把每张卡正在跑的遮罩 / 位置一并打断
	var ids := _card_sig_of(snap)
	if ids != _last_card_ids:
		_last_card_ids = ids
		battle_slot.set_cards(cards[&"refs"])
	_apply_card_cool(battle_slot, cards[&"cools"])


## 传送带：把每一张卡的 x 拨到主机那一份（**只动位置，不动卡数**）
##
## ★ 为什么只拨位置：两端各跑各的 `conveyor_velocity`，帧率与起跑时刻都不同 ⇒ 同一张卡
## 两端会逐渐岔开；而"有哪几张"由 `OP_CARD_SPAWN` 逐条下发（reliable），不需要快照再来一遍。
##
## ⚠️ **张数对不上就整帧不动**：覆盖是按下标的，两端张数不同说明这一端正在补卡 / 刚消耗掉
## 一张，两条队列**不同序** —— 硬盖只会把卡片挪到别人的位置上（看着像卡乱跳）。
## 宁可这一帧不同步，也不能挪错。
func _align_conveyor_x(mg: MainGameManager, snap: Dictionary) -> void:
	if not snap.has(&"cv_x"):
		return
	if mg.card_manager == null:
		return
	var belt: CardSlotConveyorBelt = mg.card_manager.card_slot_conveyor_belt
	if belt == null or not is_instance_valid(belt):
		return
	var xs: PackedFloat32Array = snap.get(&"cv_x", PackedFloat32Array())
	if xs.size() != belt.curr_cards.size():
		return
	for i in range(xs.size()):
		var card := belt.curr_cards[i] as Card
		if card == null or not is_instance_valid(card):
			continue
		card.position.x = xs[i]


## 这批卡的身份压成的数字序列（类别 × `CARD_SIG_TYPE_BASE` + 编号 × 2 + 是否模仿者）
## —— 只用来比"变没变"，比整包字典便宜得多
static func _card_sig_of(snap: Dictionary) -> PackedInt32Array:
	var cd_type: PackedInt32Array = snap.get(&"cd_type", PackedInt32Array())
	var cd_id: PackedStringArray = snap.get(&"cd_id", PackedStringArray())
	var cd_imit: PackedByteArray = snap.get(&"cd_imit", PackedByteArray())
	var out := PackedInt32Array()
	for i in range(_card_count(snap)):
		## content_id 现在是字符串 id，签名改用它的 hash —— 这一串只用来比"变没变"，
		## 用 hash 就够，不需要能反查回 id
		out.append(cd_type[i] * CARD_SIG_TYPE_BASE \
			+ hash(cd_id[i]) % CARD_SIG_TYPE_BASE * 2 + int(cd_imit[i]))
	return out


## 快照里那批卡：`refs` 是身份（顺序照主机卡槽，造出来的是**独立引用**，不跟任何人共享），
## `cools` 是同一批卡各自的剩余冷却
##
## ⚠️ 为什么两样要在**同一个循环**里成对取：编号非法的那一条是要丢掉的，分成两个循环
## 各丢一次的话，丢完之后"第 i 张卡"对上的就不是"第 i 个冷却"了 —— 冷却会张冠李戴。
static func _cards_of(snap: Dictionary) -> Dictionary:
	var cd_type: PackedInt32Array = snap.get(&"cd_type", PackedInt32Array())
	var cd_id: PackedStringArray = snap.get(&"cd_id", PackedStringArray())
	var cd_imit: PackedByteArray = snap.get(&"cd_imit", PackedByteArray())
	var cd_cool: PackedFloat32Array = snap.get(&"cd_cool", PackedFloat32Array())
	var refs: Array[ResourceCardReference] = []
	var cools := PackedFloat32Array()
	for i in range(_card_count(snap)):
		var reference := ResourceCardReference.create(cd_type[i], cd_id[i], bool(cd_imit[i]))
		## 编号不在枚举里 / 类别为 Null 的那一条直接丢掉，别把非法引用塞进卡槽
		if reference == null or not reference.is_valid():
			continue
		refs.append(reference)
		cools.append(cd_cool[i] if i < cd_cool.size() else 0.0)
	return {&"refs": refs, &"cools": cools}


## 这一组卡数组**共同**的长度（三条数组理论上一边长，取最短的当作有效条数，
## 免得主机改了字段却漏发一条时下标越界）
static func _card_count(snap: Dictionary) -> int:
	var cd_type: PackedInt32Array = snap.get(&"cd_type", PackedInt32Array())
	var cd_id: PackedStringArray = snap.get(&"cd_id", PackedStringArray())
	var cd_imit: PackedByteArray = snap.get(&"cd_imit", PackedByteArray())
	return mini(cd_id.size(), mini(cd_type.size(), cd_imit.size()))


## 每张卡还剩几秒冷却：主机说几秒就是几秒，客户端**不自己数**
##
## ⚠️ 两端各自 `_process` 都在往下数，而主机那一轮开始得更早（它先跑的重放）——
##   照主机报的数摆，遮罩走的才是**同一条时间线**。
## ⚠️ 都是 0 的那一张直接跳过：`set_card_cool_remain(0)` 要走 `judge_card_ready()`
##   （紫卡还要查一遍种植条件），每帧白跑一遍不值当。
func _apply_card_cool(battle_slot: CardSlotBattle, cools: PackedFloat32Array) -> void:
	for i in range(mini(battle_slot.curr_cards.size(), cools.size())):
		var card: Card = battle_slot.curr_cards[i]
		if card == null or not is_instance_valid(card):
			continue
		if card.cool_remain <= 0.0 and cools[i] <= 0.0:
			continue
		card.set_card_cool_remain(cools[i])


## 僵王：位置 / 血量覆盖；主机有本地没有的补一只；主机没有的连续缺席够了才删
##
## ★ 为什么必须能补种：客户端**不出怪**，僵王也就不自己出场（它是主机那边按波次
## `try_auto_spawn_boss()` 触发的），所以客户端那一侧压根没有僵王 —— 不补就是
## "主机在打僵王、客户端看不见"。这与僵尸同一条道理（僵尸也全靠快照补种）。
func _align_bosses(mg: MainGameManager, snap: Dictionary) -> void:
	if mg.zombie_manager == null:
		return
	var zb_id: PackedInt32Array = snap.get(&"zb_id", PackedInt32Array())
	var zb_type: PackedStringArray = snap.get(&"zb_type", PackedStringArray())
	var zb_x: PackedFloat32Array = snap.get(&"zb_x", PackedFloat32Array())
	var zb_y: PackedFloat32Array = snap.get(&"zb_y", PackedFloat32Array())
	var zb_hp: PackedFloat32Array = snap.get(&"zb_hp", PackedFloat32Array())
	var zb_death: PackedInt32Array = snap.get(&"zb_death", PackedInt32Array())

	var local := {}
	for boss in _boss_list(mg):
		local[boss.entity_id] = boss

	var seen := {}
	for i in range(zb_id.size()):
		var id := zb_id[i]
		seen[id] = true
		var target := Vector2(zb_x[i], zb_y[i])
		## 写明类型：快照里存的是 String，缺省值是 StringName，不标的会被推断成 Variant
		var boss_type: StringName = zb_type[i] if i < zb_type.size() else ZombieBossIds.NULL
		if local.has(id):
			var boss: ZB000Base = local[id]
			if not is_instance_valid(boss):
				continue
			boss.global_position = boss.global_position.lerp(target, POS_LERP)
			if boss.hp_component != null:
				boss.hp_component.curr_hp = int(zb_hp[i])
			## 主机说它死了而本地还没死 ⇒ 补一次死亡表现。
			## 为什么必须补：客户端自己不再结算伤害，
			## 就永远走不到本地的死亡流程，僵王会 0 血站着，直到缺席 90 帧被凭空删掉。
			var is_death := i < zb_death.size() and zb_death[i] != 0
			if is_death and not boss.is_death and boss.hp_component != null:
				boss.hp_component.hp_loss_to_death(false)
		else:
			_spawn_boss(mg, id, boss_type, target)

	if not _is_cut(snap, &"zb_cut"):
		_reap_missing(mg, local, seen, _delete_boss)


## 照主机的编号补一只僵王
func _spawn_boss(mg: MainGameManager, id: int, boss_type: StringName, pos: Vector2) -> void:
	if mg.zombie_manager == null:
		return
	## 拿不到类型就不造 —— 宁可这一只在客户端不显示，也不能造错一种
	## （僵王卡牌召唤出来的那一只，见 `_boss_type_of` 的已知限制）
	if boss_type == ZombieBossIds.NULL:
		return
	## ⚠️ 走**卡牌召唤**入口而不是自动入口 `create_boss()`：后者每关只成功一次
	## （registry 里 `_auto_boss_spawned` 挡着），客户端补种时那一次早被主机用掉了。
	var boss := mg.zombie_manager.try_create_boss_from_card(boss_type)
	if boss == null:
		return
	boss.assign_entity_id(id)
	boss.global_position = pos


func _delete_boss(boss) -> void:
	if is_instance_valid(boss):
		boss.queue_free()


## 子弹：位置覆盖；主机有本地没有的照类型造一颗；主机没有的缺席几帧就删
func _align_bullets(mg: MainGameManager, snap: Dictionary) -> void:
	if mg.bullets == null:
		return
	var b_id: PackedInt32Array = snap.get(&"b_id", PackedInt32Array())
	var b_type: PackedStringArray = snap.get(&"b_type", PackedStringArray())
	var b_x: PackedFloat32Array = snap.get(&"b_x", PackedFloat32Array())
	var b_y: PackedFloat32Array = snap.get(&"b_y", PackedFloat32Array())

	var local := {}
	for child in mg.bullets.get_children():
		var bullet := child as Bullet000Base
		if bullet != null and is_instance_valid(bullet) and bullet.entity_id != 0:
			local[bullet.entity_id] = bullet

	var seen := {}
	for i in range(b_id.size()):
		var id := b_id[i]
		seen[id] = true
		var target := Vector2(b_x[i], b_y[i])
		if local.has(id):
			var bullet: Bullet000Base = local[id]
			if is_instance_valid(bullet):
				## 直接吸附不用 `POS_LERP`：子弹飞得快，插值会一直落在后面拖出一条残影
				bullet.global_position = target
		else:
			_spawn_bullet(mg, id, b_type[i], target)

	## ⚠️ 主机那一帧**截断**了（实体太多装不下）就不能回收：
	## 本地这几颗只是"主机这一帧没采到"，不是"主机那边没有了" —— 回收会把它们误删
	if not _is_cut(snap, &"b_cut"):
		_reap_missing(mg, local, seen, _delete_bullet, MISS_FRAMES_BEFORE_DELETE_BULLET)


## 僵尸：位置 / 血量覆盖；主机有本地没有的补一只；主机没有的连续缺席够了才删
func _align_zombies(mg: MainGameManager, snap: Dictionary) -> void:
	if mg.zombie_manager == null:
		return
	var z_id: PackedInt32Array = snap.get(&"z_id", PackedInt32Array())
	var z_type: PackedStringArray = snap.get(&"z_type", PackedStringArray())
	var z_lane: PackedInt32Array = snap.get(&"z_lane", PackedInt32Array())
	var z_anim: PackedByteArray = snap.get(&"z_anim", PackedByteArray())
	var z_render: PackedInt32Array = snap.get(&"z_render", PackedInt32Array())
	var z_x: PackedFloat32Array = snap.get(&"z_x", PackedFloat32Array())
	var z_y: PackedFloat32Array = snap.get(&"z_y", PackedFloat32Array())
	var z_hp: PackedFloat32Array = snap.get(&"z_hp", PackedFloat32Array())

	var local := {}
	for z in mg.zombie_manager.all_zombies_1d.duplicate():
		if is_instance_valid(z) and z.entity_id != 0:
			local[z.entity_id] = z
			## 客户端的僵尸一律转"只渲染"（只做一次，内部用 meta 记着）
			_make_zombie_render_only(z)

	var seen := {}
	for i in range(z_id.size()):
		var id := z_id[i]
		seen[id] = true
		var target := Vector2(z_x[i], z_y[i])
		## `z_lane` 就是纯行号（正在播哪条动画在另一条 `z_anim` 里）
		var lane := z_lane[i]
		var anim := z_anim[i] if i < z_anim.size() else ANIM_NONE
		var render := z_render[i] if i < z_render.size() else 0
		if local.has(id):
			var z: Zombie000Base = local[id]
			if not is_instance_valid(z):
				continue
			z.global_position = z.global_position.lerp(target, POS_LERP)
			_apply_hp_display(z.hp_component, int(z_hp[i]))
			_apply_anim(z, anim)
			_apply_zombie_render(z, render)
		else:
			## 补一只：多半是"主机这一波先出生 / 包到得晚"，照主机的编号生出来
			var born := _spawn_zombie(mg, id, z_type[i], lane, target)
			if born != null:
				## ⚠️ `anim` 也要当场写：主机报的常常是一只**正在倒地**的僵尸，
				## 只写 render 不写 anim 的话，补出来的这只这一帧还在播"走路"
				_apply_anim(born, anim)
				_apply_zombie_render(born, render)

	## ⚠️ 同上：主机这一帧截断过就不能回收（否则僵尸一多，装不下的那批会被客户端误删）
	if not _is_cut(snap, &"z_cut"):
		_reap_missing(mg, local, seen, _delete_zombie)


## 这一帧主机把这一类**截断**了吗（实体太多装不下，见 `BYTE_BUDGET`）？
## 截断过就**不能回收**：本地多出来的那几颗只是"主机这一帧没采到"，不是"主机那边没有了"。
static func _is_cut(snap: Dictionary, key: StringName) -> bool:
	return bool(snap.get(key, false))


## 【主机侧】这一刻正在播的动画在动画列表里的**下标**
##
## ★ 为什么发"哪一条动画"而不是那 7 个状态字段，见文件头「动画」那一节。
## 下标两端天然一致（实例化的是同一份 .tscn），所以**不需要任何"动画名 → 编号"的映射表**。
##
## ⚠️⚠️ **动画名只能问动画组件**（`AnimComponentBase.update_current_anim()`），不能读
## `AnimationPlayer.current_animation`：动画树驱动角色时那个字段**恒为空**（树走自己的
## playback、从不调 `play()`），照它采的结果是 `z_anim` 恒为 255、客户端从不接管 ——
## 整条动画同步静默空转（3 倍速下表现为"客户端纹丝不动地原速播"）。
static func _anim_index_of(character: Character000Base) -> int:
	if character == null or not is_instance_valid(character.anim_component):
		return ANIM_NONE
	character.anim_component.update_current_anim()
	var anim_name := character.anim_component.anim_name_now
	if anim_name == &"":
		return ANIM_NONE
	var player := _anim_player_of(character)
	if player == null:
		return ANIM_NONE
	var idx := _anim_list_of(player).find(anim_name)
	## 下标必须落在 `ANIM_NONE` 之下 —— 它是单字节投递的，255 被留作"不接管"的占位符
	return ANIM_NONE if idx < 0 or idx >= ANIM_NONE else idx


## 这个播放器的动画列表（**缓存**：每帧每只调一次 `get_animation_list()` 太贵，
## 而列表在角色实例化之后就不再变 —— 两端都是同一份 .tscn，缓存不会造成错位）
## ⚠️ 必须先 `has_meta` 再 `get_meta`：`get_meta(key, 默认值)` 在键不存在时**照样会
## push_error**（引擎日志里刷一行 ERROR），默认值只是让它不崩。
static func _anim_list_of(player: AnimationPlayer) -> PackedStringArray:
	if player.has_meta(&"netplay_anim_list"):
		return player.get_meta(&"netplay_anim_list")
	var list := player.get_animation_list()
	player.set_meta(&"netplay_anim_list", list)
	return list


## 【客户端侧】接管这个角色的动画：关掉动画树的状态机，改由快照直接驱动
##
## ⚠️ **必须**关：`AnimComponentNorm` 那条路是 AnimationTree 用 `advance_expression`
## 每帧读 `is_death` / `is_attack` / `walk_status` … **自己挑**动画，我们 `play()` 的那一条
## 下一帧就被它换回去 —— "发了等于没发"。关掉之后 AnimationPlayer 完全归快照管。
## 只做一次（meta 记着，幂等）。
static func _take_over_anim(character: Character000Base) -> void:
	if character == null or not is_instance_valid(character):
		return
	if character.has_meta(&"netplay_anim_taken"):
		return
	character.set_meta(&"netplay_anim_taken", true)
	if not is_instance_valid(character.anim_component):
		return
	var norm := character.anim_component as AnimComponentNorm
	if norm == null or not is_instance_valid(norm.animation_tree):
		return
	norm.animation_tree.active = false


## 【客户端侧】照主机播同一条动画
##
## 只做"名字不一样就 `play()`"这一件事 —— 播到**第几秒**由 `z_render` / `p_render` 里的
## phase 管（`_apply_anim_phase`）；两条合起来才是完整的"播哪一条、播到第几秒"。
static func _apply_anim(character: Character000Base, idx: int) -> void:
	if idx == ANIM_NONE or character == null or not is_instance_valid(character):
		return
	_take_over_anim(character)
	var player := _anim_player_of(character)
	if player == null:
		return
	var list := _anim_list_of(player)
	if idx >= list.size():
		return
	var anim_name := list[idx]
	if player.current_animation == anim_name or not player.has_animation(anim_name):
		return
	player.play(anim_name)


## 这类僵尸有没有这个"动画变体"属性？按**脚本**缓存 —— `get_property_list()` 每帧调太贵
##
## ⚠️ 缓存键必须按**脚本**算，不能用 `get_class()`：它返回的是**引擎基类**
## （普僵和僵尸基类都是同一个），结果两只僵尸共用一个键 —— 先查的那只把结果污染给另一只，
## 于是普僵被判成"没有走路变体"，变体永远同步不过去。
## ⚠️ 参数只能写 `Node`（或更宽的基类）：这个函数僵尸和植物**共用**——
## 早先写成 `Zombie000Base`，`_hp_stage_comp_of()` 拿植物去调就直接报
## "The Object-derived class of argument 1 ... is not a subclass of the expected argument class"。
func _has_prop(target_node: Node, prop: StringName) -> bool:
	if target_node == null:
		return false
	var key := _anim_prop_cache_key(target_node)
	var props: Dictionary = _anim_prop_cache.get(key, {})
	if props.has(prop):
		return bool(props[prop])
	var found := false
	for info in target_node.get_property_list():
		if StringName(info["name"]) == prop:
			found = true
			break
	props[prop] = found
	_anim_prop_cache[key] = props
	return found


## 缓存键：优先用脚本路径（每个 `.gd` 唯一），拿不到才退回 `get_class()`
func _anim_prop_cache_key(target_node: Node) -> StringName:
	## ⚠️ 这里必须写死类型：`var node_script = get_script()` 是 Variant，
	## 后面 `var path := node_script.resource_path` 会**推断不出类型**而整份脚本解析失败
	## 变量名不叫 script：本类继承 Node，`script` 是 Object 的属性，同名会触发 SHADOWED_VARIABLE_BASE_CLASS
	var node_script: Script = target_node.get_script()
	if node_script != null:
		var path: String = node_script.resource_path
		if not path.is_empty():
			return StringName(path)
	return StringName(target_node.get_class())


#region 渲染状态的采集与写回（★ 由主机下发，客户端照着演）
# 位布局与"为什么非发不可"的完整理由见文件头「渲染状态」那一节。

## 僵尸的渲染状态打包成一个 int（掉手 / 掉头、防具破损、受击变亮、动画播到第几帧）
func _pack_zombie_render(z: Zombie000Base) -> int:
	var packed := 0
	var stage := _hp_stage_comp_of(z)
	if stage != null:
		packed |= _pack_stage(stage.curr_hp_stage) << RENDER_Z_STAGE_SHIFT
	## 每层防具的破损阶段（防具是挂在同一角色下的 ArmorComponent，可能不止一层）
	var armors := _zombie_armors_of(z)
	for i in mini(armors.size(), RENDER_Z_ARMOR_SLOT_COUNT):
		packed |= _pack_stage(armors[i].curr_hp_stage) \
			<< (RENDER_Z_ARMOR_SLOT0_SHIFT + i * RENDER_STAGE_BITS)
	if z.body != null:
		packed |= (z.body.body_light_count & RENDER_LIGHT_MASK) << RENDER_Z_LIGHT_SHIFT
	packed |= _anim_phase_packed_of(z) << RENDER_Z_PHASE_SHIFT
	return packed


func _apply_zombie_render(z: Zombie000Base, packed: int) -> void:
	_apply_body_light(z, (packed >> RENDER_Z_LIGHT_SHIFT) & RENDER_LIGHT_MASK)
	_apply_hp_stage(z,
		(packed >> RENDER_Z_STAGE_SHIFT) & RENDER_STAGE_MASK,
		(packed >> RENDER_Z_ARMOR_SLOT0_SHIFT) & RENDER_STAGE_MASK,
		(packed >> RENDER_Z_ARMOR_SLOT1_SHIFT) & RENDER_STAGE_MASK)
	_apply_phase(z, (packed >> RENDER_Z_PHASE_SHIFT) & RENDER_Z_PHASE_MASK)


## 植物的渲染状态打包成一个 int（坚果裂纹、受击变亮、产阳光还剩多久、动画播到第几秒）
func _pack_plant_render(p: Plant000Base) -> int:
	var packed := 0
	var stage := _hp_stage_comp_of(p)
	if stage != null:
		packed |= _pack_stage(stage.curr_hp_stage) << RENDER_P_STAGE_SHIFT
	if p.body != null:
		packed |= (p.body.body_light_count & RENDER_LIGHT_MASK) << RENDER_P_LIGHT_SHIFT
	var sun := _create_sun_comp_of(p)
	if sun != null and is_instance_valid(sun.create_sun_timer):
		if not sun.create_sun_timer.is_stopped():
			packed |= RENDER_P_SUN_RUNNING
		packed |= _pack_sun_time(sun.create_sun_timer.time_left) << RENDER_P_SUN_TIME_SHIFT
	packed |= _anim_phase_packed_of(p) << RENDER_P_PHASE_SHIFT
	return packed


func _apply_plant_render(p: Plant000Base, packed: int) -> void:
	_apply_body_light(p, (packed >> RENDER_P_LIGHT_SHIFT) & RENDER_LIGHT_MASK)
	## 植物没有防具阶段，后两个传 0（编码 0 = "没有这个阶段" ⇒ `_apply_hp_stage` 不会动它）
	_apply_hp_stage(p, (packed >> RENDER_P_STAGE_SHIFT) & RENDER_STAGE_MASK, 0, 0)
	_apply_create_sun(p, packed)
	_apply_phase(p, (packed >> RENDER_P_PHASE_SHIFT) & RENDER_P_PHASE_MASK)


## -1（未受损）编码成 0，实际阶段 n 编码成 n+1 ⇒ 0 同时表示"这个角色没有阶段组件"
static func _pack_stage(stage: int) -> int:
	return clampi(stage + 1, 0, RENDER_STAGE_MASK)


static func _pack_phase(phase: float) -> int:
	return clampi(int(round(phase / PHASE_STEP)), 0, RENDER_Z_PHASE_MASK)


static func _unpack_phase(packed: int) -> float:
	return float(packed) * PHASE_STEP


static func _pack_sun_time(time_left: float) -> int:
	return clampi(int(round(time_left / SUN_TIME_STEP)), 0, RENDER_P_SUN_TIME_MASK)


## 受击变亮：主机的计数变了 ⇒ 客户端补一次 `body_light()`
##
## ⚠️ 为什么是"计数变了才补"而不是"每帧写 modulate"：发光本体是一条 0.5 秒的 tween，
## 直接写颜色会被正在跑的 tween 下一帧盖回去；而每帧重开 tween 就永远回不到白色。
## ⚠️ 补种出来那一帧**只记值、不补闪**（`last < 0` 那条）：主机报的往往是一只已经挨过打的
## 僵尸（计数早就不是 0），客户端不该在它出现的瞬间莫名亮一下。
func _apply_body_light(character: Character000Base, light_count: int) -> void:
	if character == null or character.body == null:
		return
	## ⚠️ 同上：`get_meta` 带默认值也会在键不存在时 push_error，所以先 `has_meta`
	var last := int(character.get_meta(LIGHT_COUNT_META, -1)) \
		if character.has_meta(LIGHT_COUNT_META) else -1
	if last < 0:
		character.set_meta(LIGHT_COUNT_META, light_count)
		return
	if last == light_count:
		return
	character.set_meta(LIGHT_COUNT_META, light_count)
	character.body.body_light()


## 照主机下发的阶段号补掉手 / 掉头 / 防具破损
##
## ⚠️ 只把"目标阶段对应的**临界值**"喂给 `judge_body_change()`：它内部那个 `for` 循环里
## `curr_hp_stage = i` 是**当场**更新的，所以一次调用会把欠下的所有阶段级联补上，
## 不用自己写循环。防具那边同理（`ArmorComponent.apply_stage_from_snapshot()`）。
## ⚠️ 编码是"阶段 + 1"，所以目标实际阶段是 `packed_stage - 1`；0 表示"没有这个阶段"，
## 那时 `stage - 1 == -1`，`curr_hp_stage < -1` 恒假 ⇒ 自然什么都不做。
## [param armor0] / [param armor1] 前两层防具的阶段号，按挨打顺序对号入座
func _apply_hp_stage(character: Character000Base, stage: int, armor0: int, armor1: int) -> void:
	var c := _hp_stage_comp_of(character)
	if c == null:
		return
	if c.curr_hp_stage < stage - 1 and not c.boundary_value_hp.is_empty():
		c.judge_body_change(c.boundary_value_hp[mini(stage - 1, c.boundary_value_hp.size() - 1)], true)
	var armors := _zombie_armors_of(character)
	var packed_armors := [armor0, armor1]
	for i in mini(armors.size(), RENDER_Z_ARMOR_SLOT_COUNT):
		armors[i].apply_stage_from_snapshot(packed_armors[i])


## 取一个角色的防具列表（按挨打顺序）；非僵尸 / 没有僵尸血量组件时返回空数组
static func _zombie_armors_of(character: Character000Base) -> Array[ArmorComponent]:
	var zombie := character as Zombie000Base
	if zombie == null:
		return []
	var hp_component := zombie.hp_component as HpComponentZombie
	if hp_component == null:
		return []
	return hp_component.get_all_armors()


## 血量只用来**画血条**，不写回 `curr_hp`
##
## ★ **为什么连 `curr_hp` 都不写了**：它的 setter 在 `value <= death_hp` 时会**直接判死**
## （而僵尸的 `death_hp` 是**掉头线、不是 0** —— `HpStageChangeComponent` 把它写成
## `boundary_value_hp` 的最后一项，见 `component_critical_value.gd` 的头注）。
##
## 客户端一旦"自己判死"，就得反过来补一堆本地流程才补得回表现：补 `hp_loss_to_death()`
## 才有倒地、补阶段号才有掉手掉头、还得给一次性动画开"不对表"的特例免得跳过倒地……
## 那是拿本地逻辑**猜**主机那边发生了什么，补丁叠补丁。
##
## 统一成"发播哪条动画 + 第几秒"之后，客户端根本**不需要"死"这个状态**：
## 倒地就是 `z_anim` 里的一条动画，掉手 / 掉头就是 `z_render` 里的阶段号。
## 血量剩下的唯一用处是血条那一条 —— 直接画上去，连 setter 都不碰。
static func _apply_hp_display(hp_comp: HpComponent, hp: int) -> void:
	if hp_comp == null or not is_instance_valid(hp_comp):
		return
	hp_comp.label_hp.text = str(maxi(hp, 0))
	## `max_hp` 兜底成 1：除零会得到 `nan` / `inf`，血条会画成一条诡异的实心色块
	hp_comp.progress_bar_hp.value = float(maxi(hp, 0)) / maxi(hp_comp.max_hp, 1)


## 从 `*_render` 里解出相位并应用（僵尸与植物共用，位布局各有一条 `RENDER_*_PHASE_SHIFT`）
##
## ⚠️ `PHASE_NONE` = 主机那边没在播 ⇒ 客户端**别动**播放头（理由见 `PHASE_NONE` 那一节）。
func _apply_phase(character: Character000Base, phase_packed: int) -> void:
	if phase_packed == PHASE_NONE:
		return
	_apply_anim_phase(character, _unpack_phase(phase_packed))


## 动画播到第几秒：主机说到哪儿就把播放头拉到哪儿
##
## ★ **速度差就是靠这一行抹平的**：客户端的播放器始终按自己那份 1 倍速往前走，
## 而主机开 3 倍速时它报的相位每包前进 3 倍的距离 —— 差出来的那部分被这里一次次 `seek()`
## 抹掉，**平均**下来客户端的播放速度就等于主机的速度（代价是每两包跳一下的顿挫）。
## 不发倍速字段也能跟上倍速，靠的就是这个"相位差 ⇒ 硬拉"的闭环。
##
## ⚠️ 只在**偏得明显**时才 `seek()`（`PHASE_RESYNC_EPS`）：播放头本来每帧都在自己往前走，
## 每帧硬拉会跟它打架，表现为动画抖动。两端速度一致时，纠过一次之后偏差基本不再增长，
## 所以实际上只在"刚补种出来"那一下、以及冰冻 / 加速这类速度差上才纠。
## ⚠️ 客户端的动画树已被接管（`_take_over_anim`），这里不会再有状态机来抢播放头。
## ⚠️ 也不能对空播放头动手：本地还没 `play()` 过时一样会刷那条 ERROR（同 `_anim_has_head`）。
func _apply_anim_phase(character: Character000Base, phase: float) -> void:
	var player := _anim_player_of(character)
	if not _anim_has_head(player):
		return
	if absf(player.current_animation_position - phase) < PHASE_RESYNC_EPS:
		return
	player.seek(clampf(phase, 0.0, maxf(player.current_animation_length, 0.0)), true)


## 向日葵"准备产出"那一下发光：把本地的 `CreateSunTimer` 对到主机的剩余时间
##
## 亮不亮是 `create_sun()` 里那条 tween 决定的（body 调制成 2 倍、再 0.5 秒回白），
## 而它是在 `CreateSunTimer` **到点**时被调起来的 —— 两端各自 `randf_range(3, 12.5)`
## 抽的间隔必然不同 ⇒ 客户端会在错误的时间点自己亮一次。对表之后就落在同一刻。
## ⚠️ 产阳光本身**不用管**：客户端那一份已被 `GlobalUtils.sun_spawn_gate` 拦掉，
## 场上那一颗由 `NetplaySunSync` 的 `sun_spawn` 命令下发。
func _apply_create_sun(p: Plant000Base, packed: int) -> void:
	var sun := _create_sun_comp_of(p)
	if sun == null or not is_instance_valid(sun.create_sun_timer):
		return
	var timer := sun.create_sun_timer
	if (packed & RENDER_P_SUN_RUNNING) == 0:
		if not timer.is_stopped():
			timer.stop()
		return
	var host_left := float((packed >> RENDER_P_SUN_TIME_SHIFT) & RENDER_P_SUN_TIME_MASK) * SUN_TIME_STEP
	## ⚠️ 只在偏得明显时才对表：每帧 `start()` 等于每帧把计时器按回原点，它永远走不到头
	if absf(timer.time_left - host_left) <= SUN_TIME_RESYNC_EPS:
		return
	timer.stop()
	timer.start(host_left)


## 角色真正在播的那个 AnimationPlayer（动画树与纯播放器两种角色各一条路）
##
## ⚠️ 走**基类** `AnimComponentBase` 拿不到播放器：只有两个子类各自持有
## （`AnimComponentNorm` 持 `animation_tree`、`AnimComponentPlayer` 持 `animation_player`），
## 而 `AnimComponentEmpty`（保龄球植物）两个都没有 ⇒ 返回 null。
##
## ⚠️ 标了 `static`：主机侧的 `_anim_index_of()` 与客户端侧的 `_apply_anim()` 都是静态的
## （它们只吃参数、不碰实例状态），静态函数调不到非静态的 —— 这个函数本身也不碰。
static func _anim_player_of(character: Character000Base) -> AnimationPlayer:
	if character == null or not is_instance_valid(character.anim_component):
		return null
	var player: AnimationPlayer = null
	## ⚠️ 必须先 `as` 成子类再取：`anim_component` 是**基类** `AnimComponentBase`，
	## 在基类上直接写 `.animation_tree` 取到的是 Variant（`var tree :=` 推断不出类型）
	var norm := character.anim_component as AnimComponentNorm
	if norm != null:
		var tree: AnimationTree = norm.animation_tree
		if tree != null and is_instance_valid(tree):
			## ⚠️ `AnimationTree.anim_player` 是 **NodePath**，不是节点本身
			player = tree.get_node_or_null(tree.anim_player) as AnimationPlayer
	else:
		var pl := character.anim_component as AnimComponentPlayer
		if pl != null:
			player = pl.animation_player
	return player if is_instance_valid(player) else null


## 这个播放器的播放头有效吗（即：有一条正在播的动画）
##
## ⚠️ **为什么必须先探**：`current_animation` 为空时读 `current_animation_position` /
## `current_animation_length` 会刷一行 ERROR（"AnimationPlayer has no current animation."）
## —— 每只僵尸每帧都要采一次，一刷就是满屏，还看不出是哪只。
## 什么情况会空：非循环动画自然播完、刚被 `stop()`、动画树刚接管还没 `play()`。
static func _anim_has_head(player: AnimationPlayer) -> bool:
	return player != null and is_instance_valid(player) and player.current_animation != &""


## 【主机侧】动画播到第几秒 —— 返回的是**打包后可直投 `z_render` 的 int**
##
## ⚠️ 为什么返回打包值而不是 float：拿不到播放头时必须落成 `PHASE_NONE` 占位，
## 而 float 表达不了"没有相位"这件事 —— 返回 0.0 会被客户端当成"把播放头拉回第一帧"。
## ★ 同 `_anim_index_of()`：问组件，不要读播放器（动画树驱动时播放器是空的）。
func _anim_phase_packed_of(character: Character000Base) -> int:
	if character == null or not is_instance_valid(character.anim_component):
		return PHASE_NONE
	character.anim_component.update_current_anim()
	var pos := character.anim_component.anim_position_now
	if pos < 0.0:
		return PHASE_NONE
	return _pack_phase(pos)


## 取血量阶段组件（僵尸在基类上有 `hp_stage_change_component`，植物是同名子节点）
##
## ⚠️ 两边的接口不统一：`Zombie000Base` / 僵王把组件挂在**基类属性**上，而坚果 / 南瓜头 /
## 大蒜那些植物是各自脚本里 `$HpStageChangeComponent` 取的 —— `Plant000Base` 上没有这个属性。
## 所以先探属性（`_has_prop`，按脚本缓存）、探不到再按节点名找。
func _hp_stage_comp_of(character: Character000Base) -> HpStageChangeComponent:
	if character == null:
		return null
	if _has_prop(character, &"hp_stage_change_component"):
		var c := character.get(&"hp_stage_change_component") as HpStageChangeComponent
		if is_instance_valid(c):
			return c
	## ⚠️ `^"..."` 是 **NodePath** 字面量；写成 `&"..."`（StringName）过不了 `get_node_or_null()`
	var node := character.get_node_or_null(^"HpStageChangeComponent") as HpStageChangeComponent
	return node if is_instance_valid(node) else null


## 取产阳光组件（向日葵 / 阳光菇 / 双子向日葵）；没有这个组件的角色返回 null
static func _create_sun_comp_of(character: Character000Base) -> CreateSunComponent:
	if character == null:
		return null
	var c := character.get_node_or_null(^"CreateSunComponent") as CreateSunComponent
	return c if is_instance_valid(c) else null
#endregion


#region 客户端僵尸转"只渲染"
##
## 客户端的僵尸**只负责演**：不索敌、不移动、不啃、不被打、不跳、不爆炸 ——
## 一切**行为逻辑**全部关掉，判定全交给主机。
## 动画由 `z_anim` 下发（见 `_apply_anim`），所以关掉判定**不会**让动画停 ——
## 这正是当初必须先把动画同步下来的原因：顺序反了就是"僵尸 0 血站着走"。
##
## ★ **为什么连 `move_component` 也要关**（早先这里写着"不动它"）：
## 移动本身就是**行为逻辑** —— 客户端一旦自己走，走的就是它自己那份模拟
## （减速、冰冻、啃食停顿、被吸住…这些状态客户端只收到**结果**，并不推演过程），
## 必然与主机不同步。位置一律由快照拉齐（每帧 `POS_LERP`），本地那份位移纯属多余且有害。
##
## ★ **关掉移动的前提：截断时不能让谁永远收不到位置**（配套改动见 `_z_cursor`）：
## 早先不动它的理由很具体 —— 快照**截断**时（场上僵尸太多装不下）那几只既收不到位置、
## 又不会被回收，会**僵在原地**；那时移动组件还能让它们继续走，把破绽盖住。
## 现在移动也关了，这个破绽必须由**采集侧**补上 ⇒ 截断时下一帧从没采到的那一只接着采（轮转）。
##
## ⚠️ **关掉移动会丢的表现**（这条原则的已知代价）：移动组件顺带管着屋顶斜面 / 爬梯
## 那部分 y 修正（`move_y_correct_slope` / 爬梯）。客户端的僵尸因此**不走斜面修正** ——
## 位置本身（含 y）仍然是主机下发下来的，缺的只是那一点贴合斜面的偏移。
##
## ★ **为什么不动植物**：植物的开火动画长在攻击组件里，停掉它植物就只剩静止贴图；
## 而"客户端不自己造子弹"已经由 `GlobalUtils.bullet_spawn_gate` 兜住了。
const RENDER_ONLY_META := &"netplay_render_only"

## 只渲染时要**关掉**的组件（行为逻辑）
##
## ⚠️ 前三个在 `Zombie000Base` 上一定有；后面那些是**可选**的，只有特定僵尸才有
## （撑杆 / 跳跳 / 海豚有 `jump_component`，小丑有 `bomb_component_jackbox`），
## 所以统一走 `_optional_component()` 探测 —— 没有就跳过。
const BEHAVIOR_COMPONENT_PROPS: Array[StringName] = [
	&"attack_component", &"hurt_box_component", &"move_component",
	&"detect_component", &"detect_component_pogo",
	&"jump_component", &"bomb_component_jackbox",
]

## 只渲染时**保留**的组件（纯表现，不产生任何判定）：
## `hp_stage_change_component`（血量阶段换外观）、`charred_component`（焦黑）、
## `critical_value_component`（临界掉手 / 掉头）—— 它们由**血量**驱动，而血量是主机下发的。
## ⚠️ `drop_item_component`（掉落）**不必**禁：它已被掉落闸门拦住（客户端不掉东西）。
##
## ⚠️ 光"血量是主机下发的"**还不够**：`HpComponent.curr_hp` 的 setter 不发掉血信号，
## 而客户端是**直接赋值**拉齐的 ⇒ 掉手 / 掉头在客户端根本不会演。所以阶段号单独进快照
## 的 `z_render`，由 `_apply_hp_stage()` 照主机报的阶段补（见「渲染状态」那一节）。


## 把这只僵尸的行为逻辑关掉，只留下渲染
func _make_zombie_render_only(z: Zombie000Base) -> void:
	if bool(z.get_meta(RENDER_ONLY_META, false)):
		return
	## ⚠️ `disable_component` 是**粘的**：它把 Netplay 这个因素置成 false，之后任何人
	## `enable_component(别的因素)` 都拉不回来（`is_enabling` 是所有因素的**与**）。
	## 死亡 / 魅惑 / 睡眠这些正常流程里的启用不会把这道闸门顶开。
	## ⚠️ 攻击组件内部会连带禁用它自己的检测组件（见 `AttackComponentBase.disable_component`）。
	var factor := ComponentNormBase.E_IsEnableFactor.Netplay
	var all_ready := true
	for prop in BEHAVIOR_COMPONENT_PROPS:
		var c := _optional_component(z, prop)
		if c == null:
			## 基类上该有的那几个若为 null，说明组件还是 `@onready` 未就位 —— 下一帧再来
			if prop == &"attack_component" or prop == &"hurt_box_component" \
					or prop == &"move_component":
				all_ready = false
			continue
		c.disable_component(factor)
	if not all_ready:
		## ⚠️ meta **先不落**：免得"这一次没关成"被记成"已经关过了"
		return
	z.set_meta(RENDER_ONLY_META, true)


## 取一个**可选**组件（不是每类僵尸都有） —— 没有就返回 null
##
## ⚠️ 走属性探测而不是直接 `z.get()`：后者取不存在的属性会**报错**
## （撑杆僵尸有 `jump_component`，普僵没有）。探测结果按**脚本**缓存，见 `_has_prop`。
func _optional_component(z: Zombie000Base, prop: StringName) -> ComponentNormBase:
	if not _has_prop(z, prop):
		return null
	var c := z.get(prop) as ComponentNormBase
	return c if is_instance_valid(c) else null
#endregion


## 植物：照名册对齐 —— 血量覆盖、主机有本地没有的**补种**、多出来的缺席够了才回收
##
## ★ 为什么现在要能"凭空种一棵"：早先这里只拉血量，理由是"种植是命令同步的事"。
## 但命令只保证"做了什么一致"，**不保证客户端真的有这一株** ——
## 一条种植命令迟到 / 在换关的接缝里被吞掉，客户端就永远少这一株，
## 而快照这一层存在的意义恰恰是"能把少的补回来"。不补种，这一层对植物就等于没有。
##
## ⚠️ 误删会不会把玩家刚种的抖掉：不会。种植命令是 **reliable**，
## 一个 RTT 内主机的快照里就会带上这一株，而缺席阈值有 90 帧（1.5 秒），裕量大。
func _align_plants(mg: MainGameManager, snap: Dictionary) -> void:
	if mg.plant_cell_manager == null:
		return
	var p_id: PackedInt32Array = snap.get(&"p_id", PackedInt32Array())
	var p_type: PackedStringArray = snap.get(&"p_type", PackedStringArray())
	var p_cell: PackedInt32Array = snap.get(&"p_cell", PackedInt32Array())
	var p_hp: PackedFloat32Array = snap.get(&"p_hp", PackedFloat32Array())
	var p_render: PackedInt32Array = snap.get(&"p_render", PackedInt32Array())
	var p_anim: PackedByteArray = snap.get(&"p_anim", PackedByteArray())

	## ① 先建主机这一帧的名册：下面判"谁的编号不在名册里"要用到它
	var seen := {}
	for i in range(p_id.size()):
		seen[p_id[i]] = true

	## ② 本地名册按编号索引；顺手把**编号不在主机名册里**的收进孤儿池
	##
	## ★ 孤儿从哪来：客户端自己种下的那一株，编号是**本地自增**出来的
	## （`Character000Base.take_next_entity_id()`，两端各数各的），天生和主机报的号不同。
	## 不认领的后果就是实测到的那个死循环：`local.has(id)` 永远 false ⇒ 每帧
	## `_spawn_plant()` ⇒ 撞在"该格已有植物"上（`create_plant()` 直接 return null）
	## ⇒ 下一帧再来，每帧刷一条"当前位置已经有植物"。
	var local := {}
	var orphans := {}
	for row in mg.plant_cell_manager.all_plant_cells:
		for cell in row:
			if not is_instance_valid(cell):
				continue
			for place in cell.plant_in_cell:
				var plant: Plant000Base = cell.get_plant(place)
				if is_instance_valid(plant) and plant.entity_id != 0:
					local[plant.entity_id] = plant
					if not seen.has(plant.entity_id):
						var key := _orphan_key(cell.row_col, plant.plant_type)
						if not orphans.has(key):
							orphans[key] = []
						var pool: Array = orphans[key]
						pool.append(plant)

	for i in range(p_id.size()):
		var id := p_id[i]
		var render := p_render[i] if i < p_render.size() else 0
		var anim := p_anim[i] if i < p_anim.size() else ANIM_NONE
		var rc := _unpack_cell(p_cell[i])
		var plant: Plant000Base = local.get(id)
		if plant == null:
			## 编号对不上 ⇒ 先试着按"格子 + 类型"认领一株孤儿；认不出才补种
			plant = _claim_orphan(orphans, local, rc, p_type[i], id)
		if plant == null:
			_spawn_plant(mg, id, p_type[i], rc, render)
			continue
		_apply_hp_display(plant.hp_component, int(p_hp[i]))
		_apply_anim(plant, anim)
		_apply_plant_render(plant, render)

	## 主机这一帧截断过就不能回收（同上：那几株只是"没采到"，不是"没有了"）
	if not _is_cut(snap, &"p_cut"):
		_reap_missing(mg, local, seen, _delete_plant)


## 照主机的名册补种一株（客户端漏了的那些）
## [render] 主机这一帧报的渲染状态 —— 补出来那一下就写上去，不等下一帧（理由同 `_spawn_zombie`）
func _spawn_plant(mg: MainGameManager, id: int, plant_type: StringName, rc: Vector2i, render: int = 0) -> Plant000Base:
	if mg.plant_cell_manager == null:
		return null
	var cells := mg.plant_cell_manager.all_plant_cells
	if rc.x < 0 or rc.x >= cells.size():
		return null
	var row = cells[rc.x]
	if rc.y < 0 or rc.y >= row.size():
		return null
	var cell: PlantCell = row[rc.y]
	if not is_instance_valid(cell):
		return null
	## ⚠️ 第三参数 `is_plant_start_effect = false`：补种**不该**再放一次种植特效，
	## 那是"刚种下"的表现；补的是"主机那边早就有了、本地漏了"的那一株。
	## ⚠️ `place`（槽位）不用传：它由植物自己的种植条件决定，`create_plant()` 会放对
	var plant: Plant000Base = cell.create_plant(plant_type, false, false)
	if not is_instance_valid(plant):
		return null
	## `create_plant()` 里已经入树领过号了，这里改成主机的编号，两端才认得同一株
	plant.assign_entity_id(id)
	_apply_plant_render(plant, render)
	return plant


## 孤儿池的键：格子 + 植物类型（同一格同一种的，谁认领哪株都一样）
func _orphan_key(rc: Vector2i, plant_type: StringName) -> String:
	return "%d/%d/%s" % [rc.x, rc.y, plant_type]


## 认领一株孤儿：把它的编号改成主机报的那个，两端从此认得同一株
##
## ⚠️ 旧编号必须同时从本地名册里退出：否则 `_reap_missing()` 会把它当成
## "主机名册里没有的那一株"去缺席计数，攒够阈值就把刚认领的植物删掉。
func _claim_orphan(orphans: Dictionary, local: Dictionary,
		rc: Vector2i, plant_type: StringName, id: int) -> Plant000Base:
	var pool: Array = orphans.get(_orphan_key(rc, plant_type), [])
	if pool.is_empty():
		return null
	var plant := pool.pop_front() as Plant000Base
	if not is_instance_valid(plant):
		return null
	local.erase(plant.entity_id)
	plant.assign_entity_id(id)
	local[id] = plant
	return plant


## 阳光：位置覆盖；主机有本地没有的补一颗；主机没有的缺席够了才回收
##
## ★ 为什么要进快照：`NetplaySunSync` 那条是**离散命令**（多一颗 / 少一颗各发一条），
## 命令只管事件、不管"现在场上到底有几颗"。哪一包在乱序里晚到、或者本地多长了一颗，
## 命令这条路上没有东西纠正得回来 —— 快照每帧整份报一遍，漏了的能补、多了的能删。
func _align_suns(mg: MainGameManager, snap: Dictionary) -> void:
	if mg.suns == null:
		return
	var s_id: PackedInt32Array = snap.get(&"s_id", PackedInt32Array())
	var s_value: PackedInt32Array = snap.get(&"s_value", PackedInt32Array())
	var s_x: PackedFloat32Array = snap.get(&"s_x", PackedFloat32Array())
	var s_y: PackedFloat32Array = snap.get(&"s_y", PackedFloat32Array())

	var local := {}
	for child in mg.suns.get_children():
		var sun := child as Sun
		if sun != null and is_instance_valid(sun) and sun.entity_id != 0:
			local[sun.entity_id] = sun

	var seen := {}
	for i in range(s_id.size()):
		var id := s_id[i]
		seen[id] = true
		var target := Vector2(s_x[i], s_y[i])
		if local.has(id):
			var sun: Sun = local[id]
			if not is_instance_valid(sun):
				continue
			## ⚠️ 正在跑下落 tween 的那颗**不要**覆盖位置：命令通道那颗正在演"弹起来再落下"，
			## 快照每帧吸附会把它按死在半空（两端都看得到它不动，只是不动的位置不同）。
			## 落定之后 tween 就结束了，位置才交回快照管。
			if _is_sun_falling(sun):
				continue
			sun.position = target
		else:
			_spawn_sun(mg, id, s_value[i], target)

	if not _is_cut(snap, &"s_cut"):
		_reap_missing(mg, local, seen, _delete_sun, MISS_FRAMES_BEFORE_DELETE_SUN)


## 这颗是不是还在下落？（见 `_align_suns` 里"不要覆盖位置"那段）
func _is_sun_falling(sun: Sun) -> bool:
	return sun.spawn_sun_tween != null and sun.spawn_sun_tween.is_valid() \
		and sun.spawn_sun_tween.is_running()


## 返回补出来的那一只（补失败返回 null），调用方要**当场**把渲染状态写上去 ——
## 否则新生的这一只要等下一帧才轮到 `_align_zombies()` 拉齐，那一帧它是按本地默认值演的
func _spawn_zombie(mg: MainGameManager, id: int, zombie_type: StringName, lane: int, pos: Vector2) -> Zombie000Base:
	## 行号越界（换过地图 / 数据不对）就别生，省得挂到错误的行节点上
	if mg.zombie_manager == null or lane < 0 or lane >= mg.zombie_manager.all_zombie_rows.size():
		return null
	var para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrWave: -1,
	}
	var z := mg.zombie_manager.create_norm_zombie(zombie_type, null, para, pos)
	if z == null:
		return null
	## `create_norm_zombie()` 里已经入树领过号了，这里改成主机的编号，两端才认得同一只
	z.assign_entity_id(id)
	## ★ **当场**就转"只渲染"，不能等下一帧：`_align_zombies()` 只对**上一帧已经在场**的
	## 那几只转，新补出来的这一只要等到下一帧才轮到 —— 那整整一帧它在跑本地逻辑
	## （索敌 / 移动 / 啃植物），啃出来的伤害主机那一局上根本没有，两端立刻分叉。
	## 组件若还没 `@onready` 就位，这一句会自己放弃（meta 不落），下一帧照旧重试。
	_make_zombie_render_only(z)
	return z


func _spawn_sun(mg: MainGameManager, id: int, sun_value: int, pos: Vector2) -> void:
	var sun: Sun = SceneRegistry.SUN.instantiate()
	if sun == null:
		return
	sun.assign_entity_id(id)
	sun.init_sun(sun_value, pos)
	mg.suns.add_child(sun)


## 本地有、主机连续好几帧都没有的实体 ⇒ 删掉（多半是主机那边已经死了 / 被捡了）
## [threshold] 缺席多少帧才判删；子弹比僵尸短得多（见 `MISS_FRAMES_BEFORE_DELETE_BULLET`）
func _reap_missing(_mg: MainGameManager, local: Dictionary, seen: Dictionary, delete: Callable,
		threshold: int = MISS_FRAMES_BEFORE_DELETE) -> void:
	for id in local.keys():
		if seen.has(id):
			_missing.erase(id)
			continue
		var missed := int(_missing.get(id, 0)) + 1
		if missed < threshold:
			_missing[id] = missed
			continue
		_missing.erase(id)
		delete.call(local[id])


func _delete_zombie(z) -> void:
	if is_instance_valid(z):
		z.queue_free()


## 回收"主机那边没有的"植物
##
## ⚠️ 为什么不走 `PlantCell.one_plant_free()`：它**只发信号**（`signal_plant_free`）
## 和收拾梯子 / 容器，**不删节点**（里面那句清空槽位的代码是被注释掉的）。
## 这里要的是"把这株真的移除"，所以直接 `queue_free()`。
## 槽位里留下的悬空引用由 `get_plant()` + `is_instance_valid()` 兜住 ——
## 植物正常死亡走的也是同一条路（槽位不清），不是这条路新引入的。
func _delete_plant(plant) -> void:
	if is_instance_valid(plant):
		plant.queue_free()


func _delete_sun(sun) -> void:
	if is_instance_valid(sun):
		sun.queue_free()


## 照主机的类型造一颗子弹（客户端不自己开火，场上的子弹全是从这里长出来的）
func _spawn_bullet(mg: MainGameManager, id: int, bullet_type: StringName, pos: Vector2) -> void:
	## ⚠️ `is_ignore_gate = true`：客户端自己占着"不造子弹"的闸门，重建必须绕过它，
	## 否则客户端一颗都造不出来（场上完全没有豌豆）。只有这条重建路径能传 true。
	var bullet := Global.bullet_registry.create_bullet(bullet_type, true)
	if bullet == null or mg.bullets == null:
		return
	bullet.assign_entity_id(id)
	mg.bullets.add_child(bullet)
	bullet.global_position = pos
	## ★ 这是一颗**木偶**：位置每帧由快照写，它自己不要再算飞行与命中
	## （`_physics_process` 里既跑位移也跑命中判定，留着就是客户端在跑战斗逻辑）。
	## 代价：子弹自己的动画 / 旋转（比如抛物线的翻滚）不走了 —— 待办，见 §4.11。
	bullet.set_physics_process(false)


func _delete_bullet(b) -> void:
	if is_instance_valid(b):
		b.queue_free()
#endregion


## 本节点记录的这一局还活着就用它，否则退回去问 `GameContext.curr_main_game`
func _resolve_main_game() -> MainGameManager:
	if _main_game != null and is_instance_valid(_main_game):
		return _main_game
	var mg: MainGameManager = GameContext.curr_main_game
	return mg if is_instance_valid(mg) else null


func _notify(text: String) -> void:
	if _notice.is_valid():
		_notice.call(text)
