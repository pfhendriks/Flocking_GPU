//
//  UnitShader.metal
//  Flocking
//
//  Created by Pieter Hendriks on 04/01/2020.
//  Copyright © 2020 Pieter Hendriks. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct UnitVertexIn {
    float3 position  [[attribute(0)]];
    float3 normal    [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
};

struct UnitVertexOut {
    float4 position [[position]];
	float3 worldNormal;
	float3 worldPosition;
	float4 viewSpace;
    float2 texCoords;
};

struct Light {
	float3 worldPosition;
	float3 color;
};

struct VertexUniforms {
    float4x4 viewProjectionMatrix;
};


struct UnitPerInstanceVertexUniforms {
    float4x4 modelMatrix;
	float3x3 normalMatrix;
	float3   timeVec;
};

struct UnitPerSceneVertexUniforms {
    float4x4 projectionMatrix;
    float4x4 viewMatrix;
};

#define LightCount 3

struct UnitFragmentUniforms {
	float3 cameraWorldPosition;
	float3 ambientLightColor;
	Light lights[LightCount];
};





vertex UnitVertexOut Instanced_unit_vertex_main(UnitVertexIn vertexIn [[ stage_in ]],
												constant UnitPerInstanceVertexUniforms *perInstanceUniforms [[ buffer(1) ]],
												constant UnitPerSceneVertexUniforms &perSceneUniforms [[ buffer(2) ]],
												uint instanceid [[ instance_id ]])
{
	UnitPerInstanceVertexUniforms perInstanceUniform = perInstanceUniforms[instanceid];
	
    UnitVertexOut vertexOut;

	// Animating our fish
	float3 p = vertexIn.position;
	float time = perInstanceUniform.timeVec.z * ( perInstanceUniform.timeVec.x ) + perInstanceUniform.timeVec.y;
	
	//
	float body = (p.z + 0.5);
	p.x = p.x + (vertexIn.position.z)*cos(time + 0.4*body)*0.14;
	
	float4 worldPosition = perInstanceUniform.modelMatrix * float4(p, 1);
	vertexOut.viewSpace = perSceneUniforms.viewMatrix * worldPosition;

	vertexOut.position = perSceneUniforms.projectionMatrix * perSceneUniforms.viewMatrix * worldPosition;
	vertexOut.worldPosition = worldPosition.xyz;
	vertexOut.worldNormal = perInstanceUniform.normalMatrix * vertexIn.normal;

	vertexOut.texCoords = vertexIn.texCoords;

	return vertexOut;
}




fragment float4 unit_fragment_main(UnitVertexOut fragmentIn [[stage_in]],
								   constant UnitFragmentUniforms &uniforms [[buffer(0)]],
								   texture2d<float, access::sample> baseColorTexture [[texture(0)]],
								   texture2d<float, access::sample> bumpColorTexture [[texture(1)]],
								   sampler baseColorSampler [[sampler(0)]] )
{
	bool drawFog = true;

    float3 baseColor = baseColorTexture.sample(baseColorSampler, fragmentIn.texCoords).rgb;
	float  bumpColor = bumpColorTexture.sample(baseColorSampler, fragmentIn.texCoords).r;
	float3 specularColor(1.0, 1.0, 1.0);
	float  specularPower(20);
	
	float3 N = normalize(fragmentIn.worldNormal.xyz);
	float3 V = normalize(uniforms.cameraWorldPosition - fragmentIn.worldPosition.xyz);

	float3 lightingColor(0, 0, 0);
	float3 finalColor(0, 0, 0);
	
	lightingColor = 1 * uniforms.ambientLightColor * baseColor;
	for (int i=0; i < LightCount; i++) {
		float3 L = normalize(uniforms.lights[i].worldPosition - fragmentIn.worldPosition.xyz);
		float3 diffuseIntensity = saturate(dot(N, L));
		float3 H = normalize(L + V);
		float specularBase = saturate(dot(N, H));
		float specularIntensity = powr(specularBase, specularPower);
		float3 lightColor = uniforms.lights[i].color;
		
		lightingColor += 	1 * diffuseIntensity * lightColor * baseColor +
							1 * specularIntensity * lightColor * specularColor * bumpColor;
	}

	// Calculate our fog
	float3 fogColor(0.02, 0.06, 0.2);
	float FogDensity = 0.04;
	
	float dist = abs(fragmentIn.viewSpace.z);
	float fogFactor = 1.0 / exp(dist * FogDensity); // Exponential Fog
//	float fogFactor = 1.0 / exp( (dist * FogDensity) * (dist * FogDensity));  // Exponential Square Fog
	fogFactor = clamp( fogFactor, 0.0, 1.0);

	if (drawFog) {
		finalColor = mix(fogColor, lightingColor, fogFactor);
	} else {
		finalColor = lightingColor;
	}

	return float4(finalColor, 1);
}
