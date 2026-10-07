extends RefCounted
class_name ConstEventName
## 事件总线（EventBus）事件名常量表。
##
## 为什么要有这份表：EventBus 用**动态信号**实现（subscribe 时才 add_user_signal），
## 事件名是字符串，拼错不会报编译错误，只会在运行期静默失效（没人订阅 = 什么也不发生）。
## 把事件名收在这里之后，IDE 能跳转、能补全、改名能全局重构，拼错会编译报错。
##
## 用法：
##     EventBus.push_event(ConstEventName.CREATE_TROPHY, [global_pos])
##     EventBus.subscribe(ConstEventName.CREATE_TROPHY, _on_create_trophy)
##
## 新增事件：在本文件按语义分组加一行常量，**不要**在业务代码里写裸字符串。
##
## 例外：MainGameCamera.SHAKE_EVENT 仍定义在相机自己身上（相机只广播自己消费的震动事件，
## 与全局玩法事件不同族），保持不动。
##
## **payload 签名**：光有名字常量还不够 —— EventBus 用动态信号 + `callv(payload)`，
## payload 的**个数和类型**照样没有任何编译期检查，写错会静默失效。
## 因此本文件再维护一张 EVENT_PAYLOAD_SIGNATURES 表，由 EventBus 在 push 时校验。
##
## **新增事件时请顺手登记签名**：写 `事件名: [Variant.Type.TYPE_INT]` 这样的数组，
## 无参事件写 `[]`。登记了才有校验；没登记的事件按原样放行（渐进式，不为难存量代码）。
## 拿不准某个位置的类型时写 `Variant.Type.TYPE_NIL`，表示该位置跳过校验。

#region 阳光 / 卡槽 / 手持物
## 增加阳光值。payload: [阳光增量]
const ADD_SUN_VALUE := "add_sun_value"
## 紫卡（模仿者）阳光消耗变化，卡槽需要刷新显示。payload: 无
const UPDATE_CARD_PURPLE_SUN_COST := "update_card_purple_sun_cost"
## 刷新阳光飞向的收集点。payload: [Marker2D]
const UPDATE_MARKER_2D_SUN_TARGET := "update_marker_2d_sun_target"
## 常规卡槽的「开始游戏」按钮被点下。payload: 无
const CARD_SLOT_NORM_START_GAME := "card_slot_norm_start_game"
## 玩家点击了卡槽里的卡片。payload: [Card]
const MAIN_GAME_CLICK_CARD := "main_game_click_card"
## 玩家点击了铲子。payload: 无
const MAIN_GAME_CLICK_SHOVEL := "main_game_click_shovel"
## 玩家点击了手套。payload: 无
const MAIN_GAME_CLICK_GLOVE := "main_game_click_glove"
## 手上拿起了一张卡。payload: 见 CardManager
const HAND_CARD_TAKE := "hand_card_take"
## 手上的卡被放下 / 收回。payload: 见 CardManager
const HAND_CARD_RELEASE := "hand_card_release"
## 本关第一枚金币掉落（新手引导用）。payload: 见 MainGameManager
const FIRST_COIN_DROP := "first_coin_drop"
#endregion

#region 掉落物生成
## 生成金币 / 银币 / 钻石。payload: [掉落权重数组, 全局坐标]
const CREATE_COIN := "create_coin"
## 生成奖杯（通关掉落）。payload: [全局坐标]
const CREATE_TROPHY := "create_trophy"
## 生成巧克力掉落。payload: 见 DropItemManager
const CREATE_CHOCOLATE := "create_chocolate"
## 生成禅境花园植物掉落。payload: 见 DropItemManager
const CREATE_GARDEN_PLANT := "create_garden_plant"
## 生成墓碑。payload: [数量]
const CREATE_TOMBSTONE := "create_tombstone"
## 生成解锁道具掉落（冒险模式掉铲子 / 图鉴等）。payload: [全局坐标]
const CREATE_UNLOCK_DROP := "create_unlock_drop"
## 通关掉落物开始被拾取（收尾演出）。payload: 见 CanvasLayerWhiteScreen
const LEVEL_COMPLETE_PICKUP := "level_complete_pickup"
## 通关掉落物拾取演出播完。payload: 无
const LEVEL_COMPLETE_PICKUP_FINISHED := "level_complete_pickup_finished"
#endregion

