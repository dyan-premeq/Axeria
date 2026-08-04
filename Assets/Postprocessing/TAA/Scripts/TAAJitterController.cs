using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
namespace Axeria.PostProcessingLab.TAA
{
    [RequireComponent(typeof(Camera))]
    public class TAAJitterController : MonoBehaviour
    {
        public float jitterPixelStrength = 1.0f;

        private Camera jitteringCamera;
        private bool hasLoggedRendering;

        private float dWidth, dHeight;
        private int jitterFrameIndex;

        private int JitterUvDeltaId = Shader.PropertyToID("_TAA_JitterUvDelta");

        [NonSerialized]public Vector2 jitterUvDelta;
        private Vector2 prevJitterNdc;
        
        private static readonly Vector2[] Halton23 =
        {
            new Vector2(0.0f, -1.0f / 3.0f),
            new Vector2(-1.0f / 2.0f, 1.0f / 3.0f),
            new Vector2(1.0f / 2.0f, -7.0f / 9.0f),
            new Vector2(-3.0f / 4.0f, -1.0f / 9.0f),
            new Vector2(1.0f / 4.0f, 5.0f / 9.0f),
            new Vector2(-1.0f / 4.0f, -5.0f / 9.0f),
            new Vector2(3.0f / 4.0f, 1.0f / 9.0f),
            new Vector2(-7.0f / 8.0f, 7.0f / 9.0f)
        };

        void Awake()
        {
            jitteringCamera = GetComponent<Camera>();
        }

        // Start is called before the first frame update
        void Start()
        {
            
        }

        // Update is called once per frame
        void Update()
        {
            
        }

        void OnDisable()
        {
            RenderPipelineManager.beginCameraRendering -= OnBeginCameraRendering;
            RenderPipelineManager.endCameraRendering -= OnEndCameraRendering;

            if (jitteringCamera != null) jitteringCamera.ResetProjectionMatrix();
        }

        // Called when：启用、attached，同时 play mode on
        void OnEnable()
        {
            jitteringCamera = GetComponent<Camera>();
            if(jitteringCamera == null) {
                Debug.Log($"TAA Jitter controller - camera not attached");
                return;
            }
            hasLoggedRendering = false;
            RenderPipelineManager.beginCameraRendering += OnBeginCameraRendering;
            RenderPipelineManager.endCameraRendering += OnEndCameraRendering;
            Debug.Log($"TAA Jitter controller - camera: {jitteringCamera.name}", this);  
        }

        void OnBeginCameraRendering(ScriptableRenderContext ctx, Camera renderingCamera)
        {
            if (renderingCamera != jitteringCamera) return;

            if (!hasLoggedRendering) {
                hasLoggedRendering = true;

                // Debug.Log($"TAA Jitter controller - URP 开始渲染：{renderingCamera.name}");
                Debug.Log($"TAA Jitter controller - URP 开始渲染：{renderingCamera.name}", this);
                // 加上 this ，可以在 Console 中点击日志时，Unity 能高亮定位到 Main Camera 上的这个组件。
            }
            dWidth = 1.0f / renderingCamera.pixelWidth;
            dHeight = 1.0f / renderingCamera.pixelHeight;

            Matrix4x4 jitteredProjection = renderingCamera.projectionMatrix;
            renderingCamera.nonJitteredProjectionMatrix = jitteredProjection;

            // float jitterPixelX = (jitterFrameIndex & 1) == 0 ? jitterPixelStrength : -jitterPixelStrength;
            // float jitterNdcX = 2f * jitterPixelX * dWidth; // NDC [-1,1]^2 so 一个像素跨过 2/width

            Vector2 haltonSample = Halton23[jitterFrameIndex & 7];
            
            float jitterNdcX = haltonSample.x * dWidth * jitterPixelStrength;
            float jitterNdcY = haltonSample.y * dHeight * jitterPixelStrength;
            
            Vector2 jitterNdc = new Vector2(jitterNdcX, jitterNdcY);
            jitterUvDelta = (jitterNdc - prevJitterNdc) * 0.5f;
            prevJitterNdc = jitterNdc;
            Shader.SetGlobalVector(JitterUvDeltaId, jitterUvDelta);

            jitteredProjection.m02 -= jitterNdcX;
            jitteredProjection.m12 -= jitterNdcY;
            

            // Matrix4x4 jitterMatrix = Matrix4x4.Translate(new Vector3(jitterNdcX, jitterNdcY, 0.0f)); 
            // // 这个是创建一个按照指定的 vector 平移的矩阵
            // renderingCamera.projectionMatrix = jitterMatrix * originalProjection;

            renderingCamera.projectionMatrix = jitteredProjection;
        }
        void OnEndCameraRendering(ScriptableRenderContext ctx, Camera renderingCamera)
        {
            if (renderingCamera != jitteringCamera) return;

            renderingCamera.ResetProjectionMatrix();
            jitterFrameIndex++;
        } 
    }
}

