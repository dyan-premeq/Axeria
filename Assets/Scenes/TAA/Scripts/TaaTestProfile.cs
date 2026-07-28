using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace Axeria.TaaLab
{
    [CreateAssetMenu(fileName = "TaaTestProfile", menuName = "Axeria/TAA Lab/Test Profile")]
    public sealed class TaaTestProfile : ScriptableObject
    {
        [Min(1)] public int width = 640;
        [Min(1)] public int height = 360;
        public UniversalRenderPipelineAsset pipelineAsset;
        public bool disableMsaa = true;
        public bool disableBuiltInPostProcessAntiAliasing = true;
    }
}
