using System;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
[DisallowMultipleComponent]
public sealed class VIIIBitExplorerController : MonoBehaviour
{
    public const int MaxPaletteSize = 32;
    private const string UseSmoothstepKeyword = "_VIIIBIT_USE_SMOOTHSTEP";

    private static readonly int PaletteRgbId = Shader.PropertyToID("_PaletteRGB");
    private static readonly int PaletteLabId = Shader.PropertyToID("_PaletteLab");
    private static readonly int PaletteCountId = Shader.PropertyToID("_PaletteCount");
    private static readonly int OpacityId = Shader.PropertyToID("_Opacity");
    private static readonly int DownsamplingId = Shader.PropertyToID("_Downsampling");
    private static readonly int DitheringId = Shader.PropertyToID("_Dithering");

    [SerializeField]
    [Tooltip("The material assigned to the URP Full Screen Pass Renderer Feature.")]
    private Material targetMaterial;

    [SerializeField]
    [Tooltip("Palette colors interpreted as sRGB values. The supported size is 1 to 32.")]
    private Color[] paletteRGB =
    {
        new Color(0.000f, 0.000f, 0.000f),
        new Color(0.143f, 0.173f, 0.353f),
        new Color(0.494f, 0.145f, 0.325f),
        new Color(0.000f, 0.529f, 0.333f),
        new Color(0.671f, 0.322f, 0.212f),
        new Color(0.373f, 0.341f, 0.310f),
        new Color(0.761f, 0.765f, 0.780f),
        new Color(1.000f, 0.945f, 0.910f),
    };

    [SerializeField, Range(0.0f, 1.0f)]
    private float opacity = 1.0f;

    [SerializeField, Min(1)]
    private int downsampling = 4;

    [SerializeField, Range(0.0f, 1.0f)]
    private float dithering = 0.5f;

    [SerializeField]
    [Tooltip("Use smoothstep for secondary palette blending. Disable it to use a hard step.")]
    private bool useSmoothstep;

    // Always upload fixed-size buffers because Unity does not allow a material
    // vector array's capacity to change after it has been assigned.
    private readonly Vector4[] paletteRgbVectors = new Vector4[MaxPaletteSize];
    private readonly Vector4[] paletteLabVectors = new Vector4[MaxPaletteSize];

    public Material TargetMaterial
    {
        get => targetMaterial;
        set
        {
            targetMaterial = value;
            Apply();
        }
    }

    public IReadOnlyList<Color> PaletteRGB => paletteRGB;

    public int PaletteCount
    {
        get => paletteRGB?.Length ?? 0;
        set => SetPaletteCount(value);
    }

    public float Opacity
    {
        get => opacity;
        set
        {
            opacity = Mathf.Clamp01(value);
            Apply();
        }
    }

    public int Downsampling
    {
        get => downsampling;
        set
        {
            downsampling = Mathf.Max(1, value);
            Apply();
        }
    }

    public float Dithering
    {
        get => dithering;
        set
        {
            dithering = Mathf.Clamp01(value);
            Apply();
        }
    }

    public bool UseSmoothstep
    {
        get => useSmoothstep;
        set
        {
            useSmoothstep = value;
            Apply();
        }
    }

    private void OnEnable()
    {
        Apply();
    }

    private void OnValidate()
    {
        EnsureValidValues();
        Apply();
    }

    public void SetPalette(IReadOnlyList<Color> colors)
    {
        if (colors == null)
            throw new ArgumentNullException(nameof(colors));

        if (colors.Count < 1 || colors.Count > MaxPaletteSize)
        {
            throw new ArgumentException(
                $"The palette must contain between 1 and {MaxPaletteSize} colors.",
                nameof(colors)
            );
        }

        paletteRGB = new Color[colors.Count];

        for (int i = 0; i < colors.Count; i++)
            paletteRGB[i] = colors[i];

        Apply();
    }

