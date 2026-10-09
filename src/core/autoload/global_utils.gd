extends Node
class_name GlobalUtilsClass
## 全局工具脚本

## 进关闸门（通用问询口，不带联机字样）：返回 false = 这一次不许进关
##
## 默认恒为空 Callable（照旧进）。联机客户端由模组占住：打哪一关由**房主**决定
## （见 [联机模组规范](../../../docs/参考存档/联机模组规范.md) §二），
## 客户端自己点选关页不该进得去 —— 进了也会被房主的下一次进关命令覆盖，白进一次。
var enter_level_gate: Callable = Callable()

## 天降阳光的**生成闸门**（通用问询口，不带联机字样）：返回 true = 已接管，本地不生成
##
## 默认恒为空 Callable（照旧掉）。联机客户端由模组占住：天上掉哪一颗、落在哪儿由**主机**下发，
## 客户端不再自己摇 —— 两端的定时器各跑各的，摇出来的落点与时刻必然对不上。
var sun_spawn_gate: Callable = Callable()

## 点阳光的**拾取闸门**（通用问询口，不带联机字样）：返回 true = 已接管，本地不拾取
##
## 默认恒为空 Callable（照旧拾取）。联机客户端由模组占住：点阳光是一次**请求**，
## 得主机在自己那一局上跑成了才算数（见 [联机模组规范](../../../docs/参考存档/联机模组规范.md) §三）。
## 回调签名 `func(sun: Sun) -> bool`，拿得到"点的是哪一颗"。
var sun_click_gate: Callable = Callable()

## **掉落物**的生成闸门（通用问询口，不带联机字样）：返回 true = 已接管，本地不掉
##
## 默认恒为空 Callable（照旧掉）。联机客户端由模组占住：金币 / 巧克力掉不掉、掉哪一种、
## 落在哪儿全由**主机**下发 —— 客户端不该判定"这只僵尸死了掉什么"（那是战斗逻辑），
## 更不该自己摇 `randf()` 决定掉银币还是钻石。
## ⚠️ 只管**战斗掉落**（`Coin` / `ChocolateDrop`）。礼包 `Present` 不归它管：
## 那是解锁道具 / 战利品 / 关卡结算线，时机由关卡数据决定，拦了会断关卡流程。
var drop_gate: Callable = Callable()

## 点掉落物的**拾取闸门**（通用问询口，不带联机字样）：返回 true = 已接管，本地不拾取
##
## 默认恒为空 Callable（照旧拾取）。与 `sun_click_gate` 同一条链路：点一下是**请求**，
## 主机在自己那一局上收成了，两端才一起入账。
## 回调签名 `func(drop: Node) -> bool`，拿得到"点的是哪一枚"。
var drop_click_gate: Callable = Callable()

## **子弹**的生成闸门（通用问询口，不带联机字样）：返回 true = 已接管，本地不造子弹
##
## 默认恒为空 Callable（照旧造）。联机客户端由模组占住：场上飞着哪一颗由**主机**随快照下发，
## 客户端再自己造一份就会变成"一发豌豆两颗"（本地一颗 + 下发一颗）。
## ⚠️ 只拦**造子弹**这一件事，开火动画照旧本地播 —— 判定与表现不能一起停
## （停掉攻击组件会连发射动画一起没了，见 [联机模组](../../docs/参考存档/联机模组.md) §4.11）。
var bullet_spawn_gate: Callable = Callable()

#const RandomPicker = preload("random_picker.gd")
#region 工具方法
## plantcell对应的斜面位置与监测位置的差值更新
func update_plant_cell_slope_y(plant_cell:PlantCell, node_2d:Node2D):
	## 斜面与水平面的差值
	var diff_slope_flat:float = 0
	if is_instance_valid(plant_cell):
		diff_slope_flat = plant_cell.slope_step_y

	if diff_slope_flat != 0:
		node_2d.position.y -= diff_slope_flat

func update_plant_cell_slope_y_array(plant_cell:PlantCell, node2d_detect_in_slope:Array):
	## 斜面与水平面的差值
	var diff_slope_flat:float = 0
	if is_instance_valid(plant_cell):
		diff_slope_flat = plant_cell.slope_step_y

	if diff_slope_flat != 0:
		for n in node2d_detect_in_slope:
			n.position.y -= diff_slope_flat


## 数字转str,每三位加逗号
func format_number_with_commas(n: int) -> String:
	var s := str(n)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i != 0:
			result = "," + result
	return result