#region 战斗效果（跨系统广播）
## 全场僵尸冰冻（寒冰菇 / 冰瓜）。payload: 见 ZombieManager
const ICE_ALL_ZOMBIE := "ice_all_zombie"
## 辣椒烧掉一整行（表现）。payload: 见 PlantCellManager
const JALAPENO_BOMB_EFFECT := "jalapeno_bomb_effect"
## 辣椒烧掉一整行的场上道具。payload: 见 PlantCellManager / ZombieManager
const JALAPENO_BOMB_ITEM_LANE := "jalapeno_bomb_item_lane"
## 辣椒烧掉一整行的僵尸。payload: 见 ZombieManager
const JALAPENO_BOMB_LANE_ZOMBIE := "jalapeno_bomb_lane_zombie"
## 三叶草吹飞空中僵尸（气球 / 蹦极）。payload: 见 ZombieManager
const BLOVER_BLOW_AWAY_IN_SKY_ZOMBIE := "blover_blow_away_in_sky_zombie"
## 播一次全屏特效（冰 / 毁灭菇等）。payload: [E_CanvasLayerEffectType]
const CANVAS_LAYER_EFFECT_ONCE := "canvas_layer_effect_once"
## 磁力菇吸一次铁器。payload: 见 MagnetComponent
const GOLD_MAGNET_ATTRACT_ONCE := "gold_magnet_attract_once"
## 有角色被魅惑，全场重判敌我。payload: 见 DetectComponent
const CHARACTER_BE_HYPNO := "character_be_hypno"
#endregion

#region 关卡流程
## 主游戏阶段 / 战斗进度变化。payload: [进度值]
const MAIN_GAME_PROGRESS_UPDATE := "main_game_progress_update"
## 本波僵尸打完。payload: 无
const END_WAVE_ZOMBIE := "end_wave_zombie"
## 开始下一轮（多轮关卡）。payload: 无
const START_NEXT_ROUND_GAME := "start_next_round_game"
## 通关。payload: 无
const WIN_MAIN_GAME := "win_main_game"
## 僵尸进家。payload: [僵尸]
const ZOMBIE_GO_HOME := "zombie_go_home"
## 小推车被触发。payload: 见 ZombieChooseRowSystem
const LAWN_MOVER_TRIGGERED := "lawn_mover_triggered"
## 补充小推车。payload: 无
const REPLENISH_LAWN_MOVER := "replenish_lawn_mover"
#endregion

#region 设置 / 调试
## 配置项变化，需要刷新表现。payload: 无
const ON_CONFIG_UPDATE := "on_config_update"
## 是否保持系统光标可见。payload: [bool]
const SET_KEEP_SYSTEM_CURSOR_VISIBLE := "set_keep_system_cursor_visible"
## 调试：改阳光值。payload: [值]
const TEST_CHANGE_SUN_VALUE := "test_change_sun_value"
## 调试：全场僵尸死亡。payload: 无
const TEST_DEATH_ALL_ZOMBIE := "test_death_all_zombie"
#endregion

