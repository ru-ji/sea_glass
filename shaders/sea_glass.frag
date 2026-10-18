#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

// Sea Glass material body: a mechanical translation of SeaGlassBodyShader.kt
// (AGSL/SkSL) from https://github.com/mttmcknn/sea-glass to Flutter GLSL.
// Only these changes were made:
//  - float2/3/4 -> vec2/3/4; half4 main(coordinates) -> main() writing fragColor.
//  - `uniform shader` -> sampler2D. SkSL eval(texelCoords) becomes
//    texture(sampler, texelCoords / geometrySize), so geometrySize was added.
// Uniform order matters: Flutter sets floats by index (see painter.dart).

uniform sampler2D geometryA;
uniform sampler2D geometryB;
uniform vec2 materialSize;
uniform float fieldScale;
uniform float density;
uniform vec2 gradientScales;
uniform vec2 geometrySize;
uniform vec4 recipeA;
uniform vec4 recipeB;
uniform vec3 bodyColor;
uniform vec3 edgeColor;
uniform vec2 lightDirection;
uniform vec3 halfway;

out vec4 fragColor;

float hashNoise(vec2 point, float salt) {
    vec3 p = fract(vec3(point.x, point.y, point.x) * 0.1031 + salt);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z) * 2.0 - 1.0;
}

float noiseGrid(vec2 point, float spacing, float salt) {
    vec2 cell = point / spacing;
    vec2 index = floor(cell);
    vec2 fraction = fract(cell);
    vec2 eased = fraction * fraction * (3.0 - 2.0 * fraction);
    float a = hashNoise(index, salt);
    float b = hashNoise(index + vec2(1.0, 0.0), salt);
    float c = hashNoise(index + vec2(0.0, 1.0), salt);
    float d = hashNoise(index + vec2(1.0, 1.0), salt);
    return mix(mix(a, b, eased.x), mix(c, d, eased.x), eased.y);
}

// Value plus the analytic gradient of the same cubic interpolation.
// Four lattice hashes replace the center and four offset evaluations.
vec3 noiseGridGradient(vec2 point, float spacing, float salt) {
    vec2 cell = point / spacing;
    vec2 index = floor(cell);
    vec2 fraction = fract(cell);
    vec2 eased = fraction * fraction * (3.0 - 2.0 * fraction);
    vec2 derivative = 6.0 * fraction * (1.0 - fraction) / spacing;
    float a = hashNoise(index, salt);
    float b = hashNoise(index + vec2(1.0, 0.0), salt);
    float c = hashNoise(index + vec2(0.0, 1.0), salt);
    float d = hashNoise(index + vec2(1.0, 1.0), salt);
    float value = mix(mix(a, b, eased.x), mix(c, d, eased.x), eased.y);
    float dx = mix(b - a, d - c, eased.y) * derivative.x;
    float dy = mix(c - a, d - b, eased.x) * derivative.y;
    return vec3(value, dx, dy);
}

