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

            private static readonly int HistoryBufferId = Shader.PropertyToID("_HistoryBuffer");
            private static readonly int AlphaId = Shader.PropertyToID("_BlendAlpha");

            public TAAResolvePass(string passName, Material material)
            {
                profilingSampler = new ProfilingSampler(passName);
                resolveMaterial = material;
                isHistoryValid = false;

                renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing; // 先 TAA 再后处理
            }

            public void setAlpha(float a)
            {
                blendAlpha = a;
            }

            public void setCameraColor(RTHandle target)
            {
                cameraColorRT = target;
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
                if (!isHistoryValid)
                {
                    Blitter.BlitCameraTexture(cmd, cameraColorRT, historyColorRT);
                    isHistoryValid = true;
                }

                // Blitter.BlitCameraTexture(cmd, historyColorRT, cameraColorRT);
                // shader
                resolveMaterial.SetTexture(HistoryBufferId, historyColorRT);
                resolveMaterial.SetFloat(AlphaId, blendAlpha);
                Blitter.BlitCameraTexture(cmd, cameraColorRT, tempColorRT, resolveMaterial, 0); // Temporal Accumulation

                Blitter.BlitCameraTexture(cmd, tempColorRT, historyColorRT);
                Blitter.BlitCameraTexture(cmd, tempColorRT, cameraColorRT);
                
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
        public float blendAlpha;
        
        public override void Create()
        {   
            resolvePass = new TAAResolvePass("TAA Resolve Test Pass", debugResolveMaterial);
            // resolvePass.
            return;
        }
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if(renderingData.cameraData.cameraType != CameraType.Game) return;
            renderer.EnqueuePass(resolvePass);
            return;
        }

        public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
        {
            if(renderingData.cameraData.cameraType != CameraType.Game) return;

            resolvePass.setCameraColor(renderer.cameraColorTargetHandle);
            resolvePass.setAlpha(blendAlpha);
            // renderer 持有 camera color 的句柄，通过 feature 传给 render pass 来借用
        }

        protected override void Dispose(bool disposing)
        {
            resolvePass?.ReleaseResources();
            resolvePass = null;
        }


    }
}

