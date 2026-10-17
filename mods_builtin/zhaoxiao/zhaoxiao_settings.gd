extends RefCounted
## 模组「招笑版」的文案与数值：**单独一份**，因为入口脚本 `zhaoxiao_mod.gd` 与
## 两个观察者（`zhaoxiao_sunflower.gd` / `zhaoxiao_peashooter.gd`，后者又带一颗
## `zhaoxiao_shadou.gd`）都要读它 —— 几个文件互相 preload 会成环
## （同样的理由见 `glove_settings.gd` / `hammer_settings.gd`）。
##
## ⚠️ `user://` 下的脚本拿不到静态类型推断（`var x := 无类型的返回值` 会被判编译错误），
##    从数组 / `get_node_or_null()` 里取出来的东西一律**显式写类型**（见 `mods_builtin/README.md`）。

#region 改名：向日葵 → 朝阳葵
## 图鉴 `Plant` 段里向日葵那一条的键 —— 它等于注册表里的 `PlantName`：
## 只改那一行里的「名字」字段，**不动这个键**（键一改，图鉴页就按新键去查，直接查不到）
const ALMANAC_KEY := "SunFlower"
## 改名前（关掉模组还原用 / 万一没记下原名时的兜底）
const PLANT_NAME_OLD := "向日葵"
## 改名后
const PLANT_NAME_NEW := "朝阳葵"
#endregion


#region 改名：豌豆射手 → 傻豆射手
## 同向日葵：只改图鉴那一行里的「名字」字段
const PEASHOOTER_ALMANAC_KEY := "PeaShooterSingle"
## 改名前 / 改名后
const PEASHOOTER_NAME_OLD := "豌豆射手"
const PEASHOOTER_NAME_NEW := "傻豆射手"
#endregion


#region 改名：樱桃炸弹 → 烟熏樱桃
## 同向日葵：只改图鉴那一行里的「名字」字段
const CHERRY_ALMANAC_KEY := "CherryBomb"
## 改名前 / 改名后
const CHERRY_NAME_OLD := "樱桃炸弹"
const CHERRY_NAME_NEW := "烟熏樱桃"
#endregion


#region 烟熏
## 烟熏一次持续多少秒
const SMOKE_TIME := 30.0
#endregion


#region 摔倒（僵尸像被绊倒一样趴在地上，一会儿又站起来）
## 摔倒后趴在地上多久（秒）—— 到点自己站起来继续走
const FALL_TIME := 3.0
## 倒下去 / 站起来那一下把身体转 90° 用的时长（秒）
const FALL_TIPPING_TIME := 0.3
## 倒下去之后身体往上抬多少（像素）：Body 是绕脚根转的，转平之后身体中线压到
## 地面以下，抬这一下看着才是「趴在地上」而不是「一半埋进土里」
## （目眯值：想趴得再平 / 再沉就改它；小僵尸按体型缩）
const FALL_SINK_Y := 30.0
## 趴姿的旋转角（弧度）：90° = 身体放平，头朝摔倒时的走路方向
const FALL_LIE_ANGLE := PI / 2
#endregion


#region 路障僵尸变种（10 倍速、无视植物、走到第 4 列摔倒掉路障）
## 速度倍数（相对普通僵尸的动画倍速）—— 与「闪电掉头僵尸」同一招
const CONE_ZOMBIE_SPEED := 10.0
## 从僵尸入场一侧（右侧）数第几列摔倒（口径同闪电掉头僵尸的掉头列；
## 想改成「从房子一侧（左侧）数第 N 列」，把 `zhaoxiao_cone_zombie.gd` 里
## `_compute_fall_x()` 的 `col_num - CONE_ZOMBIE_FALL_COLUMN_FROM_RIGHT`
## 改成 `CONE_ZOMBIE_FALL_COLUMN_FROM_RIGHT - 1` 即可）
const CONE_ZOMBIE_FALL_COLUMN_FROM_RIGHT := 4
#endregion


#region 掉在草坪上的路障（永久存在，绊倒后来的僵尸）
## 后来走到路障上（与路障的 |x 差| ≤ 这个值）的僵尸会被绊倒
const CONE_TRIP_RANGE := 26.0
## 路障贴图相对地面的下沉（像素，负 = 往上抬）：让它看着是「掉在地上」而不是浮空
const CONE_GROUND_OFFSET_Y := -10.0
#endregion


