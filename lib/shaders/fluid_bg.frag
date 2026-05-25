#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;
uniform vec4 u_color1;
uniform vec4 u_color2;
uniform vec4 u_color3;

out vec4 frag_color;

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  
  // 流体模拟（简化版）
  vec3 color = mix(
    u_color1.rgb,
    u_color2.rgb,
    sin(uv.x * 3.0 + u_time * 0.5) * 0.5 + 0.5
  );
  
  color = mix(
    color,
    u_color3.rgb,
    cos(uv.y * 2.0 + u_time * 0.3) * 0.5 + 0.5
  );
  
  // 添加噪点增加流动感
  float noise = sin(uv.x * 10.0 + u_time) * cos(uv.y * 10.0 - u_time) * 0.1;
  color += noise;
  
  frag_color = vec4(color, 1.0);
}
