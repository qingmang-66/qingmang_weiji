#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;
uniform vec4 u_color;

out vec4 frag_color;

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  
  // 对角线 Shimmer 效果
  float shimmer = sin(uv.x * 5.0 + uv.y * 3.0 + u_time * 2.0) * 0.5 + 0.5;
  shimmer = pow(shimmer, 3.0); // 增强亮度
  
  frag_color = vec4(u_color.rgb, shimmer * u_color.a);
}
