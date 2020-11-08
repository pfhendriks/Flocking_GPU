//
//  WaterSurface.swift
//  Flocking_GPU
//
//  Created by Pieter Hendriks on 27/10/2020.
//

import Foundation
import Metal
import MetalKit


struct WaterVertexUniforms {
	var projectionMatrix = matrix_identity_float4x4
	var viewMatrix = matrix_identity_float4x4
	var Time = SIMD3<Float>(0, 0, 0)
	var Constants = SIMD4<Float>(0, 0, 0, 0)
}

struct WaterFragmentUniforms {
	var cameraWorldPosition = SIMD3<Float>(0, 0, 0)
}


class WaterSurface {
	//
	private var waterCenter     = SIMD3<Float>(0.0, 0.0, 0.0)
	private var waterDirectionX = SIMD3<Float>(1.0, 0.0, 0.0)
	private var waterDirectionY = SIMD3<Float>(0.0, 1.0, 0.0)
	private var waterDirectionZ = SIMD3<Float>(0.0, 0.0, 1.0)
	private var waterWidth : Float
	private var waterColor = SIMD3<Float>(1.0, 1.0, 1.0)
	private var waterWidthCount : Int
	
	private var waterTextureName1  : String
	private var waterTextureName2  : String
	private var waterTextureRepeat : Int
	
	var vertexCount: Int = 0

	var waterVertexBuffer:  MTLBuffer!
	var waterPipelineState: MTLRenderPipelineState!
	var waterTexture:       MTLTexture?
	var waterTexture2:      MTLTexture?

	var viewMatrix =       matrix_identity_float4x4
	var projectionMatrix = matrix_identity_float4x4
	var cameraWorldPosition = SIMD3<Float>( 0, 0, 0)


