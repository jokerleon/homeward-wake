// Kept in sync with coast() in harbor.gd. Fictional shoreline, measured in metres.
float coast(float x) {
    return 3.8 + sin(x * 0.18) * 1.9 + sin(x * 0.47) * 0.45
        + 4.5 * exp(-pow((x + 13.0) / 5.3, 2.0));
}
float segment_dist(vec2 p, vec2 a, vec2 b) {
    vec2 v = b - a;
    return length(p - a - v * clamp(dot(p-a,v)/dot(v,v),0.0,1.0));
}
