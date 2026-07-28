using UnityEngine;

[DisallowMultipleComponent]
public sealed class RectangularLapMover : MonoBehaviour
{
    [SerializeField]
    private GameObject plane1;

    [SerializeField]
    private GameObject plane3;

    [SerializeField, Min(0.0f)]
    private float speed = 4.0f;

    [SerializeField, Min(0.0f)]
    private float height = 0.6f;

    [SerializeField, Min(0.0f)]
    private float edgeInset = 1.0f;

    private readonly Vector3[] corners = new Vector3[4];
    private float distanceTravelled;

    private void OnEnable()
    {
        distanceTravelled = 0.0f;

        if (TryBuildPath(out _))
            transform.position = corners[0];
    }

    private void Update()
    {
        if (!TryBuildPath(out float perimeter) || perimeter <= Mathf.Epsilon)
            return;

        distanceTravelled = Mathf.Repeat(
            distanceTravelled + speed * Time.deltaTime,
            perimeter
        );

        transform.position = EvaluatePath(distanceTravelled);
    }

    private bool TryBuildPath(out float perimeter)
    {
        perimeter = 0.0f;

        if (plane1 == null || plane3 == null)
            return false;

        Renderer firstRenderer = plane1.GetComponent<Renderer>();
        Renderer secondRenderer = plane3.GetComponent<Renderer>();

        if (firstRenderer == null || secondRenderer == null)
            return false;

        Bounds combinedBounds = firstRenderer.bounds;
        combinedBounds.Encapsulate(secondRenderer.bounds);

        float inset = Mathf.Min(
            edgeInset,
            Mathf.Min(combinedBounds.size.x, combinedBounds.size.z) * 0.49f
        );
        float minX = combinedBounds.min.x + inset;
        float maxX = combinedBounds.max.x - inset;
        float minZ = combinedBounds.min.z + inset;
        float maxZ = combinedBounds.max.z - inset;
        float y = combinedBounds.max.y + height;

        // Viewed from above (+Y), this order travels counter-clockwise.
        corners[0] = new Vector3(minX, y, minZ);
        corners[1] = new Vector3(maxX, y, minZ);
        corners[2] = new Vector3(maxX, y, maxZ);
        corners[3] = new Vector3(minX, y, maxZ);

        perimeter = 2.0f * ((maxX - minX) + (maxZ - minZ));
        return true;
    }

    private Vector3 EvaluatePath(float distance)
    {
        for (int index = 0; index < corners.Length; index++)
        {
            Vector3 start = corners[index];
            Vector3 end = corners[(index + 1) % corners.Length];
            float segmentLength = Vector3.Distance(start, end);

            if (distance <= segmentLength)
                return Vector3.Lerp(start, end, distance / segmentLength);

            distance -= segmentLength;
        }

        return corners[0];
    }

    private void OnValidate()
    {
        speed = Mathf.Max(0.0f, speed);
        height = Mathf.Max(0.0f, height);
        edgeInset = Mathf.Max(0.0f, edgeInset);
    }
}
