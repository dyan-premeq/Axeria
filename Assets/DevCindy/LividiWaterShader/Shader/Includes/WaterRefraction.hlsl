#ifndef LIVIDI_WATER_REFRACTION_INCLUDED
#define LIVIDI_WATER_REFRACTION_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Hashes.hlsl"
#include "WaterDepth.hlsl"
#include "WaterSpace.hlsl"
// Refraction

struct WaterRefractionSample
{
    float2 uv;
    float accepted;
    WaterDepthSample depthSample;
    half3 sceneColor;
};

float2 GetRefractedOffset(float3 mappedNormalWS, float3 geometricNormalWS, float refractionStrength)
{
    float3 normalDeltaWS = mappedNormalWS - geometricNormalWS;
    // normalDeltaWS = mappedNormalWS;
    float2 normalDeltaVS  = TransformWorldToViewNormal(normalDeltaWS, false).xy;
    // normalDeltaVS = normalDeltaWS.xy;
    normalDeltaVS.x *= _ScreenParams.y / _ScreenParams.x;
    
    return normalDeltaVS.xy * refractionStrength;
}

// half3 Refraction(float2 screenUV, float3 mappedNormalWS, float3 geometricNormalWS)
// {
    // float2 distOffset = GetRefractedOffset(mappedNormalWS, geometricNormalWS);
    // float2 uvG = screenUV + distOffset;
    // float2 uvR = screenUV + distOffset * (1.0 + _ChromaticAberration); // 红光偏折多
    // float2 uvB = screenUV + distOffset * (1.0 - _ChromaticAberration); // 蓝光偏折少

    // 采样三次重组颜色
    // half r = SampleSceneColor(uvR).r;
    // half g = SampleSceneColor(uvG).g;
    // half b = SampleSceneColor(uvB).b;
    // half3 refrCol = half3(r, g, b);
    // return refrCol;
    // return 0;
// }

WaterRefractionSample ResolveRefractionUV(float2 screenUV, float3 mappedNormalWS, WaterSurfaceContext ctx, WaterDepthSample originalWaterDepth, float shoreFade)
{
    WaterRefractionSample res = (WaterRefractionSample)0;
    float distMask = CameraDistanceMask(ctx.positionWS, max(_RefractionFadeDistance, 0.001), max(_RefractionFadeRange, 0.0001)).x;
    
    float strength = lerp(_RefractionStrength_Base, _RefractionStrength_Far, distMask);
    strength *= shoreFade;
    
    float2 distOffset = GetRefractedOffset(mappedNormalWS, ctx.geometricNormalWS, strength);
    float2 RefractedUV = screenUV + distOffset;
    // float refractedSceneRawDepth = SampleSceneDepth(screenUV);
    WaterDepthSample refractedSceneDepthSample = SampleWaterDepth(ctx.positionWS, ctx.referenceUpWS, _DepthFadeDistance, RefractedUV);
    
    bool behindSurface = refractedSceneDepthSample.cameraDepth > _RefractionDepthBias;
    bool belowWater = refractedSceneDepthSample.signedWaterDepth > _RefractionDepthBias;
    
    // float cameraPosition = _WorldSpaceCameraPos;
    // float cameraDist = distance(cameraPosition, refractedSceneDepthSample.scenePositionWS);
    // float cameraDistGradient = saturate((cameraDist - _RefractionFadeDistance) / 5.);
    
    res.accepted = refractedSceneDepthSample.valid && behindSurface && belowWater;
    res.uv = res.accepted ? RefractedUV : screenUV;
    res.depthSample = originalWaterDepth;
    if (res.accepted)
    {
        res.depthSample = refractedSceneDepthSample;
    }
    res.sceneColor = SampleSceneColor(res.uv);
    return res;
}   

// Caustics

float3 SampleCausticRGB(float2 uv, float2 splitOffset)
{
    float r = SAMPLE_TEXTURE2D(
        _CausticMap, sampler_CausticMap,
        uv - splitOffset * 0.65
    ).r;

    float g = SAMPLE_TEXTURE2D(
        _CausticMap, sampler_CausticMap,
        uv
    ).r;

    float b = SAMPLE_TEXTURE2D(
        _CausticMap, sampler_CausticMap,
        uv + splitOffset
    ).r;

    return float3(r, g, b);
}


float3 EvaluateWaterCaustics(WaterDepthSample depthSample, float3 waterPositionWS)
{
    if (depthSample.valid < 0.5 ||
    depthSample.signedWaterDepth <= 0.0)
    {
        return 0.0h;
    }

    float2 uvA = UVPanner(depthSample.scenePositionWS.xz, float2(1,1), 1., _CausticsSpeedA.xy);
    float2 uvB = UVPanner(depthSample.scenePositionWS.xz, float2(1,1), 1., _CausticsSpeedB.xy) + float2(0.37, 0.71);
    float _CausticRGBSplit = 0.01;
    float2 splitOffset = float2(_CausticRGBSplit, _CausticRGBSplit);
    
    float3 causticA = SampleCausticRGB(uvA, splitOffset);
    // float3 causticB = SampleCausticRGB(uvB, splitOffset);
    float3 causticB = SAMPLE_TEXTURE2D(_CausticMap, sampler_CausticMap, uvB).r;
    
    float3 causticRGB = min(causticA, causticB);
    
    causticRGB = pow(saturate(causticRGB), _CausticSharpness);
    
    float distMask = CameraDistanceMask(waterPositionWS, _CausticsStart, _CausticsFadingSmoothness).y;
    
    return causticRGB * distMask;
}



#endif
