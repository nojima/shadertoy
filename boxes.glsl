const float PI = 3.14159265358979323846;

/*
vec3 hsv2rgb(vec3 hsv) {
    vec3 a = abs(mod(hsv.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0);
    vec3 b = smoothstep(2.0, 1.0, a);
    return hsv.z * (1.0 - hsv.y * b);
}
*/

vec3 linear2srgb(vec3 c) {
    return mix(
        12.92 * c,
        1.055 * pow(c, vec3(1.0/2.4)) - 0.055,
        step(vec3(0.0031308), c)
    );
}

/*
float sdfSphere(vec3 center, float radius, vec3 p) {
    return length(p - center) - radius;
}
*/

float sdfBox(vec3 size, vec3 p) {
    return length(max(abs(p) - 0.5 * size, 0.0));
}

float sdfRoundedBox(vec3 size, float roundSize, vec3 p) {
    return sdfBox(size, p) - roundSize;
}

/*
vec3 repetition(vec3 interval, vec3 p) {
    return mod(p, interval) - 0.5 * interval;
}
*/

vec3 repetition(float interval, vec3 p) {
    int i = int(floor(p / interval));
    float dir = i % 2 == 0 ? -1.0 : 1.0;
    p.z += 2.0 * dir * iTime;
    return mod(p, interval) - 0.5 * interval;
}

float sdf(vec3 p) {
    return sdfRoundedBox(vec3(1.0), 0.1,
        repetition(4.0, p)
    );
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

vec3 brdf(vec3 lightDir, vec3 viewDir, vec3 normal) {
    vec3 ret = vec3(0.0);

    // Lambert
    vec3 albedo = vec3(1.0, 1.0, 1.0);
    ret += albedo / PI;

    // Blinn-Phong
    float reflectance = 0.5;
    float power = 5.0;
    float z = (power + 2.0) / (2.0 * PI);
    vec3 h = normalize(lightDir + viewDir);
    float dotNH = dot(normal, h);
    ret += z * reflectance * pow(max(dotNH, 0.0), power);

    return ret;
}

vec3 renderSurface(vec3 pos, vec3 normal, vec3 viewDir) {
    // 平行光源の放射照度 [W/m^2]
    vec3 directionalLightIrradiance = vec3(2.0);
    // 環境光の放射照度 [W/m^2]
    vec3 environmentLightIrradiance = vec3(0.05);
    // pos から見た光源の方向
    vec3 lightDir = normalize(vec3(1.0, 1.0, 0.8));

    float dotLN = dot(lightDir, normal);
    vec3 irradiance =
        environmentLightIrradiance +
        directionalLightIrradiance * max(dotLN, 0.0);

    return brdf(lightDir, viewDir, normal) * irradiance;
}

vec3 renderFog(vec3 baseColor, vec3 fogColor, float dist) {
    const float k = 0.1;
    return mix(fogColor, baseColor, exp(-k*dist));
}

vec3 castRay(vec3 rayDir, vec3 cameraPos) {
    float rayLen = 0.0;
    float dist;
    for (int i = 0; i < 100; i++) {
        vec3 rayPos = rayDir * rayLen + cameraPos;
        dist = sdf(rayPos);
        rayLen += dist;
    }

    if (abs(dist) < 0.001) {
        vec3 rayPos = rayDir * rayLen + cameraPos;
        vec3 normal = normalAt(rayPos);
        vec3 color = renderSurface(rayPos, normal, -rayDir);
        return renderFog(color, vec3(0.0), rayLen);
    } else {
        return vec3(0.0);
    }
}

float toRadian(float degree) {
    return degree * (PI / 180.0);
}

vec3 render(vec2 uv) {
    // camera
    vec3 cameraPos = vec3(0.0, 0.0, 5.0);
    vec3 cameraDir = normalize(vec3(-sin(iTime * 0.1), 0.0, -cos(iTime * 0.1)));
    vec3 cameraUp  = normalize(vec3(0.0, 1.0,  0.0));
    vec3 cameraRight = cross(cameraDir, cameraUp);
    float fov = toRadian(30.0);

    // ray
    vec3 rayDir = normalize(
        mat3(cameraRight, cameraUp, cameraDir) * vec3(uv.x * sin(fov), uv.y * sin(fov), cos(fov))
    );

    return castRay(rayDir, cameraPos);
}

vec3 exposureToneMapping(float exposure, vec3 hdrColor) {
    return vec3(1.0) - exp(-hdrColor * exposure);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // 画面上の位置をアスペクト比を保ったまま [-1, 1] の範囲にマップする
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);

    vec3 color = render(uv);
    color = exposureToneMapping(2.0, color);
    color = linear2srgb(color);
    fragColor = vec4(color, 1.0);
}
