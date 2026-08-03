using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering.Universal;

namespace Axeria.PostProcessingLab.TAA
{
    public sealed class TAAResolveRenderFeature : ScriptableRendererFeature
    {
        
        private sealed class TAAResolvePass : ScriptableRenderPass
        {
            private RTHandle cameraColorRT;
            private RTHandle cameraDepthRT;
            private RTHandle tempColorRT;
            private RTHandle historyColorRT;
            private RTHandle historyDepthRT;

            private bool isHistoryValid;
            private int lastHistoryFrameCount;
            private int historyCameraId;

            private readonly Material resolveMaterial;
            private float blendAlpha;
            private float threshold;

            private bool debugMV;
            private float debugMVScale;
            
            private bool debugReprojection;

            private static readonly int HistoryBufferId = Shader.PropertyToID("_HistoryBuffer");
            private static readonly int HistoryDepthBufferId = Shader.PropertyToID("_HistoryDepthBuffer");
            
            private static readonly int AlphaId = Shader.PropertyToID("_BlendAlpha");
            private static readonly int ThresholdId = Shader.PropertyToID("_DepthMaskThreshold");
            private static readonly int DebugMVFlagId = Shader.PropertyToID("_DebugMotionVector");
            private static readonly int DebugMVScaleId = Shader.PropertyToID("_DebugMotionVectorScale");
            
            private static readonly int DebugReprojectionFlagId = Shader.PropertyToID("_DebugReprojection");


            public TAAResolvePass(string passName, Material material)
            {
                profilingSampler = new ProfilingSampler(passName);
                resolveMaterial = material;
                isHistoryValid = false;

                lastHistoryFrameCount = -1;
                historyCameraId = -1;

                renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing; // 先 TAA 再后处理
            }

            public void configurePass(RTHandle color, RTHandle depth, float a, float h, bool debug1, float scale, bool debug2)
            {
                cameraColorRT = color;
                cameraDepthRT = depth;
                blendAlpha = a;
                threshold = h;
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
                // historyCameraId = renderingData.cameraData.camera.gameObject.GetInstanceID();

                // ReAllocateIfNeeded 每帧都可以调用，但描述没有变化时不会重新创建纹理
                RenderingUtils.ReAllocateIfNeeded(ref tempColorRT, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, false, 1, 0, "_TAA_TempColorTexture");

                bool isColorReallocated = RenderingUtils.ReAllocateIfNeeded(ref historyColorRT, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, false, 1, 0, "_TAA_ColorHistoryTexture");

                desc.graphicsFormat = GraphicsFormat.R32_SFloat;
                desc.depthStencilFormat = GraphicsFormat.None;
                desc.depthBufferBits = 0;
                bool isDepthReallocated = RenderingUtils.ReAllocateIfNeeded(ref historyDepthRT, desc, FilterMode.Point, TextureWrapMode.Clamp, false, 1, 0, "_TAA_DepthHistoryTexture");

                if (isColorReallocated | isDepthReallocated) {
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

                // int currentCameraId = renderingData.cameraData.camera.GetInstanceID();
                // int currentFrameCount = Time.frameCount;
                // if (!isHistoryValid || currentFrameCount != lastHistoryFrameCount + 1 || currentCameraId != historyCameraId)
                // {
                    // isHistoryValid = false;
                // }

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
                        Blitter.BlitCameraTexture(cmd, cameraDepthRT, historyDepthRT);
                        isHistoryValid = true;
                    }
                    else
                    {
                        resolveMaterial.SetFloat(DebugMVFlagId, 0f);
                        resolveMaterial.SetFloat(DebugReprojectionFlagId, 1f);
                        resolveMaterial.SetTexture(HistoryBufferId, historyColorRT);
                        resolveMaterial.SetTexture(HistoryDepthBufferId, historyDepthRT);
                        resolveMaterial.SetFloat(AlphaId, blendAlpha);
                        resolveMaterial.SetFloat(ThresholdId, threshold);
                        Blitter.BlitCameraTexture(cmd, cameraColorRT, tempColorRT, resolveMaterial, 0); // Reprojection debug
                        Blitter.BlitCameraTexture(cmd, cameraColorRT, historyColorRT);
                        Blitter.BlitCameraTexture(cmd, cameraDepthRT, historyDepthRT);
                        
                        Blitter.BlitCameraTexture(cmd, tempColorRT, cameraColorRT);              
                    }
                    // lastHistoryFrameCount = currentFrameCount;
                    // historyCameraId = currentCameraId;
                }
                else
                {
                    if (!isHistoryValid)
                    {
                        Blitter.BlitCameraTexture(cmd, cameraColorRT, historyColorRT);
                        Blitter.BlitCameraTexture(cmd, cameraDepthRT, historyDepthRT);

                        isHistoryValid = true;
                    }
                    else
                    {
                        resolveMaterial.SetFloat(DebugMVFlagId, 0f);
                        resolveMaterial.SetFloat(DebugReprojectionFlagId, 0f); 
                        resolveMaterial.SetTexture(HistoryBufferId, historyColorRT);
                        resolveMaterial.SetTexture(HistoryDepthBufferId, historyDepthRT);
                        resolveMaterial.SetFloat(AlphaId, blendAlpha);
                        resolveMaterial.SetFloat(ThresholdId, threshold);
                        Blitter.BlitCameraTexture(cmd, cameraColorRT, tempColorRT, resolveMaterial, 0); // Temporal Accumulation
                        Blitter.BlitCameraTexture(cmd, tempColorRT, historyColorRT);
                        Blitter.BlitCameraTexture(cmd, tempColorRT, cameraColorRT); 
                        Blitter.BlitCameraTexture(cmd, cameraDepthRT, historyDepthRT);
                    }
                    // lastHistoryFrameCount = currentFrameCount;
                    // historyCameraId = currentCameraId;
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

                historyDepthRT?.Release();
                historyDepthRT = null;

                cameraColorRT = null;
                cameraDepthRT = null;

                isHistoryValid = false;
                historyCameraId = -1;
                lastHistoryFrameCount = -1;
            }
        }


        private TAAResolvePass resolvePass;

        [SerializeField]
        private Material debugResolveMaterial;
        public float blendAlpha = 0.9f;

        public float depthMaskThreshold = 0.05f;
        
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
            resolvePass.ConfigureInput(ScriptableRenderPassInput.Motion | ScriptableRenderPassInput.Depth); // 我要运动向量和深度
            renderer.EnqueuePass(resolvePass);
            return;
        }

        public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
        {
            if(renderingData.cameraData.cameraType != CameraType.Game) return;
            resolvePass.configurePass(
                renderer.cameraColorTargetHandle,
                renderer.cameraDepthTargetHandle, 
                blendAlpha, 
                depthMaskThreshold,
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
