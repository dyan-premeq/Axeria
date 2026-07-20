#ifndef LIVIDI_WATER_SURFACE_INCLUDED
#define LIVIDI_WATER_SURFACE_INCLUDED

#include "WaterSpace.hlsl"

float3 GerstnerWave(float3 position, float steepness, float wavelength, float speed, float direction, inout float3 tangent, inout float3 binormal)
{
    direction = direction * 2 - 1;
    float2 waveDir = float2(cos(PI * direction), sin(PI * direction));
    wavelength = max(wavelength, 0.001);
    float k = 2 * PI / wavelength;
    // float g = 9.8;
    // Stylized 相速度交给 artist 吧。
    // float c = sqrt(g * wavelength / (2 * PI));

    
    float A = steepness / k;
    float f = k * (dot(waveDir.xy, position.xz) - speed * _Time.y );
    float sinf = sin(f);
    float cosf = cos(f);
    tangent += float3(
        -waveDir.x * waveDir.x * (steepness * sinf),
        waveDir.x * (steepness * cosf),
        -waveDir.x * waveDir.y * (steepness * sinf)
    );
    binormal += float3(
        -waveDir.x * waveDir.y * (steepness * sinf),
        waveDir.y * (steepness * cosf),
        -waveDir.y * waveDir.y * (steepness * sinf)
    );
    return float3(
        waveDir.x * A * cosf,
        A * sinf,
        waveDir.y * A * cosf
    );
}


void GerstnerWaves_float(float3 position, float steepness, float wavelength, float speed, float4 directions, out float3 Offset, out float3 normal)
{
    Offset = 0;
    float3 tangent = float3(1, 0, 0);
    float3 binormal = float3(0, 0, 1);

    Offset += GerstnerWave(position, steepness, wavelength, speed, directions.x, tangent, binormal);
    Offset += GerstnerWave(position, steepness, wavelength, speed, directions.y, tangent, binormal);
    Offset += GerstnerWave(position, steepness, wavelength, speed, directions.z, tangent, binormal);
    Offset += GerstnerWave(position, steepness, wavelength, speed, directions.w, tangent, binormal);

    normal = normalize(cross(binormal, tangent));
    //TBN = transpose(float3x3(tangent, binormal, normal));
}

float3 SamplePlanarWaterNormalTS(float2 uv, float scaling, float2 panningSpeed)
{
    // The returned tangent-space normal is relative to the planar mapping
    // basis, not the mesh UV0 tangent basis.
    float2 normalUV = UVPanner(
        uv,
        _WaterNormalTiling.xy,
        scaling,
        panningSpeed
    );

    half4 packedNormal = SAMPLE_TEXTURE2D(
        _WaterSurfaceNormalMap,
        sampler_WaterSurfaceNormalMap,
        normalUV
    );

    return UnpackNormal(packedNormal);
}

float3 ApplyNormalStrengthTS(float3 normalTS, float strength)
{
    normalTS = normalize(normalTS);

    normalTS.xy *= strength;
    normalTS.z = lerp(1.0, normalTS.z, strength);

    return SafeNormalize(normalTS);
}

float3 SampleBlendedPlanarWaterNormalTS(float2 uv)
{
    float ratio = lerp(0.1, 1.0, saturate(_WaterNormalScalingRatio));
    float angleA = PI / 6.;
    float2 dirA = float2(cos(angleA), sin(angleA));
    float2 dirB = float2(cos(angleA*4.), sin(angleA*4.));

    float3 normalA = SamplePlanarWaterNormalTS(uv, ratio * _WaterNormalScaling, dirA * ratio * _WaterNormalSpeed);
    float3 normalB = SamplePlanarWaterNormalTS(uv, _WaterNormalScaling, dirB * _WaterNormalSpeed);
    return BlendNormal(normalA, normalB);
    
    // float3 normalA = UnpackNormal(SAMPLE_TEXTURE2D(_WaterSurfaceNormalMap, sampler_WaterSurfaceNormalMap, uvA));
    // float3 normalB = UnpackNormal(SAMPLE_TEXTURE2D(_WaterSurfaceNormalMap, sampler_WaterSurfaceNormalMap, uvB));
    //
    // float3 normalTS = BlendNormal(normalA, normalB);
    // return ApplyNormalStrengthTS(normalTS,_WaterNormalStrength);
}

struct WaterNormalSample
{
    float3 normalWS;
    float3 normalWS_Unscaled;
};

// float3 ApplyNormalStrengthTS(float3 normalTS, float strength)
// {
//     normalTS.xy *= max(strength, 0.0);
//     return normalTS;
// }

WaterNormalSample GetSamplePlanarWaterNormalWS(WaterPlanarMapping mapping)
{
    WaterNormalSample res = (WaterNormalSample)0;
    float3 unscaledNormalTS = SampleBlendedPlanarWaterNormalTS(mapping.uv);
    float3 scaledNormalTS = ApplyNormalStrengthTS(unscaledNormalTS, _WaterNormalStrength);
    
    res.normalWS = ResolvePlanarWaterNormalWS(scaledNormalTS, mapping);
    res.normalWS_Unscaled = ResolvePlanarWaterNormalWS(unscaledNormalTS, mapping);
    return res;
}

float3 SamplePlanarWaterNormalWS(WaterPlanarMapping mapping)
{
    float3 normalTS = SampleBlendedPlanarWaterNormalTS(mapping.uv);
    return ResolvePlanarWaterNormalWS(normalTS, mapping);
}

WaterNormalSample GetSampleWaterNormalWS(WaterSurfaceContext context)
{
    // Public normal-mapping boundary. A future planet path should dispatch
    // here and return its own fully resolved world-space normal.
    return GetSamplePlanarWaterNormalWS(context.planarMapping);
}

float3 SampleWaterNormalWS(WaterSurfaceContext context)
{
    // Public normal-mapping boundary. A future planet path should dispatch
    // here and return its own fully resolved world-space normal.
    return SamplePlanarWaterNormalWS(context.planarMapping);
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
    // lines
    float phase = (shallowFactor - _ShoreLine_Speed * _Time.y) * _ShoreLine_Amount;
    float phaseReverse = frac(-phase);
    float phaseForward = frac(phase);
    
    
    
    
    // float 
    
    // direction control 
    
    // dissolve mask
    
    // roundness
    
    // near shore fade
    
    // trail fade
    
    // center mask
    
    
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
