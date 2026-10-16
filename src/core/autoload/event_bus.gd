extends Node

## 事件优先级枚举
enum Priority {
	LOW = 0,			## 低优先级
	NORMAL = 1,		## 普通优先级
	HIGH = 2,		## 高优先级
}

## 事件历史记录
var _event_history: Array[Dictionary] = []
## 事件优先级表 {事件名: {object_id: {priority, once, filter}}}
var _event_metadata: Dictionary = {}
## 是否记录事件历史
@export var enable_history: bool = false
## 历史记录最大长度
@export var max_history_length: int = 100
## 已按优先级排好序的连接快照：{事件名: Array[Dictionary]}（每项额外带一个 "obj_id"）
##
## 为什么需要：原本每次 push_event 都要跑三件重活 ——
##   get_signal_connection_list()（每次分配新数组）→ sort_custom()（比较器里反复拼 obj_id 字符串）
##   → _prune_orphan_metadata()（再遍历一遍连接表、再拼一遍 obj_id）。
## 而**订阅关系几乎不变**，为一个几乎不变的结果每次推送付三遍开销不值得。
## 现在只在「订阅 / 取消订阅 / 真的撞到已释放对象」这三种时候重建快照。
var _ordered_connections_cache: Dictionary = {}
## 是否校验 payload 签名
##
## 为什么要有这道校验：EventBus 是动态信号 + `callv(payload)`，
## payload 的**个数和类型完全没有编译期检查** ——
##   个数写少了 → Godot 静默地少喂几个参数，回调拿到默认值，什么都不报；
##   个数写多了 → 多出来的被丢弃，同样沉默；
##   类型写错了 → 要一路跑到回调内部才炸，那时的栈已经指向回调里某一行，
##              真正的元凶（那个写错的 push_event）早已不在栈上。
## 三类情况的共同点是「报错地点远离出错地点」，排查成本极高。
##
## 配合 ConstEventName.EVENT_PAYLOAD_SIGNATURES，在 push 的当下把问题就地报出来。
## 没登记签名的事件照旧放行（渐进式：补一条多一条保护，不补也不会误报）。
@export var validate_payload: bool = true
## 调试模式
@export var debug_mode: bool = false
## 被 push 过的事件名集合（**仅在 debug_mode 下记录**）
##
## 用途：发现「有订阅方但从头到尾没被 push 过」的**死事件**（见 get_never_pushed_subscribed_events）。
## 只在 debug 时记录是因为正常游玩不需要这份信息，别为每个事件多付一次字典写入。
var _pushed_event_names: Dictionary = {}
## 事件拦截器列表（见 `add_interceptor`）：派发给订阅方之前先过一遍，
## 拦截器返回 true 表示「这条我接管了」，本体不再本地派发。
##
## 为什么留这个口子（而不是让需求方自己去改订阅方）：玩家操作（点卡 / 铲子 / 捡阳光）
## 天然就是 `EventBus` 上的几条事件，把它们变成"可转发的命令"只需要在**这一个点**上挂钩，
## 不碰任何 UI 与管理器。名字叫"拦截器"不叫"联机钩子"，是因为将来单机回放 / 录像
## 也能用同一个口子 —— 本体不认识任何具体玩法（硬约束 §1-8 的同款理由）。
var _interceptors: Array[Callable] = []

## 信号：事件被推送时触发
signal event_pushed(event_name: String, payload: Array)
## 信号：事件处理完成时触发
signal event_handled(event_name: String, payload: Array)

