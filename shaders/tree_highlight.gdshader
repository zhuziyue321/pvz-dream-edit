shader_type canvas_item;
render_mode unshaded;

// 智慧树「光标拿着树肥料指着树」时的白色高亮叠加。
// 对应原版 Reanimation 的 mExtraOverlayColor（白色 + alpha，画在精灵之上）。
// 这里把「精灵本身 + 白色叠加」合进一次绘制：rgb 朝白色混合，alpha 保持原贴图。
// strength 由调用方按渲染组给：树干 128/255（矮树）或 48/255（高树），树根草丛 32/255。
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, vec3(1.0), strength), tex.a);
}
