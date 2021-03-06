const float PI = 3.14159265358979323846;

vec3 linear2srgb(vec3 c) {
    return mix(
        12.92 * c,
        1.055 * pow(c, vec3(1.0/2.4)) - 0.055,
        step(vec3(0.0031308), c)
    );
}

// axis を軸として p を theta だけ回転させた座標を返す。
vec3 rotate(vec3 axis, float theta, vec3 p) {
    // https://en.wikipedia.org/wiki/Rodrigues%27_rotation_formula
    axis = normalize(axis);
    float c = cos(theta), s = sin(theta);
    return p * c + cross(axis, p) * s + axis * dot(axis, p) * (1.0 - c);
}

float sdfTorus(float majorRadius, float minorRadius, vec3 p) {
    vec2 r = vec2(length(p.xy) - majorRadius, p.z);
    return length(r) - minorRadius;
}

float sdfFloor(vec3 normal, float offset, vec3 p) {
    return dot(p, normal) - offset;
}

vec3 repetitionX(float interval, vec3 p) {
    p.x = mod(p.x + 0.5 * interval, interval) - 0.5 * interval;
    return p;
}

vec3 repetitionZ(float interval, vec3 p) {
    p.z = mod(p.z + 0.5 * interval, interval) - 0.5 * interval;
    return p;
}

float sdfWedgeX(float y, vec3 p) {
    return abs(p.x) - p.y + y;
}

float sdfWedgeZ(float y, vec3 p) {
    return abs(p.z) - p.y + y;
}

float sdfTiledFloor(vec3 p) {
    float d1 = sdfFloor(vec3(0.0, 1.0, 0.0), -2.0, p);
    float d2 = sdfWedgeX(-2.02, repetitionX(1.0, p));
    float d3 = sdfWedgeZ(-2.02, repetitionZ(1.0, p));
    return max(max(d1, -d2), -d3);
}

float sdf(vec3 p, out float outMaterial) {
    float minDist = sdfTiledFloor(p);
    outMaterial = 1.0;

    float dTorus = sdfTorus(1.0, 0.35, rotate(vec3(1.0, 0.6, 0.1), iTime, p));
    if (dTorus < minDist) {
        minDist = dTorus;
        outMaterial = 2.0;
    }

    return minDist;
}

vec3 normalAt(vec3 p) {
    // https://iquilezles.org/www/articles/normalsSDF/normalsSDF.htm
    const float h = 0.0001; // replace by an appropriate value
    const vec2 k = vec2(1, -1);
    float unused;
    return normalize(
        k.xyy * sdf(p + k.xyy*h, unused) +
        k.yyx * sdf(p + k.yyx*h, unused) +
        k.yxy * sdf(p + k.yxy*h, unused) +
        k.xxx * sdf(p + k.xxx*h, unused)
    );
}

vec3 getAlbedo(vec3 pos, float material) {
    if (material < 1.5) {
        // floor
        float a = mod(floor(pos.x) - floor(pos.z), 2.0);
        return mix(vec3(0.5), vec3(1.0), a);
    } else {
        // torus
        return vec3(0.9, 0.6, 0.5);
    }
}

vec3 brdf(vec3 pos, vec3 lightDir, vec3 viewDir, vec3 normal, float material) {
    vec3 ret = vec3(0.0);

    // Lambert
    vec3 albedo = getAlbedo(pos, material);
    ret += albedo / PI;

    // Blinn-Phong
    float reflectance = 0.5;
    float power = 30.0;
    float z = (power + 2.0) / (2.0 * PI);
    vec3 h = normalize(lightDir + viewDir);
    float dotNH = dot(normal, h);
    ret += z * reflectance * pow(max(dotNH, 0.0), power);

    return ret;
}

