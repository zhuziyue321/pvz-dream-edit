extends RefCounted
class_name NetplayCommand
## 联机命令：玩家操作的可序列化表示
##
## 为什么要有这一层：本体的玩家操作是 `EventBus` 事件，有的 payload 直接是 `Card` 对象 ——
## 对象引用过不了网络。命令把它压成**纯数据字典**：
##   { "op": 操作名, "args": { 只有 int / float / String / Vector2i } }
## 主机收到后按 op 在本机重放（重放逻辑属于下一阶段，本文件只定义"怎么打包 / 解包"）。
##
## ★ 命名纪律（模组机制边界规则 6 的同款理由）：这里出现的是"操作"，不是"联机"，
##   将来单机回放 / 录像也能复用同一份命令定义。
##
## 关联：本机采集在 [NetplaySession](netplay_session.gd) ｜ 事件名常量 [ConstEventName]

## 点了一张卡（参数：卡槽下标 + 植物类型）
const OP_CLICK_CARD := &"click_card"
## 点了铲子（参数：空）
const OP_CLICK_SHOVEL := &"click_shovel"
## 点了某一格草地（参数：row / col）—— 种植物 / 铲植物是同一枚入口，
## 手里拿着什么就做什么，主机重放时不替调用方猜意图
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
## 主机开了新的一波（参数：波次号）—— 只有主机喊得动，客户端照着开同一波
## （不是"玩家操作"，走的是 `battle_op` 那条下行通道，见 `NetplayWaveSync`）
const OP_WAVE_NEXT := &"wave_next"
## 连通性测试（参数：空）
const OP_PING := &"ping"

## 命令参数里的字段名（写出来是为了不让字符串散在收发两端）
const ARG_CARD_INDEX := "card_index"
const ARG_PLANT_TYPE := "plant_type"
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
## 这一波每只僵尸的实体编号（`OP_WAVE_NEXT` 用，与 `ARG_WAVE` 一组）
##
## 为什么连编号一起下发：两端各自自增分配出来的编号会错位（谁先多生一颗阳光就整体错开），
## 状态广播（`NetplayStateSync`）是按 `entity_id` 认人的，编号对不上就会把整波的僵尸当成
## "主机有、本地没有"而**再生成一遍** —— 场上僵尸直接翻倍。
const ARG_ZOMBIE_IDS := "z_ids"

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


## 本体事件 → 命令操作名（认不出的返回空 StringName，调用方据此跳过）
##
## ⚠️ 这里**没有** `ADD_SUN_VALUE`：那条事件上只有"加了多少点"，说不清"点的是哪一颗"。
## 拾取改由 `Sun` 的拾取闸门（`GlobalUtils.sun_click_gate`）在按下那一刻上行，
## 带的是实体编号 —— 主机才能在自己这一局上摘掉同一颗。
static func op_from_event(event_name: String) -> StringName:
	match event_name:
		ConstEventName.MAIN_GAME_CLICK_CARD:
			return OP_CLICK_CARD
		ConstEventName.MAIN_GAME_CLICK_SHOVEL:
			return OP_CLICK_SHOVEL
	return &""


## 本体事件的 payload → 命令参数（只留可序列化的标量，对象一律换成下标 / 类型）
static func args_from_event(event_name: String, payload: Array) -> Dictionary:
	match event_name:
		ConstEventName.MAIN_GAME_CLICK_CARD:
			var card: Card = payload[0] if payload.size() > 0 and payload[0] is Card else null
			if card == null:
				return {}
			return {
				ARG_CARD_INDEX: card_index_of(card),
				ARG_PLANT_TYPE: card.card_plant_type,
			}
	return {}


## 一张出战卡在自己卡槽里的下标（没有卡槽 / 不在其中时返回 -1）
##
## ⚠️ 不能拿 `card.get_index()`：那是 **Node 的兄弟下标**（卡挂在容器里，兄弟下标会被
##   纹理 / 分隔节点顶开），跟"第几张出战卡"对不上 —— 卡槽自己也是用 `find()` 反查的
##   （见 `card_slot_norm.gd` 里那一处），这里照抄它的口径。
static func card_index_of(card: Card) -> int:
	if card == null or not is_instance_valid(card):
		return -1
	var cards := battle_cards()
	if cards.is_empty():
		return -1
	return cards.find(card)


## 本机出战卡槽里现有的卡（`main_game.card_manager.card_slot_battle.curr_cards`）
static func battle_cards() -> Array[Card]:
	var mg := Global.main_game
	if mg == null or not is_instance_valid(mg) or mg.card_manager == null:
		return []
	var slot: CardSlotBattle = mg.card_manager.card_slot_battle
	if not is_instance_valid(slot):
		return []
	return slot.curr_cards
