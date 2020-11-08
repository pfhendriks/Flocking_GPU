//
//  GridShaders.metal
//  Flocking
//
//  Created by Pieter Hendriks on 04/01/2020.
//  Copyright © 2020 Pieter Hendriks. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


struct GridVertexIn {
    float3 position  [[attribute(0)]];
};

struct GridVertexOut {
    float4 position [[position]];
	float4 viewSpace;
};

struct GridVertexUniforms {
	float4x4 projectionMatrix;
	float4x4 viewMatrix;
};

struct GridFragmentUniforms {
	float3 gridColor;
};


vertex GridVertexOut grid_vertex_shader(GridVertexIn gridVertexIn [[stage_in]],
									  constant GridVertexUniforms &uniforms [[buffer(1)]])
{
    GridVertexOut gridVertexOut;

	float4 viewSpaceVec = uniforms.viewMatrix * float4(gridVertexIn.position, 1);
	float4 positionVec  = uniforms.projectionMatrix * viewSpaceVec;
	
	//pass the output to our fragment shader
	gridVertexOut.viewSpace = viewSpaceVec;
	gridVertexOut.position  = positionVec;
	
	return gridVertexOut;
}

fragment float4 grid_fragment_shader(GridVertexOut fragmentIn [[stage_in]],
								   constant GridFragmentUniforms &uniforms [[buffer(0)]])
{
	bool drawFog = true;
	float3 finalColor;

	// Calculate our fog
	float3 fogColor(0.02, 0.06, 0.2);
	float FogDensity = 0.025;
		
	float dist = abs(fragmentIn.viewSpace.z);
	float fogFactor = 1.0 / exp(dist * FogDensity);
//	float fogFactor = 1.0 / exp( (dist * FogDensity) * (dist * FogDensity));
	fogFactor = clamp( fogFactor, 0.0, 1.0);

	if (drawFog) {
		finalColor = mix(fogColor, uniforms.gridColor, fogFactor);
	} else {
		finalColor = uniforms.gridColor;
	}

	return float4(finalColor, 1);
}
