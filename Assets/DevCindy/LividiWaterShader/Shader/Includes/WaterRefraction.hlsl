#ifndef LIVIDI_WATER_REFRACTION_INCLUDED
#define LIVIDI_WATER_REFRACTION_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
#include "WaterDepth.hlsl"
#include "WaterSpace.hlsl"

struct WaterRefractionSample
{
    float2 uv;
    float accepted;
    WaterDepthSample depthSample;
    half3 sceneColor;
};

float2 GetRefractedOffset(float3 mappedNormalWS, float3 geometricNormalWS)
{
    float3 normalDeltaWS = mappedNormalWS - geometricNormalWS;
    // normalDeltaWS = mappedNormalWS;
    float2 normalDeltaVS  = TransformWorldToViewNormal(normalDeltaWS, false).xy;
    // normalDeltaVS = normalDeltaWS.xy;
    normalDeltaVS.x *= _ScreenParams.y / _ScreenParams.x;
    
    return normalDeltaVS.xy * _RefractionStrength_Base;
}

half3 Refraction(float2 screenUV, float3 mappedNormalWS, float3 geometricNormalWS)
{
    float2 distOffset = GetRefractedOffset(mappedNormalWS, geometricNormalWS);
    float2 uvG = screenUV + distOffset;
    // float2 uvR = screenUV + distOffset * (1.0 + _ChromaticAberration); // 红光偏折多
    // float2 uvB = screenUV + distOffset * (1.0 - _ChromaticAberration); // 蓝光偏折少

    // 采样三次重组颜色
    // half r = SampleSceneColor(uvR).r;
    // half g = SampleSceneColor(uvG).g;
    // half b = SampleSceneColor(uvB).b;
    // half3 refrCol = half3(r, g, b);
    // return refrCol;
    return 0;
}

WaterRefractionSample ResolveRefractionUV(float2 screenUV, float3 mappedNormalWS, WaterSurfaceContext ctx, WaterDepthSample originalWaterDepth)
{
    WaterRefractionSample res = (WaterRefractionSample)0;
    float distMask = CameraDistanceMask(originalWaterDepth.scenePositionWS, _RefractionFadeDistance, 5.).x;
    float nearShoreStrength = _RefractionStrength_Base;
    
    
    float2 distOffset = GetRefractedOffset(mappedNormalWS, ctx.geometricNormalWS);
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

#endif
