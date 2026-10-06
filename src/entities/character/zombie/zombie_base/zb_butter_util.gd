class_name ZombieButterUtil
## 僵尸「黄油糊脸」定身表现：从 Zombie000Base 里抽出来的纯逻辑
## （见 docs/参考存档/重构拆分方案.md 的 B5）
##
## 为什么单独放一个文件：
##   黄油只关心「贴一张黄油图 + 起一个定身计时器 + 到点恢复速度」，
##   与僵尸的移动 / 攻击 / 血量都没有关系，基类里只留一行转发就够。
##
## 约定：
##   · 全部 static，不持有状态：黄油节点挂在僵尸身上（butter_splat 是僵尸的子节点），
##     计时器复用僵尸的 all_timer[Butter]，这里只负责「怎么贴、怎么计时、到点怎么恢复」
##   · 需要改僵尸自身的字段时一律显式传 zombie 进来，不用 get_parent()
##   · 不做成组件：僵尸有 26 个场景，做成组件节点要逐个改 .tscn，代价远大于收益
##     （同样的判断见 重构拆分方案.md §8 B3 的「只操作宿主字段就别拆成节点」）

## 头节点的候选路径（黄油贴脸用）
## 不同僵尸的头挂法不一样，逐个试；都试不到就贴到本体上方，避免空引用
const HEAD_PATH_CANDIDATE: Array[NodePath] = [
	"Body/BodyCorrect/Anim_head/Anim_head1",
	"Body/BodyCorrect/Anim_head1",
	"Body/BodyCorrect/Zombie_head",
	"Body/BodyCorrect/Head/Anim_head1",
	"Body/BodyCorrect/Zombie_catapult_driver_head",
	## 僵王博士：头挂在 ZombieBoss 实例里（黄油对 Zombot 无效，但初始化时会找一次头节点）
	"Body/BodyCorrect/ZombieBoss/Boss_head",
]

## 找头节点，找不到返回 null（沿用原行为：只打日志，不阻断流程）
static func find_head_node(zombie: Zombie000Base) -> Node2D:
	for head_path: NodePath in HEAD_PATH_CANDIDATE:
		if zombie.has_node(head_path):
			return zombie.get_node(head_path)
	Log.error("%s 没有获取头节点" % zombie.name)
	return null

## 黄油糊脸：贴上黄油、速度归零、butter_time 秒后恢复
## 已经在黄油状态时再次被打中 → 计时器重置（与原实现一致）
static func be_butter(zombie: Zombie000Base, butter_time: float) -> void:
	if zombie.is_death:
		return
	if not is_instance_valid(zombie.butter_splat):
		zombie.butter_splat = SceneRegistry.BUTTER_SPLAT.instantiate()
		zombie.add_child(zombie.butter_splat)
	zombie.butter_splat.visible = true
	## 优先贴到头节点上；没有头节点（body 结构被替换时容易漏）兜底到本体上方
	if is_instance_valid(zombie.head_node):
		zombie.butter_splat.global_position = zombie.head_node.to_global(Vector2(20, 10))
	else:
		zombie.butter_splat.global_position = zombie.global_position + Vector2(0, -40)

	zombie.update_speed_factor(0.0, Character000Base.E_Influence_Speed_Factor.Butter)
	if not is_instance_valid(zombie.all_timer[Character000Base.E_TimerType.Butter]):
		zombie.all_timer[Character000Base.E_TimerType.Butter] = GlobalUtils.create_new_timer_once(
			zombie,
			on_butter_timer_timeout.bind(zombie)
		)
	zombie.all_timer[Character000Base.E_TimerType.Butter].start(butter_time)
	## 隐形战争：黄油糊脸时现形（玉米投手是玩家主动让僵尸现形的手段之一）
	zombie.update_invisible_show(false)

## 定身计时结束：恢复速度、收起黄油
static func on_butter_timer_timeout(zombie: Zombie000Base) -> void:
	zombie.update_speed_factor(1.0, Character000Base.E_Influence_Speed_Factor.Butter)
	if is_instance_valid(zombie.butter_splat):
		zombie.butter_splat.visible = false
	## 隐形战争：黄油掉了就重新隐形
	zombie.update_invisible_show(true)

## 死亡时立刻解除定身（原 Zombie000Base.death_stop_butter）
## 不断开计时器：僵尸马上就要被回收，计时器跟着节点一起没了
static func stop_butter(zombie: Zombie000Base) -> void:
	if is_instance_valid(zombie.butter_splat):
		on_butter_timer_timeout(zombie)