#region payload 签名表
## 事件名 → payload 每个位置应有的类型（Variant.Type）
##
## 为什么需要：上面的注释只兜住了**事件名**，兜不住 payload。
## EventBus.push_event 最终是 `callable.callv(payload)`，个数不对时 Godot 只是静默地
## 少喂 / 多丢弃几个参数，类型不对则要等到回调内部才炸，那时的栈信息已经没有参考价值。
## 有了这张表，EventBus 在 push 的当下就把问题报出来（见 EventBus._validate_payload）。
##
## **范围声明**：这里只登记已从调用点核实过的事件；没登记的事件**不校验**（照旧放行）。
## 所以这是一张可以慢慢补的表 —— 补一条就多一条保护，不补也不会误报。
##
## 写法：无参事件 `[]`；某位置不想校验写 `Variant.Type.TYPE_NIL`。
const EVENT_PAYLOAD_SIGNATURES: Dictionary[String, Array] = {
	#region 阳光 / 卡槽 / 手持物
	ADD_SUN_VALUE: [Variant.Type.TYPE_INT],
	UPDATE_CARD_PURPLE_SUN_COST: [],
	## Marker2D 是对象：这里只校验「传了个对象进来」，具体节点类型由订阅方负责
	UPDATE_MARKER_2D_SUN_TARGET: [Variant.Type.TYPE_OBJECT],
	CARD_SLOT_NORM_START_GAME: [],
	MAIN_GAME_CLICK_CARD: [Variant.Type.TYPE_OBJECT],
	MAIN_GAME_CLICK_SHOVEL: [],
	MAIN_GAME_CLICK_GLOVE: [],
	HAND_CARD_TAKE: [Variant.Type.TYPE_OBJECT],
	HAND_CARD_RELEASE: [Variant.Type.TYPE_OBJECT],
	FIRST_COIN_DROP: [Variant.Type.TYPE_OBJECT],
	#endregion

	#region 掉落物生成
	## [掉落权重数组, 全局坐标, (可选)目标落点偏移]
	## 第三个位置写 TYPE_NIL 表示「可选」：订阅方 DIM_Coin.create_coin 的第三个参数
	## 带默认值，所以调用方传 2 个（component_create_coin.gd）或 3 个
	## （component_drop_item.gd）都是合法的。TYPE_NIL 同时表示该位置跳过类型校验。
	CREATE_COIN: [Variant.Type.TYPE_ARRAY, Variant.Type.TYPE_VECTOR2, Variant.Type.TYPE_NIL],
	CREATE_TROPHY: [Variant.Type.TYPE_VECTOR2],
	CREATE_TOMBSTONE: [Variant.Type.TYPE_INT],
	CREATE_UNLOCK_DROP: [Variant.Type.TYPE_VECTOR2],
	#endregion

	#region 战斗效果（跨系统广播）
	## 三行热烈：payload 是所在行的列索引 owner_plant.row_col.x（int）
	JALAPENO_BOMB_EFFECT: [Variant.Type.TYPE_INT],
	JALAPENO_BOMB_ITEM_LANE: [Variant.Type.TYPE_INT],
	JALAPENO_BOMB_LANE_ZOMBIE: [Variant.Type.TYPE_INT],
	BLOVER_BLOW_AWAY_IN_SKY_ZOMBIE: [],
	GOLD_MAGNET_ATTRACT_ONCE: [Variant.Type.TYPE_VECTOR2],
	CHARACTER_BE_HYPNO: [Variant.Type.TYPE_OBJECT],
	#endregion

	#region 关卡流程
	ZOMBIE_GO_HOME: [Variant.Type.TYPE_OBJECT],
	END_WAVE_ZOMBIE: [],
	START_NEXT_ROUND_GAME: [],
	WIN_MAIN_GAME: [],
	#endregion

	#region 设置 / 调试
	## 注意：调用点传的是裸 bool（`push_event(名, true)`），
	## push_event 内部会包装成 [bool]，所以签名是单元素
	SET_KEEP_SYSTEM_CURSOR_VISIBLE: [Variant.Type.TYPE_BOOL],
	TEST_CHANGE_SUN_VALUE: [Variant.Type.TYPE_INT],
	TEST_DEATH_ALL_ZOMBIE: [],
	#endregion
}
#endregion
