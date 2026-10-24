extends RefCounted
class_name ConstTreeOfWisdom
## 智慧树(Tree of Wisdom)与树肥料(Tree Food)的数据表
##
## 原版口径: 一代 PC, 逐项对照 C++ 参照 `../PvZ-Portable-main/src/Lawn/Challenge.cpp`
## 的 `TreeOfWisdomInit / Grow / Fertilize / Babble / GiveWisdom / SayRepeat / HitTest / Draw`。
##   · 在戴夫商店花 $10000 买下智慧树后, 花园里多出一页「智慧树」
##     (原版是禅境花园往后翻一页 —— "going past the Aquarium Garden", 见
##      GardenManager.E_GardenBgType.TreeBg)
##   · 买下时戴夫白送几袋树肥料; 之后在商店 $2500 一袋, 一次最多囤 10 袋
##   · 喂一袋长高一英尺; 讲哪句台词由**台词编号**决定(见下),
##     100 / 500 / 1000 英尺时改讲里程碑那句(原版这三个高度会解锁
##     daisies / dance / pinata 三个输入码; 本仓库没有输入码系统, 只把台词放出来)
##
## 数据来源:
##   PVZ Wiki —— https://plantsvszombies.wiki.gg/wiki/Tree_of_Wisdom
##              https://plantsvszombies.wiki.gg/wiki/Tree_Food
##   data/strings/lawn_strings.txt 的 [TREE_OF_WISDOM_<编号>] 条目(台词原文)
##
## ★ 台词编号 = 原版 `[TREE_OF_WISDOM_<编号>]` 的编号, 逻辑按编号走, 不再按高度硬凑:
##     1..49   每次施肥后讲一句(编号 = clamp(高度-1, 1, 49), 见 Challenge::TreeOfWisdomGiveWisdom)
##     101..110 / 201..205 / 301..305 / 401..405  没长高时的闲聊(见 TreeOfWisdomBabble)
##     500     重复旧台词前的开场白(讲完 4 秒后才跳到 TreeOfWisdomSayRepeat 选的那句)
##     600     一次都没喂过时的讨食
##     800 / 900 / 1000  100 / 500 / 1000 英尺的里程碑
##     1100    超过 1000 英尺之后

#region 树肥料(商店第四页第二行第一格)
## 树肥料售价(原版 $2500 一袋)
const TREE_FOOD_PRICE := 2500
## 买一次给几袋(原版一次一袋, 与商店里其他消耗型工具的「一份 5 个」不同)
const TREE_FOOD_NUM_PER_BUY := 1
## 树肥料持有上限(原版: "The player can only acquire 10 bags at a time")
const TREE_FOOD_MAX_OWN_NUM := 10
## 买下智慧树时戴夫白送的树肥料袋数
## (原版 [CRAZY_DAVE_3200]: "这是你的智慧树！我会给你一些肥料让你开始的" —— 五袋)
const TREE_FOOD_START_NUM := 5
## 一袋树肥料让智慧树长几英尺(原版: one bag at a time, making it one foot taller)
const TREE_FOOD_GROW_FEET := 1
## 智慧树高度上限(原版是 int32 上限, 再喂就整数溢出缩回幼苗; 这里只做上限保护)
const TREE_MAX_HEIGHT := 2147483647
## 高度显示格式(原版 [TREE_OF_WISDOM_HIEGHT], 原版键名就是这个拼写)
const HEIGHT_TEXT := "%d英尺高"
## 从多少英尺开始显示高度文字(原版 Challenge::TreeOfWisdomDraw 的 aCurSize >= 50)
const HEIGHT_TEXT_MIN_HEIGHT := 50
#endregion


