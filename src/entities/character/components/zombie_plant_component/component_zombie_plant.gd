extends ComponentNormBase
class_name ZombiePlantComponent
## 植物僵尸的「替代僵尸头的那颗植物」组件（原版 ZomBotany）
##
## 为什么继承 ComponentNormBase 而不是裸 Node2D（两者都是 Node2D，场景不用改）：
## 本组件此前是唯一一个「名字叫 Component、放在 components/ 下，却不进组件体系」的组件 ——
## 它自己重写 `_ready()`，于是拿不到框架统一的两件事：
##   ① `is_enable_default`（场景里关掉组件是否真的生效）—— 子类重写 `_ready()` 漏写 super 就会静默失效；
##   ② `component_ready()` 这个生命周期入口 —— 别处查「组件初始化写在哪」时它不在。
## 代价为零：ComponentNormBase 本身就是 Node2D，14 个僵尸场景里的 `type="Node2D"` 不用动。
##
## 只负责**用植物的头把僵尸自己的头换掉**这一件事，攻击行为由各自的攻击组件负责：
##   · 僵尸原本的头（`Anim_head1` 贴图 + 下巴 / 舌头 / 胡子 / 头发）不再绘制；
##   · 按 ZomBotanyConfig 把那颗植物的头摆到僵尸身上：**挂点（轨道）与 offset / rot / scale
##     全部照抄原版** `AttachReanim`（`Zombie.cpp` 707–851 行）——
##     挂 `Anim_head1` 的跟着摇头 / 点头，挂 `Zombie_body` 的跟身体走且画在身体**之上**；
##   · 那颗头可以是**静态贴图**（`sprites`，扩展的 8 只）或**带动画的头场景**（`head_scene`，
##     原版 6 只）：后者待机播 `Head_Idle`、攻击播 `Head_Attack`（发射由动画自己的方法轨
##     回调攻击组件，见 `play_head_attack_anim()`），根 = 植物自己的原点。
##
## 那颗植物的**耐久**是挂在僵尸身上的 `ArmorComponentPlantHead`（一类防具）的血量，
## 打光了由那个防具组件把植物藏起来（见 `component_armor_plant_head.gd`）—— 本组件不碰耐久。
##
## 为什么耐久走防具而不是自己存一份：
##   伤害结算（先防具后本体）与血条显示都在 HpComponent 里，自己再存一份会和它各演化各的（K-01）。

## 僵尸自己的头（被植物取代的就是它）
## 注意是 `Anim_head`（容器）/ `Anim_head1`（承头贴图的 Sprite2D）两层 ——
## `Anim_head` 本身不能隐藏（植物就挂在它下面），也不能只改 `Anim_head1.visible`（动画会还原）
const C_ZOMBIE_HEAD_PATH := ^"Anim_head/Anim_head1"
## 僵尸脸上跟着一起没的部件（**外层**容器：动画只驱动它们内层的 visible，
## 隐藏外层不会被动画还原 —— 见 `resource_body_change.gd` 里「掉头」用的同一套路径）
const C_ZOMBIE_FACE_PATHS: Array[NodePath] = [
	^"Anim_head2",			## 下巴
	^"Anim_tongue",			## 舌头
	^"Zombie_mustache",		## 胡子
	^"Anim_hair",			## 头发
]

## 动画版植物头场景里，动画播放器在场景根下的名字（约定，改场景就要同步这里）
const C_HEAD_ANIM_PLAYER_NAME := ^"AnimationPlayer"
## 动画版植物头的待机动画名 —— 直接沿用植物自己的 `Head_Idle`（呼吸 / 张嘴）
const C_HEAD_IDLE_ANIM := &"Head_Idle"
## 动画版植物头的攻击动画名 —— 同样搬自植物（`Head_Attack`）
const C_HEAD_ATTACK_ANIM := &"Head_Attack"
## `Head_Attack` 里「吐出豌豆」那一帧调的方法名：原植物调自己 `AttackComponent` 的同名方法，
## 头搬到僵尸身上之后由本组件把这条方法轨重定向到僵尸的攻击组件（见 `_bind_head_attack_shoot_track`）
const C_HEAD_SHOOT_METHOD := &"_shoot_bullet"
## `Head_Attack` 的播放倍速：原植物把它接在 `AnimationTree` 的 `TimeScale 2 = 3.0` 上，
## 不照抄的话头会慢三拍（2 秒的动作拖成 2 秒，豌豆也对不上帧）
const C_HEAD_ATTACK_SPEED := 3.0
## 僵尸身上攻击组件的节点名（攻击动画的方法轨要指到它）
const C_ATTACK_COMPONENT_PATH := ^"AttackComponent"
## 僵尸自己的 `AnimationPlayer`（动画头的「基准姿态」要从它的动画里读，见 `_get_track_base_pose`）
const C_ZOMBIE_ANIM_PLAYER_PATH := ^"AnimationPlayer"
## 读基准姿态用的动画：僵尸走路。它的轨道第 0 帧 = reanim 第 0 帧，
## 和 idle / eat / death 各图层的第一帧是同一份姿态（三个图层都核对过）
const C_BASE_POSE_ANIM := &"Zombie_walk"
## 僵尸的领带（`Body/BodyCorrect/Zombie_tie` 这个**外层容器**，里面的贴图才随机隐藏）：
## 整颗植物替换掉头的那几只（坚果 / 高坚果 / 辣椒）领带会从植物底下露出来，
## 原版对它们 `ReanimShowPrefix("Zombie_tie", RENDER_GROUP_HIDDEN)`，这里按配置同样关掉
const C_ZOMBIE_TIE_PATH := ^"Zombie_tie"
## 僵尸的身体贴图节点（原版 `Zombie_body` 轨道）：坚果 / 高坚果 / 辣椒僵尸把头挂在这上面 ——
## 既决定了位置（跟身体走，不跟头），也决定了**图层**（画在身体贴图之上）
const C_ZOMBIE_BODY_PATH := ^"Zombie_body"
## 死亡时掉出来的那个头（普僵的头部件都在它下面）：`Body/NodeDrop/Node2D_Head_Drop/Head_Drop`
## 植物僵尸掉出来的应该是**植物头**，不是僵尸头
const C_DROP_HEAD_PATH := ^"Body/NodeDrop/Node2D_Head_Drop/Head_Drop"

