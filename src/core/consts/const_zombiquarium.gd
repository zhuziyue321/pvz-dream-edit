extends RefCounted
class_name ConstZombiquarium
## 僵尸水族馆（Zombiquarium，原版迷你游戏第 8 关）的玩法常量
##
## 本关不是草坪防守，而是原版那套「养僵尸」玩法：
## 点鱼缸花 5 阳光造一个脑子喂潜水僵尸 → 僵尸定时吐阳光 → 攒够 1000 阳光买奖杯通关；
## 僵尸不喂会掉血，掉到 0 就死，全死光判负。
##
## **数值口径（2026-10-24 起）**：本文件所有数值都来自**原版源码**
## （A 级参照工程 `../PvZ-Portable-main`，文件名 + 行号标在每条后面），
## 没有原版出处的才写「待核实」——**不要再拿 wiki 的近似值回填**。
## 改动前先看 [docs/工作记录/2026-10-24_僵尸水族馆改从原版移植.md]。
##
## 原版文本（data/strings/lawn_strings.txt）：
##   [ZOMBIQUARIUM_SNORKEL_TOOLTIP]「购买潜水僵尸」
##   [ZOMBIQUARIUM_TROPHY_TOOLTIP]「购买奖杯」
##   [ADVICE_ZOMBIQUARIUM_CLICK_TO_FEED]「点击鱼缸给僵尸喂食」
##   [ADVICE_ZOMBIQUARIUM_COLLECT_SUN]「需要得到{SCORE}点阳光才能通过这关」
##   [ADVICE_ZOMBIQUARIUM_BUY_SNORKEL]「点击购买更多的潜水僵尸！」
##   [ADVICE_ZOMBIQUARIUM_CLICK_TROPHY]「点击奖杯来完成关卡！」
##   [ADVICE_ALMOST_THERE]「就要成功了！」
##   [ZOMBIQUARIUM_DEATH_MESSAGE]「你的宠物僵尸已经全部死亡了！」


#region 阳光与购买
## 开局阳光：原版 Board.cpp:1358 `mSunMoney = 50`（水族馆没进任何特例分支，走默认值）
const SUN_START := 50
## 买一只潜水僵尸 100 阳光：原版 Plant.cpp:5004 `SEED_ZOMBIQUARIUM_SNORKEL → 100`
const PET_SUN_COST := 100
## 买奖杯 1000 阳光：原版 Plant.cpp:5005 `SEED_ZOMBIQUARIUM_TROPHY → 1000`
const TROPHY_SUN_COST := 1000
## 通关分数：原版 Challenge.cpp:61 `ZOMBIQUARIUM_WINNING_SCORE = 1000`
const WINNING_SCORE := 1000
## 造一个脑子 5 阳光：原版 Challenge.cpp:3375 `TakeSunMoney(5)`
const BRAIN_SUN_COST := 5
## 缸里同时最多 3 个脑子：原版 Challenge.cpp:3375 `aBrainsCount < 3`
const BRAIN_MAX_NUM := 3
## 场上最多 100 只宠物：原版 Challenge.cpp:3322 `CountZombiesOnScreen() > 100` 就不给买
const PET_MAX_NUM := 100
## 一颗阳光的面值：原版用 COIN_SUN（与向日葵产出的阳光同面值 25）
const PET_SUN_VALUE := 25
#endregion


#region 宠物（潜水僵尸）
## 开局 2 只：原版 Challenge.cpp:311-312 连着调了两次 `ZombiquariumSpawnSnorkle()`
const PET_NUM_START := 2
## 初始血量：原版 Zombie.cpp:867 `mBodyHealth = 200`
const PET_HEALTH_INIT := 200
## 血量上限：原版 Zombie.cpp:896 `mBodyMaxHealth = 300`（水族馆专用）
const PET_HEALTH_MAX := 300
## 血量高于 150 就不找脑子：原版 Zombie.cpp:3081 `mBodyHealth > 150 → return false`
const PET_SEEK_HEALTH := 150
## 吃到一个脑子回 200 血（封顶 300）：原版 Zombie.cpp:3108-3109
const PET_EAT_HEAL := 200
## 每 100 tick 掉 10 血：原版 Zombie.cpp:3251-3253 `mZombieAge % 100 == 0 → TakeDamage(10)`
const PET_DAMAGE_INTERVAL_TICK := 100
const PET_DAMAGE_VALUE := 10
## 血量低于 100 身上发绿：原版 Zombie.cpp:5712-5714 `mBodyHealth < 100 → Color(100,150,25)`
const PET_GREEN_HEALTH := 100
const PET_GREEN_COLOR := Color(100.0 / 255.0, 150.0 / 255.0, 25.0 / 255.0)
## 第一次吐阳光的间隔（tick）：原版 Zombie.cpp:868 `mSummonCounter = RandRangeInt(200, 400)`
const PET_SUMMON_INIT_RANGE := Vector2i(200, 400)
## 之后每次吐阳光的间隔（tick）：原版 Zombie.cpp:3247 `mSummonCounter = RandRangeInt(1000, 1500)`
const PET_SUMMON_RANGE := Vector2i(1000, 1500)
## 嘴部锚点（相对 mPos）：原版 Zombie.cpp:3092 判吃脑子用 (mPosX+50, mPosY+40)，
## 原版 Zombie.cpp:3246 吐阳光也在 (mX+50, mY+40) —— 同一个点
const PET_MOUTH_OFFSET := Vector2(50.0, 40.0)
## 游动范围：原版 Zombie.cpp:3186-3201（x 0~680、y 100~400）
const PET_AREA_X := Vector2(0.0, 680.0)
const PET_AREA_Y := Vector2(100.0, 400.0)
## 来回游的折返点：原版 Zombie.cpp:3215-3223（x < 200 折向右、x > 550 折向左）
const PET_TURN_X := Vector2(200.0, 550.0)
## 生成位置：原版 Challenge.cpp:3310-3311 `RandRangeFloat(50,650)` / `RandRangeFloat(100,400)`
const PET_SPAWN_X := Vector2(50.0, 650.0)
const PET_SPAWN_Y := Vector2(100.0, 400.0)
#endregion


