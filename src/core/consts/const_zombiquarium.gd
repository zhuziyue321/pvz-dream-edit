extends RefCounted
class_name ConstZombiquarium
## 僵尸水族馆（Zombiquarium，迷你游戏第 8 关）的玩法常量
##
## 本关是《怪怪水族箱》那套「养僵尸」玩法，与草坪防守完全不同：
## 点鱼缸造脑子喂潜水僵尸，僵尸定时产阳光，攒够阳光买奖杯通关；僵尸饿了不喂会死，全死光就输。
##
## 数据来源:
##   原版游戏文本（A 级）: data/strings/lawn_strings.txt 的
##     [ZOMBIQUARIUM_SNORKEL_TOOLTIP]「购买潜水僵尸」
##     [ZOMBIQUARIUM_TROPHY_TOOLTIP]「购买奖杯」
##     [ADVICE_ZOMBIQUARIUM_CLICK_TO_FEED]「点击鱼缸给僵尸喂食」
##     [ADVICE_ZOMBIQUARIUM_COLLECT_SUN]「需要得到{SCORE}点阳光才能通过这关」
##     [ADVICE_ZOMBIQUARIUM_CLICK_TROPHY]「点击奖杯来完成关卡！」
##     [ADVICE_ZOMBIQUARIUM_BUY_SNORKEL]「点击购买更多的潜水僵尸！」
##     [ZOMBIQUARIUM_DEATH_MESSAGE]「你的宠物僵尸已经全部死亡了！」
##   PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Zombiquarium)
##   灰机wiki(https://pvz.huijiwiki.com/index.php?curid=185)
## 口径: 原版一代 PC

## 开局阳光
const SUN_START := 50
## 开局送的潜水僵尸数量
const PET_NUM_START := 2
## 造一个脑子花多少阳光（脑子沉到缸底还没被吃就白花了）
const BRAIN_SUN_COST := 5
## 水缸里同时能存在的脑子个数
const BRAIN_MAX_NUM := 3
## 买一只潜水僵尸花多少阳光
const PET_SUN_COST := 100
## 奖杯价格：攒够这么多阳光才能买奖杯通关
const TROPHY_SUN_COST := 1000

## 僵尸多久不吃就饿死（秒）
## wiki 原文: The player has 20 seconds to feed a Snorkel Zombie before it perishes
const PET_HUNGRY_TIME := 20.0
## 饿死前多少秒开始「身体发绿黄」报警（秒）
## 待核实: wiki 只写「饿了会变绿」，没给秒数；取饿死时限的 30%，玩家有反应时间又不会一直绿着
const PET_HUNGRY_WARN_TIME := 6.0

## 僵尸一次产多少阳光
## 数据来源: 灰机wiki「僵尸会定时生产阳光……(僵尸也会产阳光(25阳光))」
const PET_SUN_VALUE := 25
## 僵尸产阳光的间隔范围（秒），取区间内随机
## 待核实: wiki 与中文百科都只写「定时生产」，没有给秒数；
##   这里取「2 只僵尸也能在几分钟内攒到 1000」的区间（2 只 ≈ 5 阳光/秒，扣掉喂食成本约 4 阳光/秒）
const PET_SUN_INTERVAL_RANGE := Vector2(8.0, 12.0)
## 新生僵尸的第一个产阳光间隔倍率（刚买下来的僵尸不该立刻吐阳光）
const PET_SUN_FIRST_SCALE := 0.6


## 水族馆里的僵尸类型（原版只有潜水僵尸）
static func get_pet_zombie_type() -> CharacterRegistry.ZombieType:
	return CharacterRegistry.ZombieType.Z012Snorkle