## 僵尸头轨道 `anim_head1`（完整路径）：节点 `position` 就是原版 reanim 轨道的 `mTrans`
##（`pak/reanim/Zombie.reanim` 第 0 帧 x=6.7 y=8.8 与 Godot 侧动画值完全一致），
## 节点原点 = 头贴图左上角 —— 原版发射点公式就架在这条轨道上（见 `get_head_shoot_global_position`）
const C_HEAD_TRACK_PATH := ^"Body/BodyCorrect/Anim_head/Anim_head1"
## 原版发射点偏移，**相对头贴图左上角**；从 `Zombie.cpp` 两段代码换算出来（不是估的）：
##   ① `UpdateZombiePeaHead()` 2338-2339 / `UpdateZombieGatlingHead()` 2458-2459：
##        aOrigin = mPos + aTransform(anim_head1) + (-9, +6 - mAltitude)
##   ② reanim 原点在 `DrawZombieWithParts()` 里是 `mPos + (15, -8)`
##      （`SetPosition(mImageOffsetX + 15 + 30 - 30s, mImageOffsetY + mBodyY - 8 + 120 - 120s)`，普通僵尸 s=1、mBodyY=0），
##      而 `mPos` 是僵尸**头顶**（碰撞框 `mZombieRect = Rect(36, 0, 42, 115)` 从 mPos 往下 115 到脚底）。
##   → 发射点 = 头贴图左上角 + (-9-15, +6+8) = 头贴图左上角 + (-24, +14)
## `mAltitude` 在两式里各出现一次（`- mAltitude` 与 `mBodyY = -mAltitude`），正好抵消；
## 跳跃高度体现在头节点自身的世界位置上，不用再减。
const C_SHOOT_OFFSET := Vector2(-24, 14)
## 魅惑态（原版 `mMindControlled`）的发射点偏移，同样相对头贴图左上角。
## 原版两个吐豆僵尸（豌豆 / 机枪头）的 `DO_FIX_BUGS` 分支完全一致：
##   `aOriginX += 90.0f * mScaleZombie`（豌豆僵尸是普通僵尸，s = 1）后改发**植物方**豌豆
##   （`PROJECTILE_PEA`，不带 `MOTION_BACKWARDS` → 朝右飞，打右边还没被魅惑的同类）。
##   → 头贴图左上角 + (-24 + 90, +14) = (66, +14)
## 仓库侧魅惑同样靠 body 水平镜像实现（`Character000Base.be_hypno()` → `update_direction_x_root(-1)`），
## 头节点世界位置已含镜像，这里直接叠原版常量，不再走下面的镜像取反（两条路只选一条）。
const C_SHOOT_OFFSET_HYPNO := Vector2(66, 14)

## 静态头的待机呼吸：原版植物头是 reanim（idle 有轻微呼吸 / 摆动），
## 本仓库除豌豆僵尸外都没有动画头，这里用一个很小的缩放循环让它不完全静止。
## ⚠️ 这是**近似表现**，不是原版 reanim；有 `head_scene` 的（豌豆僵尸）由 `Head_Idle` 自己演，不叠这个。
const C_STATIC_HEAD_IDLE_SCALE := 1.03
const C_STATIC_HEAD_IDLE_TIME := 0.9

