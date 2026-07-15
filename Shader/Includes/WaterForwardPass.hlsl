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
    float2 worldUV = surfaceContext.planarUV;
    
    // Depth base color
    half3 shallowFactor = (half3)GetWaterShallowFactor(input, _Water_Depth);
    half4 waterBaseColor = 0;
    HSVLerp_half(_Color_Deep, _Color_Shallow, shallowFactor.z, waterBaseColor);

    // Mapping-specific normal sampling always resolves to world space here.
    half3 waterNormalWS = SampleWaterNormalWS(surfaceContext);
    
    // Surface distortion is sampled once and shared by downstream surface effects.
    float2 surfaceDistortion = SampleSurfaceDistortion(worldUV);
    
    // Foam 
    
    // Surface foam
    float surfaceMask = SurfaceFoamMask(worldUV, surfaceDistortion);
    
    // intersection foam
    float intersectionMask = IntersectionFoamMask(worldUV, surfaceDistortion, shallowFactor.y);
    
    // TODO:ShoreLine foam
    
    half3 finalRGB = ApplyWaterNormalLighting(
        waterBaseColor.rgb,
        geometricNormalWS,
        waterNormalWS
    );
    half finalAlpha = waterBaseColor.a;

    BlendFoam(
        finalRGB,
        finalAlpha,
        _IntersecFoam_Color,
        intersectionMask,
        _UseIntersecFoam,
        0.0h
    );
    
    BlendFoam(
        finalRGB,
        finalAlpha,
        _SurfaceFoam_Color,
        surfaceMask,
        _UseSurfaceFoam,
        0.0h
    );
    // return half4(waterNormalWS, 1.0);
    return half4(finalRGB, finalAlpha);
}

#endif
