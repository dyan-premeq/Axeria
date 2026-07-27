using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>
/// 创建一台隐藏相机，把画面渲染到 _PlanarReflectionTexture。
///
/// Game View 和 Scene View 各自拥有相机。脚本监听 beginCameraRendering，
/// 在其中得知“哪台相机马上要渲染”，再让隐藏反射相机先为它更新纹理。
/// 因此移动 Scene View 相机时，水面反射也会跟随 Scene View，而不是继续使用
/// Main Camera 的旧视角。
///
/// 脚本拥有反射相机和 RenderTexture 的完整生命周期：OnEnable 创建，
/// 分辨率变化时重建，OnDisable / OnDestroy 释放。它们不会保存进 Scene。
/// </summary>
// ExecuteAlways 让组件在 Edit Mode 也注册渲染回调，因而不进入 Play Mode
// 就能在 Scene View 预览反射。
[ExecuteAlways]
[DisallowMultipleComponent]
[AddComponentMenu("Rendering/Lividi Planar Reflection Controller")]
public sealed class PlanarReflectionController : MonoBehaviour
{
    public const string ReflectionTextureName = "_PlanarReflectionTexture";

    // PropertyToID 把属性名缓存成 int。之后调用 SetGlobalTexture 的 int 重载，
    // 不必在每次更新时重复查找字符串对应的 Shader 属性。
    private static readonly int ReflectionTextureId =
        Shader.PropertyToID(ReflectionTextureName);

    [Header("Scene References")]
    [SerializeField, Tooltip("Game View 使用的相机；留空时使用 Camera.main。Scene View 相机会自动处理。")]
    private Camera sourceCamera;

    [SerializeField, Tooltip("位置定义平面原点，Transform.up 定义平面法线；留空时使用当前物体。")]
    private Transform reflectionPlane;

    [SerializeField, Tooltip("反射相机绘制的 Layer。应排除水面自身。")]
    private LayerMask reflectionLayers = ~0;

    [Header("Reflection")]
    [SerializeField, Range(0.1f, 1.0f), Tooltip("反射纹理相对源相机的分辨率。")]
    private float renderScale = 0.5f;

    [SerializeField, Min(0.0f), Tooltip("斜裁剪平面沿法线偏移的距离。")]
    private float clipPlaneOffset = 0.05f;

    [SerializeField, Tooltip("是否在反射相机中重新渲染阴影。")]
    private bool renderShadows;

    // 这些引用不加 SerializeField，因为对象由脚本临时创建，不能成为 Scene 数据。
    private Camera reflectionCamera;
    private UniversalAdditionalCameraData reflectionCameraData;
    private RenderTexture gameReflectionTexture;
    private RenderTexture sceneReflectionTexture;
    private RenderTexture currentReflectionTexture;
    private bool isRenderingReflection;

    public RenderTexture ReflectionTexture => currentReflectionTexture;

    private Transform Plane => reflectionPlane != null ? reflectionPlane : transform;

    private void Reset()
    {
        reflectionPlane = transform;

        int waterLayer = LayerMask.NameToLayer("Water");
        reflectionLayers = waterLayer >= 0 ? ~(1 << waterLayer) : ~0;
    }

    private void OnEnable()
    {
        EnsureReflectionCamera();

        // beginCameraRendering 会在 URP 开始处理每台相机时触发。先 -= 再 +=，
        // 可以防止脚本重载或重复启用时意外注册两次同一个方法。
        RenderPipelineManager.beginCameraRendering -= OnBeginCameraRendering;
        RenderPipelineManager.beginCameraRendering += OnBeginCameraRendering;

        // SetGlobalTexture 会把纹理提供给所有使用同名属性的 Shader，而不是只给
        // 某一个 Material。真正的反射尚未渲染时先绑定黑色，避免引用旧 RT。
        Shader.SetGlobalTexture(ReflectionTextureId, Texture2D.blackTexture);
    }

