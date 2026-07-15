#ifndef LIVIDI_WATER_SPACE_INCLUDED
#define LIVIDI_WATER_SPACE_INCLUDED

#include "WaterCommon.hlsl"

// Forward Pass 只需要一个 normalWS，它不关心是来自 uv0 / worldspace UV / Planet Triplanar

// 一般模式： Worldspace UV， uv = worldpos.xz
// 行星模式： （还没做，先不做，后面开始）

struct WaterSurfaceBasis
{
    float3 tangentWS; // +T
    float3 bitangentWS; // +B
    float3 normalWS;
    float valid;
};

struct WaterSurfaceContext
{
    float3 positionWS;

    // 一般等于 positionWS；
    // 行星模式下等于 positionWS - _PlanetCenter.xyz。
    float3 mappingPositionWS;

    // 真实网格或顶点波浪产生的表面法线，最终法线应围绕它扰动
    half3 geometricNormalWS;
    
    // 稳定的水面方向。
    // 行星模式下是径向方向，用来计算 Triplanar 权重、深度和岸线方向
    half3 waterUpWS;

    // 当前像素采样纹理时用的 UV 坐标 (UV0, worldpos.xz, ...)
    float2 planarUV; 
    WaterSurfaceBasis planarBasis;
};


WaterSurfaceBasis BuildPlanarWaterBasis(
    float3 positionWS,
    float2 planarUV,
    half3 geometricNormalWS
)
{
    WaterSurfaceBasis basis = (WaterSurfaceBasis)0;
    basis.normalWS = SafeNormalize((float3)geometricNormalWS);

    float3 dPdx = ddx(positionWS);
    float3 dPdy = ddy(positionWS);
    float2 duvdx = ddx(planarUV); //dudx = duvdx.x, dvdx = duvdx.y
    float2 duvdy = ddy(planarUV);

    float determinant = duvdx.x * duvdy.y
        - duvdx.y * duvdy.x;
    float determinantSign = determinant < 0.0 ? -1.0 : 1.0; // 只要符号，因为不关心数值，要归一化
    
    float3 tangentWS = determinantSign * (
        dPdx * duvdy.y
        - dPdy * duvdx.y
    ); // T = dPdu
    float3 bitangentWS = determinantSign * (
        dPdy * duvdx.x
        - dPdx * duvdy.x
    ); // B = dPdv

    tangentWS -= basis.normalWS * dot(basis.normalWS, tangentWS);
    bitangentWS -= basis.normalWS * dot(basis.normalWS, bitangentWS);

    float uvDerivativeScaleSq = dot(duvdx, duvdx)
        * dot(duvdy, duvdy);
    float uvAreaSq = determinant * determinant;
    float tangentLengthSq = dot(tangentWS, tangentWS);

    if (uvDerivativeScaleSq > FLT_MIN
        && uvAreaSq > uvDerivativeScaleSq * FLT_EPS
        && tangentLengthSq > FLT_MIN)
    {
        tangentWS *= rsqrt(tangentLengthSq);
        bitangentWS -= tangentWS * dot(tangentWS, bitangentWS);

        float bitangentLengthSq = dot(bitangentWS, bitangentWS);
        if (bitangentLengthSq > FLT_MIN)
        {
            basis.tangentWS = tangentWS;
            basis.bitangentWS = bitangentWS * rsqrt(bitangentLengthSq);
            basis.valid = 1.0;
        }
    }

    return basis;
}

half3 ResolvePlanarWaterNormalWS(
    half3 normalTS,
    WaterSurfaceBasis basis
)
{
    if (basis.valid < 0.5)
    {
        return (half3)basis.normalWS;
    }

    float3 normalWS = normalTS.x * basis.tangentWS
        + normalTS.y * basis.bitangentWS
        + normalTS.z * basis.normalWS;

    return (half3)SafeNormalize(normalWS);
}

WaterSurfaceContext BuildWaterSurfaceContext(Varyings input)
{
    WaterSurfaceContext context = (WaterSurfaceContext)0;
    context.positionWS = input.positionWS;
    context.mappingPositionWS = input.positionWS;
    context.geometricNormalWS = (half3)SafeNormalize((float3)input.normalWS);
    context.waterUpWS = (half3)GetWaterUpWS(input.positionWS, input.objectUpWS);
    context.planarUV = context.mappingPositionWS.xz * 0.1;
    context.planarBasis = BuildPlanarWaterBasis(
        context.positionWS,
        context.planarUV,
        context.geometricNormalWS
    );

    return context;
}

#endif