void main() {
    vec2 coordinates = FlutterFragCoord().xy;
    vec2 position = coordinates / density;
    vec3 base = texture(geometryA, position * fieldScale / geometrySize).rgb;
    vec3 rounded = texture(geometryB, position * fieldScale / geometrySize).rgb;
    vec2 gradient = (base.gb - 0.5) / gradientScales.x;
    vec2 roundedGradient = (rounded.gb - 0.5) / gradientScales.y;
    float frost = recipeA.x;
    float grain = recipeA.y;
    float thickness = recipeA.z;
    float bulge = recipeA.w;
    float transmission = recipeB.y;
    float seed = recipeB.z;
    float shortSide = min(materialSize.x, materialSize.y);
    float fine = noiseGrid(position, 0.68, seed + 0.11);
    vec3 micro = noiseGridGradient(position, 1.7, seed + 0.29);
    float worn = noiseGrid(position, 7.5, seed + 0.47);
    float cloud = noiseGrid(position, shortSide * 0.44, seed + 0.71) * 0.75 + worn * 0.25;
    float roughness = fine * 0.54 + micro.x * 0.32 + worn * 0.14;
    // The reference differences span 0.64 dp, shortened at the top/left.
    vec2 roughGradient = micro.yz * (0.32 + min(position, vec2(0.32)));
    float dome = mix(base.r, rounded.r, bulge);
    vec2 slope = mix(gradient, roundedGradient, bulge);
    float rise = 0.9 + min(thickness * 1.55, shortSide * 0.22) + bulge * shortSide * 0.34;
    vec3 shapeNormal = normalize(vec3(-slope * rise, 1.0));
    shapeNormal.z = clamp(shapeNormal.z, 0.0, 1.0);
    float rough = grain * (0.025 + frost * 0.04);
    vec3 normal = normalize(vec3(-slope * rise + roughGradient * rough, 1.0));
    float travel = clamp(position.y / materialSize.y, 0.0, 1.0);
    float flow = travel * travel * (3.0 - 2.0 * travel);
    float depth = (1.05 - flow * transmission * 0.13)
        * (0.70 + dome * (0.52 + thickness * 0.012))
        * (1.0 + (1.0 - shapeNormal.z) * max(0.0, -shapeNormal.y) * 0.28)
        * (1.0 + cloud * 0.035);
    float weathering = frost * (0.06 + (cloud + 1.0) * 0.025);
    vec3 tint = bodyColor * 0.96 + edgeColor * 0.04;
    vec3 color = 1.0 - (1.0 - tint) * depth;
    color += (1.0 - color) * weathering;

    float lx = lightDirection.x;
    float ly = lightDirection.y;
    float lightZ = 0.52;
    float lightSide = sqrt(1.0 - lightZ * lightZ);
    vec3 light = vec3(lx * lightSide, ly * lightSide, lightZ);
    float diffuse = max(0.0, dot(normal, light));
    vec3 reflectionNormal = vec3(2.0 * normal.xy * normal.z, 2.0 * normal.z * normal.z - 1.0);
    float reflectedLight = max(0.0, dot(reflectionNormal, light));
    float across = -ly * reflectionNormal.x + lx * reflectionNormal.y;
    float along = -lightZ * (lx * reflectionNormal.x + ly * reflectionNormal.y) + lightSide * reflectionNormal.z;
    float acrossScale = across / (0.78 + frost * 0.24);
    float alongScale = along / (0.46 + frost * 0.24);
    float reflection = exp(-(acrossScale * acrossScale + alongScale * alongScale))
        * clamp(reflectedLight / 0.30, 0.0, 1.0) * (0.15 + bulge * 0.12) * (0.82 + frost * 0.18);
    float scatter = pow(max(0.0, dot(normal, halfway)), 12.0 + (1.0 - frost) * 18.0) * (0.008 + frost * 0.012);
    float upperScale = (normal.y + 0.40) / 0.38;
    float upperTurn = exp(-(upperScale * upperScale)) * pow(max(normal.z, 0.000001), 0.55)
        * (0.10 + bulge * 0.14) * (0.85 + frost * 0.15);
    float palePits = pow(max(0.0, roughness + 0.20), 2.0) * grain
        * (5.0 + frost * 10.0) * (0.65 + diffuse * 0.35);
    float matte = roughness * grain * (0.012 + frost * 0.016);
    float grazing = sqrt(max(0.0, 1.0 - shapeNormal.z * shapeNormal.z));
    float lowerFacing = clamp((shapeNormal.y + 0.16) / 0.80, 0.0, 1.0);
    float shoulder = pow(grazing, 2.3) * lowerFacing * lowerFacing * (3.0 - 2.0 * lowerFacing);
    float exitAmount = clamp(transmission * (0.10 * flow + 1.65 * shoulder)
        * (0.96 - thickness * 0.005), 0.0, 0.96);
    float exitCatch = pow(max(0.0, 1.0 - shapeNormal.z), 2.2) * lowerFacing * 0.85;
    color += (1.0 - color) * (reflection + scatter + upperTurn);
    vec3 exitColor = edgeColor + (1.0 - edgeColor) * exitCatch;
    color += (exitColor - color) * exitAmount;
    color += (palePits / 255.0 + matte) * (1.0 - exitAmount * 0.45);
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