## 植物头节点（运行时创建，挂在僵尸头节点下）
var plant_head: Node2D
## 静态头的主体贴图（`sprites[0]`）——受损裂纹换的就是这一张
var _head_body_sprite: Sprite2D
## 动画版植物头的播放器（静态头 / 没配动画时为空）
var head_anim_player: AnimationPlayer
## 本实例的攻击动画里是否真的绑上了发射方法轨 —— 绑不上就让攻击组件自己发射（不会静默不射）
var _head_shoot_bound := false
## 本只植物僵尸的数据（不是植物僵尸时为空）
var zom_botany_info: ZomBotanyConfig.ZomBotanyInfo


## 组件初始化入口（**不是** `_ready()` —— 见硬约束 §1-3 与 ComponentNormBase.component_ready）
func component_ready() -> void:
	super()
	if not (owner is Zombie000Base):
		Log.error("ZombiePlantComponent 只能挂在僵尸上，当前 owner：" + str(owner))
		return
	var zombie: Zombie000Base = owner
	zom_botany_info = ZomBotanyConfig.get_info(zombie.zombie_type)
	if zom_botany_info == null:
		Log.error("僵尸 " + str(zombie.zombie_type) + " 不是已配置的植物僵尸，换头组件空转")
		return
	## 组件比宿主先 `_ready()`（Godot 先子后父），而宿主的 `ready_norm()` 里还有一步随机外观
	## （`Zombie001Norm._random_sprit_appear()` 会把舌头 / 头发随机设成 visible）——
	## 在这里直接隐藏**会被它盖掉**。所以等宿主整个 `_ready()` 走完再换头。
	if owner.is_node_ready():
		_replace_zombie_head()
	else:
		owner.ready.connect(_replace_zombie_head, CONNECT_ONE_SHOT)


## 用植物的头把僵尸自己的头换掉
func _replace_zombie_head() -> void:
	var body_correct := owner.get_node_or_null(^"Body/BodyCorrect") as Node2D
	if not is_instance_valid(body_correct):
		Log.error("植物僵尸找不到 Body/BodyCorrect，换头无法进行")
		return
	var zombie_head := body_correct.get_node_or_null(C_ZOMBIE_HEAD_PATH) as Sprite2D
	if not is_instance_valid(zombie_head):
		Log.error("植物僵尸找不到僵尸头节点 Body/BodyCorrect/" + str(C_ZOMBIE_HEAD_PATH) + "，换头无法进行")
		return
	_hide_zombie_head(zombie_head, body_correct)
	_create_plant_head(zombie_head, body_correct)
	## 换头之后再连防具（此时防具的 `curr_hp` / `max_hp` 都已就绪）与掉落物
	_connect_head_armor()
	_replace_drop_head()


## 让僵尸自己的头不再绘制
##
## 头贴图用 `self_modulate` 的 alpha 关掉，**不是** `visible = false`，两个原因：
##   1. 动画里有 `Anim_head/Anim_head1:visible` 这条 track（死亡动画会把它设成 false），
##      改 `visible` 会被动画在下一帧还原；
##   2. `visible` 是**继承**的 —— 植物就挂在这个头节点下面，关掉它等于把植物一起关掉。
## `self_modulate` 只影响本节点自身的绘制，不牵连子节点，也没有动画 track 会覆盖它。
func _hide_zombie_head(zombie_head: Sprite2D, body_correct: Node2D) -> void:
	zombie_head.self_modulate.a = 0.0
	for face_path in C_ZOMBIE_FACE_PATHS:
		var face := body_correct.get_node_or_null(face_path) as Node2D
		if is_instance_valid(face):
			face.visible = false
	## 领带：原版只对「整颗植物替换头」的那三只关掉（见 ZomBotanyConfig.hide_tie）。
	## 关的是外层容器 —— 内层贴图的 `visible` 会被 `_random_sprit_appear()` 随机打开
	if zom_botany_info != null and zom_botany_info.hide_tie:
		var tie := body_correct.get_node_or_null(C_ZOMBIE_TIE_PATH) as Node2D
		if is_instance_valid(tie):
			tie.visible = false


