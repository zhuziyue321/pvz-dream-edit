extends RefCounted
## PAM 实例状态 —— 某一帧里「某个图层此刻长什么样」
##
## 烘焙时已经把 append/remove/change 压平成每帧一份快照，运行时只读这里。

## 图层序号（绘制层级，越小越先画）
var index: int = 0
## 引用的资源下标：`is_sprite` 为 false 时是 `PAMAnimData.images` 的下标，
## 为 true 时是 `sprite_names / sprite_timelines` 的下标
var resource: int = 0
## 引用的是 sprite（另一条时间轴）还是图片
var is_sprite: bool = false
## sprite 自己播到第几帧（非 sprite 恒为 0）
var anim_frame: int = 0
## 叠加颜色（PAM 的 color，alpha 常用于吐息/隐身一类的渐变）
var color := Color.WHITE
## 本帧的变换（画布坐标）
var xform := Transform2D.IDENTITY
