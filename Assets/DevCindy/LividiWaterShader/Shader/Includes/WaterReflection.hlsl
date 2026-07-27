#ifndef  LIVIDI_WATER_REFLECTION_INCLUDED
#define  LIVIDI_WATER_REFLECTION_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
#include "WaterRefraction.hlsl"
#pragma shader_feature_local_fragment _ _USE_SCHLICK

float4 SamplePlanarReflection(float2 screenUV, float3 mappedNormalWS, float3 geometricNormalWS)
{
    // 我直接旋转获得反射相机，没有镜像 (1,1,1) -> (-1,-1,1)，所以 x 轴需要采样时镜像回去
    float2 uv = float2(1-screenUV.x, screenUV.y);
    // uv = screenUV;
    float2 offset = GetRefractedOffset(mappedNormalWS, geometricNormalWS) * _ReflectionDistortionStrength;
    float2 planarUV = float2(uv.x - offset.x, uv.y + offset.y);
    float mipLevel = PerceptualRoughnessToMipmapLevel(saturate(_ReflectionRoughness));
    float4 planarRGB = SAMPLE_TEXTURE2D_LOD(
        _PlanarReflectionTexture,
        sampler_PlanarReflectionTexture,
        planarUV,
        mipLevel);
    return planarRGB;
}

half3 SampleReflectionProbe(float3 viewDirWS, float3 waterSurfacePosWS, float3 geometricNormalWS, float2 screenUV, float2 offset)
{
    float3 V = normalize(viewDirWS);
    float3 N = normalize(geometricNormalWS);
    float3 R = reflect(-V, N); //waterNormalSampleWS.normalWS);
    // return half4(R * 0.5 + 0.5, 1.0);
    // _ReflectionDistortionStrength = 0.5;
    half3 probeDebug = GlossyEnvironmentReflection(R, waterSurfacePosWS, _ReflectionRoughness, 1, screenUV + offset * 10.0);
    return probeDebug;
}

// N 最好接受 geometricNormalWS
float Fresnel(float3 N, float3 V)
{
    float NoV = saturate(dot(normalize(N), normalize(V)));
    #if defined(_USE_SCHLICK)

        float x = 1 - NoV;
        float x2 = x * x;
        float x5 = x2 * x2 * x;

        float fresnel = _ReflectionF0 + (1.0 - _ReflectionF0) * x5;
        return saturate(fresnel);
    #else
        float F = pow((1.0 - NoV), _ReflectionFresnel);
        return F * _ReflectionStrength;
    #endif

}

half4 ResolveReflectionColor(float2 screenUV, float3 viewDirWS, float3 mappedNormalWS, WaterSurfaceContext waterSurface)
{
    half4 reflectionRGB = 0;
    float4 planarRGB = SamplePlanarReflection(screenUV, mappedNormalWS, waterSurface.geometricNormalWS);
    // float2 offset = GetRefractedOffset(mappedNormalWS, waterSurface.geometricNormalWS);
    half3 probeRGB = SampleReflectionProbe(viewDirWS, waterSurface.positionWS, waterSurface.geometricNormalWS, screenUV, 0);
    // return probeRGB;
    float fresnel = Fresnel(waterSurface.geometricNormalWS, viewDirWS);
    reflectionRGB.rgb = lerp(probeRGB, planarRGB.rgb, _PlanarReflectionBlend);
    return half4(reflectionRGB.rgb, fresnel);
}

#endif
