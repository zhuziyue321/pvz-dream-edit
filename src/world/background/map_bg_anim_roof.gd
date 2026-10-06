extends MapBgAnimBase
class_name MapBgAnimRoof
## 屋顶的背景动画。
## 屋顶斜面（MainGameSlope）不算表现 —— 僵尸落位、小推车、抛物线子弹影子都要查它的坐标，
## 属于逻辑侧，由 BackgroundManager 按 ResourceMapData.have_slope 装配。留作扩展点。
