//
//  WaterSurfaceShader.metal
//  Flocking_GPU
//
//  Created by Pieter Hendriks on 27/10/2020.
//

#include <metal_stdlib>
using namespace metal;

struct WaterVertexIn {
	float3 position  [[attribute(0)]];
	float3 normal    [[attribute(1)]];
	float3 tangent   [[attribute(2)]];
	float3 bitangent [[attribute(3)]];
	float3 color     [[attribute(4)]];
	float2 texCoords [[attribute(5)]];
};

struct WaterVertexOut {
	float4 position [[position]];
	float3 normal;
	float3 tangent;
	float3 bitangent;
	float2 texCoords1;
	float2 texCoords2;
	float4 viewSpace;
	float3 worldPosition;
};


struct WaterVertexUniforms {
	float4x4 projectionMatrix;
	float4x4 viewMatrix;
	float3   time;
	float4   constants;
};

struct WaterFragmentUniforms {
	float3 cameraWorldPosition;
};


vertex WaterVertexOut waterSurface_vertex_shader(WaterVertexIn waterVertexIn [[stage_in]], constant WaterVertexUniforms &uniforms [[buffer(1)]])
{
	WaterVertexOut waterVertexOut;

	
	// animate our surface
	float3 p    = waterVertexIn.position;
	float  time = uniforms.time.x;
	float  scale1 = uniforms.time.y;
	float  scale2 = uniforms.time.z;

	float W1 = uniforms.constants.x;
	float W2 = uniforms.constants.y;
	float W3 = uniforms.constants.z * W1;
	float W4 = uniforms.constants.w * W2;


	p.y =	waterVertexIn.position.y + W1 * scale1 * sin(p.x * W2 + time) + W3 * scale2 * sin(p.x * W4 + time) + W3 * 2 * scale2 * cos(p.z * W4 + time);
	float4 worldPosition = float4(p, 1);

	// get our normal, tangent and bitangent
	float dydx = W1 * W2 * scale1 * cos(p.x * W2 + time) + W3 * W4 * scale2 * cos(p.x * W4 + time);
	float dydz = -2 * W3 * W4 * scale2 * sin(p.z * W4 + time);

	float3 bitangent(1, dydx, 0);
	bitangent = normalize(bitangent);
	float3 tangent(0, dydz, 1);
	tangent = normalize(tangent);
	float3 normal = normalize( cross(tangent, bitangent) );
	
	//
	float4 viewSpaceVec = uniforms.viewMatrix * worldPosition;
	float4 positionVec  = uniforms.projectionMatrix * viewSpaceVec;
	
	// animate our normal map on the surface by shifting u and v
	float uShift = sin(0.06 * time);
	float vShift = cos(0.03 * time);
	float2 texOffset(uShift, vShift);
	float2 texCoord1 = waterVertexIn.texCoords + texOffset;
	float2 texCoord2 = waterVertexIn.texCoords + 0.5 * texOffset;

	//pass the output to our fragment shader
	waterVertexOut.position      = positionVec;
	waterVertexOut.normal        = normal;
	waterVertexOut.tangent       = tangent;
	waterVertexOut.bitangent     = bitangent;
	waterVertexOut.texCoords1    = texCoord1;
	waterVertexOut.texCoords2    = texCoord2;
	waterVertexOut.worldPosition = worldPosition.xyz;
	waterVertexOut.viewSpace     = viewSpaceVec;
	
	return waterVertexOut;
}



float3 getDomecolor(float z) {
	float3 domeBaseColor(0.02, 0.06, 0.2);
	float3 domeSunColor(1.0, 0.969, 0.627);
	float factorBlue = 1.0;
	float factorYel  = 0.0;
	float zSun = 0.8;
	float f = 0.0;

	if (z<0) {
		f = 1.0 + 0.7 * z;
		factorBlue = f * f * f * f;
	} else {
		if (z>zSun) {
			f = 1 + z;
			factorYel = (z - zSun) / ( 1 - zSun);
			factorBlue = (f * f) * (1 - factorYel);
		} else {
			f = 1.0 + z;
			factorBlue = f * f;
		}
	}
	return factorBlue * domeBaseColor + factorYel * domeSunColor;
}

 
float schlick(float cosine, float index)
{
	float r0 = ( 1 - index ) / ( 1 + index );
	r0 = r0 * r0;
	
	return r0 + ( 1 - r0 ) * pow( 1-cosine, 5);
}

fragment float4 waterSurface_fragment_shader(WaterVertexOut fragmentIn [[stage_in]],
											 constant WaterFragmentUniforms &uniforms [[buffer(1)]],
											 texture2d<float, access::sample> waterTexture1 [[texture(0)]],
											 texture2d<float, access::sample> waterTexture2 [[texture(1)]],
											 sampler colorSampler [[sampler(0)]])
{
	// sample our normal map1
	float3 sampleNormal1 = waterTexture1.sample(colorSampler, fragmentIn.texCoords1).rgb;
	float3 surfaceNormal1 = sampleNormal1 * 2 - 1;

	// sample our normal map2
	float3 sampleNormal2 = waterTexture2.sample(colorSampler, fragmentIn.texCoords2).rgb;
	float3 surfaceNormal2 = sampleNormal2 * 2 - 1;

	float3 surfaceNormal = 0.5 * surfaceNormal1 + 0.25 * surfaceNormal2;

	float3x3 TBN = { fragmentIn.tangent, fragmentIn.bitangent, fragmentIn.normal };

	float3 N = normalize( TBN * surfaceNormal );
	float3 V = normalize( fragmentIn.worldPosition.xyz - uniforms.cameraWorldPosition );


	// refraction calculation
	float eta = 1.3;			// refraction index water
	float3 I = -V;				// camera to position vector
	float3 R = refract(I, N, eta);
	float3 refractColor = getDomecolor(-R.y);

	// final output color
	float3 meshColor = refractColor;


	// Calculate our fog
	bool drawFog = true;
	float FogDensity = 0.015;

	// determine our fog color based on the SkyDome color
	float3 fogColor = getDomecolor(V.y);
	
	float dist = abs(fragmentIn.viewSpace.z);
//	float fogFactor = 1.0 / exp(dist * FogDensity); 							// Exponential Fog
	float fogFactor = 1.0 / exp( (dist * FogDensity) * (dist * FogDensity) ); 	// Exponential Square Fog
	fogFactor = clamp( fogFactor, 0.0, 1.0);

	//
	float3 finalColor(0, 0, 0);
	if (drawFog) {
		finalColor = mix(fogColor, meshColor, fogFactor);
	} else {
		finalColor = meshColor;
	}

	return float4(finalColor, 1);
}

