extends RefCounted
## 探针小工具 —— 无头环境没有真人操作，这里替它把关卡流程推下去
##
## 用 preload 引（`const ProbeUtil := preload("res://test/scenarios/probe_util.gd")`），
## 故意不加 class_name：不进全局类表，新增文件后不用先跑一次引擎才敢引用（见 docs/参考存档/关卡格式V2.md）。
##
## 为什么要这两个东西：
## 关卡流程是 LevelScriptBase.run_flow() 里一串 await（见 docs/参考存档/关卡时间轴.md），
## 「选卡」那一步要等玩家点「开始游戏」；提前调 main_game_start() 会把后面的事件
## （准备-安放-植物之类）塞到已经开战之后补跑，而且躲在那些事件里的东西（小推车）永远不出现。
## 所以：**先等关卡真的停在选卡上，再按；要看推车就再等它入场。**

## 替玩家点「开始游戏」：时间轴真的停在选卡上时才按，按完流程自己往下走
##
## **不能图省事直接 main_game_start()** —— 那样推进的是「已经开战」，
## 躲在流程后面的事情（准备-安放-植物、初始化小推车…）一件都不会发生
## （等价卡面板里的 BUG：按钮走的是 choose_card_finish，见 MainGameManager）
static func click_start(a, timeout: float = 40.0) -> void:
	var waited := 0.0
	while waited < timeout:
		var mg = Global.main_game
		if mg == null:
			return
		if mg.is_timeline_waiting_choose_card:
			a.log("  点「开始游戏」（当前阶段=%d）" % mg.main_game_progress)
			mg.is_timeline_waiting_choose_card = false
			await mg.choose_card_finish()
			return
		await a.wait(0.5)
		waited += 0.5
	a.log("  !! 等 %.1fs 也没停在选卡上（本关跳过选卡 / 流程已经往前走了）" % timeout)


## 等小推车登场并回到站位 —— 推车由「初始化小推车」事件吃掉这一口，
## 排在「准备-安放-植物」之前（见 LevelTimelineEventLawnMover），
## 所以**任何要对推车做断言的探针都得先调这个**，否则断言会因为「还没生成」白失败
static func wait_lawn_mowers(a, timeout: float = 20.0) -> bool:
	var waited := 0.0
	while waited < timeout:
		var gim = Global.main_game.game_item_manager.gim_lawn_mover
		if gim != null and gim.is_lawn_movers_inited and gim.pending_appear_lawn_movers.is_empty():
			## 本关压根不该有车也算「等到了」：没铺草皮的行本来就没有车，
			## 泳池 / 屋顶清洁车还要先在商店买过才会配发（见 GIM_LawnMover.is_lane_can_have_mover）
			var expect_mover := false
			for lane in range(gim.all_lane_have_lawn_mover.size()):
				if gim.is_lane_can_have_mover(lane):
					expect_mover = true
					break
			if not expect_mover:
				a.log("  本关没有可用的小推车（地图没配 / 清洁车还没买）")
				return true
			for mower: LawnMover in gim.all_lawn_movers:
				if is_instance_valid(mower):
					a.log("  小推车已就位（行%d，等了 %.1fs）" % [mower.lane, waited])
					return true
		await a.wait(0.5)
		waited += 0.5
	a.log("  !! 等 %.1fs 也没有小推车就位" % timeout)
	return false
