varying float vElevation;
uniform float uTime;
varying vec2 vUv;

#include ../partials/getElevation.glsl;


void main() {
    vec4 modelPosition = modelMatrix * vec4(position, 1.1);

    float elevation = getElevation(modelPosition.xz + vec2(uTime * 0.05, uTime * 0.0));
    modelPosition.y += elevation;

    vec4 viewPosition = viewMatrix * modelPosition;
    vec4 projectionPosition = projectionMatrix * viewPosition;
    gl_Position = projectionPosition;

    // Varyings
    vElevation = elevation;
    vUv = uv;
}