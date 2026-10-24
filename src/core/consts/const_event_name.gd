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
## 本局长出了一颗阳光（天降 / 植物产 / 掉落都算）。payload: [Sun]
##
## 与 `ADD_SUN_VALUE` 的区别：那条只说"加了多少点"，说不清**哪一颗**；
## 这一条给的是阳光节点本身（有 `entity_id` 与 `spawn_target`），
## 联机主机靠它把"天上多了哪一颗"下发下去（见 [联机模组](../../../docs/参考存档/联机模组.md) §4.8）。
## ⚠️ 只在**生成点**推送（生成方已经把落点写进 `Sun.spawn_target` 之后），
## 不要在 `Sun._ready()` 里推 —— 那一刻落点还没写，推下去的是空的。
const SUN_SPAWNED := "sun_spawned"
## 本局掉了一件战利品（金币 / 巧克力）。payload: [掉落物节点]
##
## 与 `SUN_SPAWNED` 同一套：**生成点**在把落点写完之后推，联机主机靠它下发"掉了哪一枚"。
## ⚠️ 礼包 `Present`（解锁道具 / 战利品 / 关卡结算线）**不在**这条上 ——
## 它的时机由关卡数据决定、拾取要写存档与触发结算，两端各自跑即可，拦了反而断流程。
const DROP_ITEM_SPAWNED := "drop_item_spawned"
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
## 草坪上两格的植物互换（三消类玩法那一次滑动）。payload: [行A, 列A, 行B, 列B]
##
## 与 `MAIN_GAME_CLICK_SHOVEL` 同一套：**外部替玩家做主**时推这一条，本体不认识谁在订阅
## （三消是关卡侧玩法，见硬约束 §1-8，所以这里写的是"两格互换"而不是某个玩法名）。
## 联机时主机跑成后把这一条下发，两端跑的是**同一串**交换，盘面才不会各走各的
## （见 [联机模组](../../../docs/参考存档/联机模组.md)）。
## ⚠️ 只传行列下标、不传 `PlantCell` 对象：这一条要过网络，对象引用过不去。
const MAIN_GAME_SWAP_CELL := "main_game_swap_cell"
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
## 生成灌木丛（DLC 版第 7 章 Woods）。payload: [数量]
const CREATE_BUSH := "create_bush"
## 生成解锁道具掉落（冒险模式掉铲子 / 图鉴等）。payload: [全局坐标]
const CREATE_UNLOCK_DROP := "create_unlock_drop"
## 通关掉落物开始被拾取（收尾演出）。payload: 见 CanvasLayerWhiteScreen
const LEVEL_COMPLETE_PICKUP := "level_complete_pickup"
## 通关掉落物拾取演出播完。payload: 无
const LEVEL_COMPLETE_PICKUP_FINISHED := "level_complete_pickup_finished"
## 通关战利品掉出来了（**生成点**推的，不是拾取时）。payload: 无
##
## 原版：关卡奖励掉出来时屏幕中央闪一下（PARTICLE_SCREEN_FLASH，
## 见 PvZ-Portable src/Lawn/Challenge.cpp:2017）。订阅方是 CanvasLayerWhiteScreen。
const LEVEL_COMPLETE_LOOT_SPAWNED := "level_complete_loot_spawned"
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
## 全屏染色渐变到指定浓度并保持（血月）：淡入用它、淡出把 alpha 传 0 即可。
## payload: [E_CanvasLayerEffectType, 目标 alpha, 渐变秒数]
const CANVAS_LAYER_EFFECT_FADE := "canvas_layer_effect_fade"
## 血月事件起 / 落：月夜屋顶背景拿它把底图与房门遮罩换成「血月」那套（传 false 换回来）。
## payload: [是否生效]。只管**场景外观**，加速 / 红屏 / 音效各自走自己的路子
const BLOOD_MOON_VISUAL := "blood_moon_visual"
## 磁力菇吸一次铁器。payload: 见 MagnetComponent
const GOLD_MAGNET_ATTRACT_ONCE := "gold_magnet_attract_once"
## 有角色被魅惑，全场重判敌我。payload: 见 DetectComponent
const CHARACTER_BE_HYPNO := "character_be_hypno"
## 一次伤害结算完成（**观测用**，见 [伤害系统](../../../docs/参考存档/伤害系统.md)）。
## payload: [DamageInfo, DamageResult]
##
## 频内高频（僵尸啃食每 8 帧一次 × 场上僵尸数），没有订阅者时 EventBus 会直接返回。
## 订阅方**不要**在里面再改血量：联机客户端的血量由主机快照下发，本地改了会被下一次快照覆盖。
const DAMAGE_APPLIED := "damage_applied"
#endregion

