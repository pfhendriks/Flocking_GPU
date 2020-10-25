//
//  Grid.swift
//  Flocking
//
//  Created by Pieter Hendriks on 03/01/2020.
//  Copyright © 2020 Pieter Hendriks. All rights reserved.
//

import Foundation
import Metal
import MetalKit


struct GridVertexUniforms {
	var projectionMatrix = matrix_identity_float4x4
	var viewMatrix = matrix_identity_float4x4
}

struct GridFragmentUniforms {
	var gridColor = SIMD3<Float>(1.0, 1.0, 1.0)  // default color is white
}


class Grid {
	var gridSizeX : Float
	var gridSizeY : Float
	var gridSizeZ : Float
	
	let gridColor = SIMD3<Float>(0.7, 0.7, 0.9)
	
	let gridVertexBuffer: MTLBuffer!
	var vertexCount: Int

	var gridPipelineState: MTLRenderPipelineState!
	var viewMatrix = matrix_identity_float4x4
	var projectionMatrix = matrix_identity_float4x4


	init (view: MTKView, device: MTLDevice,
		  sizeX : Float, sizeY : Float, sizeZ : Float,
		  divisionX : Int, divisionY : Int, divisionZ : Int) {

		gridSizeX = sizeX
		gridSizeY = sizeY
		gridSizeZ = sizeZ
		
		// Set the size of each unit in the grid
		let dX = gridSizeX / Float(divisionX)
		let dY = gridSizeY / Float(divisionY)
		let dZ = gridSizeZ / Float(divisionZ)
		
		let maxX =  sizeX/2
		let minX = -sizeX/2
		let maxY =  sizeY/2
		let minY = -sizeY/2
		let maxZ =  sizeZ/2
		let minZ = -sizeZ/2

		// Create vertex data for our grid
		var vertexData: [Float] = []
				
		// Determine the total vertex count in our buffer
		vertexCount = ((divisionX+1)*(divisionZ+1) + (divisionY+1)*(divisionZ+1) + (divisionX+1)*(divisionY+1))*2
		print("Total vertex count in grid is \(vertexCount)")
		
		// Horizontal lines
		for iz in 0...divisionZ {
			for iy in 0...divisionY {
				//
				vertexData += [maxX, maxY - Float(iy) * dY, minZ + Float(iz) * dZ]
				vertexData += [minX, maxY - Float(iy) * dY, minZ + Float(iz) * dZ]
			}
			for ix in 0...divisionX {
				vertexData += [minX + Float(ix) * dX, maxY, minZ + Float(iz) * dZ]
				vertexData += [minX + Float(ix) * dX, minY, minZ + Float(iz) * dZ]
			}
		}
		// Vertical lines
		for ix in 0...divisionX {
			for iy in 0...divisionY {
				vertexData += [minX + Float(ix) * dX, minY + Float(iy) * dY, minZ]
				vertexData += [minX + Float(ix) * dX, minY + Float(iy) * dY, maxZ]
			}
		}
		
		let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
		gridVertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])

		//
		let defaultLibrary = device.makeDefaultLibrary()!
		let gridVertexProgram   = defaultLibrary.makeFunction(name: "grid_vertex_shader")
		let gridFragmentProgram = defaultLibrary.makeFunction(name: "grid_fragment_shader")
		
        let gridVertexDescriptor = MDLVertexDescriptor()
        gridVertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
																format: .float3,
																offset: 0,
																bufferIndex: 0)
        gridVertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 3)
				
		let gridPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        gridPipelineStateDescriptor.vertexFunction = gridVertexProgram
        gridPipelineStateDescriptor.fragmentFunction = gridFragmentProgram

		gridPipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
		gridPipelineStateDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat

		let mtlVertexDescriptor = MTKMetalVertexDescriptorFromModelIO(gridVertexDescriptor)
		gridPipelineStateDescriptor.vertexDescriptor = mtlVertexDescriptor

		gridPipelineState = try! device.makeRenderPipelineState(descriptor: gridPipelineStateDescriptor)

	}
	
	convenience init (view: MTKView, device: MTLDevice, size : Float, division : Int) {
		self.init(view: view, device: device, sizeX: size, sizeY: size, sizeZ: size, divisionX: division, divisionY: division, divisionZ: division)
	}
	
	func Draw(commandEncoder: MTLRenderCommandEncoder) {
		//
		commandEncoder.setRenderPipelineState(gridPipelineState)
		
		var vertexUniforms = GridVertexUniforms(projectionMatrix: projectionMatrix, viewMatrix: viewMatrix)
		var fragmentUniforms = GridFragmentUniforms(gridColor: gridColor)
		
		commandEncoder.setVertexBytes(  &vertexUniforms,   length: MemoryLayout<GridVertexUniforms>.size,   index: 1)
		commandEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<GridFragmentUniforms>.size, index: 0)

		commandEncoder.setVertexBuffer(gridVertexBuffer, offset: 0, index: 0)
		commandEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertexCount, instanceCount: 1)
	}
}