#region 台词表
## 全部台词, key = 原版 `[TREE_OF_WISDOM_<编号>]` 的编号
## (原文与 data/strings/lawn_strings.txt 逐字一致; 表外编号取到空串)
const TALK_LINES: Dictionary = {
	## ---- 每次施肥后的「智慧」1..49 ----
	1: "感谢你培育我！只要不断给我肥料，我就会给你有价值的信息！",
	2: "大嘴花和坚果并肩作战能够发挥最大的效用—这并不奇怪，因为他们上大学时是舍友。",
	3: "如果你真的在听我说话，那就竖起耳朵听：种两排向日葵吧—我可是非常，非常认真的！",
	4: "潜水僵尸？真是讨厌！怎么处置他们？我的建议是：在莲叶上种植坚果，就是这样。",
	5: "嗯，试试在游戏时输入“future”，也许你能遇到来自……“未来”的僵尸！",
	6: "究竟需要多少樱桃炸弹才能解决掉巨人僵尸？提示：多于一个，少于三个。进一步提示：两个。",
	7: "如果你想为自己的花园添加一些蘑菇，那么最好尝试一些晚上的关卡。",
	8: "我可不担心末日菇，它不会对草地造成永久破坏——大地会通过时间来治愈自己。",
	9: "有没有尝试过点击主菜单上的花朵呢？试试看！我在这儿等着。",
	10: "传说被冰冻了的僵尸吃得比较慢，我认为传说是有它的道理的。",
	11: "你听说过罕见的雪人僵尸吗？有人说他喜欢躲在暗处。",
	12: "有什么比免费还要便宜的？没有！所以小喷菇在所有夜晚关卡都必不可少！",
	13: "你想不想给你的花园找一些水生植物？我用我的肚皮打赌，你会在池塘关卡里碰到好运。",
	14: "你注意到过吗？巨人僵尸有时候会用其他的僵尸来砸你的植物？我也不明白是怎么回事。",
	15: "懒蜗牛显然很喜欢巧克力。或许有点太喜欢了，你知道吗？吃过一些巧克力后，他一刻也不愿静下来。",
	16: "如果你玩无限生存模式只是为了得到水生植物的话，再好好想想吧！这里可是什么植物都会有的。",
	17: "人们总会这样问：你在哪里能找到巧克力呢？也许这样问更恰当：你在哪里会找不到巧克力？在每一种模式中都会掉落巧克力！",
	18: "咬咬碑是吧？你最好在右侧那边有墓碑时，才选择他们。换了我就会这么做。",
	19: "我听说，铁桶僵尸拥有一般僵尸五倍的防御力。",
	20: "我听说输入“mustache”，会给僵尸们带来惊人的改变！",
	21: "多个寒冰射手，能让僵尸们变得更慢吗？真相是残酷的：不会。",
	22: "我想你应该知道僵尸会从墓碑出现，对吧？用咬咬碑来摆脱他们，这难道不是令人自豪的事情吗？",
	23: "如果你想知道某一关的剩余时间，数数关卡进程表上的旗帜吧。它们会很好地告诉你。",
	24: "屋顶清理车，经典道具，强烈推荐。最大的优点？它们会在跳跳舞会中多给你一次机会。",
	25: "给舞者僵尸吃迷糊菇，他会为你召唤伴舞僵尸吗？答案是肯定的！",
	26: "想快速致富吗？那就玩无限生存模式吧！然后记得把你的银行账号发送给我！",
	27: "你可能想过火炬树桩会弄灭冰豆。那么你是对的，因为你，我的朋友，是个聪明的家伙。",
	28: "这些可恨的植物僵尸！他们以为自己是谁，竟然敢向你的植物开火？坚果会让他们好好冷静一下．",
	29: "跳跳舞会和雪橇当道，这两个迷你游戏非常非常非常地难。想去掉上一句话中的一个“非常”吗？快使用窝瓜吧。",
	30: "当你认为火爆辣椒一无是处的时候，让智慧树来告诉你，他们也能摧毁僵尸们的冰道！嘭！",
	31: "当你买了变身茄子后，可以点击郊区图鉴里左上角的小素描图，就能看到对它的介绍了。",
	32: "在坚果保龄球游戏里，打倒越多的僵尸，你能得到的硬币也就越多。",
	33: "请不要拍玻璃！ 或实际上，请便；右击水族馆花园或僵尸水族馆，来震那些水下生物。",
	34: "当我还是一颗橡树种子时，我的爷爷告诉我：“孩子，如果你从右边开始动手，砸花瓶游戏会变得简单得多。”",
	35: "“僵尸公敌”模式中，舞者僵尸看起来有点贵，但是在需要的时候，它绝对对得起你花的每一分钱。",
	36: "我做过一个梦，在梦里，猫尾草的刺扎破了气球，然后僵尸就摔在了地上。我不知道这个梦有什么含义。",
	37: "如果没有水族馆，你想在花园里种水生植物，恐怕不太可能呢。呃……我只是随便说说。",
	38: "矿工僵尸的这种钻地行为，简直就是违反自然法则的犯规，用磁力菇吸走他们的采矿锄！这才算公平。",
	39: "每一天都有新的挑战，都有新的机遇，哦，还有疯狂戴夫商店里新的金盏花。",
	40: "蘑菇园！嗯！它有什么作用？很明显，它只能够用来种蘑菇，就是这样！",
	41: "累了？郁闷了？架在高坚果上的梯子让你不爽了？ 一个磁力菇能快速的让这些消失！",
	42: "高坚果的高度赢得了大家的称赞，因为他们对付海豚僵尸骑士、蹦蹦僵尸很有一套。",
	43: "樱桃炸弹、火爆辣椒爆发出的力量，和把梯子从坚果上推倒的力量，前者要大得多。",
	44: "把全部的巧克力喂给懒蜗牛？确实很诱惑。他真的是非常喜欢巧克力。但是别忘了：花园里的植物也喜欢巧克力！",
	45: "火炬树桩之火异常之猛烈，但是雪橇车僵尸，铁栅栏，扶梯和投掷车都可以承受热量。",
	46: "若你在无限生存模式里依赖于进阶植物，要注意你在草地上有越多这种进阶植物，这种植物就会变得越贵。",
	47: "小鬼在“僵尸公敌”中看起来很弱。但当你清除了其他敌人的时候，他们会为那诱人的脑子变得极快。",
	48: "如果你输入“trickedout”看到割草机上发生了怪事，不必惊讶。",
	49: "谢谢你给我施肥！我现在有点缺乏新的智慧了。但是如果你把我种的更高，我会拥有更多智慧的！",

	## ---- 没长高时的闲聊:101..110(任意高度) ----
	101: "嗯，我确信我享用了些美味的肥料！",
	102: "我觉得我以前看到过云。",
	103: "别理我。我会在这慢慢长高。",
	104: "我正疯狂代谢中！",
	105: "我老是不明白，你们这些动物怎么整天都在到处走来走去。",
	106: "时间对我来说是非常缓慢的！",
	107: "我想我是多年生的！",
	108: "我的木质部发麻了！",
	109: "你只要站在我身边，就能得到很多很多的智慧。",
	110: "我听说过“冬天”。但我可不会期待那种日子。",

	## ---- 没长高时的闲聊:201..205(还不到 12 英尺) ----
	201: "嗯嗯…… 阳光真是 美味啊！",
	202: "哦，不好意思……我刚释放了点氧气。",
	203: "天啊，我长叶子了！",
	204: "我感觉我要爆发了！",
	205: "眼下我缺少一些关于世界观的知识！",

	## ---- 没长高时的闲聊:301..305(12 ~ 49 英尺) ----
	301: "对于你为我在肥料上花销，我真的真的很感激！",
	302: "那朵云看起来好像一个大水滴哦！",
	303: "你见过我的堂兄宇宙树了吗？很大！住在瑞典，有好多粉丝呢。",
	304: "我正在一所网上大学学习社会学，我真的学到了很多。",
	305: "经过我仔细的观察后，我推断出是地球围着太阳转，不是我们看到的那种样子——太阳绕着地球转。",

	## ---- 没长高时的闲聊:401..405(50 英尺起) ----
	401: "当你活得和我一样长时，你会睡得更少而更易产生幻觉。",
	402: "如果你弄不明白，什么是森林什么是树，只要记住。森林是树木个体的集合，反过来则不是。",
	403: "历史不停重复着自己，但是某些细节总有所不同。",
	404: "如果说过去，现在和将来同时存在。它们三位一体，成为一个“轮回”，那么经验上的“现在”，也许不过是一个精致的幻觉？",
	405: "勇气易得，奉献难求。",

	## ---- 特殊台词 ----
	500: "我有一些久经考验的智慧……",
	600: "请给我点肥料吧！",
	800: "嘿，我都100英尺高了！庆祝一下吧！输入“daisies”，让僵尸们死的时候留下一朵小菊花。",
	900: "啊哈！我500英尺高了！来点舞蹈吧！输入“dance”，让僵尸们都摇摆起来吧！",
	1000: "喔！我已经1000英尺高了！和我一起输入“pinata”，让僵尸们死的时候吐出糖果，来庆祝吧！",
	1100: "谢谢你的照料！我已经把全部智慧都给你了，但是你仍然可以让我长的更高！",
}