#region 关卡流程
## 主游戏阶段 / 战斗进度变化。payload: [进度值]
const MAIN_GAME_PROGRESS_UPDATE := "main_game_progress_update"
## 本波僵尸打完。payload: 无
const END_WAVE_ZOMBIE := "end_wave_zombie"
## 本轮战斗打完（最后一波清完 / 罐子全砸开 / 僵王倒下后清场）。payload: [全局坐标]
## ⚠️ **打完 ≠ 胜利**：胜利条件改由关卡流程决定（run_flow 跑完强制胜利，见 LevelTimelineManager）。
##    本事件只负责「还有下一轮就切轮」（多轮关卡），最后一轮打完什么都不做
const BATTLE_FINISHED := "battle_finished"
## 开始下一轮（多轮关卡）。payload: 无
const START_NEXT_ROUND_GAME := "start_next_round_game"
## 僵尸进家。payload: [僵尸]
const ZOMBIE_GO_HOME := "zombie_go_home"
## 有僵尸请求生成一只「召唤类」僵尸（巨人丢小鬼 / 舞王召唤伴舞）。
## payload: [僵尸类型(StringName), 行号(int), 初始化参数(Dictionary), 生成位置(Vector2), 生成回调(Callable 或 null)]
##
## 为什么走事件而不是直连 `ZombieManager`：僵尸脚本不该钉在管理器的某个方法签名上
## —— 联机回放 / 录像要接管生成时，只需要在这一个点上挂钩（同 `MAIN_GAME_SWAP_CELL` 的思路）。
## ⚠️ 这是**广播**不是查询：需要拿到实例的调用方（如 `create_skill_bungi`）仍应直连。
const ZOMBIE_SUMMON_REQUESTED := "zombie_summon_requested"
## 小推车被触发。payload: 见 ZombieChooseRowSystem
const LAWN_MOVER_TRIGGERED := "lawn_mover_triggered"
## ⚠️ 已删两个死事件（2026-10-11）：`WIN_MAIN_GAME` / `REPLENISH_LAWN_MOVER` 全仓**只有订阅、0 处 push**，
##   实际分别走直接调用（`MainGameManager.shortcut_win_main_game()` → `reward_manager.win_main_game()`）
##   与关卡流程事件（`LevelTimelineEventLawnMover` → `init_or_replenish_lawn_movers()`）。
##   留着"订阅了永远不响"的分支只会让人以为还有第二条路，故连订阅一起删。
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
	SUN_SPAWNED: [Variant.Type.TYPE_OBJECT],
	DROP_ITEM_SPAWNED: [Variant.Type.TYPE_OBJECT],
	UPDATE_CARD_PURPLE_SUN_COST: [],
	## Marker2D 是对象：这里只校验「传了个对象进来」，具体节点类型由订阅方负责
	UPDATE_MARKER_2D_SUN_TARGET: [Variant.Type.TYPE_OBJECT],
	CARD_SLOT_NORM_START_GAME: [],
	MAIN_GAME_CLICK_CARD: [Variant.Type.TYPE_OBJECT],
	MAIN_GAME_CLICK_SHOVEL: [],
	MAIN_GAME_SWAP_CELL: [
		Variant.Type.TYPE_INT, Variant.Type.TYPE_INT,
		Variant.Type.TYPE_INT, Variant.Type.TYPE_INT,
	],
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
	## 巧克力 / 花园植物的 payload 都只有一个落点坐标（见 component_drop_item.gd）
	CREATE_CHOCOLATE: [Variant.Type.TYPE_VECTOR2],
	CREATE_GARDEN_PLANT: [Variant.Type.TYPE_VECTOR2],
	CREATE_TOMBSTONE: [Variant.Type.TYPE_INT],
	CREATE_BUSH: [Variant.Type.TYPE_INT],
	CREATE_UNLOCK_DROP: [Variant.Type.TYPE_VECTOR2],
	## 通关掉落物本体（seed_packet.gd / present.gd 推的都是 self）
	LEVEL_COMPLETE_PICKUP: [Variant.Type.TYPE_OBJECT],
	LEVEL_COMPLETE_PICKUP_FINISHED: [],
	## 关卡奖励掉出来的那一下（无参）
	LEVEL_COMPLETE_LOOT_SPAWNED: [],
	#endregion

	#region 战斗效果（跨系统广播）
	## [统一冻结时长, 减速总时长, 伤害]（见 component_bomb_ice.gd 的 time_ice / time_decelerate / 植物 attack_value）
	## 冻结时长 0 = 走原版口径（陆地 4~6 秒随机、水中 3 秒）；减速总时长从冰冻那一刻起算（原版 20 秒）。
	## 寒冰菇的口径是「伤害 + 附加冰冻」：伤害是主体，冰冻只是挂在这次伤害上的控制效果。
	ICE_ALL_ZOMBIE: [Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_INT],
	## 三行热烈：payload 是所在行的列索引 owner_plant.row_col.x（int）
	JALAPENO_BOMB_EFFECT: [Variant.Type.TYPE_INT],
	JALAPENO_BOMB_ITEM_LANE: [Variant.Type.TYPE_INT],
	## [行号, 伤害]：行号是 owner_plant.row_col.x，伤害是该植物的 attack_value
	JALAPENO_BOMB_LANE_ZOMBIE: [Variant.Type.TYPE_INT, Variant.Type.TYPE_INT],
	BLOVER_BLOW_AWAY_IN_SKY_ZOMBIE: [],
	## 第一个位置是 E_CanvasLayerEffectType 枚举（int）；第二个位置是时长，
	## 订阅方 canvas_layer_effect_once 的 duration 带默认值 0.3，所以可选
	CANVAS_LAYER_EFFECT_ONCE: [Variant.Type.TYPE_INT, Variant.Type.TYPE_NIL],
	CANVAS_LAYER_EFFECT_FADE: [
		Variant.Type.TYPE_INT, Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT,
	],
	BLOOD_MOON_VISUAL: [Variant.Type.TYPE_BOOL],
	GOLD_MAGNET_ATTRACT_ONCE: [Variant.Type.TYPE_VECTOR2],
	CHARACTER_BE_HYPNO: [Variant.Type.TYPE_OBJECT],
	## 两个位置都是对象（DamageInfo / DamageResult），具体类型由订阅方负责
	DAMAGE_APPLIED: [Variant.Type.TYPE_OBJECT, Variant.Type.TYPE_OBJECT],
	#endregion

	#region 关卡流程
	## MainGameManager.E_MainGameProgress 枚举（int）：阶段变化由 setter 推（main_game_manager.gd）
	MAIN_GAME_PROGRESS_UPDATE: [Variant.Type.TYPE_INT],
	ZOMBIE_GO_HOME: [Variant.Type.TYPE_OBJECT],
	## 召唤类生成：类型 / 行号 / 初始化参数 / 生成位置 / 回调（可能为 null，跳过校验）
	ZOMBIE_SUMMON_REQUESTED: [Variant.Type.TYPE_STRING_NAME, Variant.Type.TYPE_INT,
		Variant.Type.TYPE_DICTIONARY, Variant.Type.TYPE_VECTOR2, Variant.Type.TYPE_NIL],
	END_WAVE_ZOMBIE: [],
	BATTLE_FINISHED: [Variant.Type.TYPE_VECTOR2],
	START_NEXT_ROUND_GAME: [],
	LAWN_MOVER_TRIGGERED: [Variant.Type.TYPE_INT],
	#endregion

	#region 设置 / 调试
	ON_CONFIG_UPDATE: [],
	## 注意：调用点传的是裸 bool（`push_event(名, true)`），
	## push_event 内部会包装成 [bool]，所以签名是单元素
	SET_KEEP_SYSTEM_CURSOR_VISIBLE: [Variant.Type.TYPE_BOOL],
	TEST_CHANGE_SUN_VALUE: [Variant.Type.TYPE_INT],
	TEST_DEATH_ALL_ZOMBIE: [],
	#endregion
}
#endregion
