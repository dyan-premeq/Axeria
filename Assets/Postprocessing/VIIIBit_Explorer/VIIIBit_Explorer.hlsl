SAMPLER(sampler_BlitTexture);
float4 _BlitTexture_TexelSize;
static const half bayer2x2[] = { -0.5, 0, 0.25, -0.25 };
static const half bayer4x4[] = { -0.5, 0.0, -0.375, 0.125, 0.25, -0.25, 0.375, -0.125, -0.3125, 0.1875, -0.4375, 0.0625, 0.4375, -0.0625, 0.3125, -0.187 };
#define MAX_PALETTE_SIZE 32

half _Opacity;
float4 _PaletteLab[MAX_PALETTE_SIZE]; // OKLab. Controlled by C#.
float4 _PaletteRGB[MAX_PALETTE_SIZE]; // sRGB. Controlled by C#.
int _PaletteCount;

uint _Downsampling;
float _Dithering;

// Linear sRGB to OKLab
half3 ec_LinearToOKLab(half3 c)
{
    half3x3 rgb2lms = half3x3(
        0.4122214708, 0.5363325363, 0.0514459929,
        0.2119034982, 0.6806995451, 0.1073969566,
        0.0883024619, 0.2817188376, 0.6299787005
    );
    half3x3 lms2lab = half3x3(
        0.2104542553, 0.7936177850, -0.0040720468,
        1.9779984951, -2.4285922050, 0.4505937099,
        0.0259040371, 0.7827717662, -0.8086757660
    );
    float3 lms = mul(rgb2lms, c);
    return mul(lms2lab, sign(lms) * pow(abs(lms), 1.0 / 3));
}

float GetDist(half3 a, half3 b)
{
    return dot(a-b, a-b);
}

half InterleavedGradientNoise(uint2 position)
{
    float2 p = position;
    return frac(52.9829189 * frac(dot(p, float2(0.06711056, 0.00583715))));
}
  

half4 Frag(Varyings IN) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
    // uint2 texelLoc = IN.texcoord * _BlitTexture_TexelSize.zw;
    uint2 gridLoc = IN.texcoord * _BlitTexture_TexelSize.zw / _Downsampling;
    float2 downsampledUV = (gridLoc + .5) * _Downsampling * _BlitTexture_TexelSize.xy;

    half dither = bayer2x2[(gridLoc.y & 1) * 2 + (gridLoc.x & 1)] * _Dithering;
    // half dither_texel = bayer2x2[(texelLoc.y & 1) * 2 + (texelLoc.x & 1)] * _Dithering;
    // half dither4x4 = bayer4x4[(gridLoc.y & 3) * 4 + (gridLoc.x & 3)] * _Dithering;
    // half ditherRan = (InterleavedGradientNoise(gridLoc) - 0.5) * _Dithering;
    
    
    half4 src = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, downsampledUV);
    half3 src_linear = saturate(src.rgb + dither);
    // half3 src_gamma = LinearToSRGB(src_linear);
    half3 src_lab = ec_LinearToOKLab(src_linear);

    float best_dist = GetDist(src_lab, _PaletteLab[0].rgb);
    half3 best_gamma = _PaletteRGB[0].rgb;
    half3 best_lab = _PaletteLab[0].rgb;
    half3 secondary_gamma = 0;
    half3 secondary_lab = 0;
    
    
    int paletteCount = clamp(_PaletteCount, 1, MAX_PALETTE_SIZE);
    UNITY_LOOP
    for (int i = 1; i < paletteCount; ++i)
    {
        half dist = GetDist(src_lab, _PaletteLab[i].rgb);
        if (dist < best_dist)
        {
            // secondary_dist = best_dist;
            secondary_lab = best_lab;
            secondary_gamma = best_gamma;
            best_dist = dist;
            best_gamma = _PaletteRGB[i].rgb;
            best_lab = _PaletteLab[i].rgb;
        }
    }
    float3 direction = secondary_lab - best_lab;
    float weightB = saturate(
        dot(src_lab - best_lab, direction) /
        max(dot(direction, direction), 1e-5)
    );
    float threshold = bayer2x2[(gridLoc.y & 1) * 2 + (gridLoc.x & 1)] + 0.625;
    
    float tt = smoothstep(0, threshold, weightB);
    // tt = step(threshold, weightB);
    half3 final_gamma = lerp(best_gamma,secondary_gamma,  tt);

    half4 originalColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, IN.texcoord);
    return lerp(originalColor, half4(SRGBToLinear(final_gamma), src.a), _Opacity);
}
