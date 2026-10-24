extends DIM_Base
class_name DIM_Coin
## 掉落管理器的子节点，掉落金币使用
## 公共的实例化 / 落点 / 广播那套在 `DIM_Base`，这里只管钱自己的三件事：
## 按概率摇出哪一种、飞向钱袋（不入账就飞错了地方）、第一次掉钱的那次提示

## 要求必须有这个金币显示label
@onready var coin_bank_label: CoinBankLabel = %CoinBankLabel
## 掉落金币的父节点
@export var all_drop_coin_parent: Node2D


func get_drop_parent() -> Node2D:
	return all_drop_coin_parent


func _ready() -> void:
	EventBus.subscribe(ConstEventName.CREATE_COIN, create_coin)


## 生产金币,按概率生产，概率和为1,
## 概率顺序为 银币金币和钻石
func create_coin(probability:Array=[0.5, 0.5, 0], global_position_new_coin:Vector2=Vector2.ZERO,
		target_position:Vector2=Vector2(randf_range(-50, 50), randf_range(80, 90))) -> Coin:
	## 闸门被占住时（联机客户端）这一枚不掉：掉不掉、掉哪一种由**主机**下发
	if is_blocked():
		return null
	## 金钱未解锁(冒险模式 2-1 之前)时不产生任何金币,见 ConstUnlockLevel
	if is_instance_valid(Global.global_game_state) and not Global.global_game_state.is_money_unlocked():
		return null
	if not is_instance_valid(coin_bank_label):
		Log.error("生成金币但没有coin_value_label")
		return null
	coin_bank_label.update_label()
	var kind := _roll_kind(probability)
	var new_coin := instantiate_drop(ItemRegistry.get_drop_scene(kind)) as Coin
	if new_coin == null:
		return null
	new_coin.drop_kind = kind
	new_coin.setup(coin_bank_label.marker_2d_coin_target.global_position)
	new_coin.global_position = global_position_new_coin
	## 抛物线发射金币:target_position 是相对起点的偏移,
	## 战斗与花园的钱都就近落在生成点附近,不飞去屏幕别处
	new_coin.launch(target_position)
	notify_drop_spawned(new_coin)
	## 第一次掉钱:通知主游戏弹一次「存钱买道具」提示(全局只弹一次,判定在 MainGameManager)
	if is_instance_valid(Global.global_game_state) and not Global.global_game_state.is_first_coin_advice_shown:
		EventBus.push_event(ConstEventName.FIRST_COIN_DROP, [new_coin])
	return new_coin


## 按概率摇出是哪一种钱（银 / 金 / 钻）
func _roll_kind(probability: Array) -> int:
	var probability_sum: float = float(probability[0]) + float(probability[1]) + float(probability[2])
	assert(abs(probability_sum - 1.0) < 0.001, "概率和不为1")
	var r := randf()
	if r < probability[0]:
		return ItemRegistry.E_DropKind.Silver
	if r < probability[0] + probability[1]:
		return ItemRegistry.E_DropKind.Gold
	return ItemRegistry.E_DropKind.Diamond
