//
//  Unit.swift
//  Flocking
//
//  Created by Pieter Hendriks on 04/01/2020.
//  Copyright © 2020 Pieter Hendriks. All rights reserved.
//

import Foundation
import Metal
import MetalKit
import simd


struct UnitPerInstanceVertexUniform {
//	var projectionMatrix = matrix_identity_float4x4
//	var viewMatrix = matrix_identity_float4x4
	var modelMatrix = matrix_identity_float4x4
	var normalMatrix = matrix_identity_float3x3
	var time = SIMD3<Float>(0, 0, 0)
}

struct UnitSceneVertexUniform {
	var projectionMatrix = matrix_identity_float4x4
	var viewMatrix = matrix_identity_float4x4
}

struct UnitFragmentUniform {
	var cameraWorldPosition = SIMD3<Float>(0, 0, 0)
	var ambientLightColor = SIMD3<Float>(0, 0, 0)
	var light0 = Light()
	var light1 = Light()
	var light2 = Light()
}



struct Light {
	var worldPosition = SIMD3<Float>(0, 0, 0)
	var color = SIMD3<Float>(0, 0, 0)
}



class Unit {
	var Pos = SIMD3<Float>(0, 0, 0)		// Position vector of the unit
	var Vel = SIMD3<Float>(0, 0, 1)		// Velocity vector of the unit
	var Acc = SIMD3<Float>(0, 0, 0)		// Accelleration vector of the unit
	var ID : Int

	var numberOfNeighbors : Float = 0
	var accCohesion =	SIMD3<Float>(0, 0, 0)
	var accAlignment =	SIMD3<Float>(0, 0, 0)
	var accSeparation =	SIMD3<Float>(0, 0, 0)
	var accCenter =		SIMD3<Float>(0, 0, 0)
	
	var positionOfNeighbors = SIMD3<Float>( 0, 0,0)
	var velocityOfNeighbors = SIMD3<Float>( 0, 0,0)
	
	var minSpeed : Float				// Minimum speed of the unit
	var maxSpeed : Float				// Maximum speed of the unit
	
	let timeOffset : Float
	let motionSpeed : Float

	var XAxisWorld = SIMD3<Float>(1.0, 0.0, 0.0)
	var YAxisWorld = SIMD3<Float>(0.0, 1.0, 0.0)
	var ZAxisWorld = SIMD3<Float>(0.0, 0.0, 1.0)
	
	var ZAxisLocal = SIMD3<Float>(0.0, 0.0, 0.0)
	var XAxisLocal = SIMD3<Float>(0.0, 0.0, 0.0)
	var YAxisLocal = SIMD3<Float>(0.0, 0.0, 0.0)
	var WorldToLocalMatrix = matrix_identity_float3x3
	var LocalToWorldMatrix = matrix_identity_float4x4
	var scaleMatrix = matrix_identity_float4x4
	
