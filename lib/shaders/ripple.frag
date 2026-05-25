#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;
uniform vec2 u_touch_position;
uniform float u_touch_radius;
uniform vec4 u_color;

out vec4 frag_color;

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  
  // 计算到触摸点的距离
  vec2 touch_uv = u_touch_position / u_resolution;
  float dist = distance(uv, touch_uv);
  
  // 创建涟漪效果
  float ripple = sin(dist * 20.0 - u_time * 5.0) * exp(-dist * 3.0);
  ripple = max(0.0, ripple);
  
  // 基础颜色
  vec3 color = u_color.rgb;
  
  // 添加涟漪
  color += vec3(ripple * 0.5);
  
  frag_color = vec4(color, u_color.a);
}
