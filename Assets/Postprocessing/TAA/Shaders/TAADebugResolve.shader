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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"


            #pragma vertex Vert
            #pragma fragment frag

            float _BlendAlpha;
            float _DepthMaskThreshold;
            TEXTURE2D(_HistoryBuffer);
            SAMPLER(sampler_HistoryBuffer);

            TEXTURE2D(_HistoryDepthBuffer);
            SAMPLER(sampler_HistoryDepthBuffer);
            
            TEXTURE2D_X(_MotionVectorTexture);
            
            // float4 texelSize = _ScreenSize;
            
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
                
                

                half4 currSample = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.texcoord);
                float currentLinearDepth = Linear01Depth(SampleSceneDepth(IN.texcoord), _ZBufferParams);

                float2 reprojectedUV = IN.texcoord - rawMotionVec; 
                bool isRepUvValid = all((reprojectedUV >= 0.0) & (reprojectedUV <= 1.0));
                
                if (!isRepUvValid)
                {
                    reprojectedUV = IN.texcoord;
                }

                half4 historyCol = SAMPLE_TEXTURE2D(_HistoryBuffer, sampler_LinearClamp, reprojectedUV);
                float historyDepth = Linear01Depth(SAMPLE_TEXTURE2D(_HistoryDepthBuffer, sampler_PointClamp, reprojectedUV), _ZBufferParams);
                float depthMask = currentLinearDepth - historyDepth;
                depthMask = (currentLinearDepth - historyDepth) / currentLinearDepth;

                float alpha = _BlendAlpha * (1 - step( _DepthMaskThreshold, depthMask));
                
                if (debugReprojectrion)
                {
                    return currSample * step( _DepthMaskThreshold, depthMask);
                    // return historyCol;
                }

                half4 color = alpha * historyCol + (1 - alpha) * currSample;
                return color;
            }
            ENDHLSL
        }
    }
}
