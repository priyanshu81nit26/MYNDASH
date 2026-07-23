#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
      mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
      mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p *= 2.03;
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float t = uTime * 0.04;

  float n1 = fbm(uv * 3.0 + vec2(t, -t * 0.7));
  float n2 = fbm(uv * 4.0 - vec2(t * 0.6, t));
  float n3 = fbm(uv * 2.0 + vec2(-t, t * 0.4));

  vec3 violet = vec3(0.486, 0.302, 1.0);
  vec3 cyan = vec3(0.0, 0.898, 1.0);
  vec3 magenta = vec3(1.0, 0.18, 0.573);

  vec3 col = vec3(0.010, 0.010, 0.018); // near-black base
  col += violet * pow(n1, 3.0) * 0.34;
  col += cyan * pow(n2, 3.5) * 0.22;
  col += magenta * pow(n3, 4.0) * 0.20;

  // soft vignette
  float d = distance(uv, vec2(0.5, 0.42));
  col *= 1.0 - d * 0.55;

  fragColor = vec4(col, 1.0);
}
