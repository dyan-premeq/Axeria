using UnityEngine;

namespace Axeria.TaaLab
{
    [DisallowMultipleComponent]
    public sealed class ConstantRotator : MonoBehaviour
    {
        public Vector3 eulerDegreesPerSecond = new Vector3(0f, 0f, 30f);

        private void Update()
        {
            transform.Rotate(eulerDegreesPerSecond * Time.deltaTime);
        }
    }
}
