Shader "LividiWaterShader"
{
    Properties
    {
        // 基本设定
        [HDR]_Color_Shallow("浅水颜色", Color) = (0.2269659, 0.822786, 0.4507858, 0)
        [HDR]_Color_Deep("深水颜色", Color) = (0, 0.2541522, 0.4507858, 1)
        _DepthFadeDistance("深度渐变距离", Float) = 0.5
        
        [ToggleUI]_WorldSpaceDepth("使用世界空间计算水深", Float) = 1
        [ToggleUI]_UsePlanetCenterUp("Use Planet Center Up", Float) = 0
        _FoamFade("Foam Fade", Range(0.9,1.0)) = 0.95
        
        [ToggleUI]_UseShoreFade("开启水岸渐变", Float) = 1
        _ShoreFadeSmoothness("水岸渐变消失程度", Float) = 0.3

        [Normal][NoScaleOffset]_WaterSurfaceNormalMap("水面法线贴图", 2D) = "bump" {}
        _WaterNormalScaling("水面法线贴图 Scaling", Float) = 1
        _WaterNormalScalingRatio("水面法线贴图层尺度分离程度", Range(0,1)) = 1
        _WaterNormalTiling("水面法线贴图 Tiling", Vector) = (1,1,0,0)
        _WaterNormalSpeed("水面法线贴图 Panning Speed", Float) = 1
        _WaterNormalStrength("水面法线强度", Float) = 1
        
        // Gerstener Wave
        [ToggleUI]_EnableWave("开启水波", Float) = 1
        _GerstnerSteepness("Gersnter 波 Steepness", Range(0, 0.25)) = 0.0825
        _GerstnerWavelength("Gerstner 波长", Float) = 1.22
        _GerstnerSpeed("Gerstner 波相速度", Float) = 0.55
        _GerstnerDirection("Gerstner 波方向（一个分量控制一个波向）", Vector) = (0.1, 0.3, 0.4, 1)
        
        // Stylized Specular
        [HDR]_WaterSpecularColor("高光颜色",Color) = (1,1,1,1)
        _WaterSpecularSpread("高光扩散",Range(0,1)) = 0.5
        _WaterSpecularSize("高光尺寸",Range(0,1)) = 0.2
        _WaterSpecularHardness("高光硬度",Range(0,1)) = 0.7
        
        // Refraction
        [ToggleUI]_UseRefraction("开启折射", Float) = 1
        _RefractionDepthBias("折射深度阈值", Float) = 0.0001 
        _RefractionFadeDistance("折射开始渐隐距离", Float) = 0.3
        _RefractionFadeRange("折射渐隐范围", Float) = 0.5
        _RefractionStrength_Base("基础折射强度", Float) = 0.008
        _RefractionStrength_Far("远处折射强度", Float) = 0.002

        // Caustics
        [ToggleUI]_EnableCaustics("开启焦散", Float) = 0
        [NoScaleOffset]_CausticMap("焦散贴图", 2D) = "white" {}
        _CausticsSpeedA("焦散层 A 移动速度", Vector) = (1,0,0,0)
        _CausticsSpeedB("焦散层 B 移动速度", Vector) = (-0.5,0.5,0,0)
        _CausticSharpness("焦散锐度", Range(0.1,16)) = 4
        _CausticsStart("焦散淡出起始距离", Float) = 20
        _CausticsFadingSmoothness("焦散淡出范围", Float) = 10
        
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
        [HDR]_IntersecFoam_Color("相交泡沫颜色", Color) = (1,1,1,1)
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
        [ToggleUI]_UseShoreLineFoam("开启海岸线泡沫", Float) = 1
        _ShoreLine_WaterDepth("海岸线泡沫水深", Float) = 0.8
        _ShoreLine_Speed("海岸线泡沫速度", Float) = 0.2
        _ShoreLine_Amount("海岸线泡沫数量", Float) = 3
        _ShoreLine_Thickness("海岸线泡沫厚度", Range(0,1)) = 0.5
        _ShoreLine_CenterMask("海岸线中心遮罩", Range(0,1)) = 0.5
        _ShoreLine_CenterMaskFade("海岸线中心遮罩渐变", Range(0.001,1)) = 0.1
        _ShoreLine_TrailFade("海岸线尾迹渐变", Range(0,1)) = 0.5
        _ShoreLine_NearShoreExpand("近岸扩张", Range(0,1)) = 0
        _ShoreLine_Dissolve("海岸线溶解程度", Range(0,1)) = 0.5
        [NoScaleOffset]_ShoreLine_DissolveMask("海岸线溶解遮罩", 2D) = "white" {}
        _ShoreLine_MaskSpeed("海岸线遮罩移动速度", Vector) = (0,0,0,0)
        _ShoreLine_MaskTile("海岸线遮罩平铺", Vector) = (1,1,0,0)
        _ShoreLine_MaskScale("海岸线遮罩缩放", Float) = 1
        _ShoreLine_LineDirectionality("海岸线方向性", Range(0,1)) = 0.5

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
//            Blend Off
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha

            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_instancing

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            
            #define _SURFACE_TYPE_TRANSPARENT 1
            
            #include "Assets/DevCindy/LividiWaterShader/Shader/Includes/WaterForwardPass.hlsl"

            ENDHLSL
        }
    }

    CustomEditor "LividiWaterShaderGUI"
    FallBack Off
}
