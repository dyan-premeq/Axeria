#ifndef LIVIDI_WATER_INPUT_INCLUDED
#define LIVIDI_WATER_INPUT_INCLUDED

CBUFFER_START(UnityPerMaterial)
    half4 _Color_Shallow;
    half4 _Color_Deep;

    float _Water_Depth;

    float _WaterNormalScaling;
    float _WaterNormalScalingRatio;
    float4 _WaterNormalTiling;
    float _WaterNormalSpeed;
    float _WaterNormalStrength;

    float _SurfaceDistortion_MaskScale;
    float4 _SurfaceDistortion_MaskPan;

//Surface Foam
    float _UseSurfaceFoam;
    half4 _SurfaceFoam_Color;
    float _SurfaceFoam_MaskScaling;
    float4 _SurfaceFoam_MaskTiling;
    float4 _SurfaceFoam_MaskPan;    
    float _SurfaceFoam_EdgeSmooth;
    float _SurfaceFoam_Edge;
    float _SurfaceFoam_MaskInverse;
    float _SurfaceFoam_Distortion;

//Intersection Foam
    float _UseIntersecFoam;
    half4 _IntersecFoam_Color;
    float _IntersecFoam_Width;
    float _IntersecFoam_GradientDissolve;
    float _IntersecFoam_Dissolve;
    float _IntersecFoam_EdgeFading;
    float _IntersecFoam_MaskScaling;
    float4 _IntersecFoam_MaskTiling;
    float4 _IntersecFoam_MaskPan;
    float _IntersecFoam_Smoothness;
    float _IntersecFoam_MaskInverse;
    float _IntersecFoam_Distortion;

//Shoreline Foam

    float _WorldSpaceDepth;
    float _UsePlanetCenterUp;
    float4 _PlanetCenter;
    float _FoamFade;
CBUFFER_END

TEXTURE2D(_WaterSurfaceNormalMap);
SAMPLER(sampler_WaterSurfaceNormalMap);

TEXTURE2D(_SurfaceFoamMask);
SAMPLER(sampler_SurfaceFoamMask);

TEXTURE2D(_IntersecFoamMask);
SAMPLER(sampler_IntersecFoamMask);

TEXTURE2D(_SurfaceDistortion_Map);
SAMPLER(sampler_SurfaceDistortion_Map);

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    half3 normalWS : TEXCOORD2;
    half3 tangentWS : TEXCOORD3;
    half3 bitangentWS : TEXCOORD4;
    float3 objectUpWS : TEXCOORD5;
};

#endif
