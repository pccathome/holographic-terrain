uniform sampler2D uTexture;
uniform float uTextureFrequency;

varying float vElevation;
varying vec2 vUv;

// #pragma glslify: getElevation = require('../partials/getElevation.glsl')
#include ../partials/getElevation.glsl
#include ../partials/getPerlinNoise2d.glsl
#include ../partials/hslToRgb.glsl

// vec3 getRainbowColor()
// {
//     vec2 uv = vUv;
//     uv.y += uTime * uHslTimeFrequency;

//     float hue = uHslHueOffset + getPerlinNoise2d(uv * uHslHueFrequency) * uHslHue;
//     float lightness = uHslLightness + getPerlinNoise2d(uv * uHslLightnessFrequency + 1234.5) * uHslLightnessVariation;
//     vec3 hslColor = vec3(hue, 1.0, lightness);
//     vec3 rainbowColor = hslToRgb(hslColor);

//     return rainbowColor;
// }

vec3 getRainbowColor()
{
    float hue = getPerlinNoise2d(vUv * 10.0);
    vec3 hslColor = vec3(hue, 1.0, 0.5);
    vec3 rainbowColor = hslToRgb(hslColor);
    return rainbowColor;
}


void main() {
    vec3 uColor = vec3(1.0, 1.0, 1.0);
    vec3 rainbowColor = getRainbowColor();
    vec4 textureColor = texture2D(uTexture, vec2(0.0, vElevation * uTextureFrequency));
    vec3 color = mix(uColor, rainbowColor, textureColor.r);
    float alpha = mod(vElevation * 10.0, 1.0);
    // alpha = step(0.95, alpha); 
    gl_FragColor = vec4(color, textureColor.g); 
}