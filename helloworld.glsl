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

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Normalized pixel coordinations (from 0 to 1)
    vec2 uv = fragCoord / iResolution.xy;

    vec3 color = hsv2rgb(vec3(uv.x, uv.y, 1.0));

    // Output to screen
    fragColor = vec4(linear2srgb(color), 1.0);
}
