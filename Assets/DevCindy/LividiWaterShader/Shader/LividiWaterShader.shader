Shader "LividiWaterShader"
{
    Properties
    {
        // 基本设定
        [HDR]_Color_Shallow("浅水颜色", Color) = (0.2269659, 0.822786, 0.4507858, 0)
        [HDR]_Color_Deep("深水颜色", Color) = (0, 0.2541522, 0.4507858, 1)
        _DepthFadeDistance("深度渐变距离", Float) = 0.5
        
        [ToggleUI]_WorldSpaceDepth("WorldSpaceDepth", Float) = 1
        [ToggleUI]_UsePlanetCenterUp("Use Planet Center Up", Float) = 1
        _FoamFade("Foam Fade", Range(0.9,1.0)) = 0.95
        
        [Normal][NoScaleOffset]_WaterSurfaceNormalMap("水面法线贴图", 2D) = "bump" {}
        _WaterNormalScaling("水面法线贴图 Scaling", Float) = 1
        _WaterNormalScalingRatio("水面法线贴图层尺度分离程度", Range(0,1)) = 1
        _WaterNormalTiling("水面法线贴图 Tiling", Vector) = (1,1,0,0)
        _WaterNormalSpeed("水面法线贴图 Panning Speed", Float) = 1
        _WaterNormalStrength("水面法线强度", Float) = 1
        
          // Stylized Specular
        [HDR]_WaterSpecularColor("高光颜色",Color) = (1,1,1,1)
        _WaterSpecularSpread("高光扩散",Range(0,1)) = 0.5
        _WaterSpecularSize("高光尺寸",Range(0,1)) = 0.2
        _WaterSpecularHardness("高光硬度",Range(0,1)) = 0.7
        
        // Project-wide planet-space convention used by the atmosphere and cloud shaders.
        _PlanetCenter("Planet Center", Vector) = (0, 0, 0, 0)
        
        // SurfaceDistortion
        [NoScaleOffset]_SurfaceDistortion_Map("表面变形贴图", 2D) = "white" {}
        _SurfaceDistortion_MaskScale("表面变形缩放", Float) = 1
        _SurfaceDistortion_MaskPan("表面变形移动速度", Vector) = (1,1,0,0)
        
        // SurfaceFoam
        [ToggleUI]_UseSurfaceFoam("开启表面泡沫", Float) = 1
        [NoScaleOffset]_SurfaceFoamMask("表面泡沫贴图", 2D) = "white" {}
        [HDR]_SurfaceFoam_Color("表面白沫颜色", Color) = (1,1,1,1)
        _SurfaceFoam_MaskScaling("表面泡沫遮罩 Scaling", Float) = 1
        _SurfaceFoam_MaskTiling("表面泡沫遮罩 Tiling",Vector) = (1,1,0,0)
        _SurfaceFoam_MaskPan("表面泡沫遮罩 Panning Speed",Vector) = (0,0,0,0)
        _SurfaceFoam_Edge("表面泡沫遮罩阈值", Range(0,1)) = 0.5
        _SurfaceFoam_EdgeSmooth("表面泡沫边缘平滑", Range(0.001,1)) = 0.1
        [ToggleUI]_SurfaceFoam_MaskInverse("反向采样表面泡沫遮罩", Float) = 0
        _SurfaceFoam_Distortion("表面泡沫变形程度", Float) = 0
        
        // IntersectionFoam
        [ToggleUI]_UseIntersecFoam("开启相交泡沫", Float) = 1
        [NoScaleOffset]_IntersecFoamMask("相交泡沫遮罩", 2D) = "white" {}
        [HDR]_IntersecFoam_Color("相交泡沫颜色", Color) = (1,1,1)
        _IntersecFoam_Width("相交泡沫宽度", Range(0.05, 1)) = 0.1
        [ToggleUI]_IntersecFoam_GradientDissolve("相交泡沫是否沿深度溶解", Float) = 1
        _IntersecFoam_Dissolve("相交泡沫溶解程度", Float) = 0.5
        _IntersecFoam_EdgeFading("相交泡沫沿深度渐变程度",Range(0,1)) = 0
        _IntersecFoam_MaskScaling("相交泡沫遮罩 Scaling", Float) = 1
        _IntersecFoam_MaskTiling("相交泡沫遮罩 Tiling",Vector) = (1,1,0,0)
        _IntersecFoam_MaskPan("相交泡沫遮罩 Panning Speed",Vector) = (0,0,0,0)
        _IntersecFoam_Smoothness("相交泡沫遮罩 Smooth", Range(0,1)) = 0.8
        [ToggleUI]_IntersecFoam_MaskInverse("反向采样泡沫遮罩", Float) = 0
        _IntersecFoam_Distortion("相交泡沫变形程度", Float) = 0
        // ShoreLineFoam
        [ToggleUI]_UseShoreLineFoam("Use shoreline foam", Float) = 1
        _Shoreline_DepthFadeDistance("海岸线泡沫深度渐变距离", Float) = 0.8

    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }

        Pass
        {
            Name "WaterForward"
            Tags { "LightMode" = "UniversalForwardOnly" }

            ZWrite Off
            ZTest LEqual
            Cull Back
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha

            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_instancing

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            
            #include "Assets/DevCindy/LividiWaterShader/Shader/Includes/WaterForwardPass.hlsl"

            ENDHLSL
        }
    }

    CustomEditor "LividiWaterShaderGUI"
    FallBack Off
}