#region 游动状态机（原版 Zombie::UpdateZombiquarium / ZombiquariumFindClosestBrain）
## 一 tick = 1/60 秒（原版 SECONDS_PER_UPDATE = 1/60）
const TICK_SECONDS := 1.0 / 60.0
## 每 tick 的加速度：原版 Zombie.cpp:3232 `mVelX = min(aMaxSpeed, mVelX + 0.01)`
const SPEED_STEP := 0.01
## 加速游的速度上限：原版 Zombie.cpp:3211 `aMaxSpeed = 0.5`
const SPEED_ACCEL := 0.5
## 来回游的速度上限：原版 Zombie.cpp:3225 `aMaxSpeed = 0.3`
const SPEED_BACK_AND_FORTH := 0.3
## 慢慢飘的速度上限：原版 Zombie.cpp:3229 `aMaxSpeed = 0.05`
const SPEED_DRIFT := 0.05
## 出界减速：原版 Zombie.cpp:3206 `aMaxSpeed = mVelX * 0.3f`
const SPEED_OUT_OF_BOUNDS_SCALE := 0.3
## 阶段计时（tick，原版 mPhaseCounter）
const PHASE_TICKS_DRIFT_INIT := 200		## 原版 Zombie.cpp:866
const PHASE_TICKS_BITE := 200			## 原版 Zombie.cpp:3113
const PHASE_TICKS_DRIFT_AFTER_BITE := 100	## 原版 Zombie.cpp:3147
const PHASE_TICKS_RANDOM := Vector2i(300, 1000)	## 原版 Zombie.cpp:3157 / 3171 / 3178
#endregion


#region 脑子
## 脑子投放位置 = 点击点 - (15,15)：原版 Challenge.cpp:3355-3356
const BRAIN_OFFSET := Vector2(15.0, 15.0)
## 吃到脑子的判定距离：原版 Zombie.cpp:3103 `aDistanceClosest < 50`
const BRAIN_EAT_DISTANCE := 50.0
## 下沉速度（每 tick）：原版 Challenge.cpp:3436 `mPosY += 0.15f`
const BRAIN_SINK_PER_TICK := 0.15
## 沉到缸底就死：原版 Challenge.cpp:3437 `mPosY >= 500`
const BRAIN_DEATH_Y := 500.0
## 落地 15 tick 之后才能被吃：原版 Zombie.cpp:3090 `mGridItemCounter >= 15`
const BRAIN_EAT_DELAY_TICK := 15
#endregion


#region 点击与提示
## 点鱼缸造脑子的范围：原版 Challenge.cpp:3362 `x < 80 || x > 720 || y < 90 || y > 430`
const CLICK_AREA := Rect2(80.0, 90.0, 640.0, 340.0)
## 原版提示文案（data/strings/lawn_strings.txt）
const ADVICE_CLICK_TO_FEED := "点击鱼缸给僵尸喂食"
## {SCORE} 会被替换成通关分数 1000（原版 Challenge.cpp:3390 `PvzpReplaceNumberString`）
const ADVICE_COLLECT_SUN := "需要得到%d点阳光才能通过这关"
## 阳光到这个数就教玩家买潜水僵尸：原版 Challenge.cpp:3400 `aScore >= 110`
const ADVICE_BUY_SNORKEL_SCORE := 110
const ADVICE_BUY_SNORKEL := "点击购买更多的潜水僵尸！"
const ADVICE_CLICK_TROPHY := "点击奖杯来完成关卡！"
const ADVICE_ALMOST_THERE := "就要成功了！"
const ADVICE_DEATH := "你的宠物僵尸已经全部死亡了！"
#endregion


#region 动画
## 原版 reanim 的基准帧率是 12 fps（见 tools/unwrap_reanim_compiled.py 的说明），
## 仓库导出的 .tres 就是这个帧率（step = 1/12 秒），
## 于是「原版播放速率 R」换算成仓库的 speed_scale = R / 12。
const REANIM_BASE_FPS := 12.0
## 游泳动画的播放速率：原版 Zombie.cpp:861 / 3143 `RandRangeFloat(8.0, 10.0)`
const ANIM_RATE_SWIM := Vector2(8.0, 10.0)
## 乱窜时的播放速率：原版 Zombie.cpp:3158 / 3172 / 3179 `RandRangeFloat(15.0, 20.0)`
const ANIM_RATE_FAST := Vector2(15.0, 20.0)
## 咬脑子的播放速率：原版 Zombie.cpp:3111 `PlayZombieReanim("anim_aquarium_bite", ..., 24.0f)`
const ANIM_RATE_BITE := 24.0
## 死亡动画的播放速率：原版 Zombie.cpp:8966 `PlayZombieReanim("anim_aquarium_death", ..., 14.0f)`
const ANIM_RATE_DEATH := 14.0
#endregion


## 水族馆里的僵尸类型（原版只有潜水僵尸）
static func get_pet_zombie_type() -> StringName:
	return ZombieIds.SNORKLE
