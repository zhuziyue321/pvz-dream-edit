extends RefCounted
class_name NetplayCommand
## 联机命令：玩家操作的可序列化表示
##
## 为什么要有这一层：本体的玩家操作（`GlobalUtils.player_action_gate` 上报的那几种）
## 带的 payload 直接是对象（`Card` / `PlantCell` / `Sun`…），对象引用过不了网络。
## 命令把它压成**纯数据字典**：
##   { "op": 操作名, "args": { 只有 int / float / String / Vector2i } }
## 主机收到后按 op 在本机重放（重放逻辑属于下一阶段，本文件只定义"怎么打包 / 解包"）。
##
## ★ 命名纪律（模组机制边界规则 6 的同款理由）：这里出现的是"操作"，不是"联机"，
##   将来单机回放 / 录像也能复用同一份命令定义。
##
## 关联：本机采集在 [NetplayActionGateway](netplay_action_gateway.gd) ｜
## 本体的操作种类见 `GlobalUtils.E_PlayerAction`

## 点了铲子（参数：空）
const OP_CLICK_SHOVEL := &"click_shovel"
## 点了某一格草地（参数：row / col + **手里那张卡的身份与花费**）—— 种植物 / 铲植物是同一枚入口，
## 手里拿着什么就做什么，主机重放时不替调用方猜意图
##
## ★ 为什么点格子要带上"是哪一张卡"：**拿起植物是本地的**（客户端自己校验，手感不等主机回话），
##   主机那一局里根本没有客户端手里这一张 —— 不带卡的话主机重放这一步等于什么都没发生。
##   带上身份，主机照着它拿起**同一张**，再跑一遍本体的种植校验（见 [联机模组规范] §3.2）。
const OP_CLICK_CELL := &"click_cell"
## 捡起一颗阳光（参数：实体编号）—— 说清"哪一颗"而不是"多少点"，
## 主机才能在自己这一局上摘掉**同一颗**（只带数值的话，两端会各自记一笔不一样的账）
const OP_PICK_SUN := &"pick_sun"
## 天上掉了一颗阳光（参数：实体编号 + 阳光值 + 起点 / 落点）—— 只有主机喊得动，
## 客户端照着这个数据在**同一处**掉一颗同样的（天降的定时器各跑各的，摇不出同一颗）
const OP_SUN_SPAWN := &"sun_spawn"
## 掉了一件战利品（参数：实体编号 + 种类 + 起点 / 落点）—— 只有主机喊得动。
## 与阳光同款：掉不掉、掉哪一种、落在哪儿都是**战斗逻辑**，客户端一律不自己判
const OP_DROP_ITEM := &"drop_item"
## 捡起一件掉落物（参数：实体编号）—— 与 `OP_PICK_SUN` 同一条链路，说清"哪一枚"
const OP_PICK_DROP := &"pick_drop"
## 主机开了新的一波（参数：波次号 + 是不是大波 / 最终波 + 要升哪面旗）—— 只有主机喊得动
##
## ★ 这一条下发的是"**演什么**"，**不是"出什么怪"**：客户端收到后只把旗帜与
##   「一大波僵尸正在接近」那一段演出播出来，**不自己开波、也不自己出怪** ——
##   场上的僵尸一律由状态广播（`NetplayStateSync`）按主机编号补出来。
##   （为什么连"出什么怪"都不下发：出怪是**连续状态**，"场上现在有哪几只"快照每帧都在报，
##   再走一条命令只会多一个"两边谁先到"的竞态；演出是**一次性事件**，只能走可靠命令。）
## （不是"玩家操作"，走的是 `battle_op` 那条下行通道，见 `NetplayWaveSync`）
const OP_WAVE_NEXT := &"wave_next"
## 主机这一段**打完了**（参数：空）—— 只有主机喊得动，理由与 `OP_WAVE_NEXT` 同一条：
##
## ★ 客户端**自己永远算不出"打完了"**：它一次波都不开（`start_next_wave_gate` 恒 false），
##   `is_end_wave` 永远等不到真；场上的僵尸又是快照补出来的木偶，死也不走本地死亡流程，
##   `curr_zombie_num` 只增不减。少这一条，关卡流程里「本段打完了吗」那个轮询在客户端
##   永远等不到真 ⇒ 流程卡在开战那一步 ⇒ 本关走不到判胜 ⇒ 客户端拿不到本关给的植物。
## （不是"玩家操作"，走的是 `battle_op` 那条下行通道，见 `NetplayWaveSync`）
const OP_BATTLE_FINISHED := &"battle_finished"
## 主机出了一张卡（参数：卡的身份 + 从哪个卡槽出 + 落点）—— 只有主机喊得动
##
## 与 `OP_SUN_SPAWN` 同一条道理：传送带是从**随机池**里抽的（`CardRandomPool` 走全局
## `randi_range`），种子雨（天降卡）连落点都是 `randf_range` —— 两端各跑各的，抽出来的
## **不是同一张卡**。客户端手里那一张主机没有，点下去主机重放时认不出它，
## 这一下操作就凭空消失了。所以"出哪一张、掉在哪儿"归主机，客户端照着重建同一张。
## （不是"玩家操作"，走的是 `battle_op` 那条下行通道，见 `NetplayCardSpawnSync`）
const OP_CARD_SPAWN := &"card_spawn"
## 连通性测试（参数：空）
const OP_PING := &"ping"

