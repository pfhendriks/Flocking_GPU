//
//  Renderer.swift
//  Flocking
//
//  Created by Pieter Hendriks on 02/01/2020.
//  Copyright © 2020 Pieter Hendriks. All rights reserved.
//

import Foundation
import MetalKit
import simd


class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
	let depthStencilState: MTLDepthStencilState
	let samplerState: MTLSamplerState

	var viewMatrix = matrix_identity_float4x4
	var projectionMatrix = matrix_identity_float4x4
	var cameraWorldPosition = SIMD3<Float>( 0, 0, 15)

	var time : Float = 0

	let grid : Grid

	let skyDome : SkyDome

	var flock : Flock
	var numberOfMembersInFlock : Int = 1000
		
	
	// This is the initializer for the Renderer class.
    init(view: MTKView, device: MTLDevice) {
        self.device = device
        commandQueue = device.makeCommandQueue()!

		// Create a Depth Stencil
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)!

		//
		let samplerDescriptor = MTLSamplerDescriptor()
		samplerDescriptor.normalizedCoordinates = true
		samplerDescriptor.minFilter = .linear
		samplerDescriptor.magFilter = .linear
		samplerDescriptor.mipFilter = .linear
		samplerState = device.makeSamplerState(descriptor: samplerDescriptor)!

		// Create our flock
		flock = Flock(view: view, device: device, numberOfMembersInFlock: numberOfMembersInFlock)

		// Create our grid
		grid = Grid(view: view, device: device, size: 20, division: 10)
		
		//
		skyDome = SkyDome(view: view, device: device, radius: 1000, sectorCount: 36, stackCount: 36)
		
		//
		super.init()
	}
	

    // mtkView will automatically call this function whenever it wants new content to be rendered.
    func draw(in view: MTKView) {
		// Determine our Projection Matrix
		let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
		projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi / 3, aspectRatio: aspectRatio, nearZ: 0.0, farZ: 100)

		// Increase our time
		let DeltaTime = 1 / Float(view.preferredFramesPerSecond)
		time += DeltaTime
		
		//
		cameraWorldPosition = viewMatrix.inverse[3].xyz
		
		// Update the flocking behavior unless paused
		if(ScenePreference.pauseAnimation == false) {
			flock.Update(deltaTime: DeltaTime, commandQueue: commandQueue)
		}

		let commandBuffer = commandQueue.makeCommandBuffer()!

        if let renderPassDescriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
			// clear the view with light-blue color
			renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(ScenePreference.clearColor.x, ScenePreference.clearColor.y, ScenePreference.clearColor.z, 1.0)

			// generic setup
            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
			commandEncoder.setDepthStencilState(depthStencilState)
			commandEncoder.setFragmentSamplerState(samplerState, index: 0)

			// Draw our grid, when turned on
			if ScenePreference.drawGrid {
				grid.viewMatrix = viewMatrix
				grid.projectionMatrix = projectionMatrix
				grid.Draw(commandEncoder: commandEncoder)
			}
			
			skyDome.viewMatrix = viewMatrix
			skyDome.projectionMatrix = projectionMatrix
			skyDome.Draw(commandEncoder: commandEncoder)

			// Draw our flocking unit
			flock.viewMatrix = viewMatrix
			flock.projectionMatrix = projectionMatrix
			flock.DrawInstanced(commandEncoder: commandEncoder)

			// Present our new drawn screen
			commandEncoder.endEncoding()
            commandBuffer.present(drawable)
			commandBuffer.commit()
		}
    }

	
	
	// mtkView will automatically call this function
    // whenever the size of the view changes (such as resizing the window).
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

}
