extends RefCounted
class_name TweenUtil
## 掉落物 / 拾取物那几段「逐字重复」的表现代码集中在这里
##
## 以前同一段 tween 在 coin.gd / seed_packet.gd / chocolate_drop.gd / present.gd / trophy.gd
## 里各写了一份（抛物线弹出、淡出后删除、拾取光晕呼吸），改一处要改五处。
## 本文件只管「表现」，不动任何玩法数据；调用方各自负责音效 / 入账 / 提示这些业务尾巴。
##
## 注：delay_free() 用的是 Timer 不是 tween，但同属「表现收尾」，放一起好找。

## 抛物线弹出：水平线性、垂直走抛物线（relative_target 是相对当前位置的落点偏移）
## 返回 tween 供调用方 await（await TweenUtil.parabola_launch(...).finished）
static func parabola_launch(node:Node2D, relative_target:Vector2, duration := 1.0, peak_height := 70.0) -> Tween:
	var start_pos := node.position
	var end_pos := start_pos + relative_target

	var tween := node.create_tween()
	tween.set_parallel()
	## 水平 x：线性插值
	tween.tween_property(node, "position:x", end_pos.x, duration)
	## 垂直 y：函数插值构建抛物线
	tween.tween_method(
		func(t: float) -> void:
			node.position.y = lerpf(start_pos.y, end_pos.y, t) - 4.0 * peak_height * t * (1.0 - t),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	return tween


## 淡出后删除：整体淡到透明，然后把 node 自身 queue_free
## [fade_node] 要淡掉的不是 node 自己时传它（例如僵尸掉落物淡的是子节点的贴图，删的是本体）
static func fade_out_and_free(node:Node, duration := 1.0, fade_node:CanvasItem = null) -> Tween:
	var target: CanvasItem = fade_node if fade_node != null else (node as CanvasItem)
	var tween := node.create_tween()
	tween.tween_property(target, "modulate:a", 0.0, duration)
	tween.tween_callback(node.queue_free)
	return tween


## 拾取光晕那种「呼吸」缩放，无限循环
## [big] / [small] 两端的缩放值；返回 tween（一般不用管，它自己循环）
static func breath_scale_loop(node:Node2D, big := 1.5, small := 1.0, duration := 1.0) -> Tween:
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2(big, big), duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", Vector2(small, small), duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_loops()
	return tween


## 安全打断：tween 可能已经被自己跑完 / 节点已释放，直接 kill() 会报错
static func kill_tween(tween:Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


## 延迟若干秒后删除自己；切场景 / 中途已被删除时自动跳过（避免空引用报错）
static func delay_free(node:Node, seconds:float) -> void:
	if node == null:
		return
	var tree := node.get_tree()
	if tree == null:
		return
	await tree.create_timer(seconds).timeout
	if is_instance_valid(node):
		node.queue_free()
