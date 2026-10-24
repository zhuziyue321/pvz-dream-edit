extends PlantSunProducerBase
class_name Plant042TwinSunFlower
## 双子向日葵
## 公共逻辑（产阳光 / 被啃食 / 死亡）在 `PlantSunProducerBase`；与向日葵的差异
## （一次产两份阳光）由场景里 `CreateSunComponent` 的参数决定，脚本不需要再抄一遍。
