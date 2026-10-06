extends Resource
class_name ResourceLevelTimelineData
## 关卡时间轴：一串按顺序执行的关卡事件
##
## 内联在关卡资源 ResourceLevelData.timeline 上（**一个关卡 = 一个文件**，
## 不单独建时间轴 .tres —— 自定义关卡只要带着关卡文件走），由 LevelTimelineManager 执行：
## 从下标 0 开始，一个事件跑完（await 到它的完成条件）再跑下一个。
## 多轮关卡每轮重新跑一遍时间轴；只想让某步发生在第一轮的，用事件的
## ResourceLevelTimelineEvent.is_first_round_only。
##
## 本资源留空（或 events 为空）时，关卡按现有开关自动生成等价的默认时间轴，
## 见 ResourceLevelData.build_default_timeline。

## 按顺序执行的关卡事件
@export var events: Array[ResourceLevelTimelineEvent] = []

## 整关只跑一遍（默认 false = 多轮关卡每轮重跑一遍）
## 勾上后：进关时从头跑一次，之后**跨轮继续往下跑**，不再每轮重启
## （砸罐子这类一批接一批的关卡用这个：一轮 = 一批，整条轴把几批都写在一起，
##  批与批之间靠 ClearField 清场事件摆下一批，见 adventure_04_05.tres）
@export var is_one_shot: bool = false
