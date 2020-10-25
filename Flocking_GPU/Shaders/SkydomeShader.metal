//
//  SkydomeShader.metal
//  Flocking_GPU
//
//  Created by Pieter Hendriks on 25/10/2020.
//

#include <metal_stdlib>
using namespace metal;

struct DomeVertexIn {
	float3 position  [[attribute(0)]];
	float3 normal    [[attribute(1)]];
	float3 color     [[attribute(2)]];
	float2 texCoords [[attribute(3)]];
};

struct DomeVertexOut {
	float4 position [[position]];
//	float3 normal;
	float3 color;
//	float2 texCoords;
};


struct DomeVertexUniforms {
	float4x4 projectionMatrix;
	float4x4 viewMatrix;
};


vertex DomeVertexOut skydome_vertex_shader(DomeVertexIn domeVertexIn [[stage_in]], constant DomeVertexUniforms &uniforms [[buffer(1)]])
{
	DomeVertexOut domeVertexOut;

	float4 viewSpaceVec = uniforms.viewMatrix * float4(domeVertexIn.position, 1);
	float4 positionVec  = uniforms.projectionMatrix * viewSpaceVec;
	
	//pass the output to our fragment shader
	domeVertexOut.position  = positionVec;
//	domeVertexOut.normal = domeVertexIn.normal;
	domeVertexOut.color = domeVertexIn.color;
//	domeVertexOut.texCoords = domeVertexIn.texCoords;
	
	return domeVertexOut;
}

fragment float4 skydome_fragment_shader(DomeVertexOut fragmentIn [[stage_in]])
{
	float3 finalColor;
	finalColor = fragmentIn.color;
	return float4(finalColor, 1);
}
