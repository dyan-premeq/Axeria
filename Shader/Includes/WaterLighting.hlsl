#ifndef LIVIDI_WATER_LIGHTING_INCLUDED
#define LIVIDI_WATER_LIGHTING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

half3 TransformWaterNormalToWorld(
    half3 normalTS,
    half3 tangentWS,
    half3 bitangentWS,
    half3 normalWS
)
{
    half3x3 TBNWS = half3x3(
        tangentWS,
        bitangentWS,
        normalWS
    );

    return NormalizeNormalPerPixel(
        TransformTangentToWorld(normalTS, TBNWS)
    );
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
