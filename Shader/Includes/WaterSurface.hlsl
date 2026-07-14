#ifndef LIVIDI_WATER_SURFACE_INCLUDED
#define LIVIDI_WATER_SURFACE_INCLUDED

#include "WaterCommon.hlsl"

half3 SampleWaterNormalTS(float2 uv)
{
    // UV0 keeps tangent-space sampling aligned with the mesh tangent basis.
    float2 normalUV = UVPanner(
        uv,
        _WaterNormalTiling.xy,
        1.0,
        float2(_WaterNormalSpeed, _WaterNormalSpeed)
    );

    half4 packedNormal = SAMPLE_TEXTURE2D(
        _WaterSurfaceNormalMap,
        sampler_WaterSurfaceNormalMap,
        normalUV
    );

    return UnpackNormalScale(packedNormal, _WaterNormalStrength);
}

float3 NormalBlend(float2 uv)
{
    float ratio = lerp(0.1, 1.0, _WaterNormalScalingRatio);
    float2 uvA = UVPanner(uv, _WaterNormalTiling.xy, 0.5 * _WaterNormalScaling, _WaterNormalSpeed);
    float2 uvB = UVPanner(uv, _WaterNormalTiling.xy, _WaterNormalScaling / ratio, _WaterNormalSpeed  * (-.5));
    
    float3 normalA = UnpackNormal(SAMPLE_TEXTURE2D(_WaterSurfaceNormalMap, sampler_WaterSurfaceNormalMap, uvA));
    float3 normalB = UnpackNormal(SAMPLE_TEXTURE2D(_WaterSurfaceNormalMap, sampler_WaterSurfaceNormalMap, uvB));
    
    float3 resultNormal = BlendNormal(normalA, normalB);
    return resultNormal;
}

float2 SampleSurfaceDistortion(float2 worldUV)
{
    float2 distortionUV = UVPanner(
        worldUV,
        float2(_SurfaceDistortion_MaskScale, _SurfaceDistortion_MaskScale),
        1.0,
        _SurfaceDistortion_MaskPan.xy
    );

    float distortion = SAMPLE_TEXTURE2D(
        _SurfaceDistortion_Map,
        sampler_SurfaceDistortion_Map,
        distortionUV
    ).r;
    
    float centeredDistortion = distortion * 2.0 - 1.0;
    return float2(centeredDistortion, centeredDistortion);
}

float SurfaceFoamMask(float2 uvFoam, float2 surfaceDistortion)
{   
    float2 surfaceFoamUV = UVPannerDistorted(
        uvFoam,
        _SurfaceFoam_MaskTiling.xy,
        _SurfaceFoam_MaskScaling,
        _SurfaceFoam_MaskPan.xy,
        _SurfaceFoam_Distortion,
        surfaceDistortion
    );
    
    float foamTexel = SAMPLE_TEXTURE2D(
        _SurfaceFoamMask,
        sampler_SurfaceFoamMask,
        surfaceFoamUV).r;
    
    float surfaceFoamMask = SmoothMask(_SurfaceFoam_Edge, _SurfaceFoam_EdgeSmooth, foamTexel);
    surfaceFoamMask = lerp(surfaceFoamMask, 1.0 - surfaceFoamMask, step(0.5, _SurfaceFoam_MaskInverse));
    return surfaceFoamMask;
}

float IntersectionFoamMask(float2 uvFoam, float2 surfaceDistortion, float shallowFactor)
{
    float2 intersectionFoamUV = UVPannerDistorted(
        uvFoam,
        _IntersecFoam_MaskTiling.xy,
        _IntersecFoam_MaskScaling,
        _IntersecFoam_MaskPan.xy,
        _IntersecFoam_Distortion,
        surfaceDistortion
    );
    
    // Dissolve mask
    float noise = SAMPLE_TEXTURE2D(
        _IntersecFoamMask,
        sampler_IntersecFoamMask,
        intersectionFoamUV
    ).r;
    noise = lerp(noise, 1.0 - noise, step(0.5, _IntersecFoam_MaskInverse));    
    float dissolveGradient = lerp(0.1, 1.0, _IntersecFoam_GradientDissolve); //remap

    float dissolveScale = lerp(2.5, 1.0, dissolveGradient);
    float noiseGate = 1.0 - noise * _IntersecFoam_Dissolve * dissolveScale;

    // Intersection
    float widthScale = lerp(0.7, 1.0, dissolveGradient);
    float edge = 1.0 - _IntersecFoam_Width * widthScale;
    half intersectionDissolveMask = SmoothMask(edge, dissolveGradient, shallowFactor);
    half intersectionDepthMask = SmoothMask(edge, 1.0, shallowFactor);
    float combined = intersectionDissolveMask * (intersectionDissolveMask + noiseGate);
    float finalFoamMask = SmoothMask(0.1, _IntersecFoam_Smoothness, combined);
    finalFoamMask = saturate(lerp(
        finalFoamMask,
        finalFoamMask * intersectionDepthMask,
        _IntersecFoam_EdgeFading
    ));

    return finalFoamMask;
}

float ShoreLineFoamMask(float2 uvFoam, float shallowFactor)
{
    return 0;
}

void BlendFoam(
    inout half3 baseRGB,
    inout half baseAlpha,
    half4 foamColor,
    half rawMask,
    half enabled,
    half preserveBaseAlpha)
{
    half coverage = saturate(rawMask) * saturate(enabled) * saturate(foamColor.a);
    
    baseRGB = lerp(baseRGB, foamColor.rgb, coverage); // RGB Blending
    baseAlpha += coverage * (1.0h - baseAlpha) * (1.0h - saturate(preserveBaseAlpha)); // Alpha Blending
}



#endif