	init (view: MTKView, device: MTLDevice,
		  waterCenter : SIMD3<Float>,
		  width : Float,
		  widthCount : Int,
		  waterDirectionX : SIMD3<Float>,
		  waterDirectionY : SIMD3<Float>,
		  waterColor: SIMD3<Float>,
		  waterTextureName1: String,
		  waterTextureName2: String,
		  waterTextureRepeat: Int) {
		
		// set all internal values
		self.waterWidth         = width
		self.waterWidthCount    = widthCount
		self.waterCenter        = waterCenter
		
		self.waterDirectionX    = waterDirectionX
		self.waterDirectionY    = waterDirectionY
		self.waterDirectionZ    = cross(waterDirectionX, waterDirectionY)		// calculate our normal by determining cross-product of X and Y directions
		
		self.waterColor         = waterColor
		
		self.waterTextureName1  = waterTextureName1
		self.waterTextureName2  = waterTextureName2
		self.waterTextureRepeat = waterTextureRepeat

		// get VertexBuffer
		getVertexBuffer(device: device)
		
		// setup METAL
		let defaultLibrary = device.makeDefaultLibrary()!
		let waterVertexProgram   = defaultLibrary.makeFunction(name: "waterSurface_vertex_shader")
		let waterFragmentProgram = defaultLibrary.makeFunction(name: "waterSurface_fragment_shader")
		
		let waterVertexDescriptor = MDLVertexDescriptor()
		waterVertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
																 format: .float3,
																 offset: MemoryLayout<Float>.size * 0,
																 bufferIndex: 0)
		waterVertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
																 format: .float3,
																 offset: MemoryLayout<Float>.size * 3,
																 bufferIndex: 0)
		waterVertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTangent,
																 format: .float3,
																 offset: MemoryLayout<Float>.size * 6,
																 bufferIndex: 0)
		waterVertexDescriptor.attributes[3] = MDLVertexAttribute(name: MDLVertexAttributeBitangent,
																 format: .float3,
																 offset: MemoryLayout<Float>.size * 9,
																 bufferIndex: 0)
		waterVertexDescriptor.attributes[4] = MDLVertexAttribute(name: MDLVertexAttributeColor,
																 format: .float3,
																 offset: MemoryLayout<Float>.size * 12,
																 bufferIndex: 0)
		waterVertexDescriptor.attributes[5] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
																 format: .float2,
																 offset: MemoryLayout<Float>.size * 15,
																 bufferIndex: 0)
		waterVertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 17)
				
		let waterPipelineStateDescriptor = MTLRenderPipelineDescriptor()
		waterPipelineStateDescriptor.vertexFunction   = waterVertexProgram
		waterPipelineStateDescriptor.fragmentFunction = waterFragmentProgram

		waterPipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
		waterPipelineStateDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat

		let mtlVertexDescriptor = MTKMetalVertexDescriptorFromModelIO(waterVertexDescriptor)
		waterPipelineStateDescriptor.vertexDescriptor = mtlVertexDescriptor

		waterPipelineState = try! device.makeRenderPipelineState(descriptor: waterPipelineStateDescriptor)

		//
		LoadTextures(device: device, vertexDescriptor: waterVertexDescriptor, name1: waterTextureName1, name2: waterTextureName2)

		print("Total vertex count in water surface is \(vertexCount)")

	}
	
	
	func getVertexBuffer(device: MTLDevice) {
		
		// Create vertex data for our grid
		var vertexData: [Float] = []

		//
		let start = waterCenter - 0.5 * waterWidth * (waterDirectionX + waterDirectionY)
		let stepX = waterDirectionX * waterWidth / Float(waterWidthCount)
		let stepY = waterDirectionY * waterWidth / Float(waterWidthCount)

		//
		for i in 0...(waterWidthCount-1) {
			for j in 0...(waterWidthCount-1) {
				//
		
				let vertex1 = getVertices(i: i,   j: j,   start: start, stepX: stepX, stepY: stepY)
				let vertex2 = getVertices(i: i,   j: j+1, start: start, stepX: stepX, stepY: stepY)
				let vertex3 = getVertices(i: i+1, j: j+1, start: start, stepX: stepX, stepY: stepY)
				let vertex4 = getVertices(i: i+1, j: j,   start: start, stepX: stepX, stepY: stepY)
				
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
		waterVertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])
	}

	func getVertices(i : Int, j : Int, start: SIMD3<Float>, stepX: SIMD3<Float>, stepY: SIMD3<Float>) -> [Float] {
		//
		let position = start + Float(i) * stepX + Float(j) * stepY

		// vertex position (x, y, z)
		let x  : Float = position.x
		let y  : Float = position.y
		let z  : Float = position.z
				
		// normalized vertex normal (nx, ny, nz)
		let nx : Float = waterDirectionZ.x
		let ny : Float = waterDirectionZ.y
		let nz : Float = waterDirectionZ.z
				
		// normalized vertex normal (nx, ny, nz)
		let tx : Float = waterDirectionX.x
		let ty : Float = waterDirectionX.y
		let tz : Float = waterDirectionX.z
				
		// normalized vertex normal (nx, ny, nz)
		let bx : Float = waterDirectionY.x
		let by : Float = waterDirectionY.y
		let bz : Float = waterDirectionY.z
				
		// set color
		let r : Float = waterColor.x
		let g : Float = waterColor.y
		let b : Float = waterColor.z
		
		// vertex tex coord (s, t)
		let s : Float = ( Float(i) / Float(waterWidthCount) ) * Float(waterTextureRepeat)
		let t : Float = ( Float(j) / Float(waterWidthCount) ) * Float(waterTextureRepeat)

		// return our calculated values
		let vertex = [x, y, z, nx, ny, nz, tx, ty, tz, bx, by, bz, r, g, b, s, t]
		
		return vertex
	}


	func Draw(commandEncoder: MTLRenderCommandEncoder, time: Float) {
		//
		cameraWorldPosition = viewMatrix.inverse[3].xyz
		
		let Time = SIMD3<Float>(time, 0.5, 0.3)
		let Constants = SIMD4<Float>(1.5, 0.1, 0.33, 3.10)
		
		//
		commandEncoder.setRenderPipelineState(waterPipelineState)
//		commandEncoder.setTriangleFillMode(.lines)
//		commandEncoder.setCullMode(.front)

		var waterVertexUniforms   = WaterVertexUniforms(projectionMatrix: projectionMatrix, viewMatrix: viewMatrix, Time: Time, Constants: Constants)
		var waterFragmentUniforms = WaterFragmentUniforms(cameraWorldPosition: cameraWorldPosition)

		commandEncoder.setVertexBytes(&waterVertexUniforms, length: MemoryLayout<WaterVertexUniforms>.size, index: 1)
		commandEncoder.setFragmentBytes(&waterFragmentUniforms, length: MemoryLayout<WaterFragmentUniforms>.size, index: 1)

		commandEncoder.setFragmentTexture(waterTexture, index: 0)
		commandEncoder.setFragmentTexture(waterTexture2, index: 1)

		commandEncoder.setVertexBuffer(waterVertexBuffer, offset: 0, index: 0)
		commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount, instanceCount: 1)

//		commandEncoder.setTriangleFillMode(.fill)
	}

	
	func LoadTextures(device: MTLDevice, vertexDescriptor: MDLVertexDescriptor, name1: String, name2: String) {
		let textureLoader = MTKTextureLoader(device: device)
		let options: [MTKTextureLoader.Option : Any] = [.origin : true, .allocateMipmaps : true, .generateMipmaps : true, .SRGB : true]

		waterTexture = try? textureLoader.newTexture(name: name1,
													 scaleFactor: 1.0,
													 bundle: nil,
													 options: options)

		waterTexture2 = try? textureLoader.newTexture(name: name2,
													 scaleFactor: 1.0,
													 bundle: nil,
													 options: options)
	}


}