## 推送事件
## [param event_name] 事件名
## [param payload] 事件负载
## [param immediate] 是否立即触发事件
func push_event(event_name: String, payload : Variant = [], immediate: bool = true) -> void:
	if not payload is Array:
		payload = [payload]

	## payload 签名校验：把「回调里才炸」的错误提前到 push 这一刻报出来
	_validate_payload(event_name, payload)

	if debug_mode:
		_pushed_event_names[event_name] = true

	if enable_history:
		_record_event(event_name, payload)

	event_pushed.emit(event_name, payload)

	# 拦截器：返回 true = 已被接管（例如联机客户端把这条操作转成命令上行，等主机回状态）
	#
	# 放在 event_pushed 之后：观测方照样看得到事件，只是不再本地派发给订阅方。
	# 没有拦截器时这一段是一次 is_empty() 判断，热路径上可忽略。
	if not _interceptors.is_empty() and _run_interceptors(event_name, payload):
		return

	# 如果没有这个信号（从未被订阅过），直接返回
	#
	# 这个分支同时是「事件名拼错」和「订阅方还没挂上」的共同表现：
	# 两者都是**整条链路静默什么都不发生**，排查时毫无痕迹。
	# 拼错的名字在外面找不到（EventBus 是动态信号，拼错不报编译错），只能靠肉眼看常量表。
	if not has_signal(event_name):
		return

	# 按优先级排好序的连接快照（订阅关系没变过时直接复用缓存）
	var ordered_connections := _get_ordered_connections(event_name)
	if ordered_connections.is_empty():
		return

	# 筛选满足过滤条件的连接
	# to_disconnect 存 {callable, obj_id}：obj_id 为空表示对象已释放（此时取不到 instance id）
	var callable_list: Array[Callable] = []
	var to_disconnect: Array[Dictionary] = []
	## 只有真的撞到已释放对象时才做元数据对账（正常路径零开销）
	var found_dead_object := false

	for conn in ordered_connections:
		var cb: Callable = conn["callable"]
		var object = cb.get_object()

		# 如果对象已被释放，将其标记为需要断开连接
		if not is_instance_valid(object):
			to_disconnect.append({"callable": cb, "obj_id": ""})
			found_dead_object = true
			continue

		# 检查过滤器（obj_id 已在建快照时算好，这里不再拼字符串）
		var obj_id: String = conn["obj_id"]
		if _event_metadata.has(event_name) and _event_metadata[event_name].has(obj_id):
			var metadata = _event_metadata[event_name][obj_id]
			var filter_callable = metadata["filter"]

			# 应用过滤器
			if filter_callable.is_valid() and not filter_callable.call(payload):
				continue

			# 如果是一次性订阅，标记为需要断开连接
			if metadata["once"]:
				to_disconnect.append({"callable": cb, "obj_id": obj_id})

		callable_list.append(cb)

	# 发送事件
	for cb in callable_list:
		if immediate:
			cb.callv(payload)
		else:
			_schedule_deferred_call(cb, payload)

	# 断开一次性连接 / 对象已释放的僵尸连接
	# 注意：这里**不能**加 is_instance_valid(object) 保护 —— 僵尸连接的对象本来就已释放，
	# 加了这层判断它们永远断不掉，连接表与 _event_metadata 会随关卡切换单调膨胀
	for item in to_disconnect:
		var cb: Callable = item["callable"]
		var obj_id: String = item["obj_id"]
		if is_connected(event_name, cb):
			disconnect(event_name, cb)
			_invalidate_cache(event_name)
		if obj_id != "" and _event_metadata.has(event_name):
			_event_metadata[event_name].erase(obj_id)
			if _event_metadata[event_name].is_empty():
				_event_metadata.erase(event_name)

	# 对象已释放的连接取不到 instance id，对应元数据只能靠连接表对账回收。
	# 只在确认存在已释放对象时才跑 —— 没有僵尸连接时不付这份开销
	if found_dead_object:
		_prune_orphan_metadata(event_name)

	event_handled.emit(event_name, payload)