    private void OnValidate()
    {
        renderScale = Mathf.Clamp(renderScale, 0.1f, 1.0f);
        clipPlaneOffset = Mathf.Max(0.0f, clipPlaneOffset);
    }

    private void OnBeginCameraRendering(
        ScriptableRenderContext context,
        Camera source)
    {
        // 手动渲染 reflectionCamera 时不能再次创建一层反射，否则会无限递归。
        // 当前只接受指定的 Game Camera 与 Unity 的 Scene View Camera；Preview、
        // Reflection 等编辑器内部相机不会触发额外渲染。
        if (isRenderingReflection || !ShouldRenderFor(source))
            return;

        EnsureReflectionCamera();
        RenderTexture target = GetReflectionTexture(source);
        if (target == null)
            return;

        CopyCameraSettings(source, target);
        UpdateReflectionTransform(source);
        UpdateObliqueClipPlane(source);

        // 反射相机保持 disabled，不参加 Unity 的普通相机队列。我们在源相机真正
        // 开始渲染前，使用当前 SRP context 立即渲染它，这样 Scene/Game 两个视图
        // 都会拿到与自己视角对应的纹理。
        isRenderingReflection = true;
        try
        {
            // URP 14 已把该 API 标记为 obsolete 并推荐 Render Request；但这里已经
            // 位于 beginCameraRendering，现有 context 能保证反射先于 source 完成，
            // 同时该 API 不会再次触发 beginCameraRendering，控制流更短、更直观。
#pragma warning disable CS0618
            UniversalRenderPipeline.RenderSingleCamera(context, reflectionCamera);
#pragma warning restore CS0618

            // 关闭自动生成后，每次反射完成时只显式更新一次整条 mip 链。
            // 水面随后才能用本帧画面按粗糙度选择不同清晰度。
            if (target.IsCreated() && target.mipmapCount > 1)
                target.GenerateMips();
        }
        finally
        {
            isRenderingReflection = false;
        }

        currentReflectionTexture = target;
        Shader.SetGlobalTexture(ReflectionTextureId, target);
    }

    private bool ShouldRenderFor(Camera candidate)
    {
        if (candidate == null || candidate == reflectionCamera)
            return false;

        if (candidate.cameraType == CameraType.SceneView)
            return true;

        if (candidate.cameraType != CameraType.Game)
            return false;

        Camera gameCamera = sourceCamera != null ? sourceCamera : Camera.main;
        return candidate == gameCamera;
    }

    private void EnsureReflectionCamera()
    {
        if (reflectionCamera != null)
            return;

        var cameraObject = new GameObject("Planar Reflection Camera")
        {
            // HideAndDontSave = 不出现在普通 Hierarchy 中，也不随 Scene/Prefab 保存。
            // 它并不等于自动释放，所以 OnDisable/OnDestroy 仍必须主动销毁对象。
            hideFlags = HideFlags.HideAndDontSave
        };

        // AddComponent<T> 返回刚创建的组件引用。先禁用 Camera，避免它在
        // targetTexture、位置和投影矩阵尚未配置好时意外渲染一帧。
        reflectionCamera = cameraObject.AddComponent<Camera>();
        reflectionCamera.enabled = false;

        // UniversalAdditionalCameraData 保存 URP 专属的相机设置，例如阴影、
        // 后处理以及是否生成 _CameraDepthTexture / _CameraOpaqueTexture。
        reflectionCameraData =
            cameraObject.AddComponent<UniversalAdditionalCameraData>();
        reflectionCameraData.renderType = CameraRenderType.Base;
    }