## 在僵尸身上摆出那颗植物的头
##
## 两种植物头，二选一（配置表里 `head_scene` 优先）：
##   · `head_scene`：一颗带 AnimationPlayer 的「植物头场景」，待机 `Head_Idle`、攻击 `Head_Attack`。
##     摆放**直接照抄原版**：`ZomBotanyInfo.attach` 的挂点轨道 + offset / rot / scale
##     （`Zombie.cpp` 707–851 行的 `AttachReanim`），见 `_attach_head_to_original_track()`；
##   · `sprites`：没有动画资源时的兜底，用几张静态 PNG 拼出来（组件自己按「贴图中心对贴图中心」摆）。
func _create_plant_head(zombie_head: Sprite2D, body_correct: Node2D) -> void:
	plant_head = _create_plant_head_node()
	if not is_instance_valid(plant_head):
		## 头场景坏了也不能让僵尸顶着一颗没被替换的人头：退回空节点，下面用 `sprites` 拼静态头
		plant_head = Node2D.new()
	plant_head.name = &"PlantHead"
	## 头场景实例化出来了（有子节点）才走原版 attach；否则按静态头处理
	if zom_botany_info.head_scene != null and plant_head.get_child_count() > 0:
		_attach_head_to_original_track(zombie_head, body_correct)
		_bind_head_attack_shoot_track()
		_resolve_head_body_sprite()
		## 起播失败（缺 AnimationPlayer / 缺 idle 动画）就保持场景自己的静态姿势，
		## 不再叠一层静态头（那会变成两张脸）
		_play_plant_head_idle()
		return
	_attach_static_head(zombie_head)
	for sprite_info: ZomBotanyConfig.PlantSprite in zom_botany_info.sprites:
		var sprite := Sprite2D.new()
		sprite.texture = sprite_info.texture
		sprite.position = sprite_info.offset
		sprite.scale = Vector2.ONE * sprite_info.scale
		plant_head.add_child(sprite)
		## `sprites[0]` 是主体（配置表约定「越靠后越上层」，主体放第一张）：
		## 受损裂纹换的是它，别的部件（眼睛 / 炮筒）不跟着换
		if _head_body_sprite == null:
			_head_body_sprite = sprite
	_start_static_head_idle()


## 动画头：按原版 `AttachReanim(轨道, offset, rot, scale)` 把「植物原点」摆到挂点轨道上
##
## 挂点就是**图层**：
##   · `Anim_head1`（僵尸头节点）—— 走路摇头 / 啃咬点头都在这条 track 上，植物跟着一起动；
##   · `Zombie_body`（身体贴图节点）—— 跟身体走、不跟头，且画在身体贴图**之上**（子节点后绘制）。
## 原版哪只挂哪条见 `Zombie.cpp` 707–851 行，配置表 `ZomBotanyInfo.attach` 一一对应。
##
## `position` / `rotation` / `scale` 三个数直接对应原版，但**旋转要取负**：
##   · `position`：原版轨道 `(x,y)` 就是贴图的**左上角**（`DrawTrack` 里给矩阵预乘
##     `T(+cel/2)`，`ReanimBltMatrix` 再减 `scale*cel/2`，两者相消），本仓库的精灵是
##     `centered = false`、节点原点同样是左上角 —— 所以 offset 原样用，**不要**加减半个贴图；
##   · `rotation`：原版 `PvzpScaleRotateTransformMatrix(rad)` 的线性部分是
##     `[[cos·sx, sin·sy], [-sin·sx, cos·sy]]` = `R(-rad)·S`，而 Godot 的 `rotation` 是 `R(θ)·S`，
##     所以 `rotation = -attach.rotation`；直接写 `+0.2` 会把植物反向掰 ~23°；
##   · `scale`：原版 x 的负号是水平镜像，原样用（植物贴图朝右、僵尸朝左）。
##
## ⚠️ 摆位**不是**直接把植物挂到轨道节点下：原版要扣掉挂点轨道的**基准姿态**（见
## `_get_track_base_pose`），所以中间垫一层 `AttachBasePoseInverse`。
func _attach_head_to_original_track(zombie_head: Sprite2D, body_correct: Node2D) -> void:
	var attach := zom_botany_info.attach
	if attach == null:
		Log.error("植物僵尸配了动画头却没配原版 attach 参数：" + str(zom_botany_info.head_scene.resource_path))
		attach = ZomBotanyConfig.HeadAttach.new()
	var anchor := _get_head_anchor(zombie_head, body_correct, attach.to_body)
	## 抵消挂点轨道的基准姿态（原版 `mFrameBasePose = 0` 做的就是这个除法）
	var remove_base_pose := Node2D.new()
	remove_base_pose.name = &"AttachBasePoseInverse"
	remove_base_pose.transform = _get_track_base_pose(anchor).affine_inverse()
	anchor.add_child(remove_base_pose)
	remove_base_pose.add_child(plant_head)
	## 坐标原点是同一个（贴图左上角），offset 原样用；旋转取负，见上面的说明
	plant_head.position = attach.offset
	plant_head.rotation = -attach.rotation
	plant_head.scale = attach.scale


