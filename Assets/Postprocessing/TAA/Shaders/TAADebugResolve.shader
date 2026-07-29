Shader "Hidden/Axeria/Postprocessing/TAADebugResolve"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
        // _BlendAlpha("Blend Alpha", Float) = 0.9
    }
    SubShader
    {

        Tags { "RenderPipeline" = "UniversalPipeline" }

        // No culling or depth
        Cull Off ZWrite Off ZTest Always Blend Off

        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            #pragma vertex Vert
            #pragma fragment frag

            float _BlendAlpha;
            TEXTURE2D(_HistoryBuffer);
            SAMPLER(sampler_HistoryBuffer);

            half4 frag(Varyings IN) : SV_Target
            {
                half4 currSample = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.texcoord);
                half4 historyCol = SAMPLE_TEXTURE2D(_HistoryBuffer, sampler_HistoryBuffer, IN.texcoord);
                half4 color = _BlendAlpha * historyCol + (1 - _BlendAlpha) * currSample;
                return color;
            }
            ENDHLSL
        }
    }
}
