#ifndef LIVIDI_WATER_DEPTH_INCLUDED
#define LIVIDI_WATER_DEPTH_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "WaterCommon.hlsl"

// Returns 1 at the shoreline and approaches 0 in deep water, matching the
// original shader's deep-to-shallow color interpolation convention.
float3 GetWaterShallowFactor(
    Varyings input,
    float depthFadeDistance,
    float2 screenUV
)
{
    float rawSceneDepth = SampleSceneDepth(screenUV);

#if UNITY_REVERSED_Z
    if (rawSceneDepth <= 0.00001)
    {
        return 0.0;
    }

    float deviceDepth = rawSceneDepth;
#else
    if (rawSceneDepth >= 0.99999)
    {
        return 0.0;
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
    float3 waterUpWS = ResolveWaterReferenceUpWS(input.positionWS, input.objectUpWS);
    
    float worldDepth = max(
        0.0,
        dot(input.positionWS - scenePositionWS, waterUpWS)
    );
    float worldShallowFactor = saturate(
        exp(-worldDepth / max(depthFadeDistance, 0.0001))
    );

    // Preserve the original camera-space fallback and its depth scale.
    float sceneEyeDepth = -TransformWorldToView(scenePositionWS).z;
    float surfaceEyeDepth = -TransformWorldToView(input.positionWS).z;
    float cameraDepth = max(0.0, sceneEyeDepth - surfaceEyeDepth);
    float cameraShallowFactor = 1.0 - saturate(
        cameraDepth / max(depthFadeDistance * 10.0, 0.0001)
    );

    return (float3)(cameraShallowFactor, worldShallowFactor, lerp(
        cameraShallowFactor,
        worldShallowFactor,
        saturate(_WorldSpaceDepth)
    ));
}

float3 GetWaterShallowFactor(Varyings input, float depthFadeDistance)
{
    return GetWaterShallowFactor(
        input,
        depthFadeDistance,
        GetNormalizedScreenSpaceUV(input.positionCS)
    );
}

float3 GetWaterShallowFactor(Varyings input)
{
    return GetWaterShallowFactor(input, _DepthFadeDistance);
}

#endif