float calculateShadow(vec3 origin, vec3 lightDir) {
    const float lightVisibilityOnShadow = 0.1;
    float c = 0.001;
    float r = 1.0;
    for (int i = 0; i < 50; i++) {
        float unused;
        float dist = sdf(origin + lightDir * c, unused);
        if (dist < 0.001) {
            return lightVisibilityOnShadow;
        }
        r = min(r, dist / c);
        c += dist;
    }
    return mix(1.0, lightVisibilityOnShadow, exp(-90.0*r*r));
}

// 平行光源の反射光の放射輝度を返す
vec3 directionalLightReflectedRadiance(vec3 pos, vec3 normal, vec3 viewDir, float material) {
    // 平行光源の放射照度 [W/m^2]
    const vec3 directionalLightIrradiance = vec3(2.0);
    // pos から見た光源の方向
    const vec3 lightDir = normalize(vec3(0.7, 1.0, -0.5));

    float dotLN = dot(lightDir, normal);
    float lightVisibility = calculateShadow(pos + normal * 0.001, lightDir);
    vec3 incidentLight = directionalLightIrradiance * lightVisibility * max(dotLN, 0.0);

    return brdf(pos, lightDir, viewDir, normal, material) * incidentLight;
}

// 環境光の反射光の放射輝度を返す
vec3 ambientLightReflectedRadiance(vec3 pos, vec3 normal, vec3 viewDir, float material) {
    // 環境光の放射輝度 [W/sr/m^2]
    const vec3 ambientLightIrradiance = vec3(0.05);
    // Lambert 面で近似する
    return getAlbedo(pos, material) * ambientLightIrradiance;
}

// サーフィス上の点から視線方向へ反射される光の放射輝度を求める
vec3 renderSurface(vec3 pos, vec3 normal, vec3 viewDir, float material) {
    return directionalLightReflectedRadiance(pos, normal, viewDir, material)
         + ambientLightReflectedRadiance(pos, normal, viewDir, material);
}

vec3 renderFog(vec3 baseColor, vec3 fogColor, float dist) {
    const float k = 0.1;
    return mix(fogColor, baseColor, exp(-k*dist));
}

vec3 castRay(vec3 rayDir, vec3 cameraPos) {
    float rayLen = 0.0;
    float dist;
    float material;
    for (int i = 0; i < 100; i++) {
        vec3 rayPos = rayDir * rayLen + cameraPos;
        dist = sdf(rayPos, material);
        rayLen += dist;
    }

    if (abs(dist) < 0.001) {
        vec3 rayPos = rayDir * rayLen + cameraPos;
        vec3 normal = normalAt(rayPos);
        vec3 color = renderSurface(rayPos, normal, -rayDir, material);
        return renderFog(color, vec3(0.02), rayLen);
    } else {
        return vec3(0.02);
    }
}

mat3 cameraLookAt(vec3 cameraPos, vec3 targetPos, vec3 up) {
    vec3 cameraDir = normalize(targetPos - cameraPos);
    vec3 cameraRight = cross(cameraDir, normalize(up));
    vec3 cameraUp = cross(cameraRight, cameraDir);
    return mat3(cameraRight, cameraUp, cameraDir);
}

vec3 render(vec2 uv) {
    // camera
    vec3 cameraPos = vec3(0.0, 3.0, 5.0);
    mat3 cameraMatrix = cameraLookAt(cameraPos, vec3(0.0), vec3(0.0, 1.0, 0.0));
    float fov = radians(30.0);

    // ray
    vec3 rayDir = normalize(cameraMatrix * vec3(uv.xy * tan(fov), 1.0));

    return castRay(rayDir, cameraPos);
}

vec3 exposureToneMapping(float exposure, vec3 hdrColor) {
    return vec3(1.0) - exp(-hdrColor * exposure);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // 画面上の位置をアスペクト比を保ったまま [-1, 1] の範囲にマップする
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);

    vec3 color = render(uv);
    color = exposureToneMapping(1.0, color);
    color = linear2srgb(color);
    fragColor = vec4(color, 1.0);
}
