#ifndef LIVIDI_WATER_FORWARD_PASS_INCLUDED
#define LIVIDI_WATER_FORWARD_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "WaterDepth.hlsl"
#include "WaterSurface.hlsl"
#include "WaterLighting.hlsl"
#include "WaterRefraction.hlsl"

Varyings Vert(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    
    float3 basePositionWS = TransformObjectToWorld(input.positionOS.xyz);
    
    float3 finalPositionWS = basePositionWS;
    float3 finalNormalWS = TransformObjectToWorldNormal(input.normalOS);
    
    UNITY_BRANCH if (_EnableWave > 0.5)
    {
        float3 waveOffsetWS;
        float3 waveNormalWS;

        GerstnerWaves_float(
            basePositionWS,
            _GerstnerSteepness,
            _GerstnerWavelength,
            _GerstnerSpeed,
            _GerstnerDirection,
            waveOffsetWS,
            waveNormalWS
        );

        finalPositionWS += waveOffsetWS;
        finalNormalWS = waveNormalWS;
    }
    
    output.objectUpWS = TransformObjectToWorldNormal(float3(0.0, 1.0, 0.0));
    output.normalWS = finalNormalWS;
    output.positionWS = finalPositionWS;
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.uv = input.uv;
    
    return output;
}

half4 Frag(Varyings input) : SV_Target
{
    WaterSurfaceContext surfaceContext = BuildWaterSurfaceContext(input);

    float3 geometricNormalWS = surfaceContext.geometricNormalWS;
    float2 worldUV = surfaceContext.planarMapping.uv;
    float2 screenUV = GetNormalizedScreenSpaceUV(input.positionCS);
    
    // Depth base color
    WaterDepthSample geometryDepth = SampleWaterDepth(input, surfaceContext.referenceUpWS);
    
    float shoreFade = ComputeShoreFade(geometryDepth, _UseShoreFade, _ShoreFadeSmoothness);
    
    half4 waterBaseColor = 0;
    HSVLerp_half(_Color_Deep, _Color_Shallow, geometryDepth.shallowFactor.z, waterBaseColor);
        
    // Mapping-specific normal sampling always resolves to world space here.
    // float3 waterNormalWS = SampleWaterNormalWS(surfaceContext); // mapped normal
    WaterNormalSample waterNormalSampleWS = GetSampleWaterNormalWS(surfaceContext);
    
    // return half4(screenUV + GetRefractedOffset(waterNormalWS, geometricNormalWS), 0.0, 1.0);
    // return half4(waterNormalSampleWS.normalWS * .5 + .5, 1.0);
    
    bool useSurfaceFoam = _UseSurfaceFoam > 0.5;
    bool useIntersectionFoam = _UseIntersecFoam > 0.5;
    bool useShorelineFoam = _UseShoreLineFoam > 0.5;
    bool useRefraction = _UseRefraction > 0.5;
    bool useCaustics = _EnableCaustics > 0.5;
    
    bool needsFoamDistortion =
        (useSurfaceFoam && abs(_SurfaceFoam_Distortion) > 0.0)
        || (useIntersectionFoam && abs(_IntersecFoam_Distortion) > 0.0);

    float2 surfaceDistortion = 0.0;
    UNITY_BRANCH if (needsFoamDistortion)
    {
        surfaceDistortion = SampleSurfaceDistortion(worldUV);
    }
    float4 shadowCoord =TransformWorldToShadowCoord(surfaceContext.positionWS);
    Light mainLight = GetMainLight(shadowCoord);
    
    half3 finalRGB = waterBaseColor.rgb;
    
    half finalAlpha = waterBaseColor.a;
    
    finalRGB = ApplyWaterNormalLighting(waterBaseColor.rgb, geometricNormalWS ,waterNormalSampleWS.normalWS, mainLight);
    
    UNITY_BRANCH if (useRefraction)
    {
        WaterRefractionSample refractionSample = ResolveRefractionUV(screenUV, waterNormalSampleWS.normalWS_Unscaled, surfaceContext, geometryDepth, shoreFade);
        WaterDepthSample opticalDepth = refractionSample.depthSample;

        half3 opticalSceneRGB = refractionSample.sceneColor;
        
        UNITY_BRANCH if (useCaustics)
        {
            // 如果不用 opticalDepth，而是 geometryDepth？
            // 焦散本身也是从水底反射过来最终被看到的，所以也需要经过折射。如果用 geometry depth
            // 就会看到你折射你的，我的焦散好像浮在上面一样，不真实
            half3 causticMask = EvaluateWaterCaustics(opticalDepth, surfaceContext.positionWS);
            opticalSceneRGB += causticMask;
        }
        
        half4 opticalWaterRGB = 0;
        HSVLerp_half(_Color_Deep, _Color_Shallow, opticalDepth.shallowFactor.z, opticalWaterRGB);
        half3 litWaterRGB = ApplyWaterNormalLighting(opticalWaterRGB.rgb, geometricNormalWS ,waterNormalSampleWS.normalWS, mainLight);
        finalRGB = lerp(opticalSceneRGB, litWaterRGB.rgb, opticalWaterRGB.a);
        
        // half3 original = SampleSceneColor(screenUV);
        // half3 difference =
        //     abs(refractionSample.sceneColor - original) * 20.0h;
        //
        // return half4(difference, 1.0h);
    }
    
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(surfaceContext.positionWS);
    half3 waterSpecular = EvaluateMainWaterSpecular(mainLight.direction, waterNormalSampleWS.normalWS, viewDirWS, mainLight);
    
    finalRGB += waterSpecular;
    
    UNITY_BRANCH if (useIntersectionFoam)
    {
        float intersectionDriver = geometryDepth.shallowFactor.y; // 星球模式下……

        float intersectionMask = IntersectionFoamMask(worldUV, surfaceDistortion, intersectionDriver);
        BlendFoam(finalRGB, finalAlpha, _IntersecFoam_Color, intersectionMask, 1.0h, 0.0h);
    }

    UNITY_BRANCH if (useSurfaceFoam)
    {
        float surfaceMask = SurfaceFoamMask(worldUV, surfaceDistortion);
        BlendFoam(finalRGB, finalAlpha, _SurfaceFoam_Color, surfaceMask, 1.0h, 0.0h);
    }

    // UNITY_BRANCH if (useShorelineFoam)
    // {
    // }
    
    // return half4(waterNormalWS, 1.0);

    // finalRGB = ApplyWaterNormalLighting(finalRGB, geometricNormalWS, waterNormalWS, mainLight);
    
    finalAlpha = useRefraction ? shoreFade : shoreFade * finalAlpha;
    
    return half4(finalRGB, finalAlpha);
}

#endif
