//
//  Trail.swift
//
//  Created by Pieter Hendriks on 12/10/2020.
//

import Foundation
import MetalKit
import simd

struct TrailVertexUniforms {
	var projectionMatrix = matrix_identity_float4x4
	var viewMatrix = matrix_identity_float4x4
}

struct TrailFragmentUniforms {
	var drawColor = SIMD3<Float>(1.0, 1.0, 1.0)  // default color is white
}


class Trail {
	//
	private var metalDevice : MTLDevice!
	private var vertexBuffer : MTLBuffer!
	private var metalRenderPipelineState : MTLRenderPipelineState!

	var viewMatrix = matrix_identity_float4x4
	var projectionMatrix = matrix_identity_float4x4

	var vertexData : [Float] = []			// this will hold our vertix data
	var numberOfPoints : Int  = 40000		// Maximum number of the total points we want to draw
	var drawIndex : Int = 0					// Number of primitives we will draw
	var drawInterval : Int = 5
	var IntervalCounter : Int = 0

	var drawColor = SIMD3<Float>(1.0, 1.0, 1.0)

	init(metalView: MTKView, metalDevice: MTLDevice, x0 : Float, y0 : Float, z0 : Float, dColor : SIMD3<Float>) {

		// Create our Verextbuffer
		self.metalDevice = metalDevice
		initiateOutputPoints(x0: x0, y0: y0, z0: z0)
		createVertexBuffer()

		// set our line color
		self.drawColor = dColor
		
		//
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		
		//finds the metal file from the main bundle
		let library = metalDevice.makeDefaultLibrary()!
		
		//
		let VertexDescriptor = MDLVertexDescriptor()
		VertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
															format: .float3,
															offset: 0,
															bufferIndex: 0)
		VertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 3)

		let metalVertexDescriptor = MTKMetalVertexDescriptorFromModelIO(VertexDescriptor)
		pipelineDescriptor.vertexDescriptor = metalVertexDescriptor

		//give the names of the function to the pipelineDescriptor
		pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
		pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")

		//set the pixel format to match the MetalView's pixel format
		pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
		pipelineDescriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat

		//make the pipelinestate using the gpu interface and the pipelineDescriptor
		metalRenderPipelineState = try! metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)

	}

	func initiateOutputPoints(x0 : Float, y0 : Float, z0 : Float) {
		for _ in 1...numberOfPoints {
			vertexData += [ x0, y0, z0]
		}

		// Set our second vertex to create an initial line segment
		vertexData[3] = x0
		vertexData[4] = y0
		vertexData[5] = z0 + 0.001

		drawIndex = 2
	}

	func createVertexBuffer() {
		//
		let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
		vertexBuffer = metalDevice.makeBuffer(bytes: vertexData, length: dataSize, options: [])
	}
	
	func AddVertexToTrail(newVertex : SIMD3<Float>) {
		if ( (IntervalCounter == drawInterval) ?? (drawIndex < numberOfPoints) ) {
			vertexData[drawIndex * 3 + 0] = newVertex.x
			vertexData[drawIndex * 3 + 1] = newVertex.y
			vertexData[drawIndex * 3 + 2] = newVertex.z
			drawIndex += 1		// increase our primative draw index
			IntervalCounter = 0	// reset our interval counter

			// update the Vertex Buffer
			createVertexBuffer()
		}
		IntervalCounter += 1
	}

	func Update() {
			createVertexBuffer()
	}
	
	func Draw(commandEncoder: MTLRenderCommandEncoder) {
		// We tell it what render pipeline to use
		commandEncoder.setRenderPipelineState(metalRenderPipelineState)

		// Set our Vertex Uniforms
		var vertexUniforms = TrailVertexUniforms(projectionMatrix: projectionMatrix, viewMatrix: viewMatrix)
		commandEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<TrailVertexUniforms>.size, index: 1)

		var fragmentUniforms = TrailFragmentUniforms(drawColor : drawColor)
		commandEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<TrailFragmentUniforms>.size, index: 0)

		// Encoding the commands
		commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
		commandEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: drawIndex)
	}

}