## 订阅事件
## [param event_name] 事件名
## [param callback] 回调函数
## [param priority] 优先级
## [param once] 是否只执行一次
## [param filter] 过滤器
func subscribe(
	event_name: String,
	callback: Callable,
	priority: Priority = Priority.NORMAL,
	once: bool = false,
	filter: Callable = func(_p): return true
) -> void:
	# 动态添加信号（如果不存在）
	if not has_signal(event_name):
		add_user_signal(event_name)

	# 检查是否已存在相同的回调
	for conn in get_signal_connection_list(event_name):
		if conn["callable"] == callback:
			Log.warn("Callback already subscribed to event: %s" % event_name)
			return

	# 连接信号
	connect(event_name, callback)

	# 保存优先级和其他元数据
	var object = callback.get_object()
	var method = callback.get_method()
	var obj_id = _get_object_id(object, method)

	if not _event_metadata.has(event_name):
		_event_metadata[event_name] = {}

	_event_metadata[event_name][obj_id] = {
		"priority": priority,
		"once": once,
		"filter": filter
	}

	# 订阅关系变了，排好序的快照作废
	_invalidate_cache(event_name)

## 取消订阅事件
## [param event_name] 事件名
## [param callback] 回调函数
func unsubscribe(event_name: String, callback: Callable) -> void:
	if not has_signal(event_name):
		return

	# 断开连接
	if is_connected(event_name, callback):
		disconnect(event_name, callback)
		# 订阅关系变了，排好序的快照作废
		_invalidate_cache(event_name)

		# 移除元数据
		var object = callback.get_object()
		var method = callback.get_method()
		var obj_id = _get_object_id(object, method)

		if _event_metadata.has(event_name) and _event_metadata[event_name].has(obj_id):
			_event_metadata[event_name].erase(obj_id)
			if _event_metadata[event_name].is_empty():
				_event_metadata.erase(event_name)

## 订阅一次性事件
## [param event_name] 事件名
## [param callback] 回调函数
## [param priority] 优先级
## [param filter] 过滤器
func subscribe_once(
	event_name: String,
	callback: Callable,
	priority: Priority = Priority.NORMAL,
	filter: Callable = func(_p): return true
) -> void:
	subscribe(event_name, callback, priority, true, filter)

## 加一个事件拦截器
## [param callback] 签名 `func(event_name: String, payload: Array) -> bool`，返回 true 表示已接管
func add_interceptor(callback: Callable) -> void:
	if not callback.is_valid() or _interceptors.has(callback):
		return
	_interceptors.append(callback)


## 移除事件拦截器
func remove_interceptor(callback: Callable) -> void:
	_interceptors.erase(callback)


## 跑一遍拦截器：任意一个返回 true 就算被接管
func _run_interceptors(event_name: String, payload: Array) -> bool:
	for callback in _interceptors:
		if not callback.is_valid():
			continue
		if callback.call(event_name, payload):
			return true
	return false


## 取消订阅所有事件
## [param callback] 回调函数
func unsubscribe_all(callback: Callable) -> void:
	for event_name in _get_all_signals():
		if is_connected(event_name, callback):
			unsubscribe(event_name, callback)

## 清除所有订阅
func clear_subscriptions() -> void:
	for event_name in _get_all_signals():
		for conn in get_signal_connection_list(event_name):
			disconnect(event_name, conn["callable"])

	_event_metadata.clear()
	## 所有订阅关系都没了，快照整体作废
	_ordered_connections_cache.clear()

## 获取事件订阅者数量
## [param event_name] 事件名
func get_subscriber_count(event_name: String) -> int:
	if not has_signal(event_name):
		return 0
	return get_signal_connection_list(event_name).size()

## 获取事件历史记录
## [return] 事件历史记录
func get_event_history() -> Array[Dictionary]:
	return _event_history.duplicate()

## 清除事件历史记录
func clear_event_history() -> void:
	_event_history.clear()

## 记录事件
## [param event_name] 事件名
## [param payload] 事件负载
func _record_event(event_name: String, payload: Array) -> void:
	var event = {
		"timestamp": Time.get_unix_time_from_system(),
		"event_name": event_name,
		"payload": payload
	}
	_event_history.push_front(event)

	if _event_history.size() > max_history_length:
		_event_history.pop_back()