## 里程碑高度 -> 台词编号(原版 TreeOfWisdomGiveWisdom 只认「正好等于」)
const MILESTONE_HEIGHT_TALK: Dictionary = {
	100: 800,
	500: 900,
	1000: 1000,
}
## 超过这个高度之后, 每次施肥改讲 1100(原版 aTreeSize > 1000)
const TALK_INDEX_ALL_WISDOM_GIVEN := 1100
## 一次都没喂过时讨食的编号(原版 TREE_OF_WISDOM_600)
const TALK_INDEX_HUNGRY := 600
## 重复旧台词前的开场白编号(原版 TREE_OF_WISDOM_500)
const TALK_INDEX_REPEAT_INTRO := 500
## 闲聊池的起始编号(原版 201 / 301 / 401 三档)
const TALK_POOL_MID_HEIGHT := 201
const TALK_POOL_TALL := 301
const TALK_POOL_HUGE := 401
## 闲聊池 101..110 的起始编号(原版 aBabbleHit == 1 时不分高度随机取一条)
const TALK_POOL_ANY_HEIGHT := 101
## 每个闲聊池的条数
const TALK_POOL_SIZE := 5
const TALK_POOL_ANY_HEIGHT_SIZE := 10


## 取一句台词; 表里没有的编号返回空串
static func get_talk_line(talk_index: int) -> String:
	return str(TALK_LINES.get(talk_index, ""))
