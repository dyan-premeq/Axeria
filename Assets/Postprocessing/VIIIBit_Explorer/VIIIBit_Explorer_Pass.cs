using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// This pass creates an RTHandle and blits the camera color to it.
// The RTHandle is then set as a global texture, which is available to shaders in the scene.
public class VIIIBitExplorerPass : ScriptableRenderPass
{
    private static readonly int DownsamplingId = Shader.PropertyToID("_Downsampling");

    private ProfilingSampler m_ProfilingSampler = new ProfilingSampler("VIIIBitExplorerPass");
    private RTHandle cameraColorHandle;
    private RTHandle lowColorHandle;
    // private const string k_OutputName = "_LowPaletteTexture";
    // private int m_OutputId = Shader.PropertyToID(k_OutputName);
    private Material m_Material;

    public VIIIBitExplorerPass(Material mat)
    {
        renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
        m_Material = mat;
    }
    
    public void SetInput(RTHandle src)
    {
       // The Renderer Feature uses this variable to set the input RTHandle.
        cameraColorHandle = src;
    }

    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        // Configure the custom RTHandle
        var desc = cameraTextureDescriptor;
        int downsampling = Mathf.Max(
            1,
            Mathf.RoundToInt(m_Material.GetFloat(DownsamplingId))
        );
        desc.width = Mathf.Max(1, (desc.width + downsampling - 1) / downsampling);
        desc.height = Mathf.Max(1, (desc.height + downsampling - 1) / downsampling);
        
        desc.depthBufferBits = 0;
        desc.msaaSamples = 1;
        desc.useMipMap = false;
        desc.autoGenerateMips = false;
        
        RenderingUtils.ReAllocateIfNeeded(
            ref lowColorHandle,
            desc,
            FilterMode.Point,
            TextureWrapMode.Clamp,
            name: "_VIIIBitLowColor"
        );

        // Set the RTHandle as the output target
        ConfigureTarget(lowColorHandle);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer cmd = CommandBufferPool.Get("VIIIBit Explorer");
        using (new ProfilingScope(cmd, m_ProfilingSampler))
        {
            // Blit the input RTHandle to the output one
            Blitter.BlitCameraTexture(cmd, cameraColorHandle, lowColorHandle, m_Material, 0);
            
            // RenderBufferLoadAction.Load 在开始写 CameraColor 前，保留 CameraColor 里面已有的内容
            // RenderBufferStoreAction.Store 绘制完成后，保留新的 CameraColor 内容，供后续渲染或最终显示使用。
            Blitter.BlitCameraTexture(cmd, lowColorHandle, cameraColorHandle, RenderBufferLoadAction.Load, RenderBufferStoreAction.Store, m_Material, 1);

            // Make the output texture available for the shaders in the scene
            // cmd.SetGlobalTexture(m_OutputId, lowColorHandle.nameID);
        }
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }
    
    public void Dispose()
    {
        lowColorHandle?.Release();
        lowColorHandle = null;
        cameraColorHandle = null;
    }
}
