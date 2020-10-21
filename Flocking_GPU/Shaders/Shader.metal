//
//  Shader.metal
//
//  Created by Pieter Hendriks on 12/10/2020.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;


struct VertexIn {
	float3 position  [[attribute(0)]];
};

struct VertexOut {
	vector_float4 position [[position]];
	vector_float4 color;
};

struct VertexUniforms {
	float4x4 projectionMatrix;
	float4x4 viewMatrix;
};

struct FragmentUniforms {
	float3 drawColor;
};

vertex VertexOut vertexShader(VertexIn vertexIn [[stage_in]], constant VertexUniforms &uniforms [[buffer(1)]])
{
	//
	VertexOut output;
		
	float4 viewSpaceVec = uniforms.viewMatrix * float4(vertexIn.position, 1);
	float4 positionVec  = uniforms.projectionMatrix * viewSpaceVec;

	output.position = positionVec;

	//set the color
	output.color = vector_float4( 1, 1, 1, 1);
//	output.color = uniforms.color;

	return output;
}

fragment vector_float4 fragmentShader(VertexOut interpolated [[stage_in]],
									  constant FragmentUniforms &uniforms [[buffer(0)]])
{
	float3 finalColor;
	finalColor = uniforms.drawColor;

	return float4(finalColor, 1);
}
