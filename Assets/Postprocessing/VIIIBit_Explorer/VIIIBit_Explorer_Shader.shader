Shader "Axeria/Postprocessing/VIIIBit_Explorer_Shader"
{
    Properties
    {
        [HideInInspector] _Downsampling("下采样强度", Float) = 4
        [HideInInspector] _Dithering("抖动强度", Range(0, 1)) = 0.5
        [HideInInspector] _Opacity("8Bit Palette 不透明度", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            Name "QuantizeLowRes"
            
            HLSLPROGRAM
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            
            #pragma vertex Vert 
            #pragma fragment Frag_Quantization
            #pragma multi_compile_local_fragment _ _VIIIBIT_USE_SMOOTHSTEP
            #pragma multi_compile_local_fragment _ _VIIIBIT_USE_LEGACY_SECONDARY
            
            #include "VIIIBit_Explorer.hlsl"
            
          
            ENDHLSL
        }

        Pass
        {
            Name "CompositePoint"
            
            Blend SrcAlpha OneMinusSrcAlpha
            ColorMask RGB
            
            HLSLPROGRAM
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "VIIIBit_Explorer.hlsl" 
            
            #pragma vertex Vert 
            #pragma fragment Frag_Composition

            ENDHLSL
        }
    }
}
