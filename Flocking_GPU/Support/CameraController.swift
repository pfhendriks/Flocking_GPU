//
//  CameraController.swift
//  Flocking
//
//  Created by Pieter Hendriks on 02/01/2020.
//  Copyright © 2020 Pieter Hendriks. All rights reserved.
//


import Foundation
import QuartzCore
import simd

class CameraController {
    var viewMatrix: float4x4 {
        return float4x4(translationBy: SIMD3<Float>(0, 0, -radius)) *
               float4x4(rotationAbout: SIMD3<Float>(1, 0, 0), by: altitude) *
               float4x4(rotationAbout: SIMD3<Float>(0, 1, 0), by: azimuth)
        
    }
    
    var radius: Float = 10
    var sensitivity: Float = 0.01
	var zoomSensitivity: Float = 1 / 150
    let minAltitude: Float = -.pi / 4
    let maxAltitude: Float =  .pi / 2
    
    
    private var altitude: Float = 0
    private var azimuth: Float = 0

    private var lastPoint: NSPoint = .zero
    
    func startedInteraction(at point: NSPoint) {
        lastPoint = point
    }
    
    func dragged(to point: NSPoint) {
        let deltaX = Float(lastPoint.x - point.x)
        let deltaY = Float(lastPoint.y - point.y)
        azimuth  += -deltaX * sensitivity
        altitude += -deltaY * sensitivity
        altitude = min(max(minAltitude, altitude), maxAltitude)
        lastPoint = point
    }
	
	func wheel(to ammount: Float) {
		self.radius -= ammount * zoomSensitivity
		if self.radius < 0.5 { self.radius = 0.5 }
	}
}



extension float4 {
	var xyz: SIMD3<Float> {
		return SIMD3<Float>(x, y, z)
	}
}

extension float4x4 {
	init(scaleBy s: Float) {
		self.init(SIMD4<Float>(s, 0, 0, 0),
				  SIMD4<Float>(0, s, 0, 0),
				  SIMD4<Float>(0, 0, s, 0),
				  SIMD4<Float>(0, 0, 0, 1))
	}
	
	init(rotationAbout axis: SIMD3<Float>, by angleRadians: Float) {
		let x = axis.x, y = axis.y, z = axis.z
		let c = cosf(angleRadians)
		let s = sinf(angleRadians)
		let t = 1 - c
		self.init(SIMD4<Float>( t * x * x + c,     t * x * y + z * s, t * x * z - y * s, 0),
				  SIMD4<Float>( t * x * y - z * s, t * y * y + c,     t * y * z + x * s, 0),
				  SIMD4<Float>( t * x * z + y * s, t * y * z - x * s,     t * z * z + c, 0),
				  SIMD4<Float>(                 0,                 0,                 0, 1))
	}
	
	init(translationBy t: SIMD3<Float>) {
		self.init(SIMD4<Float>(   1,    0,    0, 0),
				  SIMD4<Float>(   0,    1,    0, 0),
				  SIMD4<Float>(   0,    0,    1, 0),
				  SIMD4<Float>(t[0], t[1], t[2], 1))
	}
	
	init(perspectiveProjectionFov fovRadians: Float, aspectRatio aspect: Float, nearZ: Float, farZ: Float) {
		let yScale = 1 / tan(fovRadians * 0.5)
		let xScale = yScale / aspect
		let zRange = farZ - nearZ
		let zScale = -(farZ + nearZ) / zRange
		let wzScale = -2 * farZ * nearZ / zRange
		
		let xx = xScale
		let yy = yScale
		let zz = zScale
		let zw = Float(-1)
		let wz = wzScale
		
		self.init(SIMD4<Float>(xx,  0,  0,  0),
				  SIMD4<Float>( 0, yy,  0,  0),
				  SIMD4<Float>( 0,  0, zz, zw),
				  SIMD4<Float>( 0,  0, wz,  1))
	}

	var normalMatrix: float3x3 {
		let upperLeft = float3x3(self[0].xyz, self[1].xyz, self[2].xyz)
		return upperLeft.transpose.inverse
	}
}

