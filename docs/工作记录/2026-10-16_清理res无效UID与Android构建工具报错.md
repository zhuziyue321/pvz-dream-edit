<!-- AGENT-DOC: record -->

# 2026-10-16_清理res无效UID与Android构建工具报错

> **本次任务**：清掉启动/`--import` 日志里 34 条 `invalid UID: 'uid://a'` 告警，以及 `Unable to open Android 'build-tools' directory.`
> **耗时 / 轮次**：一轮；**未开游戏**（用 `--headless --import` + 临时 `SceneTree` 探针取证）
> **推荐度**：推荐

## 目标

- `godot --headless --path . --import 2> err.txt` 里的告警清零：
  - `In external resource #N, invalid UID: 'uid://a' - using text path instead: ...` ×34
  - `Unable to open Android 'build-tools' directory.` ×1

## 最简路径（步骤）

1. **取证**：`cmd /c "godot.exe --headless --path <repo> --import >o.txt 2>e.txt"`，再 grep `invalid UID`。
   - 34 条只来自 3 个文件（`item/lawn_mover/roof_cleaner.res`、`plant/pumpkin/all_anims.res`、`zombie_digger/zombie_digger_up.res`）。
   - **别以为另外 12 个 .res 没病**：告警只在资源**被加载**时打，`--import` 只 load 到这 3 个。
2. **看清「uid://a」的真身**：`godot --headless --script <探针>.gd` 里 `print(ResourceUID.id_to_text(0))` → 输出 `uid://a`。
   也就是说文件里存的 uid 是 **0**（原意「没有 uid，按 text path 解析」），不是真写了 `uid://a`。
   Godot 4.6 的 `ResourceLoaderBinary` 只在 `uid != INVALID_ID` 时才跳过该字段，遇到 0 会进
   `!ResourceUID.has_id(0)` 分支 → 每个外部资源打一条告警。
3. **修**：`python tools/fix_res_refs.py --apply`（`animation/` 下 15 个二进制 `.res` 的唯一修复工具）。
   本版工具做了两处必要改造：
   - 表定位锚点从 `data.find(b"res://assets/")` 换成「文件里最早的一条资源路径串」——迁移完就没有 `assets/` 了，旧锚点必然 `PARSE FAIL`；
   - 每个 ext 条目的 uid 统一写成 `INVALID_ID = 0xFFFFFFFFFFFFFFFF`（不是原来的 0），并成功走完 ext+int 两张表后才动手。
4. **验证（必须做，且不能只看 `--import`）**：写一个 `extends SceneTree` 的探针，把 `animation/` 下 15 个 `.res` 全部 `load()` 一遍 → 0 条告警、全部非 null。
5. **顺手做个可复现性测试**（强烈建议，5 分钟）：
   - 反向把路径改回 `res://assets/...` 并把 int offset 回退，再跑一次工具 → 输出应与改前**字节完全相同**（我用 SHA256 比对）。
   - 把 uid 全写回 0 再跑工具 → 同样应字节完全相同。
6. **Android 那条**：清 editor_settings（`%APPDATA%\Godot\editor_settings-4.6.tres` 与 `-4.7.tres`）里的
   `export/android/android_sdk_path`（本机指向不存在的 `C:\Users\<用户>\AppData\Local\Android\Sdk`）。
   没有 Android SDK 时该值留空即可，**不要**动项目里的 `export_presets.cfg`。

## 弯路 / 踩坑（三段式）

- **试过**：按字面理解，以为 `.res` 里真写了 `uid://a`，打算把每个外部资源改成「引用 PNG 的真实 uid」。
- **因为**：探针实测 `ResourceUID.id_to_text(0)` 的输出就是 `uid://a` —— 文件里是 0，不是 10 也不是别的。
  写成 `INVALID_ID` 才是「无 uid」的正解：运行期依旧是 text path 解析（行为零变化），告警消失。
- **结论**：统一写 `INVALID_ID`，不要填真实 uid（真实 uid 一旦重导入就变，反而制造新的悬空 uid）。

- **试过**：把 `export_presets.cfg` 里 Android 预设的 `runnable` 改成 `false`，想绕过启动时的校验。
- **因为**：无效，`Unable to open Android 'build-tools' directory.` 照打 —— 触发点不是「可运行预设」，
  而是编辑器加载预设时向 Android 平台取导出选项，平台会去枚举 build-tools。
- **结论**：要么装/配 Android SDK，要么把 `editor_settings` 里的 SDK 路径清空；`export_presets.cfg` 不用改。

- **试过**：沿用 `tools/fix_res_refs.py` 里 `has_uid = u32(data, pos+pl) > 64` 这个启发式判断「条目带不带 uid 字段」。
- **因为**：原版文件的 uid 恰好是 0，`> 64` 判成「没有 uid 字段」，于是**整张表走歪**：
  工具跑完报告 `ext=1`（真实 24），却因为「没有一条路径以 `res://assets/` 开头」而静默什么都不改，看着像没必要修。
- **结论**：改成「带 uid / 不带 uid 两种走法，哪种能把 ext+int 两张表走完且 offset 合理就用哪种」，
  并让 `PARSE FAIL` 显式打出来 —— 走不通时必须吵，不能静默当成功。

## 推荐度与理由

推荐。要点：

- **告警不吵不代表没问题**：只被加载的资源才会告警，所以「跑完很安静」不等于「全仓都干净」，要用探针全量 load。
- **别信 `uid://a` 这个字面值**：见第 2 步，先 `ResourceUID.id_to_text(0)` 验一下再动手。
- **纯二进制文件改完必须验字节级可复现**（第 5 步），否则下次谁再跑一次工具就可能把文件改坏而无从发现。
- 想让这条不再回流：把 `invalid UID` 加进 `test/check_scripts.ps1` 的 `$RealPattern` 即可（本次没加，避免扩大门禁口径）。

## 补充 / 评价（事后追加，见 §5）
