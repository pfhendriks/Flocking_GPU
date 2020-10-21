//
//  FlockingComputeShader.metal
//  Flocking_GPU
//
//  Created by Pieter Hendriks on 21/10/2020.
//

#include <metal_stdlib>
using namespace metal;


struct ComputeUniforms {
	//
};


kernel void Flocking(constant float3 *position [[ buffer(0) ]],
					 constant float3 *velocity [[ buffer(1) ]],
					 device float3 *positionOut [[ buffer(2) ]],
					 device float3 *velocityOut [[ buffer(3) ]],
					 constant ComputeUniforms &uniforms [[buffer(4)]],
					 uint index [[thread_position_in_grid]])
{
	//

}
