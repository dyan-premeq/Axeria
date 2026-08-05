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
            TEXTURE2D(_HistoryDepthBuffer);
            TEXTURE2D_X(_MotionVectorTexture);
            
            float _UseDepthCorrection;
            float _UseClamping;
            float _UseMotionVectorDilation;
            
            float4 _TAA_JitterUvDelta;
            
            float _DebugMotionVector;
            float _DebugMotionVectorScale;
            
            float _DebugReprojection;

            half4 frag(Varyings IN) : SV_Target
            {
                bool debugMV = _DebugMotionVector > .5;
                bool debugReprojectrion = _DebugReprojection > .5;

                // 接下来全都默认 UNITY_REVERSED_Z 
                float historyDepthRaw = SampleSceneDepth(IN.texcoord);;
                
                float2 rawMotionVec = SAMPLE_TEXTURE2D_X(_MotionVectorTexture, sampler_PointClamp, IN.texcoord).xy;

                if (_UseMotionVectorDilation > .5)
                {
                    UNITY_UNROLL
                    for (int di = -1; di < 2; ++di)
                    {
                        for (int dj = -1; dj < 2; ++dj)
                        {
                            float2 duv = IN.texcoord.xy + float2(_ScreenSize.z * di, _ScreenSize.w * dj);
                            float d = SampleSceneDepth(duv);
                            float2 v = SAMPLE_TEXTURE2D_X(_MotionVectorTexture, sampler_PointClamp, duv).xy;
                            if (d > historyDepthRaw)
                            {
                                historyDepthRaw = d;
                                rawMotionVec = v;
                            }
                        }
                    }
                }

                rawMotionVec.x -= _TAA_JitterUvDelta.x;
                rawMotionVec.y -= _TAA_JitterUvDelta.y;


                if (debugMV)
                {
                    float2 encodedMotion = saturate(0.5 + rawMotionVec * _DebugMotionVectorScale);
                    return half4(encodedMotion.x, encodedMotion.y, 0.5, 1.0);
                }

                

                float2 reprojectedUV = IN.texcoord - rawMotionVec; 
                bool isRepUvValid = all((reprojectedUV >= 0.0) & (reprojectedUV <= 1.0));
                
                if (!isRepUvValid)
                {
                    reprojectedUV = IN.texcoord;
                }

                half4 historyCol = SAMPLE_TEXTURE2D(_HistoryBuffer, sampler_LinearClamp, reprojectedUV);
                // float historyDepth = Linear01Depth(SAMPLE_TEXTURE2D(_HistoryDepthBuffer, sampler_PointClamp, reprojectedUV), _ZBufferParams);

                float2 samplingUV = 0;
                float3 neighbourVal = 0;
                float3 minn = REAL_MAX;
                float3 maxx = -REAL_MAX; 
                UNITY_UNROLL
                for (int di = -1; di < 2; ++di)
                {
                    for (int dj = -1; dj < 2; ++dj)
                    {
                        samplingUV = IN.texcoord + float2(_ScreenSize.z * di, _ScreenSize.w * dj);
                        neighbourVal = RGBToYCoCg(SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp, samplingUV).rgb);
                        minn = min(minn, neighbourVal);
                        maxx = max(maxx, neighbourVal);
                    }
                }
                
                
                historyDepthRaw = 10;
                
                UNITY_UNROLL
                for (int di = -1; di < 2; ++di)
                {
                    for (int dj = -1; dj < 2; ++dj)
                    {
                        float2 duv = reprojectedUV + float2(_ScreenSize.z * di, _ScreenSize.w * dj);
                        float d = SAMPLE_TEXTURE2D(_HistoryDepthBuffer, sampler_PointClamp, duv).r;
                        historyDepthRaw = min(historyDepthRaw, d);
                        
                    }
                }
                
                // historyDepthRaw = SAMPLE_TEXTURE2D(_HistoryDepthBuffer, sampler_PointClamp, reprojectedUV).r;
                float historyDepth = Linear01Depth(historyDepthRaw, _ZBufferParams);
                
                half4 rawHistory = historyCol;
                historyCol.rgb = lerp(rawHistory.rgb, YCoCgToRGB(clamp(RGBToYCoCg(historyCol), minn, maxx)), _UseClamping);
                
                float currentLinearDepth = Linear01Depth(SampleSceneDepth(IN.texcoord), _ZBufferParams);
                float depthMask = currentLinearDepth - historyDepth;
                depthMask = (currentLinearDepth - historyDepth) / currentLinearDepth;

                float alpha = _BlendAlpha * (1 - _UseDepthCorrection * step( _DepthMaskThreshold, depthMask));
                
                half4 currSample = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.texcoord);
                
                if (debugReprojectrion)
                {
                    // return half4(abs(rawHistory.rgb - historyCol.rgb), 1.0);
                    // return half4((maxx - minn).rgb, 1);
                    return currSample * step( _DepthMaskThreshold, depthMask);
                }
                
                half4 color = alpha * historyCol + (1 - alpha) * currSample;
                return color;
            }
            ENDHLSL
        }
    }
}
