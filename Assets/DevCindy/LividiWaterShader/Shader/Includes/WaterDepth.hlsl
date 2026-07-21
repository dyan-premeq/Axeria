#ifndef LIVIDI_WATER_DEPTH_INCLUDED
#define LIVIDI_WATER_DEPTH_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "WaterCommon.hlsl"

struct WaterDepthSample
{
    float valid;
    float signedWaterDepth;
    float cameraDepth;
    float3 scenePositionWS; // 水底 scene 的世界位置
    float3 shallowFactor;
    // shallowFactor is 1 at the shoreline and approaches 0 in deep water, matching the
    // original shader's deep-to-shallow color interpolation convention.
};

WaterDepthSample SampleWaterDepth(
    float3 surfacePositionWS,   
    float3 referenceUpWS,
    float depthFadeDistance,
    float2 screenUV
)
{
    WaterDepthSample res = (WaterDepthSample)0;

    bool uvValid = all(screenUV >= 0.0) && all(screenUV <= 1.0);
    if (!uvValid)
    {
        return res;
    }
    
    float rawSceneDepth = SampleSceneDepth(screenUV);
    
#if UNITY_REVERSED_Z
    if (rawSceneDepth <= 0.00001)
    {
        return res;
    }

    float deviceDepth = rawSceneDepth;
#else
    if (rawSceneDepth >= 0.99999)
    {
        return res;
    }

    float deviceDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1.0, rawSceneDepth);
#endif

    float3 scenePositionWS = ComputeWorldSpacePosition(
        screenUV,
        deviceDepth,
        UNITY_MATRIX_I_VP
    );

    // Project the surface-to-scene separation onto either the planet radial
    // direction or this water object's own local-up direction.
    res.signedWaterDepth = dot(surfacePositionWS - scenePositionWS, referenceUpWS);
    float worldDepth = max(0.0, res.signedWaterDepth);
    
    float worldShallowFactor = saturate(
        exp(-worldDepth / max(depthFadeDistance, 0.0001))
    );

    // Preserve the original camera-space fallback and its depth scale.
    float sceneEyeDepth = -TransformWorldToView(scenePositionWS).z;
    float surfaceEyeDepth = -TransformWorldToView(surfacePositionWS).z;
    float cameraDepth = max(0.0, sceneEyeDepth - surfaceEyeDepth);
    float cameraShallowFactor = 1.0 - saturate(
        cameraDepth / max(depthFadeDistance * 10.0, 0.0001)
    );
    res.shallowFactor = float3(cameraShallowFactor, worldShallowFactor, lerp(
        cameraShallowFactor,
        worldShallowFactor,
        saturate(_WorldSpaceDepth)
    ));
    res.scenePositionWS = scenePositionWS;
    res.cameraDepth = cameraDepth;
    res.valid = 1;
    return res;
    // return (float3)(cameraShallowFactor, worldShallowFactor, lerp(
    //     cameraShallowFactor,
    //     worldShallowFactor,
    //     saturate(_WorldSpaceDepth)
    // ));
}

WaterDepthSample SampleWaterDepth(Varyings input, float3 waterUpWS, float depthFadeDistance)
{
    return SampleWaterDepth(
        input.positionWS,
        waterUpWS,
        depthFadeDistance,
        GetNormalizedScreenSpaceUV(input.positionCS)
    );
}

WaterDepthSample SampleWaterDepth(Varyings input, float3 waterUpWS)
{
    return SampleWaterDepth(input, waterUpWS, _DepthFadeDistance);
}

float ComputeShoreFade(
     WaterDepthSample geometryDepth,
     float enabled,
     float smoothness
 )
{
    float awayFromShore = max(0.0, geometryDepth.signedWaterDepth);
    // awayFromShore = saturate(1.0 - geometryDepth.shallowFactor.y);

    float fade = smoothstep(0.0, max(smoothness, 0.0001), awayFromShore);

    // 深度纹理无效时保持水面可见
    float applyFade = saturate(enabled) * geometryDepth.valid;
    return lerp(1.0, fade, applyFade);
}


#endif
