extends Plant000DownBase
class_name Plant017LilyPad

## 荷叶没有自己的逻辑：水面起伏统一走基类 Plant000DownBase 的 is_float_anim
## （本场景把 is_float_anim 打开、幅度与周期在场景里配），驱动方式是 AnimationPlayer 动画，
## 与花盆（写在 pot_idle 动画里的 DownPlantContainer:position 轨道）保持同一套机制。