## 命令参数里的字段名（写出来是为了不让字符串散在收发两端）
const ARG_ROW := "row"
const ARG_COL := "col"
## 阳光值（`OP_SUN_SPAWN` 用：掉下来的这一颗值多少）
const ARG_SUN_VALUE := "sun_value"
## 阳光的实体编号（`OP_PICK_SUN` / `OP_SUN_SPAWN` 用）
const ARG_SUN_ID := "sun_id"
## 阳光出现的位置（`OP_SUN_SPAWN` 用，Vector2 可直接进 RPC）
const ARG_FROM := "from"
## 阳光落到的位置（`OP_SUN_SPAWN` 用）
const ARG_TO := "to"
## 阳光掉这一趟用了多少秒（`OP_SUN_SPAWN` 用：两端的下落动画要一样快）
const ARG_FALL := "fall"
## 掉落物的**种类**（`OP_DROP_ITEM` 用，见 `NetplayDropSync.E_Kind`）
const ARG_DROP_KIND := "drop_kind"
## 波次号（`OP_WAVE_NEXT` 用）
const ARG_WAVE := "wave"
## 这一波要升起的旗帜下标（`OP_WAVE_NEXT` 用，-1 = 不升）
##
## 只有旗帜波与最终波升旗，序号跟本体同一个口径：`int(curr_wave % max_wave_one_round / 10.0)`
## （见 `ZombieWaveManager.start_next_wave()` 里调 `set_progress_bar()` 的那两处）。
## ⚠️ 主机**不要**去读 `ZombieWaveManager._flag_to_raise`：那是**一次性**的
##   （`take_flag_raise_index()` 读走即清），主机抢读了，主机自己的旗就升不起来了。
const ARG_FLAG := "flag"
## 是不是最终波（`OP_WAVE_NEXT` 用）—— 决定那一段演出播的是"最终"那一版
const ARG_FINAL := "final"
## 是不是大波（`OP_WAVE_NEXT` 用：旗帜波 / 最终波）—— 只有大波才有那一段演出
const ARG_BIG := "big"
## 一张卡的身份（`OP_CARD_SPAWN` / `OP_CLICK_CELL` 用）—— 就是 `ResourceCardReference.to_dict()`
## 那三个标量（`card_type` / `content_id` / `is_imitater`），能直接进 RPC；对端用 `from_dict()` 还原
const ARG_CARD_REF := "card_ref"
## 这一张卡此刻的阳光花费（`OP_CLICK_CELL` 用）：卡**只在那个人自己的卡槽里**，
## 主机那一局上没有它 —— 花多少由"手里拿着这一张的人"报，主机照着扣同样的数
## （紫卡会随场上株数加价，主机自己算不出来，只能照报的数扣）
const ARG_SUN_COST := "sun_cost"
## 种成之后**新植株的实体编号**（`OP_CLICK_CELL` 用）：由主机种成后回填进这条命令，
## 客户端照着把自己刚种下那一株改写成同一个号 —— 两端从此认得同一株植物。
## 不带的后果见 `NetplayBattleSync._claim_fresh_plant()`。
const ARG_NEW_ID := "new_id"

## 字典键名（写出来是为了不让字符串散在收发两端）
const KEY_OP := "op"
const KEY_ARGS := "args"


## 打包一条命令
static func build(op: StringName, args: Dictionary = {}) -> Dictionary:
	return {KEY_OP: op, KEY_ARGS: args}


## 取操作名（不是命令字典 / 没写 op 时返回空 StringName）
static func op_of(data: Dictionary) -> StringName:
	if not data is Dictionary:
		return &""
	return StringName(str(data.get(KEY_OP, "")))


## 取参数（缺失或类型不对时返回空字典）
static func args_of(data: Dictionary) -> Dictionary:
	if not data is Dictionary:
		return {}
	var args: Variant = data.get(KEY_ARGS, {})
	return args if args is Dictionary else {}


## 是否是一条能认的命令
static func is_valid(data: Dictionary) -> bool:
	return op_of(data) != &""


