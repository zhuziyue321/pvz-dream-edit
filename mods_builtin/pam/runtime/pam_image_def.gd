extends RefCounted
## PAM 图片定义 —— 一张碎图（图集里的一块）

## 部件名（PAM 里 `name` 的 `|` 前一半，如 `celerystalker_69x105`）
var part_name := ""
## 图集贴图（加载后注入；单图集模式下所有部件共用同一张）
var texture: Texture2D = null
## 在图集里占的矩形（像素）
var src_rect := Rect2()
## 绘制尺寸（像素，与源图同尺寸；缩放走 `local_xform`）
var draw_size := Vector2.ZERO
## 图片自身的局部变换（绝大多数是画布内的平移）
var local_xform := Transform2D.IDENTITY