	var modelMatrix = matrix_identity_float4x4

	
	init (Position : SIMD3<Float>, Velocity: SIMD3<Float>, MinSpeed: Float, MaxSpeed: Float, ID : Int) {
		// Set the initial position and velocity for the unit
		self.Pos = Position
		self.Vel = Velocity
		self.minSpeed = MinSpeed
		self.maxSpeed = MaxSpeed
		self.ID = ID
		
		self.timeOffset = Float.random(in: 0.0 ..< 5.0)
		self.motionSpeed = Float.random(in: 8.0 ..< 11.0)
		
		// Setup the initial Modelmatrix
		self.XAxisWorld = SIMD3<Float>(1.0, 0.0, 0.0)
		self.YAxisWorld = SIMD3<Float>(0.0, 1.0, 0.0)
		self.ZAxisWorld = SIMD3<Float>(0.0, 0.0, 1.0)
		
		self.ZAxisLocal = simd_normalize( Vel )
		self.XAxisLocal = simd_normalize( simd_cross(YAxisWorld, ZAxisLocal) )
		self.YAxisLocal = simd_normalize( simd_cross(ZAxisLocal, XAxisLocal) )

		// Scale and position our our fish mesh suh that its center is at the middle and its length is equal to 1.0
		var matScale = matrix_identity_float4x4
		var matTrans = matrix_identity_float4x4
		let vecShift = SIMD3<Float>(0.0, 0.0, -1.0)
			
		matScale = float4x4(scaleBy: -0.125)
		matTrans = float4x4(translationBy: vecShift)
//		var rotAxis  = SIMD3<Float>(-1.0, 0.0, 0.0)
//		matTrans = float4x4(rotationAbout: rotAxis, by: 0.5*Float.pi)

		self.scaleMatrix = matScale * matTrans

		// Set initial Modelmatrix
		updateMatrices()
	}

	
	func updateMatrices() {
		// Calculate Modelmatrix for the unit
		LocalToWorldMatrix = LocalToWorld()
		let TranslatelMatrix = float4x4(translationBy: Pos)
		modelMatrix = TranslatelMatrix * LocalToWorldMatrix * scaleMatrix
	}
	
	
	func Update(deltaTime: Float) {
		// Update the current position of the unit
		Pos += Vel*deltaTime
		
		// Update the velocity of the unit as a result of the overall accelleration
		Acc = accCohesion + accAlignment + accSeparation + accCenter

		let l1 = simd_length(Vel)
		let a1 = Vel + Acc * deltaTime
		let l2 = simd_length(a1)
		
		Vel = a1 * (l1/l2)
//		Vel = Vel + Acc * deltaTime

		// Check whether the velocity is withing the Min-Max range
		let maxSpeedSqrt = maxSpeed * maxSpeed
		let minSpeedSqrt = minSpeed * minSpeed
		let velSqrt = simd_length_squared(Vel)
		if (velSqrt > maxSpeedSqrt) { Vel = maxSpeed * simd_normalize(Vel) }
		if (velSqrt < minSpeedSqrt) { Vel = minSpeed * simd_normalize(Vel) }

		// Reset all accellrations for the next cycle
		accCohesion =	SIMD3<Float>(0, 0, 0)
		accAlignment =	SIMD3<Float>(0, 0, 0)
		accSeparation =	SIMD3<Float>(0, 0, 0)
		accCenter =		SIMD3<Float>(0, 0, 0)
	}
	
		
	func LocalToWorld() -> float4x4 {
		XAxisWorld = SIMD3<Float>(1.0, 0.0, 0.0)
		YAxisWorld = SIMD3<Float>(0.0, 1.0, 0.0)
		ZAxisWorld = SIMD3<Float>(0.0, 0.0, 1.0)
		
		ZAxisLocal = simd_normalize( Vel )
		XAxisLocal = simd_normalize( simd_cross(YAxisWorld, ZAxisLocal) )
		YAxisLocal = simd_normalize( simd_cross(ZAxisLocal, XAxisLocal) )

		let Row1 = SIMD4<Float>( simd_dot(XAxisWorld, XAxisLocal), simd_dot(XAxisWorld, YAxisLocal), simd_dot(XAxisWorld, ZAxisLocal), 0 )
		let Row2 = SIMD4<Float>( simd_dot(YAxisWorld, XAxisLocal), simd_dot(YAxisWorld, YAxisLocal), simd_dot(YAxisWorld, ZAxisLocal), 0 )
		let Row3 = SIMD4<Float>( simd_dot(ZAxisWorld, XAxisLocal), simd_dot(ZAxisWorld, YAxisLocal), simd_dot(ZAxisWorld, ZAxisLocal), 0 )
		let Row4 = SIMD4<Float>(0, 0, 0, 1)
		let LocalToWorldTransformMatrix = simd_matrix_from_rows(Row1, Row2, Row3, Row4)
		
		return LocalToWorldTransformMatrix
	}
	
	
	func WorldToLocal() -> float3x3 {
		XAxisWorld = SIMD3<Float>(1.0, 0.0, 0.0)
		YAxisWorld = SIMD3<Float>(0.0, 1.0, 0.0)
		ZAxisWorld = SIMD3<Float>(0.0, 0.0, 1.0)
		
		ZAxisLocal = simd_normalize( Vel )
		XAxisLocal = simd_normalize( simd_cross(YAxisWorld, ZAxisLocal) )
		YAxisLocal = simd_normalize( simd_cross(ZAxisLocal, XAxisLocal) )

		let Row1 = SIMD3<Float>( simd_dot(XAxisLocal, XAxisWorld), simd_dot(XAxisLocal, YAxisWorld), simd_dot(XAxisLocal, ZAxisWorld) )
		let Row2 = SIMD3<Float>( simd_dot(YAxisLocal, XAxisWorld), simd_dot(YAxisLocal, YAxisWorld), simd_dot(YAxisLocal, ZAxisWorld) )
		let Row3 = SIMD3<Float>( simd_dot(ZAxisLocal, XAxisWorld), simd_dot(ZAxisLocal, YAxisWorld), simd_dot(ZAxisLocal, ZAxisWorld) )
		let WorldToLocalTransformMatrix = simd_matrix_from_rows(Row1, Row2, Row3)
		
		return WorldToLocalTransformMatrix
	}

	
}
