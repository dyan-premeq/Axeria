#ifndef LIVIDI_WATER_COMMON_INCLUDED
#define LIVIDI_WATER_COMMON_INCLUDED
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

#include "WaterInput.hlsl"

// HSV 颜色混合
half3 RGBToHSV(half3 In)
{
    half4 K = half4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    half4 P = lerp(half4(In.bg, K.wz), half4(In.gb, K.xy), step(In.b, In.g));
    half4 Q = lerp(half4(P.xyw, In.r), half4(In.r, P.yzx), step(P.x, In.r));
    half D = Q.x - min(Q.w, Q.y);
    half E = 1e-10;
    return half3(abs(Q.z + (Q.w - Q.y)/(6.0 * D + E)), D / (Q.x + E), Q.x);
}

half3 HSVToRGB(half3 In)
{
    half4 K = half4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    half3 P = abs(frac(In.xxx + K.xyz) * 6.0 - K.www);
    return In.z * lerp(K.xxx, saturate(P - K.xxx), In.y);
}

void HSVLerp_half(half4 A, half4 B, half T, out half4 Out)
{
    A.xyz = RGBToHSV(A.xyz);
    B.xyz = RGBToHSV(B.xyz);

    half t = T; // used to lerp alpha, needs to remain unchanged

    half hue;
    half d = B.x - A.x; // hue difference

    if(A.x > B.x)
    {
        half temp = B.x;
        B.x = A.x;
        A.x = temp;

        d = -d;
        T = 1-T;
    }

    if(d > 0.5)
    {
        A.x = A.x + 1;
        hue = (A.x + T * (B.x - A.x)) % 1;
    }

    if(d <= 0.5) hue = A.x + T * d;

    half sat = A.y + T * (B.y - A.y);
    half val = A.z + T * (B.z - A.z);
    half alpha = A.w + t * (B.w - A.w);

    half3 rgb = HSVToRGB(half3(hue,sat,val));

    Out = half4(rgb, alpha);
}


// 通过球体获取 up / worlduv ...
float3 GetPlanetUpWS(float3 positionWS)
{
    float3 radial = positionWS - _PlanetCenter.xyz;
    float radialLengthSq = dot(radial, radial);
    return radialLengthSq > 1e-8
        ? radial * rsqrt(radialLengthSq)
        : float3(0.0, 1.0, 0.0);
}

float3 GetWaterUpWS(float3 positionWS, float3 objectUpWS)
{
    float objectUpLengthSq = dot(objectUpWS, objectUpWS);
    float3 normalizedObjectUpWS = objectUpLengthSq > 1e-8
        ? objectUpWS * rsqrt(objectUpLengthSq)
        : float3(0.0, 1.0, 0.0);

    float usePlanetCenterUp = step(0.5, _UsePlanetCenterUp);
    return lerp(
        normalizedObjectUpWS,
        GetPlanetUpWS(positionWS),
        usePlanetCenterUp
    );
}


// UV 计算 helper func
float2 UVPanner(float2 uv, float2 uvTile, float uvScale, float2 panningSpeed)
{
    return uv * (uvTile * uvScale) + panningSpeed * _Time.y * 0.1;
}

float2 UVPannerDistorted(float2 uv, float2 uvTile, float uvScale, float2 panningSpeed, float distortionStrength, float2 distortionValue)
{
    float2 pannedUV = UVPanner(uv, uvTile, uvScale, panningSpeed);
    return pannedUV + distortionValue * (distortionStrength * 0.1);
}

// 使用一个不受 scaling / tiling 影响的偏移值加在 uv 上面
float2 UVPanner(float2 uv, float2 uvTile, float uvScale, float2 panningSpeed, float2 uvOffset)
{
    return UVPannerDistorted(uv, uvTile, uvScale, panningSpeed, 10, uvOffset);
}


float SmoothMask(float edge, float smoothness, float t)
{
    return smoothstep(edge, edge + smoothness, t);
}
float DoubleSmoothMask(float edge, float smoothness, float t)
{
    return smoothstep(edge - smoothness * .5, edge + smoothness * .5, t);   
}

float4 Overlay(float4 Base, float4 Overlay, float Blend)
{
    float4 A = lerp(Base, Overlay, Overlay.w);
    float4 B = lerp(Base, Base + Overlay, Overlay.w);
    return lerp(A, B, Blend);
}



#endif