## 挂点轨道在**基准帧（reanim 第 0 帧）**上的姿态 —— 原版会把它除掉
##
## 原版 `Reanimation::GetAttachmentOverlayMatrix()` 算的是
## `僵尸 overlay · 轨道(当前帧) · 轨道(基准帧)⁻¹`，基准帧由 `aBodyReanim->mFrameBasePose = 0`
## 指定（`NO_BASE_POSE = -2`，写 0 就是第 0 帧，**不是**「没有基准」）。
## 也就是说轨道第 0 帧自带的平移 / 缩放**不参与**：植物原点正好落在 `attach.offset`
## （僵尸 reanim 坐标系），植物只再乘一次 `attach.scale`。
##
## 本仓库的动画资源写的是**绝对姿态**（每个图层的时间 0 = reanim 第 0 帧，四个图层核对过），
## 直接挂到轨道节点下会多乘一次 `轨道(0)`（reanim 1 单位 = 800x600 下 1 像素）：
##   · 挂 `Zombie_body` 的三只（坚果 / 高坚果 / 辣椒）：多带 (28.9, 33.8) 和 0.8 缩放
##     → 植物原点偏低 ~34px、还右移 ~19px；
##   · 挂 `Anim_head1` 的三只（豌豆 / 机枪 / 窝瓜）：多带 (6.7, 8.8) 和 0.8 缩放
##     → 偏低 9~12px；
##   · 六只共同：植物被 0.8 再缩一次（净 0.64 而不是 `attach.scale` 的 0.8），小 20%。
## 这就是用户反馈的「坚果 / 高坚果 / 辣椒靠下、窝瓜靠上、机枪 / 豌豆有微小差别」。
func _get_track_base_pose(anchor: Node2D) -> Transform2D:
	var anim := _find_base_pose_anim(anchor)
	if anim == null:
		## 读不到就退回「不抵消」的旧行为（只会偏几像素，不至于让头飞到天上去）
		Log.warn("[ZombiePlantComponent] 读不到挂点轨道的基准姿态，植物头会偏几像素："
			+ str(owner.get_path_to(anchor)))
		return Transform2D.IDENTITY
	var track_prefix := str(owner.get_path_to(anchor))
	var base_position := anchor.position
	var base_rotation := anchor.rotation
	var base_scale := anchor.scale
	var position_value: Variant = _first_key_value(anim, NodePath(track_prefix + ":position"))
	if position_value is Vector2:
		base_position = position_value
	var rotation_value: Variant = _first_key_value(anim, NodePath(track_prefix + ":rotation"))
	if rotation_value is float or rotation_value is int:
		base_rotation = float(rotation_value)
	var scale_value: Variant = _first_key_value(anim, NodePath(track_prefix + ":scale"))
	if scale_value is Vector2:
		base_scale = scale_value
	return Transform2D(base_rotation, base_scale, 0.0, base_position)


## 找一份含该挂点轨道的动画：优先走路，找不到再扫整库
## （各图层的第 0 帧是同一份基准姿态，用哪份都一样）
func _find_base_pose_anim(anchor: Node2D) -> Animation:
	var anim_player := _get_zombie_anim_player()
	if not is_instance_valid(anim_player):
		return null
	var track_path := NodePath(str(owner.get_path_to(anchor)) + ":position")
	var preferred := anim_player.get_animation(C_BASE_POSE_ANIM)
	if preferred != null and _find_track_by_path(preferred, track_path) >= 0:
		return preferred
	for anim_name: StringName in anim_player.get_animation_list():
		var anim := anim_player.get_animation(anim_name)
		if anim != null and _find_track_by_path(anim, track_path) >= 0:
			return anim
	return null


## 僵尸自己的 `AnimationPlayer`（六个植物僵尸场景都继承 `zombie_norm.tscn`，直属子节点）
func _get_zombie_anim_player() -> AnimationPlayer:
	var anim_player := owner.get_node_or_null(C_ZOMBIE_ANIM_PLAYER_PATH) as AnimationPlayer
	if is_instance_valid(anim_player):
		return anim_player
	return owner.find_child(str(C_ZOMBIE_ANIM_PLAYER_PATH), true, false) as AnimationPlayer


## 取某条轨道第 0 帧的值（读不到返回 null）
func _first_key_value(anim: Animation, path: NodePath) -> Variant:
	var track := _find_track_by_path(anim, path)
	if track < 0 or anim.track_get_key_count(track) <= 0:
		return null
	return anim.track_get_key_value(track, 0)


## 按轨道路径找下标（找不到 -1）
##
## ⚠️ 不用 `Animation.track_find_by_path()` —— Godot 4 的 `Animation` 没有这个函数
## （那是 Godot 3 的 API；`find_track(path, type)` 在 4.x 里签名也变过），
## 这里直接遍历 `track_get_path()`，两个版本都稳。
func _find_track_by_path(anim: Animation, path: NodePath) -> int:
	for track in anim.get_track_count():
		if anim.track_get_path(track) == path:
			return track
	return -1


## 原版的挂点轨道：`to_body` = 身体贴图 `Zombie_body`，否则 = 僵尸头 `Anim_head1`
func _get_head_anchor(zombie_head: Sprite2D, body_correct: Node2D, to_body: bool) -> Node2D:
	if not to_body:
		return zombie_head
	var body := body_correct.get_node_or_null(C_ZOMBIE_BODY_PATH) as Node2D
	if is_instance_valid(body):
		return body
	Log.error("植物僵尸找不到身体贴图节点 Body/BodyCorrect/" + str(C_ZOMBIE_BODY_PATH) + "，改挂到僵尸头上")
	return zombie_head


