#ifndef LIVIDI_WATER_LIGHTING_INCLUDED
#define LIVIDI_WATER_LIGHTING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

float EvaluateWaterSpecularLobe(float3 L, float3 N, float3 V, float spread)
{
    L = SafeNormalize(L);
    N = SafeNormalize(N);
    V = SafeNormalize(V);
    float3 H = SafeNormalize(L+V);
    
    float smoothness = exp2((1 - spread) * 10.0 + 1.0);
    float lobe = pow(saturate(dot(N, H)), smoothness);
    lobe *= step(0.0, dot(N, L));
    
    return lobe;
}



half3 EvaluateMainWaterSpecular(float3 L, float3 N, float3 V, Light mainLight)
{
    // float3 H = SafeNormalize(float3(L) + float3(V));
    // float NdotH = saturate(dot(N, H));
    // return pow(NdotH, smoothness);
    
    float3 specularMask = EvaluateWaterSpecularLobe(L, N, V, _WaterSpecularSpread);
    float lowerEdge = 1 - _WaterSpecularSize;
    float upperEdge = lowerEdge + 0.15;
    float hardSpecular = smoothstep(lowerEdge, upperEdge, specularMask);
    specularMask = lerp(specularMask, hardSpecular, _WaterSpecularHardness);
    
    float3 stylizedSpecular = _WaterSpecularColor.rgb * specularMask;
    half attenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation;
    return stylizedSpecular * mainLight.color * attenuation;
}

// The water color is currently stylized and unlit. Apply only the main-light
// difference introduced by the normal map so a flat normal preserves it.
half3 ApplyWaterNormalLighting(
    half3 baseColor,            
    half3 geometricNormalWS,    // 几何法线
    half3 mappedNormalWS,        // 法线贴图扰动后的微观法线
    Light mainLight
)
{

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
