shader_type canvas_item;
render_mode blend_mix;

// 原版泳池水面特效（PoolEffect.cpp 的 PoolEffectDraw / UpdateWaterEffect）逐像素移植。
// 原版按 15×5 顶点网格画三层同矩形贴图（边缘顶点钉死、顶点间线性插值），这里连续化到像素：
//   层 0：TEXTURE（水面底图），偏移组 [0]；
//   层 1：shading_tex（明暗层，蒙版已烘进 alpha），偏移组 [1]，普通 alpha 混合；
//   层 2：焦散亮纹 —— caustic_tex（256×256 灰度、平铺）做两次不同速度的滚动采样取均值，
//         按原版阈值折成 alpha，再乘逐区域顶点色（白天左 0xC0 / 右 0x80、雾夜 0x30、边缘 0x20）。
// 原版 mPoolCounter 每逻辑帧 +1（30fps），这里用 TIME * 30 等价；相位周期 316800 帧同样保留。
// 常驻波光粒子（PoolSparkly）另挂在 pool.tscn，不归本 shader 管。

uniform sampler2D shading_tex : source_color, filter_linear;
uniform sampler2D caustic_tex : filter_linear, repeat_enable;
uniform float is_night : hint_range(0.0, 1.0) = 0.0;

const float CELL_X = 1.0 / 15.0;
const float CELL_Y = 1.0 / 5.0;

void fragment() {
	// 原版顶点相位 xPhase = x * 3 * 2π / 15（x = 0..15）→ 连续形式 uv * 6π
	float x_phase = UV.x * 6.0 * PI;
	float y_phase = UV.y * 6.0 * PI;
	float phase = mod(TIME * 30.0, 316800.0) * PI;
	float w1 = phase / 800.0;
	float w2 = phase / 150.0;
	float w3 = phase / 900.0;
	float w4 = phase / 800.0;
	float w5 = phase / 110.0;

	// 边缘钉死系数：原版仅边缘顶点偏移为 0，顶点间线性插值（PoolEffect.cpp:155-181）
	float pin_x = clamp(min(UV.x, 1.0 - UV.x) / CELL_X, 0.0, 1.0);
	float pin_y = clamp(min(UV.y, 1.0 - UV.y) / CELL_Y, 0.0, 1.0);
	float pin = pin_x * pin_y;

	// 偏移组 [0]：底图层（PoolEffect.cpp:167-168）
	vec2 off0 = vec2(
		sin(y_phase + w2) * 0.002 + sin(y_phase + w1) * 0.005,
		sin(x_phase + w5) * 0.01 + sin(x_phase + w3) * 0.015 + sin(x_phase + w4) * 0.005) * pin;
	// 偏移组 [1]：明暗层（PoolEffect.cpp:169-170）
	vec2 off1 = vec2(
		sin(y_phase * 0.2 + w2) * 0.015 + sin(y_phase * 0.2 + w1) * 0.012,
		sin(x_phase * 0.2 + w5) * 0.005 + sin(x_phase * 0.2 + w3) * 0.015 + sin(x_phase * 0.2 + w4) * 0.02) * pin;
	// 偏移组 [2]：焦散层 UV（PoolEffect.cpp:171-172）
	vec2 off2 = vec2(
		sin(y_phase + w1 * 1.5) * 0.004 + sin(y_phase + w2 * 1.5) * 0.005,
		sin(x_phase * 4.0 + w5 * 2.5) * 0.005 + sin(x_phase * 2.0 + w3 * 2.5) * 0.04 + sin(x_phase * 3.0 + w4 * 2.5) * 0.02) * pin;

	vec4 base_c = texture(TEXTURE, UV + off0);

	// 明暗层：普通 alpha 混合（DrawTrianglesTex 默认混合）
	vec4 sh = texture(shading_tex, UV + off1);

	// 焦散：两次滚动采样取均值，单位 = 逻辑帧 / 256 像素（PoolEffect.cpp:101-106）
	float counter = TIME * 30.0;
	vec2 uv_c = UV + off2;
	float a1 = texture(caustic_tex, uv_c + vec2(-counter / (6.0 * 256.0), counter / (8.0 * 256.0))).r;
	float a0 = texture(caustic_tex, uv_c + vec2(counter / (10.0 * 256.0), 0.0)).r;
	float a = (a0 + a1) * 0.5 * 255.0;

	// 原版阈值折 alpha（PoolEffect.cpp:108-122）：≥160 倒 V、[128,160) 线性上升、其余 0，再 /3
	float al;
	if (a >= 160.0) {
		al = 255.0 - 2.0 * (a - 160.0);
	} else if (a >= 128.0) {
		al = 5.0 * (a - 128.0);
	} else {
		al = 0.0;
	}
	al /= 3.0 * 255.0;

	// 逐区域顶点色（PoolEffect.cpp:207-222）：边缘 0x20，雾夜 0x30，白天左半 0xC0 / 右半 0x80。
	// 原版顶点色按行 / 列取值，这里按像素近似（底行在原版算内部色，差异可忽略）。
	float day_region = UV.x <= 7.0 * CELL_X ? 0.753 : 0.502;
	float interior = mix(day_region, 0.188, is_night);
	float color_mask = pin_x * clamp(UV.y / CELL_Y, 0.0, 1.0);
	al *= mix(0.125, interior, color_mask);

	// 合成：底图 ← 明暗层（over） ← 白色焦散（over）
	vec3 rgb = mix(base_c.rgb, sh.rgb, sh.a);
	float alpha = sh.a + base_c.a * (1.0 - sh.a);
	rgb = mix(rgb, vec3(1.0), al);
	alpha = al + alpha * (1.0 - al);

	COLOR = vec4(rgb, alpha);
}
