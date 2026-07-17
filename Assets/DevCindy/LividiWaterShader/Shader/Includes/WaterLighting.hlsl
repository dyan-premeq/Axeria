#ifndef LIVIDI_WATER_LIGHTING_INCLUDED
#define LIVIDI_WATER_LIGHTING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

half3 LightingSpecluar(float3 L, float3 N, float3 V, float smoothness)
{
    float3 H = SafeNormalize(float3(L) + float3(V));
    float NdotH = saturate(dot(N, H));
    return pow(NdotH, smoothness);
}

// The water color is currently stylized and unlit. Apply only the main-light
// difference introduced by the normal map so a flat normal preserves it.
half3 ApplyWaterNormalLighting(
    half3 baseColor,
    half3 geometricNormalWS,
    half3 mappedNormalWS
)
{
    Light mainLight = GetMainLight();

    half flatNdotL = saturate(dot(geometricNormalWS, mainLight.direction));
    half mappedNdotL = saturate(dot(mappedNormalWS, mainLight.direction));
    half lightIntensity = saturate(max(
        mainLight.color.r,
        max(mainLight.color.g, mainLight.color.b)
    ) * mainLight.distanceAttenuation);

    half normalLighting = max(
        0.0h,
        1.0h + (mappedNdotL - flatNdotL) * lightIntensity
    );

    return baseColor * normalLighting;
}



#endif