## 静态头兜底：几张 PNG 拼在僵尸头节点下，「贴图中心对贴图中心」+ 抵消头节点自身的缩放 / 倾斜
func _attach_static_head(zombie_head: Sprite2D) -> void:
	zombie_head.add_child(plant_head)
	## 头贴图是 `centered = false`：贴图从节点原点画到 size，所以节点原点就是「头的左上角」，
	## 植物原点要落在头贴图的**中心**上，再由配置表做最后几像素的微调
	var head_center := Vector2.ZERO
	if zombie_head.texture != null:
		head_center = zombie_head.texture.get_size() * 0.5
	plant_head.position = head_center + zom_botany_info.head_offset
	## 抵消僵尸头节点自身的缩放与倾斜：植物最终大小 = `head_scale`，静止时是正的。
	## 抵消的是**初始值**，动画随后在头节点上播的摆动照常传下来（头摇，植物跟着摇）。
	plant_head.rotation = -zombie_head.rotation
	plant_head.scale = Vector2.ONE * (zom_botany_info.head_scale / maxf(absf(zombie_head.scale.x), 0.0001))
	## 左右翻转：植物贴图一律朝右（植物的朝向），而僵尸朝左走（房子在左，豌豆也朝左飞），
	## 不翻的话植物是「背对着」僵尸行进方向长在头上的。翻的是 `plant_head` 的 x 缩放，
	## 各张贴图的 `offset` 会跟着一起镜像，整颗植物就是一张水平镜像图；
	## 位置参数都在上一层（僵尸头节点）坐标系里，不受这次翻转影响。
	plant_head.scale.x *= -1.0