#region 转头（朝阳葵）
## 转一次头**花的时间**（秒）：按「从当前姿态到位」的固定时长插值，**所有朝阳葵都一样**。
## 不用角速度：角速度下要转的角度大的（离得远的）那株会转得更久，同一批花就不是一起转完的
const TURN_TIME := 0.3
#endregion


#region 汗滴（朝阳葵）
## 汗滴相对**花心**（花瓣围出来的那个圆心）的落点：往右上一点，看着像挂在脸上
const SWEAT_OFFSET := Vector2(14.0, -16.0)
## 汗滴大小 —— 贴图本身只有 17 × 25 像素，1 倍就够
const SWEAT_SCALE := 1.0
#endregion


#region 怒气（傻豆射手）
## 怒气上限（1.0 = 满，满了就放大招）
const ANGER_MAX := 1.0
## 每打出一颗傻豆攒多少怒气 —— 0.2 × 5 发正好攒满（1.5 秒一发，约 7.5 秒一次大招）
const ANGER_PER_SHOT := 0.2
## 满怒时贴图染成什么颜色：按怒气比例从**纯白**渐变到它（`BodyCharacter.base_color` 是乘法合成）
const ANGER_TINT := Color(1.0, 0.16, 0.16)
#endregion


#region 大招（傻豆射手）
## 大招持续多少秒 —— 这段时间里怒气**匀速**从满降到 0
const ULTIMATE_TIME := 2.0
## 大招期间每隔多久散射一颗**普通豌豆**
const ULTIMATE_SHOT_INTERVAL := 0.1
## 散射的角度范围（度）：以正前方（射线方向）为 0，在 ±它之内随机
const ULTIMATE_ANGLE_DEG := 25.0
## 散射的**速度区间**（像素 / 秒）：每个豌豆在这个区间里随机取一个速度
const ULTIMATE_SPEED_RANGE := Vector2(220.0, 420.0)
#endregion


#region 傻豆（那两种「豌豆」）
## 傻豆飞得多快 —— 与本体豌豆一致（300），这样「看起来像正常豌豆」
const SHADOU_SPEED := 300.0
## 两种傻豆各占的权重：**掉地上** / **射偏**
const SHADOU_DROP_WEIGHT := 1.0
const SHADOU_OFF_WEIGHT := 1.0

## 傻豆「掉地上」那种：离僵尸**受击框前缘**还有这么远（像素）就开始往下掉 ——
## 掉落点因此落在僵尸前面一个明显的位置，而不是贴着它脚下
const SHADOU_FALL_GAP := 60.0
## 已经飞到僵尸身后这么多像素之后就**不算**「在前面」了（避免挑到已经越过的僵尸）
const SHADOU_FALL_OVERSHOOT := 12.0
## 本行前面一只僵尸都没有时：飞这么远（像素）就自己掉下来
const SHADOU_FALL_DISTANCE := 220.0
## 往下掉的重力（像素 / 秒²）与掉落时的水平速度比例
const SHADOU_GRAVITY := 1400.0
const SHADOU_FALL_H_RATIO := 0.35
## 落地那一下播的「豌豆命中」特效：用它自带的 4 帧溅射贴图走一遍的时长（秒）
## （本体那套特效只显示第一帧；这里顺手让这 4 帧动起来，「命中动画」才真的在动）
const SHADOU_SPLAT_ANIM_TIME := 0.2

## 傻豆「射偏」那种：让轨迹**恰好**从僵尸受击框边上擦过去 —— 在框外再留这么多像素
## （这一份是给豌豆自己的半径 + 「僵尸还在往前走」那点估算误差一起留的余量）
const SHADOU_OFF_CLEARANCE := 16.0
## 傻豆「射偏」那种：前面**一只僵尸都没有**时的兜底偏角区间（度，正负随机）
const SHADOU_OFF_ANGLE_DEG := Vector2(14.0, 38.0)
## 傻豆「射偏」那种：飞这么远（像素）就消失
const SHADOU_MAX_DISTANCE := 1400.0
#endregion