## 获取所有可用信号
func _get_all_signals() -> Array[String]:
	var signal_list: Array[String] = []
	for signal_dict in get_signal_list():
		if signal_dict["name"] != "event_pushed" and signal_dict["name"] != "event_handled":
			signal_list.append(signal_dict["name"])
	return signal_list

## 为对象和方法生成唯一ID
func _get_object_id(object: Object, method: StringName) -> String:
	return str(object.get_instance_id()) + "_" + method

## 回收孤儿元数据：连接表里已经找不到对应订阅者的条目
## 为什么需要：对象被释放后 get_instance_id() 取不到，push_event 里无法拼出 obj_id，
## 只能拿「当前连接表」与「元数据表」对账，把没有存活订阅者的条目清掉。
## 不清的后果：每关重建的管理器反复订阅，_event_metadata 单调膨胀（内存 + 排序开销）。
func _prune_orphan_metadata(event_name: String) -> void:
	if not _event_metadata.has(event_name):
		return
	var alive_ids: Dictionary = {}
	for conn in get_signal_connection_list(event_name):
		var object = conn["callable"].get_object()
		if is_instance_valid(object):
			alive_ids[_get_object_id(object, conn["callable"].get_method())] = true
	## keys() 返回快照数组，遍历中 erase 安全
	for obj_id in _event_metadata[event_name].keys():
		if not alive_ids.has(obj_id):
			_event_metadata[event_name].erase(obj_id)
	if _event_metadata[event_name].is_empty():
		_event_metadata.erase(event_name)

## 按 ConstEventName.EVENT_PAYLOAD_SIGNATURES 校验 payload 的个数与类型
##
## 设计上刻意**只日志不改流程**：校验失败照样把事件发出去。
## 理由是这条防线是为了「尽早暴露问题」而不是「替业务做决定」——
## 万一签名表登记错了（比如某个位置漏写了类型），直接拦下事件会让功能整个失效，
## 那比原来的静默失效还糟。报错 + 继续，至少功能还在，日志里也有据可查。
##
## 没在签名表里登记的事件直接返回（不校验）。
func _validate_payload(event_name: String, payload: Array) -> void:
	if not validate_payload:
		return
	if not ConstEventName.EVENT_PAYLOAD_SIGNATURES.has(event_name):
		return

	var signature: Array = ConstEventName.EVENT_PAYLOAD_SIGNATURES[event_name]
	## 必填个数 = 从头数到第一个 TYPE_NIL；TYPE_NIL 表示「这位置可选」
	## （见签名表 CREATE_COIN 的注释：订阅方参数带默认值时允许多传少传）
	var min_size := 0
	while min_size < signature.size() and signature[min_size] != Variant.Type.TYPE_NIL:
		min_size += 1

	if payload.size() < min_size or payload.size() > signature.size():
		Log.error("[EventBus] 事件 %s 的 payload 个数不匹配：期望 %d~%d 个，实际 %d 个。payload=%s" % [
			event_name, min_size, signature.size(), payload.size(), str(payload)
		])
		return

	for i in payload.size():
		var expected: Variant.Type = signature[i]
		## TYPE_NIL 表示该位置不校验（可选参数 / 拿不准类型时写这个）
		if expected == Variant.Type.TYPE_NIL:
			continue
		if typeof(payload[i]) != expected:
			Log.error("[EventBus] 事件 %s 的 payload 第 %d 个参数类型不对：期望 %s，实际 %s（值=%s）" % [
				event_name, i, _type_name(expected), _type_name(typeof(payload[i])), str(payload[i])
			])


