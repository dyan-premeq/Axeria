#ifndef LIVIDI_WATER_INPUT_INCLUDED
#define LIVIDI_WATER_INPUT_INCLUDED

CBUFFER_START(UnityPerMaterial)
    half4   _Color_Shallow;
    half4   _Color_Deep;

    float   _DepthFadeDistance;

// Shore Fade
    float   _UseShoreFade;
    float   _ShoreFadeSmoothness;

// Normal and Distortion

    float   _WaterNormalScaling;
    float   _WaterNormalScalingRatio;
    float4  _WaterNormalTiling;
    float   _WaterNormalSpeed;
    float   _WaterNormalStrength;

    float   _SurfaceDistortion_MaskScale;
    float4  _SurfaceDistortion_MaskPan;

// Lighting
    half4   _WaterSpecularColor;
    float   _WaterSpecularSpread;
    float   _WaterSpecularSize;
    float   _WaterSpecularHardness;

// Gerstner Wave
    float   _EnableWave;
    float   _GerstnerSteepness;
    float   _GerstnerWavelength;
    float   _GerstnerSpeed;
    float4  _GerstnerDirection;

// Caustics
    float   _EnableCaustics;
    float4   _CausticsSpeedA;
    float4   _CausticsSpeedB;
    float   _CausticSharpness;
    float   _CausticsStart;
    float   _CausticsFadingSmoothness;

// Refraction
    float   _UseRefraction;
    float   _RefractionDepthBias;
    float   _RefractionFadeDistance;
    float   _RefractionFadeRange;
    float   _RefractionStrength_Base;
    float   _RefractionStrength_Far;

//Surface Foam
    float   _UseSurfaceFoam;
    half4   _SurfaceFoam_Color;
    float   _SurfaceFoam_MaskScaling;
    float4  _SurfaceFoam_MaskTiling;
    float4  _SurfaceFoam_MaskPan;    
    float   _SurfaceFoam_EdgeSmooth;
    float   _SurfaceFoam_Edge;
    float   _SurfaceFoam_MaskInverse;
    float   _SurfaceFoam_Distortion;

//Intersection Foam
    float   _UseIntersecFoam;
    half4   _IntersecFoam_Color;
    float   _IntersecFoam_Width;
    float   _IntersecFoam_GradientDissolve;
    float   _IntersecFoam_Dissolve;
    float   _IntersecFoam_EdgeFading;
    float   _IntersecFoam_MaskScaling;
    float4  _IntersecFoam_MaskTiling;
    float4  _IntersecFoam_MaskPan;
    float   _IntersecFoam_Smoothness;
    float   _IntersecFoam_MaskInverse;
    float   _IntersecFoam_Distortion;

//Shoreline Foam
    float   _UseShoreLineFoam;
    float   _ShoreLine_WaterDepth;
    float   _ShoreLine_Speed;
    float   _ShoreLine_Amount;
    float   _ShoreLine_Thickness;

    float   _ShoreLine_CenterMask;
    float   _ShoreLine_CenterMaskFade;
    float   _ShoreLine_TrailFade;

    float   _ShoreLine_NearShoreExpand;
    float   _ShoreLine_Dissolve;

    float2  _ShoreLine_MaskSpeed;
    float2  _ShoreLine_MaskTile;
    float   _ShoreLine_MaskScale;

    float   _ShoreLine_LineDirectionality;


    float   _WorldSpaceDepth;
    float   _UsePlanetCenterUp;
    float4  _PlanetCenter;
    float   _FoamFade;
CBUFFER_END

TEXTURE2D(_WaterSurfaceNormalMap);
SAMPLER(sampler_WaterSurfaceNormalMap);

TEXTURE2D(_SurfaceFoamMask);
SAMPLER(sampler_SurfaceFoamMask);

TEXTURE2D(_IntersecFoamMask);
SAMPLER(sampler_IntersecFoamMask);

TEXTURE2D(_SurfaceDistortion_Map);
SAMPLER(sampler_SurfaceDistortion_Map);

TEXTURE2D(_ShoreLine_DissolveMask);
SAMPLER(sampler_ShoreLine_DissolveMask);

TEXTURE2D(_CausticMap);
SAMPLER(sampler_CausticMap);

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
    float2 uv : TEXCOORD0;          // uv0
    float3 positionWS : TEXCOORD1;
    half3  normalWS : TEXCOORD2;
    float3 objectUpWS : TEXCOORD3;  // 水体对象自身局部 Y 轴转换到世界空间后的方向。
};

#endif
