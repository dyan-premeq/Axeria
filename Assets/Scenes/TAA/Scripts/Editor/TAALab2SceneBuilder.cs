using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using Axeria.PostProcessingLab.TAA;

namespace Axeria.TaaLab
{
    // 一键构建 TAA_Lab_2_Detection：关卡 7（深度 disocclusion 检测）与关卡 8（AABB Clamp 对照）的验收布景。
    // 可重复运行；会整体覆盖同名场景文件。材质资产已存在时直接复用，不改参数。
    public static class TAALab2SceneBuilder
    {
        private const string SceneDir = "Assets/Scenes/TAA";
        private const string ScenePath = SceneDir + "/TAA_Lab_2_Detection.unity";

        [MenuItem("Axeria/TAA/Build TAA_Lab_2_Detection Scene")]
        public static void Build()
        {
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())
                return;

            Texture2D checkerTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(SceneDir + "/BlackWhiteChecker.png");
            // 地面用 Lit 版棋盘：Lab 2 需要接收球体的移动阴影（关卡 8C 的着色变化案例），Unlit 的 Chessboard.mat 做不到。
            // tiling 1.5 让 30m 地面的格子密度与 Lab 1（10m、tiling 0.5）一致。
            Material chessboardLit = LoadOrCreateLitMaterial(SceneDir + "/TAALab2_ChessboardLit.mat", Color.white, 0.05f, checkerTexture, new Vector2(1.5f, 1.5f));
            Material wallGray = LoadOrCreateLitMaterial(SceneDir + "/TAALab2_WallGray.mat", new Color(0.62f, 0.62f, 0.62f), 0.1f, null, Vector2.one);
            Material barDark = LoadOrCreateLitMaterial(SceneDir + "/TAALab2_BarDark.mat", new Color(0.04f, 0.04f, 0.045f), 0.2f, null, Vector2.one);
            Material sphereLit = LoadOrCreateLitMaterial(SceneDir + "/TAALab2_SphereLit.mat", new Color(1f, 0.3f, 0.05f), 0.35f, null, Vector2.one);
            TaaTestProfile profile = AssetDatabase.LoadAssetAtPath<TaaTestProfile>(SceneDir + "/TAA_Lab_1_Static_TAA_TestProfile.asset");

            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);

            // 相机：Jitter + Profile 应用 + 可重复路径。far 压到 40，Linear01 深度灰度才有可读的梯度。
            Camera camera = Camera.main;
            camera.transform.SetPositionAndRotation(new Vector3(0f, 2.5f, -2f), Quaternion.Euler(10f, 0f, 0f));
            camera.nearClipPlane = 0.3f;
            camera.farClipPlane = 40f;
            camera.GetUniversalAdditionalCameraData().antialiasing = AntialiasingMode.None;
            camera.gameObject.AddComponent<TAAJitterController>();
            TaaTestProfileApplier applier = camera.gameObject.AddComponent<TaaTestProfileApplier>();
            SerializedObject applierSo = new SerializedObject(applier);
            applierSo.FindProperty("profile").objectReferenceValue = profile;
            applierSo.ApplyModifiedPropertiesWithoutUndo();
            camera.gameObject.AddComponent<CameraPathDriver>();

            Light light = Object.FindObjectOfType<Light>();
            light.transform.rotation = Quaternion.Euler(50f, -30f, 0f);
            light.shadows = LightShadows.Soft;

            GameObject floor = GameObject.CreatePrimitive(PrimitiveType.Plane);
            floor.name = "Floor_Checker";
            floor.transform.position = new Vector3(0f, 0f, 8f);
            floor.transform.localScale = new Vector3(3f, 1f, 3f);
            floor.GetComponent<MeshRenderer>().sharedMaterial = chessboardLit;

            // 均匀灰墙：disocclusion 拖影与 mask 边界在无纹理背景上最清楚，也是 Clamp 收敛最快的对照面。
            CreateCube("BackWall_Gray", new Vector3(0f, 3f, 16f), new Vector3(24f, 6f, 0.3f), Quaternion.identity, wallGray, null);