## 静态头的待机呼吸（近似原版 reanim 的 idle）：轻微放大再回位，循环。
## 有动画头的（原版 6 只 + 扩展里有 `head_scene` 的）走 `Head_Idle`，不进这里。
func _start_static_head_idle() -> void:
	if not is_instance_valid(plant_head):
		return
	var base_scale: Vector2 = plant_head.scale
	var tween := plant_head.create_tween().set_loops()
	tween.tween_property(plant_head, "scale", base_scale * C_STATIC_HEAD_IDLE_SCALE, C_STATIC_HEAD_IDLE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(plant_head, "scale", base_scale, C_STATIC_HEAD_IDLE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 连头顶植物那层防具的掉血信号：受损到 2/3、1/3 时换裂纹贴图
func _connect_head_armor() -> void:
	var head_armor := _get_head_armor()
	if head_armor == null:
		return
	if not head_armor.signal_armor_hp_loss.is_connected(_on_head_armor_hp_loss):
		head_armor.signal_armor_hp_loss.connect(_on_head_armor_hp_loss)


## 头顶植物那层防具（`ArmorComponentPlantHead`）；没有配这层防具时返回 null
func _get_head_armor() -> ArmorComponent:
	var zombie := owner as Zombie000Base
	if zombie == null:
		return null
	return zombie.get_armor(ConstArmor.E_ArmorType.PlantHead)


## 防具掉血：按破损阶段换裂纹（原版 `Zombie::TakeHelmDamage()` 的 damage index）
## `curr_hp_stage`：-1 = 满血、0 = 掉到 2/3、1 = 掉到 1/3；再往下整颗头会被防具组件隐藏。
func _on_head_armor_hp_loss(_curr_hp: int, _is_drop: bool) -> void:
	if zom_botany_info == null or zom_botany_info.cracked_sprites.is_empty():
		return
	if not is_instance_valid(_head_body_sprite):
		return
	var head_armor := _get_head_armor()
	if head_armor == null or head_armor.curr_hp_stage < 0:
		return
	var index := mini(head_armor.curr_hp_stage, zom_botany_info.cracked_sprites.size() - 1)
	var cracked: Texture2D = zom_botany_info.cracked_sprites[index]
	if cracked != null:
		_head_body_sprite.texture = cracked


## 死亡时掉出来的头换成植物头（原版尸体掉的就是它自己的那颗头）
##
## 掉落节点 `Body/NodeDrop/Node2D_Head_Drop/Head_Drop` 里是普僵头的几个部件，
## 把部件隐藏、补一张植物头主体贴图即可：弹跳 / 旋转是掉落节点自己驱动的，这里不用管。
func _replace_drop_head() -> void:
	var drop_head := owner.get_node_or_null(C_DROP_HEAD_PATH) as Node2D
	if not is_instance_valid(drop_head):
		return
	var body_texture: Texture2D = null
	if zom_botany_info != null and not zom_botany_info.sprites.is_empty():
		body_texture = zom_botany_info.sprites[0].texture
	if body_texture == null:
		return
	for child in drop_head.get_children():
		if child is Sprite2D:
			child.visible = false
	var sprite := Sprite2D.new()
	sprite.texture = body_texture
	sprite.position = zom_botany_info.head_offset
	sprite.scale = Vector2(-zom_botany_info.head_scale, zom_botany_info.head_scale)
	drop_head.add_child(sprite)


## 建植物头节点本体：有动画场景就实例化它，没有就新建空 Node2D 等 `sprites` 往里拼
func _create_plant_head_node() -> Node2D:
	if zom_botany_info.head_scene == null:
		return Node2D.new()
	var head := zom_botany_info.head_scene.instantiate() as Node2D
	if not is_instance_valid(head):
		Log.error("植物头场景实例化失败（根节点必须是 Node2D）：" + str(zom_botany_info.head_scene.resource_path))
		return null
	return head


## 起播植物头的待机动画：那颗植物不再是静态图，跟着自己的 `Head_Idle` 呼吸 / 张嘴
## 返回 false = 这颗头播不了动画（缺播放器 / 缺动画），调用方退回静态头
func _play_plant_head_idle() -> bool:
	var anim_player := plant_head.get_node_or_null(C_HEAD_ANIM_PLAYER_NAME) as AnimationPlayer
	if not is_instance_valid(anim_player):
		Log.error("植物头动画场景缺少 " + str(C_HEAD_ANIM_PLAYER_NAME) + "：" + str(zom_botany_info.head_scene.resource_path))
		return false
	if not anim_player.has_animation(C_HEAD_IDLE_ANIM):
		Log.error("植物头动画场景缺少 " + str(C_HEAD_IDLE_ANIM) + " 动画：" + str(zom_botany_info.head_scene.resource_path))
		return false
	head_anim_player = anim_player
	## 攻击动画是一次性的，播完回待机；待机本身循环，不会触发这个信号
	if not anim_player.animation_finished.is_connected(_on_head_anim_finished):
		anim_player.animation_finished.connect(_on_head_anim_finished)
	anim_player.speed_scale = 1.0
	anim_player.play(C_HEAD_IDLE_ANIM)
	return true


## 动画头里「主体贴图」的节点（受损裂纹换的就是它）
##
## 静态头的贴图是组件自己建的（`sprites[0]`），动画头的贴图由动画资源自己设，
## 所以只能在实例化后按 `ZomBotanyInfo.head_body_path` 找节点，找不到就不换裂纹（不报错：
## 扩展出来的那几只本来就没有裂纹贴图）
func _resolve_head_body_sprite() -> void:
	_head_body_sprite = null
	if zom_botany_info.head_body_path.is_empty():
		return
	_head_body_sprite = plant_head.get_node_or_null(zom_botany_info.head_body_path) as Sprite2D
	if not is_instance_valid(_head_body_sprite) and not zom_botany_info.cracked_sprites.is_empty():
		Log.error("植物头场景里找不到主体贴图节点 " + str(zom_botany_info.head_body_path)
			+ "：" + str(zom_botany_info.head_scene.resource_path))


## 攻击动画播完：回到待机呼吸
func _on_head_anim_finished(anim_name: StringName) -> void:
	if anim_name == C_HEAD_ATTACK_ANIM:
		_play_plant_head_idle()


## 播头顶植物的攻击动画，返回 true 表示「这次发射交给动画了」
##
## 发射不是这里做的：`Head_Attack` 自带一条方法轨，在「吐出豌豆」那一帧回调攻击组件的
## `_shoot_bullet()`（植物本体就是这么接的，见 `plant_pea_shooter_single.tscn` 的 `AttackComponent` 方法轨）。
## 返回 false（静态头 / 没配攻击动画 / 发射方法轨没绑上）时，调用方照旧自己发射。
func play_head_attack_anim() -> bool:
	if not _head_shoot_bound:
		return false
	if not is_instance_valid(head_anim_player) or not head_anim_player.has_animation(C_HEAD_ATTACK_ANIM):
		return false
	head_anim_player.speed_scale = C_HEAD_ATTACK_SPEED
	head_anim_player.play(C_HEAD_ATTACK_ANIM)
	return true


## 把 `Head_Attack` 里那条发射方法轨指到**僵尸自己的**攻击组件
##
## 为什么必须重定向：方法轨原本写的是 `NodePath("AttackComponent")`（植物场景里攻击组件就在根下），
## 头现在挂在 `Body/BodyCorrect/Anim_head/Anim_head1/PlantHead` 下面，路径对不上；
## 而 `Head_Attack` 是**共享资源**，不能就地改（所有僵尸会互相覆盖、还可能写回磁盘），
## 所以先复制一份动画，再整库替换成本实例专用的。
func _bind_head_attack_shoot_track() -> void:
	var anim_player := plant_head.get_node_or_null(C_HEAD_ANIM_PLAYER_NAME) as AnimationPlayer
	if not is_instance_valid(anim_player):
		return
	var source_library := anim_player.get_animation_library(&"")
	if source_library == null:
		return
	## 库里一条方法轨都没有（原版 6 只里只有豌豆有 `Head_Attack`）→ 没什么可重定向的，
	## 保持共享的动画资源不动：复制整个库只是白白给每只僵尸多占几十 KB（机枪的 idle 就有 57 KB）
	if not _library_has_method_track(source_library):
		return
	var attack_component := owner.get_node_or_null(C_ATTACK_COMPONENT_PATH)
	_head_shoot_bound = false
	var library := AnimationLibrary.new()
	for anim_name: StringName in source_library.get_animation_list():
		var anim := source_library.get_animation(anim_name)
		if anim_name == C_HEAD_ATTACK_ANIM:
			anim = _build_head_attack_anim(anim, attack_component)
		library.add_animation(anim_name, anim)
	anim_player.remove_animation_library(&"")
	anim_player.add_animation_library(&"", library)


## 库里的动画是否存在方法轨（有才需要复制 + 重定向，见 `_bind_head_attack_shoot_track`）
func _library_has_method_track(library: AnimationLibrary) -> bool:
	for anim_name: StringName in library.get_animation_list():
		var anim := library.get_animation(anim_name)
		if anim == null:
			continue
		for i in anim.get_track_count():
			if anim.track_get_type(i) == Animation.TYPE_METHOD:
				return true
	return false


## 复制一份 `Head_Attack`，把里面的发射方法轨指到 [param attack_component]
## （没有攻击组件 / 组件没有这个方法时删掉那条轨，免得播放时刷 Node not found）
func _build_head_attack_anim(source: Animation, attack_component: Node) -> Animation:
	var anim := source.duplicate() as Animation
	## 从后往前删：`remove_track()` 会让后面的下标前移
	for i in range(anim.get_track_count() - 1, -1, -1):
		if anim.track_get_type(i) != Animation.TYPE_METHOD:
			continue
		## `method_track_get_name()` 要 (轨道, 关键帧) 两个下标；方法轨通常只有一帧
		var method_name := anim.method_track_get_name(i, 0) if anim.track_get_key_count(i) > 0 else &""
		if not is_instance_valid(attack_component) or not attack_component.has_method(method_name):
			anim.remove_track(i)
			continue
		anim.track_set_path(i, plant_head.get_path_to(attack_component))
		if method_name == C_HEAD_SHOOT_METHOD:
			_head_shoot_bound = true
	return anim


## 原版口径的「头顶植物吐子弹」世界坐标 —— 各攻击组件用它当发射点
##
## 原版僵尸的豌豆 / 机枪子弹都从 `anim_head1` 轨道的**当前帧**位置加偏移算出来
##（`Zombie.cpp` `UpdateZombiePeaHead()` / `UpdateZombieGatlingHead()`，推导见 `C_SHOOT_OFFSET`），
## 所以发射点跟着走路摇头 / 啃咬点头一起动，永远贴着那颗植物头。
##
## 放在本组件而不是各攻击组件里：这些僵尸的「嘴」本来就是**这颗植物头的属性**，
## 只在这里算一份，改常量时不会漏改另一处。取不到头轨道（场景结构被改坏）时返回 [param fallback]。
##
## 魅惑态单独一档（见 `C_SHOOT_OFFSET_HYPNO`）：原版对被魅惑的吐豆僵尸改发植物方豌豆、
## 发射点再前移 90，与普通态不是同一个偏移。
func get_head_shoot_global_position(fallback: Vector2) -> Vector2:
	var head := owner.get_node_or_null(C_HEAD_TRACK_PATH) as Node2D
	if not is_instance_valid(head):
		return fallback
	## 魅惑（`is_hypno`）：直接用原版「+90 前移 + 植物方豌豆」口径，
	## 不走下面的镜像取反 —— 魅惑在仓库里同样靠 body 水平镜像实现，两条路只能选一条，
	## 选与原版数值一致的那条（常量出处见 C_SHOOT_OFFSET_HYPNO）。
	var zombie := owner as Zombie000Base
	if is_instance_valid(zombie) and zombie.is_hypno:
		return head.global_position + C_SHOOT_OFFSET_HYPNO
	## 头被水平镜像时（非魅惑原因，如模组自定义朝向）偏移也要翻到另一侧，否则子弹会从脑后飞。
	## ⚠️ 判据用 `global_transform` 的第一列，**不能**用 `global_scale.x`：
	## 设 `scale.x = -1` 之后 Godot 的分解结果可能是 `(1, -1)`（等价矩阵，符号被挪到 y 上）
	var offset_x := C_SHOOT_OFFSET.x
	var body := owner.get_node_or_null(^"Body") as Node2D
	if is_instance_valid(body) and body.global_transform.x.x < 0.0:
		offset_x = -offset_x
	return head.global_position + Vector2(offset_x, C_SHOOT_OFFSET.y)