    public void SetPaletteColor(int index, Color color)
    {
        EnsurePaletteSize();

        if (index < 0 || index >= paletteRGB.Length)
        {
            throw new ArgumentOutOfRangeException(
                nameof(index),
                index,
                $"Index must be between 0 and {paletteRGB.Length - 1}."
            );
        }

        paletteRGB[index] = color;
        Apply();
    }

    public void SetPaletteCount(int count)
    {
        int clampedCount = Mathf.Clamp(count, 1, MaxPaletteSize);
        EnsurePaletteSize();

        if (paletteRGB.Length != clampedCount)
            Array.Resize(ref paletteRGB, clampedCount);

        Apply();
    }

    [ContextMenu("Apply Settings")]
    public void Apply()
    {
        if (targetMaterial == null)
            return;

        EnsureValidValues();

        for (int i = 0; i < paletteRGB.Length; i++)
        {
            Color srgb = paletteRGB[i];
            Vector3 linearRgb = new Vector3(
                SrgbToLinear(srgb.r),
                SrgbToLinear(srgb.g),
                SrgbToLinear(srgb.b)
            );
            Vector3 lab = LinearRgbToOklab(linearRgb);

            paletteRgbVectors[i] = new Vector4(srgb.r, srgb.g, srgb.b, srgb.a);
            paletteLabVectors[i] = new Vector4(lab.x, lab.y, lab.z, 0.0f);
        }

        targetMaterial.SetVectorArray(PaletteRgbId, paletteRgbVectors);
        targetMaterial.SetVectorArray(PaletteLabId, paletteLabVectors);
        targetMaterial.SetInt(PaletteCountId, paletteRGB.Length);
        targetMaterial.SetFloat(OpacityId, opacity);
        targetMaterial.SetFloat(DownsamplingId, downsampling);
        targetMaterial.SetFloat(DitheringId, dithering);

        if (useSmoothstep)
            targetMaterial.EnableKeyword(UseSmoothstepKeyword);
        else
            targetMaterial.DisableKeyword(UseSmoothstepKeyword);
    }

    private void EnsureValidValues()
    {
        EnsurePaletteSize();
        opacity = Mathf.Clamp01(opacity);
        downsampling = Mathf.Max(1, downsampling);
        dithering = Mathf.Clamp01(dithering);
    }

    private void EnsurePaletteSize()
    {
        if (paletteRGB == null || paletteRGB.Length == 0)
            paletteRGB = new[] { Color.black };
        else if (paletteRGB.Length > MaxPaletteSize)
            Array.Resize(ref paletteRGB, MaxPaletteSize);
    }

    private static float SrgbToLinear(float value)
    {
        return value <= 0.04045f
            ? value / 12.92f
            : Mathf.Pow((value + 0.055f) / 1.055f, 2.4f);
    }

    private static Vector3 LinearRgbToOklab(Vector3 color)
    {
        float l = 0.4122214708f * color.x + 0.5363325363f * color.y + 0.0514459929f * color.z;
        float m = 0.2119034982f * color.x + 0.6806995451f * color.y + 0.1073969566f * color.z;
        float s = 0.0883024619f * color.x + 0.2817188376f * color.y + 0.6299787005f * color.z;

        float lRoot = SignedCubeRoot(l);
        float mRoot = SignedCubeRoot(m);
        float sRoot = SignedCubeRoot(s);

        return new Vector3(
            0.2104542553f * lRoot + 0.7936177850f * mRoot - 0.0040720468f * sRoot,
            1.9779984951f * lRoot - 2.4285922050f * mRoot + 0.4505937099f * sRoot,
            0.0259040371f * lRoot + 0.7827717662f * mRoot - 0.8086757660f * sRoot
        );
    }

    private static float SignedCubeRoot(float value)
    {
        return Mathf.Sign(value) * Mathf.Pow(Mathf.Abs(value), 1.0f / 3.0f);
    }
}
