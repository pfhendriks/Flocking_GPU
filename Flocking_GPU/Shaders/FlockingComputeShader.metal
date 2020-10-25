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
	float deltaTime;
	float3 centerOfFlock;
};


kernel void Flocking(constant float3 *position     [[ buffer(1) ]],
					 constant float3 *velocity     [[ buffer(2) ]],
					 constant float3 *maxVelocity  [[ buffer(3) ]],
					 device   float3 *positionOut  [[ buffer(4) ]],
					 device   float3 *velocityOut  [[ buffer(5) ]],
					 constant ComputeUniforms &uniforms [[buffer(0)]],
					 uint index [[thread_position_in_grid]])
{
	int N = 0;
	float3 Pave = 0;
	float3 Vave = 0;
	
	float3 accSeparation = 0;
	float3 accCohesion = 0;
	float3 accAlignment = 0;
	float3 accCenterOfGrid = 0;
	float3 accCenterOfFlock = 0;

	float dT =  uniforms.deltaTime;
	float3 centerOfFlock = uniforms.centerOfFlock;

	//position and velocity of the current unit being cosidered
	float3 posUnit = position[index];
	float3 velUnit = velocity[index];

	// Our normalized velocity vector
	float3 v = normalize( velUnit );

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

	
	// determine the accelleration to pull the units to the center of our grid
	float distToCenterOfGridSqrd = length_squared(posUnit);
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
	
	
	// Encourage each unit to move in one plane
	float3 Updir = 0;
	Updir.y = 1.0;
	float vupdot = dot(v, Updir);
	float3 accHorz = -Updir * vupdot * 0005;
	
	
	// Update the current position of the unit
	float3 newPosUnit = posUnit + (dT * velUnit);

	
	// calculate the total acceleration
	float3 Acc = accAlignment + accCohesion + accSeparation + accCenterOfGrid + accCenterOfFlock + accHorz;
	
	
	// Calculate the new velocity - METHOD 1
/*	float AccL = length(Acc);
	float AccMax = maxVelocity[index].z;
	if (AccL > AccMax) {
		Acc = Acc * ( AccMax / AccL);
	}
	
	float3 newVelUnit = velUnit + Acc * dT;
*/

	// Calculate the new velocity - METHOD 2
	float3 a1 = velUnit + Acc * dT;
	float l1 = length( velUnit );
	float l2 = length(a1);
	
	float3 newVelUnit = a1 * (l1/l2);
	
	// Check whether the velocity is withing the Min-Max range
	float maxV = maxVelocity[index].x;
	float minV = maxVelocity[index].y;

	// Check whether speed is stil within limits
	float maxSpeedSqrt = maxV * maxV;
	float minSpeedSqrt = minV * minV;
	float velSqrt =  length_squared(newVelUnit);
	if (velSqrt > maxSpeedSqrt) {
		newVelUnit = maxV * normalize(newVelUnit);
	}
	if (velSqrt < minSpeedSqrt) {
		newVelUnit = minV * normalize(newVelUnit);
	}
	
	// Output the new position and velocity data
	positionOut[index]  = newPosUnit;
	velocityOut[index]  = newVelUnit;
}