    private void CopyCameraSettings(Camera source, RenderTexture target)
    {
        // Camera.CopyFrom 复制 Camera 自身的常规渲染设置，例如 FOV、Aspect、
        // Near/Far、Clear Flags、背景色和 HDR。它不会复制 GameObject Transform，
        // 也不会替我们配置 UniversalAdditionalCameraData。
        reflectionCamera.CopyFrom(source);

        // targetTexture 非空时，相机把最终颜色写入 RT，而不是显示器。
        reflectionCamera.targetTexture = target;

        // RenderTexture 的像素宽高比可能不同于 Scene/Game 窗口。显式沿用源相机
        // aspect，保证反射投影与当前视图一致；RT 尺寸只影响采样清晰度。
        reflectionCamera.aspect = source.aspect;

        // LayerMask 实质是 32 位 bit mask。按位与表示：物体必须同时被源相机
        // 和 reflectionLayers 允许，才会进入反射相机的 Culling。
        reflectionCamera.cullingMask = source.cullingMask & reflectionLayers.value;

        // 这些选项不是反射成立的必要条件，只是在教学版中避免明显的额外成本。
        reflectionCamera.allowMSAA = false;
        reflectionCamera.allowDynamicResolution = false;
        reflectionCamera.useOcclusionCulling = false;

        reflectionCameraData.renderType = CameraRenderType.Base;
        reflectionCameraData.renderShadows = renderShadows;
        reflectionCameraData.renderPostProcessing = false;
        reflectionCameraData.requiresDepthTexture = false;
        reflectionCameraData.requiresColorTexture = false;
    }

    private void UpdateReflectionTransform(Camera source)
    {
        Vector3 planePosition = Plane.position;
        Vector3 planeNormal = Plane.up.normalized;
        Vector3 sourcePosition = source.transform.position;

        // Dot(sourcePosition - planePosition, planeNormal) 是点到平面的
        // “有符号距离”。这里 planeNormal 已归一化，所以不需要再除以 |normal|。
        // 点的镜像就是沿法线反向移动该距离的两倍。
        float distance = Vector3.Dot(sourcePosition - planePosition, planeNormal);
        Vector3 reflectedPosition =
            sourcePosition - 2.0f * distance * planeNormal;

        // Vector3.Reflect 实现 v' = v - 2 * dot(v, n) * n。
        // forward/up 是方向而不是位置，所以不需要考虑 planePosition。
        Vector3 reflectedForward =
            Vector3.Reflect(source.transform.forward, planeNormal);
        Vector3 reflectedUp =
            Vector3.Reflect(source.transform.up, planeNormal);

        // 重点：Quaternion 没有负责镜像，两个 Vector3 在上面已经镜像完了。
        // Quaternion.LookRotation(forward, up) 大致做了以下工作：
        //   Z = normalize(forward)
        //   X = normalize(cross(up, Z))
        //   Y = cross(Z, X)
        // 再把 X/Y/Z 组成的普通旋转基转换成 Quaternion。也就是说，它回答：
        // “怎样旋转相机，才能让本地 +Z 朝向 reflectedForward，并让本地 +Y
        // 尽量朝向 reflectedUp？”Quaternion 只是这个旋转的紧凑存储形式。
        // 因为这里使用的是普通旋转，而不是行列式为 -1 的反射 View Matrix，
        // 所以此版本不需要 GL.invertCulling。
        Quaternion reflectedRotation =
            Quaternion.LookRotation(reflectedForward, reflectedUp);

        reflectionCamera.transform.SetPositionAndRotation(
            reflectedPosition,
            reflectedRotation);
    }

