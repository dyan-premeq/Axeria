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
            
            TEXTURE2D_X(_MotionVectorTexture);
            
            float _DebugMotionVector;
            float _DebugMotionVectorScale;
            
            float _DebugReprojection;

            half4 frag(Varyings IN) : SV_Target
            {
                bool debugMV = _DebugMotionVector > .5;
                bool debugReprojectrion = _DebugReprojection > .5;
                float2 rawMotionVec = SAMPLE_TEXTURE2D_X(_MotionVectorTexture, sampler_PointClamp, IN.texcoord).xy;
                
                if (debugMV)
                {
                    float2 encodedMotion = saturate(0.5 + rawMotionVec * _DebugMotionVectorScale);
                    return half4(encodedMotion.x, encodedMotion.y, 0.5, 1.0);
                }
                
                
                float2 reprojectedUV = IN.texcoord - rawMotionVec; 
                bool isRepUvValid = all((reprojectedUV >= 0.0) & (reprojectedUV <= 1.0));
                half4 historyCol = SAMPLE_TEXTURE2D(_HistoryBuffer, sampler_HistoryBuffer, reprojectedUV);
                half4 currSample = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.texcoord);
                
                if (!isRepUvValid)
                {
                    historyCol = currSample;
                }
                
                if (debugReprojectrion)
                {
                    // half4 currSample = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.texcoord);
                    return historyCol;
                }
                
                half4 color = _BlendAlpha * historyCol + (1 - _BlendAlpha) * currSample;
                return color;
            }
            ENDHLSL
        }
    }
}