#endregion


#region 台词选择(原版 Challenge 的判定逐条搬过来)
## 施肥后讲哪句: 里程碑 / 超 1000 / 其余按高度(原版 TreeOfWisdomGiveWisdom)
static func get_give_wisdom_talk(height: int) -> int:
	if MILESTONE_HEIGHT_TALK.has(height):
		return int(MILESTONE_HEIGHT_TALK[height])
	if height > 1000:
		return TALK_INDEX_ALL_WISDOM_GIVEN
	## 原版 std::clamp(aTreeSize - 1, 1, 49): 1~2 英尺讲第 1 句, 50 英尺往后讲第 49 句
	return clampi(height - 1, 1, 49)


## 没长高时自己嘟囔哪句(原版 TreeOfWisdomBabble)
## `babble_hit` 是原版 RandRangeInt(0, 2) 的那个 0/1/2
static func get_babble_talk(height: int, babble_hit: int) -> int:
	if height <= 1:
		return TALK_INDEX_HUNGRY
	if babble_hit == 0 and height >= 5:
		return TALK_INDEX_REPEAT_INTRO
	if babble_hit == 1:
		return randi_range(TALK_POOL_ANY_HEIGHT, TALK_POOL_ANY_HEIGHT + TALK_POOL_ANY_HEIGHT_SIZE - 1)
	var pool_start := TALK_POOL_MID_HEIGHT
	if height >= 50:
		pool_start = TALK_POOL_HUGE
	elif height >= 12:
		pool_start = TALK_POOL_TALL
	return randi_range(pool_start, pool_start + TALK_POOL_SIZE - 1)


## 重复旧台词时讲哪句(原版 TreeOfWisdomSayRepeat)
## 100 / 500 / 1000 英尺往后各有 1/47 的概率重讲里程碑那句, 否则从 2..clamp(高度,3,49) 里随机
static func get_repeat_talk(height: int) -> int:
	if height >= 100 and randi_range(0, 46) == 0:
		return 800
	if height >= 500 and randi_range(0, 46) == 0:
		return 900
	if height >= 1000 and randi_range(0, 46) == 0:
		return 1000
	return randi_range(2, clampi(height, 3, 49))
#endregion


#region 表现参数
## 原版树叶 / 树干的悬停高亮不透明度(mExtraOverlayColor.a / 255):
## 树干按树高分两档, 树根草丛固定; 见 Challenge::TreeOfWisdomDraw
const HOVER_ALPHA_TRUNK_SMALL := 128.0 / 255.0
const HOVER_ALPHA_TRUNK_BIG := 48.0 / 255.0
const HOVER_ALPHA_ROOT := 32.0 / 255.0
## 树高低于这个值时树干高亮更亮(原版 aHeight < 18)
const HOVER_SMALL_TREE_HEIGHT := 18