## 本体的玩家操作（`GlobalUtils.E_PlayerAction`）→ 命令操作名（认不出的返回空 StringName）
##
## ★ 为什么按**操作**而不是按 `EventBus` 事件映射：本体给玩家操作的统一上报口是
##   `GlobalUtils.player_action_gate`（见 [联机模组规范](../../docs/参考存档/联机模组规范.md) §3.5），
##   它带的是**操作种类**，不是事件名 —— 点格子 / 捡阳光 / 捡掉落物压根没有对应的事件。
##   照操作映射，"本体那一次点击"与"网络上的这一条命令"才是一一对应的。
##
## ⚠️ 这里**没有**"加了多少阳光"这种按**数值**上报的操作：说不清"点的是哪一颗"。
##   拾取上行的是**实体编号**（见 `OP_PICK_SUN`），主机才能在自己这一局上摘掉同一颗。
## ⚠️ 这里**没有**点卡（`ClickCard`）：拿起植物是**本地**的（客户端自己校验阳光 / 冷却），
##   不在命令表里 —— 主机那一局里没有这一张卡，上行了它也拿不起来（见 §3.2）。
##   "种不种得下去"由点格子那一步带上卡的身份交给主机校验。
static func op_from_action(action: int) -> StringName:
	match action:
		GlobalUtils.E_PlayerAction.ClickShovel:
			return OP_CLICK_SHOVEL
		GlobalUtils.E_PlayerAction.ClickCell:
			return OP_CLICK_CELL
		GlobalUtils.E_PlayerAction.PickSun:
			return OP_PICK_SUN
		GlobalUtils.E_PlayerAction.PickDrop:
			return OP_PICK_DROP
	return &""


## 本体的玩家操作 + payload → 命令参数（只留可序列化的标量，对象一律换成身份 / 编号 / 下标）
##
## 拿不出参数的返回空字典 —— 调用方据此**不接管**（让本体照单机那样本地跑）。
static func args_from_action(action: int, payload: Array) -> Dictionary:
	match action:
		GlobalUtils.E_PlayerAction.ClickShovel:
			return {}
		GlobalUtils.E_PlayerAction.ClickCell:
			return _args_of_click_cell(payload)
		GlobalUtils.E_PlayerAction.PickSun:
			return _args_of_entity(payload, ARG_SUN_ID)
		GlobalUtils.E_PlayerAction.PickDrop:
			return _args_of_entity(payload, ARG_SUN_ID)
	return {}


## 点某一格：row / col，外加**手里那一张卡的身份与花费**（手上没卡就只有格子）
##
## ★ 为什么要带卡：两端是各挑各的卡（选卡协商只保证**不重复**），客户端拿起的那一株
##   主机手上没有 —— 主机只能照着身份自己拿起一张同样的，才知道要种什么、扣多少阳光。
static func _args_of_click_cell(payload: Array) -> Dictionary:
	var cell: PlantCell = payload[0] if payload.size() > 0 and payload[0] is PlantCell else null
	if cell == null or not is_instance_valid(cell):
		return {}
	var args := {
		ARG_ROW: cell.row_col.x,
		ARG_COL: cell.row_col.y,
	}
	var card := held_card()
	if card != null and card.card_reference != null:
		args[ARG_CARD_REF] = card.card_reference.to_dict()
		args[ARG_SUN_COST] = card.sun_cost
	return args


## 捡一个场上实体（阳光 / 掉落物）：上行的是**编号**，不是数值（理由见 `OP_PICK_SUN`）
static func _args_of_entity(payload: Array, key: String) -> Dictionary:
	if payload.size() == 0:
		return {}
	var target = payload[0]
	if target == null or not is_instance_valid(target):
		return {}
	var entity_id := int(target.get("entity_id")) if _has_prop(target, &"entity_id") else 0
	if entity_id == 0:
		return {}
	return {key: entity_id}


## 这个对象上有没有这个属性（捡的东西不止一种，直接 `get` 不存在的属性会报错）
static func _has_prop(target, prop: StringName) -> bool:
	for info in target.get_property_list():
		if StringName(info["name"]) == prop:
			return true
	return false


## 当前**拿在手上**的那一张卡（手上没东西 / 拿的不是卡时返回 null）
##
## 为什么问的是"手上"而不是"卡槽第几张"：两端各挑各的卡，**下标对不上**（同样第 0 张，
## 两个人挑的往往不是同一株）。而"我现在拿着哪一张"才是主机重放时真正需要的那一条信息 ——
## 拿 `card_reference` 说身份，主机照着它自己取 / 造一张同样的。
static func held_card() -> Card:
	var mg := GameContext.curr_main_game
	if mg == null or not is_instance_valid(mg) or mg.hand_manager == null:
		return null
	var hand := mg.hand_manager.curr_hand_component as HandComponentCharacter
	if hand == null:
		return null
	var card: Card = hand.curr_card
	if card == null or not is_instance_valid(card):
		return null
	return card
