#ifndef LIVIDI_WATER_FORWARD_PASS_INCLUDED
#define LIVIDI_WATER_FORWARD_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "WaterDepth.hlsl"
#include "WaterSurface.hlsl"
#include "WaterLighting.hlsl"

Varyings Vert(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);

    VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.positionCS = positionInputs.positionCS;
    output.positionWS = positionInputs.positionWS;
    output.uv = input.uv;
    output.normalWS = normalInputs.normalWS;
    output.tangentWS = normalInputs.tangentWS;
    output.bitangentWS = normalInputs.bitangentWS;
    output.objectUpWS = TransformObjectToWorldNormal(float3(0.0, 1.0, 0.0));
    return output;
}

half4 Frag(Varyings input) : SV_Target
{
    WaterSurfaceContext surfaceContext = BuildWaterSurfaceContext(input);
    half3 geometricNormalWS = surfaceContext.geometricNormalWS;
    float2 worldUV = surfaceContext.planarMapping.uv;
    
    // Depth base color
    half3 shallowFactor = (half3)GetWaterShallowFactor(input, _Water_Depth);
    half4 waterBaseColor = 0;
    HSVLerp_half(_Color_Deep, _Color_Shallow, shallowFactor.z, waterBaseColor);

    // Mapping-specific normal sampling always resolves to world space here.
    half3 waterNormalWS = SampleWaterNormalWS(surfaceContext);
    
    // return half4(waterNormalWS * .5 + .5, 1.0);
    
    bool useSurfaceFoam = _UseSurfaceFoam > 0.5;
    bool useIntersectionFoam = _UseIntersecFoam > 0.5;
    bool useShorelineFoam = _UseShoreLineFoam > 0.5;

    // Shoreline foam has no distortion input yet. Add it to this condition
    // when the placeholder effect gains its distortion controls.
    bool needsFoamDistortion =
        (useSurfaceFoam && abs(_SurfaceFoam_Distortion) > 0.0)
        || (useIntersectionFoam && abs(_IntersecFoam_Distortion) > 0.0);

    float2 surfaceDistortion = 0.0;
    UNITY_BRANCH if (needsFoamDistortion)
    {
        surfaceDistortion = SampleSurfaceDistortion(worldUV);
    }
    

    half3 finalRGB = ApplyWaterNormalLighting(
        waterBaseColor.rgb,
        geometricNormalWS,
        waterNormalWS
    );
    half finalAlpha = waterBaseColor.a;
    UNITY_BRANCH if (useIntersectionFoam)
    {
        float intersectionDriver = shallowFactor.y; // 星球模式下……

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
    return half4(finalRGB, finalAlpha);
}

#endif