    private void UpdateObliqueClipPlane(Camera source)
    {
        // ---------------- 为什么需要斜裁剪投影？ ----------------
        // 普通 Camera 的 Near Clip Plane 永远垂直于相机 forward。
        // 镜像后的相机位于水面另一侧，但我们真正想要的裁剪边界是“水面本身”。
        // 两个平面通常不平行，因此仅调整 nearClipPlane 数值无法解决问题。
        // Oblique Projection 会修改投影矩阵，让任意斜着的水面取代普通 Near Plane。

        Vector3 planePosition = Plane.position;
        Vector3 planeNormal = Plane.up.normalized;

        // (n, d) 与 (-n, -d) 描述同一个几何平面，但代表相反的正负半空间。
        // 裁剪必须知道保留哪一侧，所以让法线朝向源相机。
        if (Vector3.Dot(source.transform.position - planePosition, planeNormal) < 0.0f)
            planeNormal = -planeNormal;

        // 将裁剪面向观察者一侧推开少量距离，防止水面本身因为浮点误差
        // 一会儿被保留、一会儿被裁掉，从而产生闪烁。
        Vector3 offsetPosition =
            planePosition + planeNormal * clipPlaneOffset;

        // Camera.CalculateObliqueMatrix 要求传入“相机空间”的平面方程。
        // worldToCameraMatrix 正是 World Space -> Camera/View Space 的矩阵。
        Matrix4x4 worldToCamera = reflectionCamera.worldToCameraMatrix;

        // MultiplyPoint 把输入当作齐次坐标 (x,y,z,1)，所以会应用旋转和位移。
        // 平面上的参考点具有具体位置，必须受到相机位移影响。
        Vector3 positionCS = worldToCamera.MultiplyPoint(offsetPosition);

        // MultiplyVector 把输入当作 (x,y,z,0)，只应用旋转，不应用位移。
        // 法线表示方向；移动相机不应改变方向，因此这里不能用 MultiplyPoint。
        // 一般含非均匀缩放的矩阵需要用 inverse-transpose 变换法线；Camera 的
        // View Matrix 是旋转+位移的刚体变换，所以 MultiplyVector 后归一化即可。
        Vector3 normalCS =
            worldToCamera.MultiplyVector(planeNormal).normalized;

        // ---------------- 为什么 normalCS 能构建平面方程？ ----------------
        // normalCS 不能“单独”确定完整平面：它只确定朝向；positionCS 提供位置。
        // 对任意平面上的点 x，向量 (x - positionCS) 必须与法线垂直：
        //
        //   dot(normalCS, x - positionCS) = 0
        //   dot(normalCS, x) - dot(normalCS, positionCS) = 0
        //
        // 展开 dot(normalCS, x) 就得到标准平面方程：
        //
        //   a*x + b*y + c*z + d = 0
        //   (a,b,c) = normalCS
        //   d = -dot(normalCS, positionCS)
        //
        // 因此 Vector4 的 xyz 来自法线，w 来自“法线与平面上一点”的点积。
        Vector4 clipPlaneCS = new Vector4(
            normalCS.x,
            normalCS.y,
            normalCS.z,
            -Vector3.Dot(positionCS, normalCS));

        // ---------------- CalculateObliqueMatrix 做了什么？ ----------------
        // 普通 Projection Matrix 会把 Camera Space 的视锥体映射到 Clip Space，
        // GPU 再依据 Clip Space 的 near 边界裁掉几何体。这个 API 修改投影矩阵中
        // 控制 clip-space Z 的部分，使上面的 clipPlaneCS 恰好映射到 near 边界。
        // 于是：平面上的点落在 Near Plane，一侧保留，另一侧被硬件裁剪。
        //
        // CopyFrom 已让 reflectionCamera 拥有与源相机相同的 FOV/Aspect 投影；
        // CalculateObliqueMatrix 返回修改后的新矩阵，赋给 projectionMatrix 才生效。
        reflectionCamera.projectionMatrix =
            reflectionCamera.CalculateObliqueMatrix(clipPlaneCS);
    }

    private RenderTexture GetReflectionTexture(Camera source)
    {
        // Game View 与 Scene View 通常尺寸不同。若共用一个要求尺寸完全匹配的 RT，
        // 两个窗口每次渲染都会互相触发重建，所以这里各自持有一张纹理。
        if (source.cameraType == CameraType.SceneView)
        {
            EnsureReflectionTexture(
                source,
                ref sceneReflectionTexture,
                "Scene View Planar Reflection Texture");
            return sceneReflectionTexture;
        }

        EnsureReflectionTexture(
            source,
            ref gameReflectionTexture,
            "Game View Planar Reflection Texture");
        return gameReflectionTexture;
    }

