extends RefCounted
## PAM 动画数据 —— `.pam.bin` 在运行时的载体（只读）
##
## ★ 同一个 `.bin` **全工程只解析一次**：`PAMAnimator` 按路径缓存本对象，多个实例共享。
##   这里存的是「压平后的每帧全量快照」，播放时不需要再解析 PAM 的 append/remove/change。
##
## ★ 贴图在加载后注入（`texture_map` + 每张 `PAMImageDef.texture`），
##   所以本对象一旦被缓存就带着贴图，重复实例化不会再读盘。

## 帧率（源 PAM 的 frame_rate，潜伏芹菜是 30）
var frame_rate: float = 30.0
## 画布尺寸（像素）；渲染时把画布中心对齐节点原点
var canvas_size := Vector2(390.0, 390.0)
## 主时间轴：每帧是一个 `Array[PAMInstanceState]`，已按 index 排好（index = 绘制层级）
var frames: Array = []
## 状态映射：状态名 → [起始帧, 帧数]
var states: Dictionary = {}
## 图片定义列表；实例里的 `resource` 就是这里的下标
var images: Array = []
## sprite 名（与 `sprite_timelines` 同序）；同名多份 = 同一部件被拆成多个图层
var sprite_names := PackedStringArray()
## 每个 sprite 一份时间轴（潜伏芹菜全是单帧，结构上仍按时间轴处理）
var sprite_timelines: Array = []
## 部件名 → 图片下标（同名部件以最后一张为准）
var part_map: Dictionary = {}
## bin 内嵌的贴图路径
var texture_paths := PackedStringArray()
## 贴图映射：文件名（去扩展名）→ Texture2D
var texture_map: Dictionary = {}
