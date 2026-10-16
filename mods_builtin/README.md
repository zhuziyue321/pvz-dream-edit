<!-- AGENT-DOC: pointer -->
# README.md —— `mods_builtin/` 目录指针（内置模组源码 = **两个加载源之一**）

> 本文件**只做指针**：模组机制的正文在 [../docs/参考存档/模组机制.md](../docs/参考存档/模组机制.md)。

## 一句话

这里放**内置模组的源码**，是**两个加载源**里的内置那一份（另一个是 `user://mods/`）：

- **默认就是从这里加载** —— 改这里的文件，重启即生效；
- 玩家在 `user://mods/` 下放了**同名模组**（整目录拷过去）时，那一份**优先**，这份就不加载了；
- 玩家那份**读不出来**（导出后脚本被转成引擎认不出的形态）时，会退回到这里再试一次。

两个源**不互相复制**（2026-10-15 起）：这里的文件不会自动铺到 `user://mods/`，
想改哪个内置模组就自己把**整个目录**拷过去（含 `mod_base.gd`，一个模组只从一个根加载）。

## 为什么要有这么一层

| 约束 | 结论 |
|---|---|
| 玩家要求「模组文件夹在 `user://mods`」 | 运行时**优先**从 `user://` 加载，那里没有才用这份 |
| 模组源码得进仓库、还得能编译 | 得留一份在 `res://`（这份就是默认加载源） |
| 只给玩家一个游戏文件（pck 嵌进 exe）时也要能跑 | 这份自带、永远齐全，不存在「装不上就没了」 |
| autoload 脚本必须是 `res://` 资源 | `mod_manager.gd` 留在 `src/mods/`（见 [../src/mods/README.md](../src/mods/README.md)） |

于是：`src/mods/` 只留框架，`mods_builtin/` 是内置加载源，`user://mods/` 是玩家那份（优先）。

## ⚠️ 在这里写代码的硬规矩（踩过的坑）

`user://` 下的脚本 **`class_name` 不会注册成全局类**（实测 Godot 4.6.2），所以：

| 不能写 | 改成 |
|---|---|
| `extends ModBase` | `extends "../mod_base.gd"`（相对路径；绝对路径也行） |
| `var m: ModBase` / `-> ModBase` | 去掉类型标注（`ModBase` 常量只用来取 `DETAIL_REFRESH_META` 这类常量） |
| `GloveMod.CONST` / `X.new()` | 先 `const GloveMod := preload("xxx.gd")`，再用常量引用 |
| 两个文件互相 `preload` | **会成环**，把「两边都要读的设置」抽成第三个文件（如 `glove_settings.gd` / `hammer_settings.gd`） |

**`mod_ids.gd` / `mod_config.gd` 是例外**：它们保留 `class_name`，因为它们是本体 ↔ 模组的契约，
`res://` 侧（`adventure_04_06.gd`、`data/mods/mod_config.tres`）要用它们的名字编译。

另外两个实测结论（已写进 `mod_manager.gd` 的类注释）：

- `user://` 的脚本**不走资源缓存**，每次 `load()` 都是新对象 → `Script.instance_has()` **恒为 false**，
  判断「是不是 ModBase 子类」要沿 `get_base_script()` 基链**比路径**。
- `res://` 的脚本**可以** `preload("res://mods_builtin/xxx.gd")`，探针就是这么引用的 ——
  模组不写 `class_name`，两边都只能按路径 preload 成常量。

**模组素材（贴图 / 场景）**放**模组自己目录**里，用 `load_asset("x.png")`（入口脚本，`ModBase` 子类）
或 `ModManager.load_mod_asset(ModIds.XXX, "x.png")`（角色 / 组件 / 规则脚本）读 ——
**别** `preload("res://assets/...")` 塞进本体（那样模组不自包含，整目录拷到 `user://mods/` 时素材不跟着走，
导出后 `user://` 那份也读不到）。细则见 [../docs/参考存档/模组机制.md §2.2](../docs/参考存档/模组机制.md)。

## 文件