    private void EnsureReflectionTexture(
        Camera source,
        ref RenderTexture texture,
        string textureName)
    {
        int width =
            Mathf.Max(1, Mathf.RoundToInt(source.pixelWidth * renderScale));
        int height =
            Mathf.Max(1, Mathf.RoundToInt(source.pixelHeight * renderScale));
        RenderTextureFormat format = source.allowHDR
            ? RenderTextureFormat.DefaultHDR
            : RenderTextureFormat.Default;

        // RenderTexture.IsCreated 检查底层 GPU 资源是否仍然有效；仅有一个非空的
        // C# RenderTexture 引用，并不保证显存对象已经创建或没有丢失。
        bool reusable = texture != null &&
                        texture.IsCreated() &&
                        texture.width == width &&
                        texture.height == height &&
                        texture.format == format &&
                        texture.useMipMap &&
                        !texture.autoGenerateMips &&
                        texture.filterMode == FilterMode.Trilinear;
        if (reusable)
            return;

        ReleaseReflectionTexture(ref texture);

        // 构造参数中的 24 是深度缓冲位数，不是颜色精度。深度缓冲用于反射相机
        // 正常执行 Z Test；最终发布给水面 Shader 的仍然是颜色纹理。
        texture = new RenderTexture(width, height, 24, format)
        {
            name = textureName,
            hideFlags = HideFlags.HideAndDontSave,
            filterMode = FilterMode.Trilinear,
            wrapMode = TextureWrapMode.Clamp,
            antiAliasing = 1,
            useMipMap = true,
            autoGenerateMips = false
        };

        // new RenderTexture 创建的是 Unity 对象；Create 才明确申请底层 GPU 资源。
        if (texture.Create())
            return;

        Debug.LogError("无法创建平面反射 RenderTexture。", this);
        ReleaseReflectionTexture(ref texture);
    }

    private void OnDisable()
    {
        RenderPipelineManager.beginCameraRendering -= OnBeginCameraRendering;
        ReleaseResources();
    }

    private void OnDestroy()
    {
        RenderPipelineManager.beginCameraRendering -= OnBeginCameraRendering;
        ReleaseResources();
    }

    private void ReleaseResources()
    {
        Shader.SetGlobalTexture(ReflectionTextureId, Texture2D.blackTexture);
        currentReflectionTexture = null;
        ReleaseReflectionTexture(ref gameReflectionTexture);
        ReleaseReflectionTexture(ref sceneReflectionTexture);

        if (reflectionCamera == null)
            return;

        GameObject cameraObject = reflectionCamera.gameObject;
        reflectionCamera.enabled = false;
        reflectionCamera = null;
        reflectionCameraData = null;
        DestroyUnityObject(cameraObject);
    }

    private void ReleaseReflectionTexture(ref RenderTexture texture)
    {
        if (texture == null)
            return;

        if (reflectionCamera != null && reflectionCamera.targetTexture == texture)
            reflectionCamera.targetTexture = null;

        // Release 释放 GPU 资源，Destroy/DestroyImmediate 销毁 Unity 对象；
        // 两者职责不同，所以这里都要执行。
        if (texture.IsCreated())
            texture.Release();

        DestroyUnityObject(texture);
        texture = null;
    }

    private static void DestroyUnityObject(Object target)
    {
        if (target == null)
            return;

        // Play Mode 中 Destroy 延迟到本帧结束，符合 Unity 对象生命周期规则；
        // Edit Mode 没有同样的帧循环，应使用 DestroyImmediate 立即清理临时对象。
        if (Application.isPlaying)
            Destroy(target);
        else
            DestroyImmediate(target);
    }
}
