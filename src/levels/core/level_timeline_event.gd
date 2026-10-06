extends Resource
class_name ResourceLevelTimelineEvent
## 关卡时间轴上的一个事件（时间轴见 ResourceLevelTimelineData）
##
## **一种事件 = 一个脚本**：本类是基类，每种事件继承它 ——
## 脚本自己 `@export` 出来的字段就是本事件的参数，脚本自己实现的 `run()` 就是本事件的行为。
## LevelTimelineManager 只管按数组顺序 `await` 每个事件的 run()，不认识任何具体事件类型。
##
## 为什么不是「通用事件 + 事件类型枚举 + 执行器里 match 分发」：
##   那样加一种事件要同时动执行器 / 枚举 / 事件资源三处，而且所有事件的参数都堆在同一个
##   资源上（戴夫对话的对话资源和等待的秒数挤在一起，各自只用到一两个字段）。
##   一种事件一个脚本后：加一种事件 = 新建一个脚本，参数只属于它自己。
##
## 现有的事件脚本都在 `level/script/timeline_event/`。

## 事件备注：只在编辑器里给人看，不参与运行
@export var note: String = ""

## 是否启用：关掉就等于把这一步从时间轴上摘掉
@export var is_enabled: bool = true

## 是否只在第一轮执行：多轮关卡每轮都会重跑一遍时间轴，勾上后第 2 轮起跳过
## （整关只跑一遍的轴见 ResourceLevelTimelineData.is_one_shot，那种轴本字段没意义）
@export var is_first_round_only: bool = false

## 轮询等待条件的间隔秒数
const POLL_STEP := 0.25


## 执行本事件：子类重写；跑完（await 到自己的完成条件）才返回
##
## **基类也故意写成协程**：调用方手里是基类类型（`var event: ResourceLevelTimelineEvent`），
## 编译器按基类签名判 REDUNDANT_AWAIT —— 基类不带 await 就被判成「不必 await」刷警告，
## 可运行期调到的是子类含 await 的 run()，等待是真的生效的（是个假阳性）。
## 末尾 await 一下让基类的静态类型也是协程，调用方就不必逐个 @warning_ignore。
func run(_main_game: MainGameManager) -> void:
	Log.warn("时间轴事件没实现 run()：" + str(get_script().resource_path))
	await wait_seconds(_main_game, 0.0)


#region 等待工具（等一个条件的事件用）
## 等待秒数（走场景树计时器，游戏暂停时一起停）
func wait_seconds(main_game: MainGameManager, seconds: float) -> void:
	if seconds <= 0.0:
		return
	## 关卡中途被销毁（玩家退出关卡 / 探针结束本关）时别再往下等，
	## 否则时间轴还挂在「等一个条件」上，会去访问已经释放的 MainGameManager
	if not is_instance_valid(main_game):
		return
	await main_game.get_tree().create_timer(seconds).timeout


## 轮询等待条件成立；timeout 大于 0 时最多等这么多秒（0 = 一直等）
func wait_until(main_game: MainGameManager, condition: Callable, timeout: float = 0.0) -> void:
	var waited := 0.0
	while true:
		if condition.call():
			return
		if timeout > 0.0 and waited >= timeout:
			Log.warn("时间轴事件等待超时，继续下一个事件：" + note)
			return
		await wait_seconds(main_game, POLL_STEP)
		## 等的过程中关卡没了：立刻结束本事件，别再调条件（条件里也访问 main_game）
		if not is_instance_valid(main_game):
			return
		waited += POLL_STEP
#endregion