| 文件 | 作用 |
|---|---|
| `mod_base.gd` | `ModBase`：模组基类，`install()` / `on_level_para_ready()` / `install_to_main_game()`（时序见类注释） |
| `mod_ids.gd` | `ModIds`：模组 id 常量表（**保留 `class_name`**，本体与模组共用） |
| `mod_config.gd` | `ModConfig`：**工程默认**开关数据资源（`data/mods/mod_config.tres` 用它；只在存档文件不存在时播种一次，保留 `class_name`） |
| `glove/` | 手套模组：把场上已种下的植物搬到另一个格子（含 `glove_settings.gd`） |
| `hammer/` | 锤子模组：点一下草坪，对小范围内的僵尸造成伤害（数值可调，也可秒杀；含 `hammer_settings.gd`） |
| `more_armor/` | 更多的防具模组：铜桶 / 钻石桶 / 下界合金桶，各配一只戴桶的僵尸（热注册，编号 9001 起） |
| `custom_level/` | 自制关卡模组：加载 `user://custom_level` 下的玩家自制关卡，并在主菜单加入口 |
| `netplay/` | 联机模组：ENet 连线 + 命令同步，主菜单加入口 |
| `purple_direct_plant/` | 紫卡直接种植模组：紫卡不必先种基座植物，代价是「基座植物的阳光 + 惩罚阳光」（含 `purple_direct_plant_rule.gd`） |
| `water_bowl/` | 水盆模组：新增战斗植物「水盆」（花盆的水生形态，摆在陆地上、**上面只接水生植物**，且**上层植物的影子藏掉**；含 `plant_water_bowl.tscn` / `water_bowl_plant.gd`）—— **新增植物怎么装**见 [../docs/参考存档/运行期植物.md](../docs/参考存档/运行期植物.md) |
| `pvz2/` | PVZ2 模组：**新增战斗植物「菜问」**（《植物大战僵尸 2》的角色，原版没有）；PVZ2 的 PAM 动画已离线烘焙成 `.tscn`（贴图在 `res://mods_builtin/pvz2/bonkchoy/`，与脚本/场景同目录，模组自包含），本仓库只收产物、不在运行时解析 PAM —— 见 [../docs/参考存档/模组机制.md](../docs/参考存档/模组机制.md) §6.7 |
| `balance/` | 原版平衡模组：把**原版已有的数值**改成同人口径（10 条：三种植物的阳光、寒冰菇伤害、机枪连发、仙人掌子弹穿透、卷心菜索敌三行、吸金磁能吸铁器、格子新增光照等级 → 向日葵按光照多产阳光），不加任何玩法（含 `balance_settings.gd` / `balance_plant_patcher.gd` / `balance_wiring.gd`）—— **本体为它留的通用口子**见 [../docs/参考存档/模组机制.md](../docs/参考存档/模组机制.md) §6.6 |
| `zhaoxiao/` | 招笑版模组：改向日葵与豌豆射手两只植物。**向日葵 → 朝阳葵**：任何一株产阳光时其余朝阳葵一起**只转头**看它（花茎叶子不动；目标在左边就把花头镜像过去，再转到「右侧对准目标」），它自己**持续**流汗（纯贴图挂一颗在花心上、不做动画，借禅境花园那颗「缺水」水珠贴图）。**豌豆射手 → 傻豆射手**：普通攻击打出去的是一颗**没有碰撞箱、不造成伤害**的傻豆（两种随机：飞到**僵尸前面**就**掉到地上**、落地那一下播本体的「豌豆命中」特效再消失 / **射偏** —— 照僵尸受击框算出来的方向，**恰好**擦着头顶或贴着脚底过去），每打一颗攒怒气、怒气把整株**慢慢染红**，满了放大招 —— 怒气 2 秒内**匀速**降下去，这段时间朝正前方 ±25 度、以随机速度散射**普通豌豆**（真子弹）。两只植物的观察者节点都是每局现挂（含 `zhaoxiao_settings.gd` / `zhaoxiao_sunflower.gd` / `zhaoxiao_peashooter.gd` / `zhaoxiao_shadou.gd`）—— 见 [../docs/参考存档/模组机制.md](../docs/参考存档/模组机制.md) §6.8 |

| `zhaoxiao/`（续） | **樱桃炸弹 → 烟熏樱桃**：爆炸**一点伤害都不造成**（伤害压 0，爆炸表现照旧），改成给爆炸范围内的僵尸上 30 秒**烟熏** —— 遇到植物就**站着播待机**（不啃，植物一滴血不掉）、并且**被同类索敌**（标上本体那个「谁都能打它」的通用口子，归属阵营不变 ⇒ 玩家植物照旧打得中它）；状态挂在僵尸身上 30 秒后自己撤干净（含 `zhaoxiao_cherry.gd` / `zhaoxiao_smoke.gd`）—— 见 [../docs/参考存档/模组机制.md](../docs/参考存档/模组机制.md) §6.8.3 |

## 新增一个模组

`ModIds` 加常量 → `ModManager.MOD_SCRIPT_PATHS` 加一行 → `mods_builtin/<id>/` 写入口脚本（继承 `ModBase`）。
细则与边界规则见 [../docs/参考存档/模组机制.md](../docs/参考存档/模组机制.md) §四 / §五。

改完这里的文件**直接生效**，不用加版本号、也不用等同步 —— 它就是默认加载源
（`user://mods/` 下没有同名模组时跑的就是这份）。
