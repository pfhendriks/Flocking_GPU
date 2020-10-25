//
//  SkyDome.swift
//  Flocking_GPU
//
//  Created by Pieter Hendriks on 25/10/2020.
//

import Foundation
import Metal
import MetalKit


struct DomeVertexUniforms {
	var projectionMatrix = matrix_identity_float4x4
	var viewMatrix = matrix_identity_float4x4
}

struct DomeFragmentUniforms {
	var domeColor = SIMD3<Float>(1.0, 1.0, 1.0)  // default color is white
}


class SkyDome {
	private var domeCenter = SIMD3<Float>(0.0, 0.0, 0.0)
	private var domeRadius : Float
//	private var domeColor = SIMD3<Float>(1.0, 1.0, 1.0)
	private var domeColor = SIMD3<Float>(0.02, 0.06, 0.2)

	var domeVertexBuffer: MTLBuffer!
	var vertexCount: Int = 0

	var domePipelineState: MTLRenderPipelineState!
	var viewMatrix = matrix_identity_float4x4
	var projectionMatrix = matrix_identity_float4x4


	init (view: MTKView, device: MTLDevice,
		  radius : Float,
		  sectorCount : Int, stackCount : Int) {
		
		self.domeRadius = radius

		// get VertexBuffer
		getVertexBuffer(device: device, sectorCount : sectorCount, stackCount : stackCount)
		
		// setup METAL
		let defaultLibrary = device.makeDefaultLibrary()!
		let domeVertexProgram   = defaultLibrary.makeFunction(name: "skydome_vertex_shader")
		let domeFragmentProgram = defaultLibrary.makeFunction(name: "skydome_fragment_shader")
		
		let domeVertexDescriptor = MDLVertexDescriptor()
		domeVertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
																format: .float3,
																offset: 0,
																bufferIndex: 0)
		domeVertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
																format: .float3,
																offset: MemoryLayout<Float>.size * 3,
																bufferIndex: 0)
		domeVertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeColor,
																format: .float3,
																offset: MemoryLayout<Float>.size * 6,
																bufferIndex: 0)
		domeVertexDescriptor.attributes[3] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
																format: .float2,
																offset: MemoryLayout<Float>.size * 9,
																bufferIndex: 0)
		domeVertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 11)
				
		let domePipelineStateDescriptor = MTLRenderPipelineDescriptor()
		domePipelineStateDescriptor.vertexFunction   = domeVertexProgram
		domePipelineStateDescriptor.fragmentFunction = domeFragmentProgram

		domePipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
		domePipelineStateDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat

		let mtlVertexDescriptor = MTKMetalVertexDescriptorFromModelIO(domeVertexDescriptor)
		domePipelineStateDescriptor.vertexDescriptor = mtlVertexDescriptor

		domePipelineState = try! device.makeRenderPipelineState(descriptor: domePipelineStateDescriptor)

		print("Total vertex count in skydome is \(vertexCount)")
	}
	
	func getVertexBuffer(device: MTLDevice, sectorCount : Int, stackCount : Int) {
		// Create vertex data for our grid
		var vertexData: [Float] = []

		//
		for i in 0...(stackCount-1) {
			for j in 0...(sectorCount-1) {
				//
		
				let vertex1 = getVertices(i: i,   j: j,   sectorCount: sectorCount, stackCount: stackCount)
				let vertex2 = getVertices(i: i,   j: j+1, sectorCount: sectorCount, stackCount: stackCount)
				let vertex3 = getVertices(i: i+1, j: j+1, sectorCount: sectorCount, stackCount: stackCount)
				let vertex4 = getVertices(i: i+1, j: j,   sectorCount: sectorCount, stackCount: stackCount)

				// first triangle
				vertexData += vertex1
				vertexData += vertex2
				vertexData += vertex3
				// second triangle
				vertexData += vertex1
				vertexData += vertex3
				vertexData += vertex4
				
				//
				vertexCount += 6
			}
		}

		//
		let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
		domeVertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])
	}
	
	func getVertices(i : Int, j : Int, sectorCount : Int, stackCount : Int) -> [Float] {
		//
		let sectorStep : Float = (2 * Float.pi) / Float(sectorCount)
		let stackStep  : Float = Float.pi / Float(stackCount)
		
		let stackAngle  : Float = (Float.pi / 2) - Float(i) * stackStep
		let sectorAngle : Float = Float(j) * sectorStep

		// vertex position (x, y, z)
		let xy : Float = domeRadius * cosf(stackAngle)
				
		let x  : Float = xy * cosf(sectorAngle)
		let y  : Float = xy * sinf(sectorAngle)
		let z  : Float = domeRadius * sinf(stackAngle)
				
		// normalized vertex normal (nx, ny, nz)
		let lengthInv : Float = 1.0 / domeRadius
		let nx : Float = x * lengthInv
		let ny : Float = y * lengthInv
		let nz : Float = z * lengthInv
				
		// vertex tex coord (s, t) range between [0, 1]
		let s : Float = Float(j) / Float(sectorCount)
		let t : Float = Float(i) / Float(stackCount)
				
		// set color
		var factor : Float = 1.0
		if (z<0) {
			let f = 1 + 0.7 * ( z * lengthInv )
			factor = f * f * f * f
		} else {
			let f = 1 + ( z * lengthInv )
			factor = f * f
		}
		
		let r : Float = domeColor.x * factor
		let g : Float = domeColor.y * factor
		let b : Float = domeColor.z * factor

		// return our calculated values
		let vertex = [x, z, -y, nx, nz, -ny, r, g, b, s, t]

		return vertex
	}

	func Draw(commandEncoder: MTLRenderCommandEncoder) {
		//
		commandEncoder.setRenderPipelineState(domePipelineState)
//		commandEncoder.setTriangleFillMode(.lines)

		var vertexUniforms = DomeVertexUniforms(projectionMatrix: projectionMatrix, viewMatrix: viewMatrix)
		commandEncoder.setVertexBytes(  &vertexUniforms,   length: MemoryLayout<DomeVertexUniforms>.size,   index: 1)
		commandEncoder.setVertexBuffer(domeVertexBuffer, offset: 0, index: 0)
		commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount, instanceCount: 1)

//		commandEncoder.setTriangleFillMode(.fill)
	}

}
