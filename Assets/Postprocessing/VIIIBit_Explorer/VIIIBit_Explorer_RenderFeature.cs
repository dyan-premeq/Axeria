using UnityEngine;
using UnityEngine.Rendering.Universal;

public sealed class VIIIBitExplorerRenderFeature : ScriptableRendererFeature
{
    [SerializeField]
    private Material material;
    private VIIIBitExplorerPass pass;

    public override void Create()
    {
        pass = new VIIIBitExplorerPass(material);
    }
    
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // if (renderingData.cameraData.cameraType != CameraType.Game)
        // return;
        
        renderer.EnqueuePass(pass);
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        // if (renderingData.cameraData.cameraType != CameraType.Game)
        // return;
        
        pass.SetInput(renderer.cameraColorTargetHandle);
    }

    protected override void Dispose(bool disposing)
    {
        pass?.Dispose();
        pass = null;
    }
}