            // 细杆阵：亚像素级细结构，观察 Jitter 闪烁、时域积累收益与 Clamp 过度裁切。
            for (int i = 0; i < 5; i++)
                CreateCube($"ThinBar_{i}", new Vector3(-5.2f + 0.5f * i, 1.25f, 11.5f), new Vector3(0.06f, 2.5f, 0.06f), Quaternion.identity, barDark, null);

            // 旋转细十字：持续物体 Motion Vector 源，贴着灰墙背景。
            GameObject cross = new GameObject("RotatingCross");
            cross.transform.position = new Vector3(6.5f, 1.8f, 15.2f);
            for (int i = 0; i < 3; i++)
                CreateCube($"Arm_{i}", Vector3.zero, new Vector3(0.08f, 3.2f, 0.08f), Quaternion.Euler(0f, 0f, 60f * i), barDark, cross.transform);
            cross.AddComponent<ConstantRotator>();

            // 深度阶梯：7A 深度可视化的灰度台阶（far=40 下约 0.11/0.19/0.26/0.35）。
            CreateCube("DepthStep_A", new Vector3(2.5f, 0.5f, 4.5f), Vector3.one, Quaternion.identity, wallGray, null);
            CreateCube("DepthStep_B", new Vector3(3.2f, 0.5f, 7.5f), Vector3.one, Quaternion.identity, wallGray, null);
            CreateCube("DepthStep_C", new Vector3(3.9f, 0.5f, 10.5f), Vector3.one, Quaternion.identity, wallGray, null);
            CreateCube("DepthStep_D", new Vector3(4.6f, 0.5f, 14f), Vector3.one, Quaternion.identity, wallGray, null);

            // 两个角标定义 RectangularLapMover 的包围盒：环绕中景道具的矩形跑道，
            // 近边从所有道具前经过（前景遮挡背景），远边从阶梯与细杆后经过（被前景遮挡）。
            GameObject markerA = CreateCube("LapMarker_A", new Vector3(-7f, 0.1f, 2.2f), new Vector3(0.2f, 0.2f, 0.2f), Quaternion.identity, barDark, null);
            GameObject markerB = CreateCube("LapMarker_B", new Vector3(7f, 0.1f, 13.5f), new Vector3(0.2f, 0.2f, 0.2f), Quaternion.identity, barDark, null);

            GameObject sphere = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            sphere.name = "SphereRunner";
            sphere.transform.position = new Vector3(0f, 1.2f, 3.2f);
            sphere.GetComponent<MeshRenderer>().sharedMaterial = sphereLit;
            RectangularLapMover mover = sphere.AddComponent<RectangularLapMover>();
            SerializedObject moverSo = new SerializedObject(mover);
            moverSo.FindProperty("plane1").objectReferenceValue = markerA;
            moverSo.FindProperty("plane3").objectReferenceValue = markerB;
            moverSo.FindProperty("height").floatValue = 1f;
            moverSo.ApplyModifiedPropertiesWithoutUndo();

            EditorSceneManager.SaveScene(scene, ScenePath);
            Debug.Log($"[TAALab2] 场景已生成并保存：{ScenePath}");
        }

        private static GameObject CreateCube(string name, Vector3 localPosition, Vector3 localScale, Quaternion localRotation, Material material, Transform parent)
        {
            GameObject cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
            cube.name = name;
            cube.transform.SetParent(parent, false);
            cube.transform.localPosition = localPosition;
            cube.transform.localRotation = localRotation;
            cube.transform.localScale = localScale;
            cube.GetComponent<MeshRenderer>().sharedMaterial = material;
            return cube;
        }

        private static Material LoadOrCreateLitMaterial(string path, Color baseColor, float smoothness, Texture2D baseMap, Vector2 tiling)
        {
            Material material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material != null)
                return material;

            material = new Material(Shader.Find("Universal Render Pipeline/Lit"));
            material.SetColor("_BaseColor", baseColor);
            material.SetFloat("_Smoothness", smoothness);
            if (baseMap != null)
            {
                material.SetTexture("_BaseMap", baseMap);
                material.SetTextureScale("_BaseMap", tiling);
            }
            AssetDatabase.CreateAsset(material, path);
            return material;
        }
    }
}
