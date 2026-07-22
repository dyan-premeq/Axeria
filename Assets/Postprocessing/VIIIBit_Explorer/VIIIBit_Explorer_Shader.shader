Shader "Axeria/Postprocessing/VIIIBit_Explorer_Shader"
{
    Properties
    {
//        _Downsampling("下采样强度", Int) = 4
//        _Dithering("抖动强度", Range(0,1)) = 0.5
//        _Opacity("8Bit Pallete不透明度",Range(0,1)) = 1
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
