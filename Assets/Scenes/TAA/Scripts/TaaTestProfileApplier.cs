using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Axeria.TaaLab
{
    [DisallowMultipleComponent]
    [RequireComponent(typeof(Camera))]
    public sealed class TaaTestProfileApplier : MonoBehaviour
    {
        [SerializeField] private TaaTestProfile profile;

        private RenderPipelineAsset previousPipelineAsset;
        private int previousQualityMsaa;
        private bool previousCameraAllowMsaa;
        private AntialiasingMode previousPostProcessAntiAliasing;
        private bool applied;

        private void OnEnable()
        {
            if (!Application.isPlaying || profile == null)
            {
                return;
            }

            Camera targetCamera = GetComponent<Camera>();
            UniversalAdditionalCameraData cameraData = GetComponent<UniversalAdditionalCameraData>();

            previousPipelineAsset = QualitySettings.renderPipeline;
            previousQualityMsaa = QualitySettings.antiAliasing;
            previousCameraAllowMsaa = targetCamera.allowMSAA;

            if (cameraData != null)
            {
                previousPostProcessAntiAliasing = cameraData.antialiasing;
            }

            if (profile.disableMsaa)
            {
                QualitySettings.antiAliasing = 0;
                targetCamera.allowMSAA = false;
            }

            if (profile.disableBuiltInPostProcessAntiAliasing && cameraData != null)
            {
                cameraData.antialiasing = AntialiasingMode.None;
            }

            if (profile.pipelineAsset != null)
            {
                QualitySettings.renderPipeline = profile.pipelineAsset;
            }

            Screen.SetResolution(profile.width, profile.height, FullScreenMode.Windowed);
            applied = true;
        }

        private void OnDisable()
        {
            if (!applied || !Application.isPlaying)
            {
                return;
            }

            Camera targetCamera = GetComponent<Camera>();
            UniversalAdditionalCameraData cameraData = GetComponent<UniversalAdditionalCameraData>();

            QualitySettings.renderPipeline = previousPipelineAsset;
            QualitySettings.antiAliasing = previousQualityMsaa;
            targetCamera.allowMSAA = previousCameraAllowMsaa;

            if (cameraData != null)
            {
                cameraData.antialiasing = previousPostProcessAntiAliasing;
            }

            applied = false;
        }
    }
}
