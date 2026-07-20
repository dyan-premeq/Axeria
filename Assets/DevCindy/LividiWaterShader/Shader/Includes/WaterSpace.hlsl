#ifndef LIVIDI_WATER_SPACE_INCLUDED
#define LIVIDI_WATER_SPACE_INCLUDED

#include "WaterCommon.hlsl"

// BuildWaterSurfaceContext() owns the mapping setup for the current water
// space. Surface sampling consumes that context and exposes only normalWS to
// lighting.
//
// Currently supported mapping:
// - Planar: world-space XZ coordinates, preserving the existing material look.
//
// Planet mapping is intentionally deferred. When it is added, build its
// mapping here and keep the forward-lighting interface unchanged.

struct WaterSurfaceBasis
{
    float3 tangentWS; // +T
    float3 bitangentWS; // +B
    float3 normalWS;
    float valid;
};

struct WaterPlanarMapping
{
    float2 uv;
    WaterSurfaceBasis basis;
};

struct WaterSurfaceContext
{
    float3 positionWS;

    // 一般等于 positionWS；
    // 行星模式下等于 positionWS - _PlanetCenter.xyz。
    float3 mappingPositionWS;

    // 真实网格或顶点波浪产生的表面法线，最终法线应围绕它扰动
    float3 geometricNormalWS;
    
    // 当前水体空间使用的，稳定的水面竖直方向。
    // 行星模式下是径向方向，用来计算 Triplanar 权重、深度和岸线方向
    // ResolveWaterReferenceUpWS() 计算
    float3 referenceUpWS;

    WaterPlanarMapping planarMapping;
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

WaterPlanarMapping BuildPlanarWaterMapping(
    float3 positionWS,
    float3 mappingPositionWS,
    half3 geometricNormalWS
)
{
    WaterPlanarMapping mapping = (WaterPlanarMapping)0;
    mapping.uv = mappingPositionWS.xz * 0.1;
    mapping.basis = BuildPlanarWaterBasis(
        positionWS,
        mapping.uv,
        geometricNormalWS
    );

    return mapping;
}

half3 ResolvePlanarWaterNormalWS(
    half3 normalTS,
    WaterPlanarMapping mapping
)
{
    WaterSurfaceBasis basis = mapping.basis;

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
    context.geometricNormalWS = SafeNormalize(input.normalWS);
    context.referenceUpWS = ResolveWaterReferenceUpWS(input.positionWS, input.objectUpWS);
    context.planarMapping = BuildPlanarWaterMapping(
        context.positionWS,
        context.mappingPositionWS,
        context.geometricNormalWS
    );

    return context;
}

#endif
