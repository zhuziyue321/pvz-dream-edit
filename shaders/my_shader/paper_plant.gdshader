shader_type canvas_item;

// 「我是僵尸」模式的纸板植物外观
//
// 原版 `Challenge::IZombieDrawPlant`（`../PvZ-Portable-main/src/Lawn/Challenge.cpp:4505`）
// 用**同一个 reanim 画 4 遍**造出纸板质感：
//   1. 白滤镜（FILTER_EFFECT_WHITE）+ 偏移 (+4,+4) + 深棕 (122, 86, 58)
//   2. 白滤镜 + 偏移 (+2,+2) + 中棕 (171, 135, 107)
//   3. 白滤镜 + 偏移 (-2,-2) + 中棕 (171, 135, 107)
//   4. 无滤镜 + 原位 + 淡肤色 (255, 201, 160)
//
// 原版的「白滤镜 + SetColor」= **把剪影染成这个颜色**（Graphics::SetColorizeImages），
// 所以描边层是**纯色剪影**（不是白剪影），本体层是原图 × 淡肤色。
//
// 仓库侧对应两种用法：
//   · silhouette = true  → 纯色剪影（描边层，颜色由 paper_tint 给）
//   · silhouette = false → 原图 × paper_tint（本体层，paper_tint = 原版的淡肤色）
//
// ⚠️ **paper_tint 必须传 0~1 的比例**：Godot 的 `Color(255, 201, 160)` 是 0~255 的值
//   （Color 构造不归一化），直接塞进 uniform 会被 clamp 成纯白 —— 画面上纸板全是白的。
//   调用方（`PaperPlantLook`）负责除 255。
// ⚠️ **不要加 source_color 提示**：加了 Godot 会再做一次 sRGB→线性转换，颜色会偏。
//
// ⚠️ modulate 自己在 vertex 阶段存一份（v_modulate）：
// fragment 阶段的 COLOR 输入语义（是否已乘过贴图）各版本说法不一，
// 自己存一份最稳（与 `my_shader/imitater.gdshader` 同一套写法）。

varying vec4 v_modulate;

// 着色（本体层 = 淡肤色；描边层 = 描边色）—— 0~1 的比例
uniform vec4 paper_tint = vec4(1.0, 0.788, 0.627, 1.0);
// 是否只取剪影（描边层）
uniform bool silhouette = false;

void vertex() {
	v_modulate = COLOR; // 节点自己的 modulate（含 self_modulate）
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// 描边层：丢掉原色，填成描边色（原版的 FILTER_EFFECT_WHITE + SetColor）
	vec3 rgb = silhouette ? paper_tint.rgb : tex.rgb * paper_tint.rgb;
	// 保留 modulate（受击发白 / 冰冻染色那些表现）
	COLOR = vec4(rgb * v_modulate.rgb, tex.a * v_modulate.a);
}