## 对话气泡的位置: 树苗 / 小树 / 大树三档(原版 TreeOfWisdomDraw 的 aPosX / aPosY)
const SPEECH_BUBBLE_POS_SMALL := Vector2(400, 152)
const SPEECH_BUBBLE_POS_MID := Vector2(395, 60)
const SPEECH_BUBBLE_POS_BIG := Vector2(390, 52)
## 气泡里的文字框相对气泡左上角的偏移与尺寸(原版 Rect(aPosX + 25, aPosY + 6, 233, 144))
const SPEECH_BUBBLE_TEXT_OFFSET := Vector2(25, 6)
const SPEECH_BUBBLE_TEXT_SIZE := Vector2(233, 144)

## 点击判定: 原版 Challenge::TreeOfWisdomHitTest 的四档固定矩形(800×600 屏幕坐标)
const HIT_RECT_SPROUT := Rect2(310, 275, 175, 175)   ## 高度 <= 1
const HIT_RECT_SMALL := Rect2(290, 255, 205, 195)    ## 高度 < 7
const HIT_RECT_MID := Rect2(290, 215, 205, 225)      ## 高度 < 12
const HIT_RECT_BIG := Rect2(280, 155, 225, 305)      ## 其余

## 施肥时树肥料袋子落下的位置(原版 TreeOfWisdomFertilize 的 AddReanimation(340, 300))
const FERTILIZE_POS := Vector2(340, 300)

## 状态机计时(原版按 100Hz 的 tick 计, 这里统一换成秒):
## 树长高后的弹跳 / 讲智慧 / 闲聊 / 两次闲聊之间的等待
const TICK := 0.01
const TIMER_JUST_GREW := 120 * TICK
const TIMER_GIVE_WISDOM := 1000 * TICK
const TIMER_BABBLE := 400 * TICK
const TIMER_REPEAT := 600 * TICK
const TIMER_WAIT_BABBLE_MIN := 700 * TICK
const TIMER_WAIT_BABBLE_MAX := 1500 * TICK
const TIMER_WAIT_BABBLE_AGAIN_MIN := 700 * TICK
const TIMER_WAIT_BABBLE_AGAIN_MAX := 1000 * TICK
## 高度文字在「刚长高」期间的弹跳: 原版 PvzpAnimateCurveFloat(55, 20, counter, 1.0, 1.2, CURVE_BOUNCE)
const GROW_PULSE_FROM := 55 * TICK
const GROW_PULSE_TO := 20 * TICK
const GROW_PULSE_SCALE := 0.2
#endregion


#region 外观(动画缺档时的兜底)
## 外观档位的起始高度(下标 = 档位, 见 get_stage_index)
## 0 档是刚买下的幼苗; 最后三档对齐原版的 100 / 500 / 1000 英尺三个里程碑
const STAGE_MIN_HEIGHT: Array[int] = [0, 1, 3, 6, 11, 21, 41, 101, 501, 1001]

## 51 档动画(原版 anim_grow1..51)的产物目录 / 命名 / 档位上限
const ANIM_DIR := "res://animation/garden/tree_of_wisdom/"
const ANIM_PREFIX := "treeofWisdom_grow"
## 进场播到第几档(原版 TreeOfWisdomInit: clamp(size, 1, 50))
const ANIM_STAGE_INIT_MAX := 50
## 长高播到第几档(原版 TreeOfWisdomGrow: clamp(size, 1, 51))
const ANIM_STAGE_GROW_MAX := 51
## 长高时的播放速率, 单位是"帧/秒"(原版 TreeOfWisdomGrow 的 PlayReanim(..., 8.0f))
## 素材本身 12fps ⇒ 实际 0.67 倍速, 一档 5~10 帧播 0.5~0.8 秒, 这才看得见"拉伸"
const ANIM_PLAY_RATE_GROW := 8.0

