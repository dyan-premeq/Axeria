using UnityEngine;

namespace Axeria.TaaLab
{
    // 可重复相机路径：同一模式与参数下，每次 Play 的轨迹完全一致（正弦基于 Time.time，从 0 开始）。
    // Static = 固定机位；Strafe = 沿世界 X 横移（背景重投影观察）；Dolly = 沿世界 Z 前后（深度失效误报观察）。
    [DisallowMultipleComponent]
    public sealed class CameraPathDriver : MonoBehaviour
    {
        public enum PathMode { Static, Strafe, Dolly }

        public PathMode mode = PathMode.Static;
        [Min(0f)] public float amplitude = 1.5f;
        [Min(0.01f)] public float periodSeconds = 6f;

        private Vector3 basePosition;

        private void OnEnable()
        {
            basePosition = transform.localPosition;
        }

        private void Update()
        {
            if (mode == PathMode.Static)
            {
                transform.localPosition = basePosition;
                return;
            }

            float offset = amplitude * Mathf.Sin(2f * Mathf.PI * Time.time / periodSeconds);
            Vector3 axis = mode == PathMode.Strafe ? Vector3.right : Vector3.forward;
            transform.localPosition = basePosition + axis * offset;
        }
    }
}
