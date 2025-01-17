#ifndef __STANDARDSURFACE_INCLUDE__
#define __STANDARDSURFACE_INCLUDE__
#include "VirtualTexture.cginc"
	struct Input {
			float2 uv_MainTex;
			float3 viewDir;
			float3 worldPos;
			#ifdef USE_UV2
			float2 uv2;
			#endif
		};
cbuffer UnityPerMaterial
{
    float _SpecularIntensity;
		float _MetallicIntensity;
    float4 _EmissionColor;
		float _Occlusion;
		float4 _TileOffset;
		float _Glossiness;
		float4 _Color;
		float _EmissionMultiplier;
		float _Cutoff;
		float _ClearCoatSmoothness;
		float _ClearCoat;
		#ifdef TESSELLATION_SHADER
		float _MinDist;
		float _MaxDist;
		float _Tessellation;
		#endif
		float _HeightmapIntensity;
		float2 _NormalIntensity;
		int _DecalLayer;
		float4 _SecondaryTileOffset;
}

		sampler2D _BumpMap;
		sampler2D _SpecularMap;
		sampler2D _MainTex; 
		sampler2D _EmissionMap;
		sampler2D _PreIntDefault;
		sampler2D _SecondaryMainTex;
		sampler2D _SecondaryBumpMap;
		sampler2D _SecondarySpecularMap;
		Texture2D<float> _HeightMap; SamplerState sampler_HeightMap;

float3 ProcessNormal(float4 value)
{
    value.x *= value.w > 0.01 ? value.w : 1;
    float3 n;
    n.xy = value.xy * 2 - 1;
    n.z = sqrt(1 - dot(n.xy, n.xy));
    return n;
}
Texture2DArray<float4> _VirtualMainTex; SamplerState sampler_VirtualMainTex;
Texture2DArray<float2> _VirtualBumpMap; SamplerState sampler_VirtualBumpMap;
Texture2DArray<float2> _VirtualSMMap; SamplerState sampler_VirtualSMMap;
Texture2D<float4> _TerrainVTIndexTex;
float4 _TerrainVTIndexTex_TexelSize;

		float surf (Input IN, inout SurfaceOutputStandardSpecular o) {
			float2 originUv = IN.uv_MainTex;
			float2 uv = originUv * _TileOffset.xy + _TileOffset.zw;
			float height = _HeightMap.SampleLevel(sampler_HeightMap, uv, 0);
			#ifndef TESSELLATION_SHADER
			uv += ParallaxOffset(height, _HeightmapIntensity,IN.viewDir);
			#endif
#if LIT_ENABLE
			float4 spec = tex2D(_SpecularMap,uv);
			float4 c =  tex2D (_MainTex, uv);
			o.Normal = ProcessNormal( tex2D(_BumpMap,uv));
			#ifdef USE_SECONDARY_MAP
			float2 secUV = originUv * _SecondaryTileOffset.xy + _SecondaryTileOffset.zw;
			float4 secondCol = tex2D(_SecondaryMainTex, secUV); 	
			c.xyz = lerp(c.xyz, secondCol.xyz, secondCol.w);
			o.Normal = lerp(o.Normal, ProcessNormal(tex2D(_SecondaryBumpMap, secUV)), secondCol.w);
			spec.xyz = lerp(spec.xyz, tex2D(_SecondarySpecularMap, secUV).xyz, secondCol.w);
			#else
			#ifdef USE_VT_BLEND
			float4 virtualUV = WorldPosToUV(IN.worldPos.xz);
			float3 vtUV = GetVirtualTextureUV(_TerrainVTIndexTex, _TerrainVTIndexTex_TexelSize, virtualUV.xy, virtualUV.zw);
			float4 secondCol = _VirtualMainTex.SampleLevel(sampler_VirtualMainTex, vtUV, 0);
			float3 secondNormal;
			secondNormal.xy = _VirtualBumpMap.SampleLevel(sampler_VirtualBumpMap, vtUV, 0);
			secondNormal.z = sqrt(1 - dot(secondNormal.xy, secondNormal.xy));
			float2 sm = _VirtualSMMap.SampleLevel(sampler_VirtualSMMap, vtUV, 0);
			float lerpValue = pow(saturate(0.1 * (10 - IN.worldPos.y)), 2.2);
			c.xyz = lerp(c.xyz, secondCol.xyz, lerpValue);
			spec.z = lerp(spec.z, secondCol.w, lerpValue);
			spec.xy = lerp(spec.xy, sm, lerpValue);
			o.Normal = lerp(o.Normal, secondNormal, lerpValue);
			#endif
			#endif
			
			o.Albedo = c.rgb;

			o.Albedo *= _Color.rgb;
			o.Alpha = 1;
			o.Occlusion = lerp(1, spec.b, _Occlusion);
			float metallic =  _MetallicIntensity * spec.g;
			o.Specular = lerp(_SpecularIntensity, o.Albedo, metallic); 
			o.Albedo *= lerp(1 - _SpecularIntensity, 0, metallic);
			o.Smoothness = _Glossiness * spec.r;
			#else
			o = (SurfaceOutputStandardSpecular)0;
#endif
#ifdef USE_SECONDARY_MAP
			o.Emission = _EmissionColor;
#else
			o.Emission = _EmissionColor * tex2D(_EmissionMap, uv) * _EmissionMultiplier;
#endif
			return height;
		}

#ifdef TESSELLATION_SHADER
void VertexOffset(inout float4 vertex, float3 normal, float2 uv)
{
	vertex.xyz += _HeightMap.SampleLevel(sampler_HeightMap, uv * _TileOffset.xy + _TileOffset.zw, 0) * normal * _HeightmapIntensity;
}
#endif
#endif