## 智慧树外观: 下标 = 档位
## trunk / root 是两张贴图, 摆放直接取自 assets/all_reanim/treeofWisdom.reanim 里该部件首次出现的帧
## (tree_bg.jpg 天空 + tree_grass.jpg 草坡 + trunk + root 叠起来就是原版的智慧树一页)
## root 只有 4 档以后才有(树大了, 用更大的树根草丛盖住上一档的根部)
## ★ 是 `static var` 不是 `const`：贴图经 AssetRegistry 取用（缓存 / 可运行时替换），
##   而 const 的初始值必须是常量表达式；`get_stage_sprite()` 等取用方是 static 函数
static var TREE_STAGES: Array[Dictionary] = [
	{	## 刚买下: 一截刚冒头的幼苗
		"trunk": AssetRegistry.get_texture("res://pak/reanim/tree01.png"),
		"trunk_position": Vector2(385.6, 405.1),
		"trunk_scale": Vector2(1.0, 0.324),
		"root": null, "root_position": Vector2.ZERO, "root_scale": Vector2.ONE,
	},
	{
		"trunk": AssetRegistry.get_texture("res://pak/reanim/tree1.png"),
		"trunk_position": Vector2(381.0, 308.2),
		"trunk_scale": Vector2(1.0, 1.196),
		"root": null, "root_position": Vector2.ZERO, "root_scale": Vector2.ONE,
	},
	{
		"trunk": AssetRegistry.get_texture("res://pak/reanim/tree2.png"),
		"trunk_position": Vector2(372.7, 249.0),
		"trunk_scale": Vector2.ONE,
		"root": null, "root_position": Vector2.ZERO, "root_scale": Vector2.ONE,
	},
	{
		"trunk": AssetRegistry.get_texture("res://pak/reanim/tree3.png"),
		"trunk_position": Vector2(326.7, 160.0),
		"trunk_scale": Vector2(1.032, 1.032),
		"root": null, "root_position": Vector2.ZERO, "root_scale": Vector2.ONE,
	},
	{
		"trunk": AssetRegistry.get_texture("res://pak/reanim/tree4.png"),
		"trunk_position": Vector2(305.0, 74.2),
		"trunk_scale": Vector2.ONE,
		"root": AssetRegistry.get_texture("res://pak/reanim/tree_overlay4.png"),
		"root_position": Vector2(347.4, 392.2), "root_scale": Vector2.ONE,
	},
	{
		"trunk": AssetRegistry.get_texture("res://pak/reanim/tree5.png"),
		"trunk_position": Vector2(261.5, 10.5),
		"trunk_scale": Vector2.ONE,
		"root": AssetRegistry.get_texture("res://pak/reanim/tree_overlay5.png"),
		"root_position": Vector2(337.6, 385.5), "root_scale": Vector2.ONE,
	},
	{
		"trunk": AssetRegistry.get_texture("res://assets_custom/reanim/tree6.png"),
		"trunk_position": Vector2(160.7, -51.4),
		"trunk_scale": Vector2(0.959, 1.0),
		"root": AssetRegistry.get_texture("res://pak/reanim/tree_overlay6.png"),
		"root_position": Vector2(294.7, 373.6), "root_scale": Vector2(0.959, 1.0),
	},
	{
		"trunk": AssetRegistry.get_texture("res://assets_custom/reanim/tree7.png"),
		"trunk_position": Vector2(45.6, -86.4),
		"trunk_scale": Vector2(0.903, 1.051),
		"root": AssetRegistry.get_texture("res://pak/reanim/tree_overlay7.png"),
		"root_position": Vector2(242.4, 347.5), "root_scale": Vector2(0.903, 1.051),
	},
	{
		"trunk": AssetRegistry.get_texture("res://assets_custom/reanim/tree8.png"),
		"trunk_position": Vector2(34.0, -100.3),
		"trunk_scale": Vector2(0.906, 1.086),
		"root": AssetRegistry.get_texture("res://assets_custom/reanim/tree_overlay8.png"),
		"root_position": Vector2(197.3, 335.9), "root_scale": Vector2(0.906, 1.086),
	},
	{
		"trunk": AssetRegistry.get_texture("res://assets_custom/reanim/tree9.png"),
		"trunk_position": Vector2(158.7, -89.9),
		"trunk_scale": Vector2(1.0, 1.063),
		"root": AssetRegistry.get_texture("res://assets_custom/reanim/tree_overlay9.png"),
		"root_position": Vector2(158.1, 314.8), "root_scale": Vector2(1.0, 1.063),
	},
]


## 该高度显示第几档外观(0 = 刚买下的幼苗)
static func get_stage_index(height: int) -> int:
	var stage := 0
	for i in range(STAGE_MIN_HEIGHT.size()):
		if height >= STAGE_MIN_HEIGHT[i]:
			stage = i
	return stage


## 该档外观的贴图与摆放
static func get_stage_sprite(stage: int) -> Dictionary:
	return TREE_STAGES[clampi(stage, 0, TREE_STAGES.size() - 1)]
#endregion