## 递归让子节点使用父节点shader材质
func node_use_parent_material(node: Node2D) -> void:
	node.use_parent_material = true
	## 遍历所有子节点
	for child in node.get_children():
		if child.is_class("Node2D"):
			node_use_parent_material(child)

## 求字典value乘积
func get_dic_product(my_dict:Dictionary) -> float:
	var product = 1.0
	for value in my_dict.values():
		product *= value
	return product

## 列表求和
func sum_arr(arr: Array[float]) -> float:
	var total = 0.0
	for n in arr:
		total += n
	return total

## 根据当前植物类型和僵尸类型获取当前是植物还是僵尸
func get_character_type(plant_type:CharacterRegistry.PlantType, zombie_type:CharacterRegistry.ZombieType) -> CharacterRegistry.CharacterType:
	if plant_type == CharacterRegistry.PlantType.Null:
		if zombie_type == CharacterRegistry.ZombieType.Null:
			return CharacterRegistry.CharacterType.Null
		else:
			return CharacterRegistry.CharacterType.Zombie
	else:
		return CharacterRegistry.CharacterType.Plant

## 补全列表
func pad_array(arr: Array, target_size: int, pad_value: Variant = 0) -> Array:
	while arr.size() < target_size:
		arr.append(pad_value)
	return arr

## 世界坐标转屏幕坐标
func world_to_screen(global_pos : Vector2) -> Vector2:
	# pos 是 world / canvas 坐标，也就是某个 Node2D 的 global_position
	var viewport := get_viewport()
	# 获取视口变换 （画布 -> 屏幕）
	var vt : Transform2D = viewport.get_screen_transform()
	# 用 vt * pos 得到屏幕上的像素位置
	return vt * global_pos

## 创建计时器(触发一次)(角色buff[减速]使用)
func create_new_timer_once(need_node:Node, callable:Callable, wait_time:float=0):
	var timer = Timer.new()
	timer.one_shot = true
	timer.autostart = false
	if wait_time != 0:
		timer.wait_time = wait_time
	timer.timeout.connect(callable)
	need_node.add_child(timer)
	return timer

enum E_CurrTimeType{
	String,

}

## 获取当前时间
func get_curr_time(curr_time_type:E_CurrTimeType=E_CurrTimeType.String):
	match curr_time_type:
		E_CurrTimeType.String:
			var d := Time.get_datetime_dict_from_system()
			var text := "%04d-%02d-%02d %02d:%02d:%02d" % [
				d.year, d.month, d.day, d.hour, d.minute, d.second
			]
			return text


## 当天日期字符串(YYYY-MM-DD)
## 用于"每日限购"这类按自然日重置的判定(见 ConstShop.MARIGOLD_SPROUT_DAILY_LIMIT)
func get_today_date_string() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

## 切换主场景(全项目统一走这里,不要直接 get_tree().change_scene_to_file)
## 必须延迟到本帧遍历结束之后再真正切换:
## 换场景若在输入回调(_pressed / _input)里同步执行,SceneTree::_call_input_pause()
## 此时正在遍历输入组的**快照**,旧场景节点被立刻摘出树却仍留在快照里,
## 之后每走到一个就触发一次 can_process 报错(Condition "!is_inside_tree()" is true)。
## 同理也避开在 _process / _physics_process 里同步改场景树的问题。
## 注：曾回迁过旧版的淡入淡出过场（scene_transition），因黑幕缓冲拖慢节奏已撤掉；
## 这里保持「本帧末直接切」，调用方 fire-and-forget，不要 await 本方法
func change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(scene_path)




#endregion


#region 特殊僵尸生成函数

func get_special_zombie_callable(zombie_type:CharacterRegistry.ZombieType, plant_cell:PlantCell) -> Callable:
	match zombie_type:
		CharacterRegistry.ZombieType.Z021Bungi:
			return create_bungi.bind(plant_cell)
	return Callable()

## 蹦极僵尸
func create_bungi(zombie_bungi:Zombie021Bungi, plant_cell:PlantCell):
	zombie_bungi.plant_cell = plant_cell

## 空投僵尸的蹦极僵尸（蹦极闪电战）
## 只存数据，真正把僵尸挂到绳子上在 Zombie026BungiDrop.ready_norm 里做（那时节点才进树）
func create_bungi_drop(zombie_bungi_drop:Zombie026BungiDrop, plant_cell:PlantCell, carry_zombie:Zombie000Base):
	zombie_bungi_drop.plant_cell = plant_cell
	zombie_bungi_drop.carry_zombie = carry_zombie

#endregion