## Variant.Type 转成能读的名字（报错信息里用）
func _type_name(type: Variant.Type) -> String:
	match type:
		Variant.Type.TYPE_NIL: return "null"
		Variant.Type.TYPE_BOOL: return "bool"
		Variant.Type.TYPE_INT: return "int"
		Variant.Type.TYPE_FLOAT: return "float"
		Variant.Type.TYPE_STRING: return "String"
		Variant.Type.TYPE_VECTOR2: return "Vector2"
		Variant.Type.TYPE_VECTOR2I: return "Vector2i"
		Variant.Type.TYPE_OBJECT: return "Object"
		Variant.Type.TYPE_ARRAY: return "Array"
		Variant.Type.TYPE_DICTIONARY: return "Dictionary"
		Variant.Type.TYPE_CALLABLE: return "Callable"
		_: return "type#%d" % type


## 取「已按优先级排好序」的连接快照
##
## 返回值每项是在 Godot 原生连接 Dictionary 上加了一个 "obj_id"（实例 id + 方法名），
## 这样 push_event 里过滤时不必重拼字符串。
## 命中缓存就直接返回，省掉 get_signal_connection_list() 的数组分配与排序开销。
func _get_ordered_connections(event_name: String) -> Array[Dictionary]:
	if _ordered_connections_cache.has(event_name):
		return _ordered_connections_cache[event_name]

	var connections: Array[Dictionary] = []
	for conn in get_signal_connection_list(event_name):
		conn["obj_id"] = _get_object_id(conn["callable"].get_object(), conn["callable"].get_method())
		connections.append(conn)

	if _event_metadata.has(event_name):
		connections.sort_custom(func(a, b):
			# 高优先级在前
			return _priority_of(event_name, a["obj_id"]) > _priority_of(event_name, b["obj_id"])
		)

	_ordered_connections_cache[event_name] = connections
	return connections


## 某个连接的优先级（没登记元数据时按 NORMAL）
func _priority_of(event_name: String, obj_id: String) -> int:
	if _event_metadata.has(event_name) and _event_metadata[event_name].has(obj_id):
		return _event_metadata[event_name][obj_id]["priority"]
	return Priority.NORMAL


## 让某个事件的连接快照失效
##
## **订阅关系一变就必须调**：订阅、取消订阅、清订阅三处都要，
## 否则 push_event 会拿着一份已经不含新订阅者（或还含已退订者）的旧快照发事件。
func _invalidate_cache(event_name: String) -> void:
	_ordered_connections_cache.erase(event_name)

## 延迟调用
func _schedule_deferred_call(callable: Callable, payload: Array) -> void:
	call_deferred("_do_deferred_call", callable, payload)

## 执行延迟调用
func _do_deferred_call(callable: Callable, payload: Array) -> void:
	if callable.is_valid() and is_instance_valid(callable.get_object()):
		callable.callv(payload)

## 获取订阅数量（测试用）
func get_subscription_counts() -> Dictionary:
	var result = {}
	for event_name in _get_all_signals():
		result[event_name] = get_signal_connection_list(event_name).size()
	return result

## 诊断：列出「有人订阅、但从未被 push 过」的事件名（死事件候选）
##
## 为什么要有：死事件靠人肉搜 `ConstEventName.XXX` 的调用点才能发现，而事件一多就没人再查。
## 这里让运行期自己把答案说出来 —— 跑一关（或多跑几个模式）后取一次，
## 列出来的就是「订阅方等着、发布方根本没写」的事件，可以据此决定删订阅还是补发布。
##
## **只在 debug_mode 下有效**：没开 debug 时 `_pushed_event_names` 是空的，
## 此时本函数会把**所有**有订阅的事件都列出来（等于没信息），所以调用前请先开 debug_mode。
func get_never_pushed_subscribed_events() -> Array[String]:
	var result: Array[String] = []
	for event_name in _get_all_signals():
		if not _pushed_event_names.has(event_name) and get_subscriber_count(event_name) > 0:
			result.append(event_name)
	return result
