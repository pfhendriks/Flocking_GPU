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
	int numberOfUnits;
	float viewAngle;
	float viewRadius;
	float separationDistance;
	float separationStrength;
	float cohesionStrength;
	float alignmentStrength;
	float maxDistanceFromCenterOfGridSqrd;
	float centerPullStrength;
	float maxDistanceFromCenterOfFlockSqrd;
	float centerOfFlockPullStrength;
};


kernel void Flocking(constant float3 *position     [[ buffer(0) ]],
					 constant float3 *velocity     [[ buffer(1) ]],
					 device   float3 *acceleration [[ buffer(2) ]],
					 constant ComputeUniforms &uniforms [[buffer(3)]],
					 uint index [[thread_position_in_grid]])
{
	int N = 0;
	float3 Pave = 0;
	float3 Vave = 0;
	
	float3 accSeparation = 0;
	float3 accCohesion = 0;
	float3 accAlignment = 0;
	
	float3 centerOfFlock = 0;

	//position of the current unit being cosidered
	float3 posUnit = position[index];
	
	// Our normalized velocity vector
	float3 v = normalize( velocity[index] );

	// iterate through all the other units in the flock to determine its neighbors and their influence
	for (int j = 0; j < (uniforms.numberOfUnits - 1); j++)
	{
		//
		if ( index != uint(j) )
		{
			//
			float3 posNeighbor = position[j];
			float3 d = posNeighbor - posUnit;
			float dLength = length(d);
			float3 dNorm = normalize(d);
			
			// Check if the angle between v and d vectors is within our field of view
			float vdDot = dot(v, dNorm);
			if (vdDot >= uniforms.viewAngle) {
				//check if the potential neighbor is within the minimum radius

				if (dLength <= uniforms.viewRadius) {
					//
					N++;
					Pave += position[j];
					Vave += velocity[j];
				}
				// Check for SEPARATION RULE
				if (dLength <= uniforms.separationDistance ) {
					accSeparation += -dNorm * uniforms.separationStrength;
				}
			}
		}
	}
	
	if (N > 0) {
		// Determine COHESION FORCE
		// Calculate the average position of its neighbors
		Pave = Pave / N;
		float3 u = normalize(Pave - posUnit);
		
		//
		float vudot = dot(v, u);
		accCohesion = acos(vudot) * u * uniforms.cohesionStrength;

		// Determine ALIGNMENT FORCE
		Vave = Vave / N;
		u = normalize(Vave);
		vudot = dot(v, u);
		accAlignment = acos(vudot) * u * uniforms.alignmentStrength;
	}
	
	
	// Reset acelleration to center of our grid and to the centerOfFlock to zero
	float3 accCenterOfGrid = 0;
	float3 accCenterOfFlock = 0;

	// determine the accelleration to pull the units to the center of our grid
//	float3 PosToCenterOfGrid = posUnit;
	float distToCenterOfGridSqrd = length_squared(posUnit);
	
	// // calculate pulling accelleration to the center of our grid
	if (distToCenterOfGridSqrd > uniforms.maxDistanceFromCenterOfGridSqrd) {
		//
		float3 dirToCenterOfGrid = normalize(posUnit);
		accCenterOfGrid = -1 * dirToCenterOfGrid * (distToCenterOfGridSqrd - uniforms.maxDistanceFromCenterOfGridSqrd) * uniforms.centerPullStrength;
	}

	// determine the accelleration to pull the units to the center of the flock
	float3 PosToCenterOfFlock = posUnit - centerOfFlock;
	float distToCenterOfFlockSqrd = length_squared(PosToCenterOfFlock);
				
	// calculate pulling accelleration to the center of all the units in the flock
	float3 dirToCenterOfFlock = normalize(PosToCenterOfFlock);
	accCenterOfFlock = -1 * dirToCenterOfFlock * (distToCenterOfFlockSqrd - uniforms.maxDistanceFromCenterOfFlockSqrd) * uniforms.centerOfFlockPullStrength;

	
	// calculate the total acceleration
	acceleration[index] = accAlignment + accCohesion + accSeparation + accCenterOfGrid + accCenterOfFlock;
}
