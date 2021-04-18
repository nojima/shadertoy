const float PI = 3.14159265358979323846;


// [-1, 1] の範囲にある x を [0, 1] にマップする
#define to01(x) ((x) * 0.5 + 0.5)

// [0, 1] の範囲にある x を [-1, 1] にマップする
#define to11(x) ((x) * 2.0 - 1.0)

vec3 hsv2rgb(vec3 hsv) {
    vec3 a = abs(mod(hsv.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0);
    vec3 b = smoothstep(2.0, 1.0, a);
    return hsv.z * (1.0 - hsv.y * b);
}

vec3 linear2srgb(vec3 c) {
    return mix(
        12.92 * c,
        1.055 * pow(c, vec3(1.0/2.4)) - 0.055,
        step(vec3(0.0031308), c)
    );
}

float sdf(vec3 pos) {
    return length(pos) - 2.0;
}

vec3 normalAt(vec3 p) {
#if 1
    // https://iquilezles.org/www/articles/normalsSDF/normalsSDF.htm
    const float h = 0.0001; // replace by an appropriate value
    const vec2 k = vec2(1, -1);
    return normalize(
        k.xyy * sdf(p + k.xyy*h) +
        k.yyx * sdf(p + k.yyx*h) +
        k.yxy * sdf(p + k.yxy*h) +
        k.xxx * sdf(p + k.xxx*h)
    );
#else
    const float h = 0.0001;
    return normalize(vec3(
        sdf(p + vec3(  h, 0.0, 0.0)) - sdf(p + vec3( -h, 0.0, 0.0)),
        sdf(p + vec3(0.0,   h, 0.0)) - sdf(p + vec3(0.0,  -h, 0.0)),
        sdf(p + vec3(0.0, 0.0,   h)) - sdf(p + vec3(0.0, 0.0,  -h))
    ));
#endif
}

vec3 shaderSurface(vec3 pos, vec3 normal) {
    // 光源の照度 [W/m^2]
    vec3 lightIrradiance = vec3(2.0);
    // pos から見た光源の方向
    vec3 lightDir = normalize(vec3(1.0, 1.0, 0.5));
    // surface の色
    vec3 albedo = vec3(1.0, 1.0, 1.0);

    return (albedo / PI) * dot(lightDir, normal) * lightIrradiance;
}

vec3 castRay(vec3 rayDir, vec3 cameraPos) {
    float rayLen = 0.0;
    float dist;
    for (int i = 0; i < 16; i++) {
        vec3 rayPos = rayDir * rayLen + cameraPos;
        dist = sdf(rayPos);
        rayLen += dist;
    }

    if (abs(dist) < 0.001) {
        vec3 rayPos = rayDir * rayLen + cameraPos;
        vec3 normal = normalAt(rayPos);
        return shaderSurface(rayPos, normal);
    } else {
        return vec3(0.0);
    }
}

vec3 render(vec2 uv) {
    // camera
    vec3 cameraPos = vec3(0.0, 0.0,  3.0);
    vec3 cameraDir = vec3(0.0, 0.0, -1.0);
    vec3 cameraUp  = vec3(0.0, 1.0,  0.0);

    vec3 cameraRight = cross(cameraDir, cameraUp);
    mat3 cameraMat = mat3(cameraRight, cameraUp, cameraDir);

    float targetDepth = 1.0;

    // ray
    vec3 rayDir = normalize(cameraMat * vec3(uv.xy, targetDepth));

    return castRay(rayDir, cameraPos);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // 画面上の位置をアスペクト比を保ったまま [-1, 1] の範囲にマップする
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);

    vec3 color = render(uv);
    fragColor = vec4(linear2srgb(color), 1.0);
}
