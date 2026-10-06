extends Resource
class_name CrazyDaveDialogDetailResource
## 与戴夫的交流细节资源文件，每一句话

## 当前语句的文本内容
@export_multiline var text:String
## 戴夫当前语句是否为发疯动画
@export var is_crazy:bool = false
## 戴夫当前语句是否展示手上物品
@export var is_hand:bool = false
## 当前对话的手持物品的编号(戴夫对话资源手持物品场景列表的下标)
@export var hand_item_id:int = -1

## 戴夫当前语句是否为选择
@export var is_choosed:bool = false
## 念到这句时往事件总线推的事件名（空 = 不推）
## 原版 1-5：戴夫说到「我们去玩保龄球！」的同一时刻，草坪上的保龄球红线出现
## （事件名见 WallnutBowlingStripe.SHOW_STRIPE_EVENT）
@export var on_talk_event:StringName = &""
