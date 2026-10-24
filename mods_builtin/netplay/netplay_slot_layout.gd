extends RefCounted
## 联机的**卡槽分块**：出战卡槽按人数切成若干块，每人一块
##
## ★ 为什么要有"块"：卡与冷却都存在**房主**那一局里（全局只有一份），
##   两个人各有各的卡 ⇒ 必须说清"这一格是谁的"，否则谁都能种别人的卡。
##   分块就是这句话的答案：**每人一段**，种植时客户端报"卡在卡槽里的第几格"，
##   房主验"这一格落在谁的块里"，再照本体那套判种植合法 / 阳光够不够。
##
## ★ 三层口径（别混）：
##   1. **宽度**（`block_widths`）：卡槽格数按人数**尽量均分** —— 每人最多能选几张
##   2. **合并卡表**（`compose`）：各人选的卡按块顺序拼成**一份**，房主的卡槽里就是这一份
##   3. **归属**（`owns_index`）：某个下标是不是落在某个人的块里（房主验种植时用）
##
## 纯数据、无节点依赖 ⇒ 探针可以直接验它（`test/scenarios/probe_netplay_slot_layout.gd`）。
##
## 关联：[联机模组](../../docs/参考存档/联机模组.md) ｜
## [NetplayCardSync](netplay_card_sync.gd) ｜ [NetplayBattleSync](netplay_battle_sync.gd)

## 卡槽容量按人数切成若干块（尽量均分）：返回**每块的宽度**
##
## 切法：`第 i 块的宽度 = floor((i+1)*S/P) - floor(i*S/P)`
## ⇒ 多出来的那几格落在**靠后**的块上（S=6、P=2 ⇒ 3+3；S=7、P=2 ⇒ 3+4；S=5、P=3 ⇒ 1+2+2）
##
## ★ 为什么"多出来的给靠后的块"：房主自己占第 0 块（他是事实来源），
##   把零头留给后面的人，房主那一块永远是最小的那个 ⇒ 房主不会因为人多而占不到卡位。
static func block_widths(capacity: int, players: int) -> Array[int]:
	var out: Array[int] = []
	if capacity <= 0 or players <= 0:
		return out
	for i in range(players):
		out.append(_boundary(capacity, i + 1, players) - _boundary(capacity, i, players))
	return out


## 第 [param index] 条分界线在卡槽里的位置（整数除法 = 向下取整）
static func _boundary(capacity: int, index: int, players: int) -> int:
	return int(floor(float(index * capacity) / float(players)))


## 分块方案：{peer_id = 该人那块能放几张}
##
## [param peer_ids] 参与这一局的人（**房主排第一个**，其余按 peer id 升序）
static func plan_of(peer_ids: Array, capacity: int) -> Dictionary:
	var out: Dictionary = {}
	var widths := block_widths(capacity, peer_ids.size())
	for i in range(peer_ids.size()):
		out[int(peer_ids[i])] = int(widths[i]) if i < widths.size() else 0
	return out


## 把各人选的卡按块顺序拼成一份，并算出每块在合并卡表里的范围
##
## [param blocks] 每项 `{peer_id: int, refs: Array}`（refs 是 `ResourceCardReference` 列表）
## [return] `{refs: Array[ResourceCardReference], ranges: {peer_id: {start, count}}}`
##
## ★ 范围为什么按**实际选到的张数**切：合并卡表是紧凑的（没有空格），
##   每个人的卡必须**连成一段**（一段 = 一块），否则"第几格属于谁"就没法判了。
##   "尽量均分"落在**宽度**那一层（每人最多能选几张，见 `block_widths`）。
static func compose(blocks: Array) -> Dictionary:
	var refs: Array[ResourceCardReference] = []
	var ranges: Dictionary = {}
	for block in blocks:
		if not (block is Dictionary):
			continue
		var peer_id := int(block.get("peer_id", 0))
		var block_refs: Array = block.get("refs", [])
		var start := refs.size()
		for one in block_refs:
			var reference := one as ResourceCardReference
			## ⚠️ 这里**不拿 `is_valid()` 过滤**：那个只认**内置**角色
			##   （运行期热注册的模组角色不在 `ALL` 里，见 `ResourceCardReference.is_valid()`），
			##   一过滤掉，模组自己的卡就会从合并卡表里消失 ⇒ 两端"第几格"对不上。
			if reference == null or reference.content_id == &"":
				continue
			refs.append(reference)
		ranges[peer_id] = {"start": start, "count": refs.size() - start}
	return {"refs": refs, "ranges": ranges}


## 卡槽第 [param index] 格是不是落在 [param peer_id] 那一块里
##
## ★ 这是房主验种植的那一句：**不属于这个人的块 ⇒ 这一笔不认**（别人的卡不许种）。
static func owns_index(ranges: Dictionary, peer_id: int, index: int) -> bool:
	if index < 0:
		return false
	var block: Dictionary = ranges.get(peer_id, {})
	if block.is_empty():
		return false
	var start := int(block.get("start", -1))
	var count := int(block.get("count", 0))
	if start < 0 or count <= 0:
		return false
	return index >= start and index < start + count


## 某人那块在合并卡表里的范围（没有就返回空字典）
static func range_of(ranges: Dictionary, peer_id: int) -> Dictionary:
	var block: Dictionary = ranges.get(peer_id, {})
	return block if not block.is_empty() else {}
