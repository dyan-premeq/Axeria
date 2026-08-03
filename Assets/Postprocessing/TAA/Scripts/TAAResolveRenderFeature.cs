using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Axeria.PostProcessingLab.TAA
{
    public sealed class TAAResolveRenderFeature : ScriptableRendererFeature
    {
        
        private sealed class TAAResolvePass : ScriptableRenderPass
        {
            private RTHandle cameraColorRT;
            private RTHandle tempColorRT;
            private RTHandle historyColorRT;

            private bool isHistoryValid;

            private readonly Material resolveMaterial;
            private float blendAlpha;
            
            private bool debugMV;
            private float debugMVScale;
            
            private bool debugReprojection;

            private static readonly int HistoryBufferId = Shader.PropertyToID("_HistoryBuffer");
            private static readonly int AlphaId = Shader.PropertyToID("_BlendAlpha");
            
            private static readonly int DebugMVFlagId = Shader.PropertyToID("_DebugMotionVector");
            private static readonly int DebugMVScaleId = Shader.PropertyToID("_DebugMotionVectorScale");
            
            private static readonly int DebugReprojectionFlagId = Shader.PropertyToID("_DebugReprojection");


            public TAAResolvePass(string passName, Material material)
            {
                profilingSampler = new ProfilingSampler(passName);
                resolveMaterial = material;
                isHistoryValid = false;

                renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing; // 先 TAA 再后处理
            }

            public void configurePass(RTHandle target, float a, bool debug1, float scale, bool debug2)
            {
                cameraColorRT = target;
                blendAlpha = a;
                debugMV = debug1;
                debugMVScale = scale;
                debugReprojection = debug2;
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                ConfigureTarget(cameraColorRT);

                RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
                desc.msaaSamples = 1;       // 普通单采样纹理 
                desc.depthBufferBits = 0;   //　颜色纹理，不额外创建深度

                // ReAllocateIfNeeded 每帧都可以调用，但描述没有变化时不会重新创建纹理
                RenderingUtils.ReAllocateIfNeeded(ref tempColorRT, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, false, 1, 0, "_TAA_TempColorTexture");
                bool isReallocated = RenderingUtils.ReAllocateIfNeeded(ref historyColorRT, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, false, 1, 0, "_TAA_HistoryTexture");
                if (isReallocated) {
                    isHistoryValid = false;
                }

            }

            public override void OnCameraCleanup(CommandBuffer cmd)
            {
                // base.OnCameraCleanup(cmd);
            }
            public override void Execute(ScriptableRenderContext ctx, ref RenderingData renderingData)
            {
                CommandBuffer cmd = CommandBufferPool.Get("TAA Resolve Test");
                // cmd.ClearRenderTarget(false, true, Color.magenta); // 不清深度，屏幕颜色清成洋红色
                // Blitter.BlitCameraTexture(cmd, cameraColorRT, tempColorRT);
                if (debugMV)
                {
                    resolveMaterial.SetFloat(DebugMVFlagId, 1f);
                    resolveMaterial.SetFloat(DebugMVScaleId, debugMVScale);
                    Blitter.BlitCameraTexture(cmd, cameraColorRT, tempColorRT, resolveMaterial, 0); // MV debug
                    Blitter.BlitCameraTexture(cmd, tempColorRT, cameraColorRT);
                    isHistoryValid = false;
                }
                else if (debugReprojection)
                {
                    if (!isHistoryValid)
                    {
                        Blitter.BlitCameraTexture(cmd, cameraColorRT, historyColorRT);
                        isHistoryValid = true;
                    }
                    else
                    {
                        resolveMaterial.SetFloat(DebugMVFlagId, 0f);
                        resolveMaterial.SetFloat(DebugReprojectionFlagId, 1f);
                        resolveMaterial.SetTexture(HistoryBufferId, historyColorRT);
                        resolveMaterial.SetFloat(AlphaId, blendAlpha);
                        Blitter.BlitCameraTexture(cmd, cameraColorRT, tempColorRT, resolveMaterial, 0); // Reprojection debugBlitter.BlitCameraTexture(cmd, cameraColorRT, historyColorRT);
                        Blitter.BlitCameraTexture(cmd, cameraColorRT, historyColorRT);
                        Blitter.BlitCameraTexture(cmd, tempColorRT, cameraColorRT);              
                    }
                }
                else
                {
                    if (!isHistoryValid)
                    {
                        Blitter.BlitCameraTexture(cmd, cameraColorRT, historyColorRT);
                        isHistoryValid = true;
                    }
                    else
                    {
                        resolveMaterial.SetFloat(DebugMVFlagId, 0f);
                        resolveMaterial.SetFloat(DebugReprojectionFlagId, 0f); 
                        resolveMaterial.SetTexture(HistoryBufferId, historyColorRT);
                        resolveMaterial.SetFloat(AlphaId, blendAlpha);
                        Blitter.BlitCameraTexture(cmd, cameraColorRT, tempColorRT, resolveMaterial, 0); // Temporal Accumulation
                        Blitter.BlitCameraTexture(cmd, tempColorRT, historyColorRT);
                        Blitter.BlitCameraTexture(cmd, tempColorRT, cameraColorRT); 

                    }
                }
                
                ctx.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }

            public void ReleaseResources()
            {
                tempColorRT?.Release();
                tempColorRT = null;
                
                historyColorRT?.Release();
                historyColorRT = null;

                cameraColorRT = null;
            }
        }


        private TAAResolvePass resolvePass;

        [SerializeField]
        private Material debugResolveMaterial;
        public float blendAlpha = 0.9f;
        
        public bool debugMotionVector = false;
        public float debugMotionVectorScale = 40f;

        public bool debugProjectedHistory = false;
        
        public override void Create()
        {   
            // Dispose() 和 Create() 不是成对调用的
            // Inspector 修改或发生序列化又会中途再次调用 Create()
            resolvePass?.ReleaseResources();
            resolvePass = new TAAResolvePass("TAA Resolve Test Pass", debugResolveMaterial);
            // resolvePass.
            return;
        }
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if(renderingData.cameraData.cameraType != CameraType.Game) return;
            resolvePass.ConfigureInput(ScriptableRenderPassInput.Motion); // 我要运动向量 T T
            renderer.EnqueuePass(resolvePass);
            return;
        }

        public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
        {
            if(renderingData.cameraData.cameraType != CameraType.Game) return;
            resolvePass.configurePass(
                renderer.cameraColorTargetHandle, 
                blendAlpha, 
                debugMotionVector, 
                debugMotionVectorScale,
                debugProjectedHistory);
            // renderer 持有 camera color 的句柄，通过 feature 传给 render pass 来借用
        }

        protected override void Dispose(bool disposing)
        {
            resolvePass?.ReleaseResources();
            resolvePass = null;
        }

    }
}

