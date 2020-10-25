//
//  Flock.swift
//  Flocking
//
//  Created by Pieter Hendriks on 04/01/2020.
//  Copyright © 2020 Pieter Hendriks. All rights reserved.
//

import Foundation
import Metal
import MetalKit
import simd

struct ComputeUniforms {
	//
	var numberOfUnits : Int32
	var viewAngle : Float32
	var viewRadius : Float32
	var separationDistance : Float32
	var separationStrength : Float32
	var cohesionStrength : Float32
	var alignmentStrength : Float32
	var maxDistanceFromCenterOfGridSqrd : Float32
	var centerPullStrength : Float32
	var maxDistanceFromCenterOfFlockSqrd : Float32
	var centerOfFlockPullStrength : Float32
	var deltaTime : Float32
	var centerOfFlock: SIMD3<Float32>
};


class Flock {
	var numberOfUnits : Int = 1
	var unit: [Unit] = []
	
	var L : Float = 1.0
	var W : Float = 0.25

	// Average position of all our units int he floak
	var centerOfFlock =    SIMD3<Float>(0, 0, 0)
	var dimensionOfFlock = SIMD3<Float>(0, 0, 0)
	var maxOfFlock =       SIMD3<Float>(0, 0, 0)
	var minOfFlock =       SIMD3<Float>(0, 0, 0)

	// Set parameters for field of view for our units
	let viewAngle = cos(120 * Float.pi / 180)
	var viewRadius : Float = 1.2

	var cohesionStrength   : Float = 8
	var alignmentStrength  : Float = 8
	var separationStrength : Float = 8
	var separationDistance : Float = 1.0

	var centerPullStrength              : Float = 0.05	// Factor to scale the pull toward the center of our grid
	var maxDistanceFromCenterOfGrid     : Float = 1
	let maxDistanceFromCenterOfGridSqrd : Float
	
	var centerOfFlockPullStrength        : Float = 0.025	// Factor to scale the pull toward the flock center
	var maxDistanceFromCenterOfFlock     : Float = 0.0
	let maxDistanceFromCenterOfFlockSqrd : Float

	// Our Metal variables
    let device: MTLDevice
	var unitVertexBuffer: MTLBuffer!
	var vertexCount = Int(0)
	var unitPipelineState: MTLRenderPipelineState!
	var unitMesh: MTKMesh?
	var baseColorTexture: MTLTexture?
	var bumpColorTexture: MTLTexture?

	var computeState: MTLComputePipelineState!

	var positionArray     : [SIMD3<Float>] = []
	var velocityArray     : [SIMD3<Float>] = []
	var maxVelocityArray  : [SIMD3<Float>] = []

	var positionBuffer     : MTLBuffer!
	var velocityBuffer     : MTLBuffer!
	var maxVelocityBuffer  : MTLBuffer!
	var positionOutBuffer  : MTLBuffer!
	var velocityOutBuffer  : MTLBuffer!

	var perInstanceVertexUniforms : [UnitPerInstanceVertexUniform]!
	var perInstanceVertexUniformsBuffer : MTLBuffer!

	var viewMatrix = matrix_identity_float4x4
	var projectionMatrix = matrix_identity_float4x4
	var cameraWorldPosition = SIMD3<Float>( 0, 0, 0)
	
	var time : Float = 0
	
	var trail1 : Trail!
	
	
	//MARK: INITIALIZING
	init (view: MTKView, device: MTLDevice, numberOfMembersInFlock : Int) {
		// Initialize the parameters for our calculations
		maxDistanceFromCenterOfGridSqrd  = maxDistanceFromCenterOfGrid  * maxDistanceFromCenterOfGrid
		maxDistanceFromCenterOfFlockSqrd = maxDistanceFromCenterOfFlock * maxDistanceFromCenterOfFlock

		// Setup Metal
		self.device = device
		let defaultLibrary = device.makeDefaultLibrary()!
		let unitVertexProgram   = defaultLibrary.makeFunction(name: "Instanced_unit_vertex_main")
		let unitFragmentProgram = defaultLibrary.makeFunction(name: "unit_fragment_main")
		
        let unitVertexDescriptor = MDLVertexDescriptor()
        unitVertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
																format: .float3,
																offset: 0,
																bufferIndex: 0)
        unitVertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
																format: .float3,
																offset: MemoryLayout<Float>.size * 3,
																bufferIndex: 0)
		unitVertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
																format: .float2,
																offset: MemoryLayout<Float>.size * 6,
																bufferIndex: 0)
        unitVertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 8)
				
		let unitPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        unitPipelineStateDescriptor.vertexFunction = unitVertexProgram
        unitPipelineStateDescriptor.fragmentFunction = unitFragmentProgram

		unitPipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
		unitPipelineStateDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat

		let mtlVertexDescriptor = MTKMetalVertexDescriptorFromModelIO(unitVertexDescriptor)
		unitPipelineStateDescriptor.vertexDescriptor = mtlVertexDescriptor
		unitPipelineState = try! device.makeRenderPipelineState(descriptor: unitPipelineStateDescriptor)
		
		self.numberOfUnits = numberOfMembersInFlock
		CreateInstanceBuffers()
				
		// Initialize the units in our flock
		for i in 0...(numberOfMembersInFlock - 1) {
			let P = SIMD3<Float>( Float.random(in: -5.0 ..< 5.0), Float.random(in: -5.0 ..< 5.0), Float.random(in: -5.0 ..< 5.0) )
			let V = 5.0 * simd_normalize( SIMD3<Float>( Float.random(in: -1.0 ..< 1.0), Float.random(in: -1.0 ..< 1.0), Float.random(in: -1.0 ..< 1.0) ) )
			let minSpeed = Float.random(in: 0.3 ..< 0.6)
			let maxSpeed = Float.random(in: 5.0 ..< 20.0)
			let maxAccel = Float(8)
			let newUnit = Unit( Position : P, Velocity : V, MinSpeed : minSpeed, MaxSpeed : maxSpeed, ID : i )
			unit.append(newUnit)
			
			let Vmax = SIMD3<Float>(maxSpeed, minSpeed, maxAccel)
			//
			positionArray.append(P)
			velocityArray.append(V)
			maxVelocityArray.append(Vmax)
		}
		
		trail1 = Trail(metalView: view, metalDevice: device, x0: unit[0].Pos.x, y0: unit[0].Pos.y, z0: unit[0].Pos.z, dColor: SIMD3<Float>(1.0, 0.0, 0.0) )
	
		// Load our compute Shader
		let computeFn = defaultLibrary.makeFunction(name: "Flocking")!
		computeState = try! device.makeComputePipelineState(function: computeFn)
		
		// Load fish obj from file
		LoadObjFromFile(device: device, vertexDescriptor: unitVertexDescriptor)

		// Print key shortcuts
		printShortcuts()
	}
	
	func CreateInstanceBuffers() {
		//
		perInstanceVertexUniforms = [UnitPerInstanceVertexUniform](repeatElement(UnitPerInstanceVertexUniform(), count: numberOfUnits))
		perInstanceVertexUniformsBuffer = device.makeBuffer(length: perInstanceVertexUniforms.count * MemoryLayout<UnitPerInstanceVertexUniform>.stride, options: [])
	}
	
	func UpdateInstanceBuffers() {
		var pointer = perInstanceVertexUniformsBuffer.contents().bindMemory(to: UnitPerInstanceVertexUniform.self, capacity: perInstanceVertexUniforms.count)
		for i in 0...(numberOfUnits-1) {
			unit[i].updateMatrices()
			pointer.pointee.modelMatrix = unit[i].modelMatrix
			pointer.pointee.normalMatrix = unit[i].modelMatrix.normalMatrix
			pointer.pointee.time = SIMD3<Float>(time, unit[i].timeOffset, unit[i].motionSpeed)
			pointer = pointer.advanced(by: 1)
		}
	}
	
	func DrawInstanced(commandEncoder: MTLRenderCommandEncoder) {
		cameraWorldPosition = viewMatrix.inverse[3].xyz

		let ambientLightColor = SIMD3<Float>(0.02, 0.02, 0.02)

		let lv = Float(0.8)
		
		let light0 = Light(worldPosition: SIMD3<Float>( 0, 35, 0), color: SIMD3<Float>( lv, lv, lv) )
		let light1 = Light(worldPosition: SIMD3<Float>( 5, 35, 5), color: SIMD3<Float>( lv, lv, lv) )
		let light2 = Light(worldPosition: SIMD3<Float>(-5, 35, 5), color: SIMD3<Float>( lv, lv, lv) )

		//
		if (ScenePreference.drawTrail) {
			trail1.viewMatrix = viewMatrix
			trail1.projectionMatrix = projectionMatrix
			trail1.Draw(commandEncoder: commandEncoder)
		}

		// do all our setup which is the same for all the units
		commandEncoder.setRenderPipelineState(unitPipelineState)

		var sceneVertexUniforms = UnitSceneVertexUniform(projectionMatrix: projectionMatrix,
														 viewMatrix: viewMatrix )

		var fragmentUniforms = UnitFragmentUniform(cameraWorldPosition: cameraWorldPosition,
												   ambientLightColor: ambientLightColor,
												   light0: light0,
												   light1: light1,
												   light2: light2)

		UpdateInstanceBuffers()

		let fishVertexBuffer = unitMesh?.vertexBuffers.first!
		let submesh = unitMesh!.submeshes[0]
		commandEncoder.setVertexBuffer(fishVertexBuffer?.buffer, offset: fishVertexBuffer!.offset, index: 0)
		commandEncoder.setVertexBuffer(perInstanceVertexUniformsBuffer, offset: 0, index: 1)
		commandEncoder.setVertexBytes(&sceneVertexUniforms, length: MemoryLayout<UnitSceneVertexUniform>.size, index: 2)
		commandEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<UnitFragmentUniform>.size, index: 0)
		commandEncoder.setFragmentTexture(baseColorTexture, index: 0)
		commandEncoder.setFragmentTexture(bumpColorTexture, index: 1)
		commandEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
											 indexCount: submesh.indexCount,
											 indexType: submesh.indexType,
											 indexBuffer: submesh.indexBuffer.buffer,
											 indexBufferOffset: submesh.indexBuffer.offset,
											 instanceCount: numberOfUnits)
	}

	
	func Update(deltaTime: Float, commandQueue: MTLCommandQueue) {
		// Check for key input
		CheckKeyInput()
		
		// Calculate total time elapsed
		time += deltaTime
		
		//
		centerOfFlock = SIMD3<Float>(0.0, 0.0, 0.0)
		for i in 0...(numberOfUnits-1) {
			positionArray[i] = unit[i].Pos
			velocityArray[i] = unit[i].Vel

			// calculate center of the flock location
			centerOfFlock += unit[i].Pos;
		}
		centerOfFlock = centerOfFlock/Float(numberOfUnits)

		let commandBuffer = commandQueue.makeCommandBuffer()!
		let computeEncoder = commandBuffer.makeComputeCommandEncoder()!

		//
		computeEncoder.setComputePipelineState(computeState)


		positionBuffer = device.makeBuffer(bytes: positionArray,
										   length: MemoryLayout<SIMD3<Float>>.size * numberOfUnits,
										   options: .storageModeShared)

		velocityBuffer = device.makeBuffer(bytes: velocityArray,
										   length: MemoryLayout<SIMD3<Float>>.size * numberOfUnits,
										   options: .storageModeShared)
		
		maxVelocityBuffer = device.makeBuffer(bytes: maxVelocityArray,
											  length: MemoryLayout<SIMD3<Float>>.size * numberOfUnits,
											  options: .storageModeShared)

		positionOutBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.size * numberOfUnits,
											  options: .storageModeShared)

		velocityOutBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.size * numberOfUnits,
											  options: .storageModeShared)

		
		computeEncoder.setBuffer(positionBuffer,     offset: 0, index: 1)
		computeEncoder.setBuffer(velocityBuffer,     offset: 0, index: 2)
		computeEncoder.setBuffer(maxVelocityBuffer,  offset: 0, index: 3)
		computeEncoder.setBuffer(positionOutBuffer,  offset: 0, index: 4)
		computeEncoder.setBuffer(velocityOutBuffer,  offset: 0, index: 5)

		var computeUniforms = ComputeUniforms(numberOfUnits: Int32(numberOfUnits),
											  viewAngle: Float32(viewAngle),
											  viewRadius: Float32(viewRadius),
											  separationDistance: Float32(separationDistance),
											  separationStrength: Float32(separationStrength),
											  cohesionStrength: Float32(cohesionStrength),
											  alignmentStrength: Float32(alignmentStrength),
											  maxDistanceFromCenterOfGridSqrd: Float32(maxDistanceFromCenterOfGridSqrd),
											  centerPullStrength: Float32(centerPullStrength),
											  maxDistanceFromCenterOfFlockSqrd: Float32(maxDistanceFromCenterOfFlockSqrd),
											  centerOfFlockPullStrength: Float32(centerOfFlockPullStrength),
											  deltaTime: Float32(deltaTime),
											  centerOfFlock: centerOfFlock)

		computeEncoder.setBytes(&computeUniforms, length: MemoryLayout<ComputeUniforms>.size, index: 0)
	
		let threadsPerGrid = MTLSize(width: numberOfUnits, height: 1, depth: 1)
		let maxThreadPerThreadgroup = computeState.maxTotalThreadsPerThreadgroup
		let threadsPerThreadgroup = MTLSize(width: maxThreadPerThreadgroup, height: 1, depth: 1)
		computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
		
		computeEncoder.endEncoding()
		commandBuffer.commit()
		commandBuffer.waitUntilCompleted()

		var positionOutBufferPointer  = positionOutBuffer?.contents().bindMemory(to: SIMD3<Float>.self, capacity: MemoryLayout<Float>.size * numberOfUnits)
		var velocityOutBufferPointer  = velocityOutBuffer?.contents().bindMemory(to: SIMD3<Float>.self, capacity: MemoryLayout<Float>.size * numberOfUnits)
		
		for i in 0...(numberOfUnits-1) {
			let newPos = positionOutBufferPointer!.pointee
			let newVel = velocityOutBufferPointer!.pointee
			positionOutBufferPointer = positionOutBufferPointer?.advanced(by: 1)
			velocityOutBufferPointer = velocityOutBufferPointer?.advanced(by: 1)
			
			// store our calculated positiona and velocity
			unit[i].Pos = newPos
			unit[i].Vel = newVel
		}
		
		// update our trail on the first unit
		if (ScenePreference.drawTrail) {
			trail1.AddVertexToTrail(newVertex: unit[0].Pos)
		}
	}
	
		
	func CalculateFlockingAccelerationsBasic(i : Int) {
				// Initialize
				var N = 0
				var Pave = SIMD3<Float>(0, 0, 0)
				var Vave = SIMD3<Float>(0, 0, 0)

				unit[i].accSeparation = SIMD3<Float>(0, 0, 0)
				unit[i].accCohesion   = SIMD3<Float>(0, 0, 0)
				unit[i].accAlignment  = SIMD3<Float>(0, 0, 0)

				//position of the current unit being cosidered
				let posUnit = unit[i].Pos
				
				// Our normalized velocity vector
				let v = simd_normalize( unit[i].Vel )

				// iterate through all the other units in the flock to determine its neighbors and their influence
				for j in 0...(numberOfUnits-1) {
					if (i != j) {
						// Calculate the normalized vector from our unit to its potential neighbor
						let posNeightbor = unit[j].Pos
						let d = posNeightbor - posUnit
						let dLength = simd_length(d)
						let dNorm = simd_normalize(d)
						
						// Check if the angle between v and d vectors is within our field of view
						let vdDot = simd_dot(v, dNorm)
						if (vdDot >= viewAngle) {
							//check if the potential neighbor is within the minimum radius
							if (dLength <= viewRadius) {
								//
								N += 1
								Pave += unit[j].Pos
								Vave += unit[j].Vel
							}
							// Check for SEPARATION RULE
							if (dLength < separationDistance) {
								//
								unit[i].accSeparation += -dNorm * separationStrength
							}
						}
					}
				}

				// Determine various forces
				if (N>0) {
					// Determine COHESION FORCE
					// Calculate the average position of its neighbors
					Pave = Pave / Float(N)
					var u = simd_normalize( Pave - unit[i].Pos )

					//
					var vudot = simd_dot(v, u)
					unit[i].accCohesion = acos(vudot) * u * cohesionStrength
	//				unit[i].accCohesion = acos(vudot) * unit[i].XAxisLocal * cohesionStrength
				
					// Determine ALIGNMENT FORCE
					Vave = Vave / Float(N)
					u = simd_normalize(Vave)
					vudot = simd_dot(v, u)
					unit[i].accAlignment = acos(vudot) * u * alignmentStrength
				}
	}
	

	func CalculateCenterAccelerations(i : Int) {
		// Reset acelleration to center of our grid and to the centerOfFlock to zero
		var accCenterOfGrid	 = SIMD3<Float>(0, 0, 0)
		var accCenterOfFlock = SIMD3<Float>(0, 0, 0)

		// determine the accelleration to pull the units to the center of our grid
		let PosToCenterOfGrid = unit[i].Pos
		let distToCenterOfGridSqrd = simd_length_squared(PosToCenterOfGrid)
		
		// calculate pulling accelleration to the center of our grid
		if (distToCenterOfGridSqrd > maxDistanceFromCenterOfGridSqrd) {
			let dirToCenterOfGrid = simd_normalize(PosToCenterOfGrid)
			accCenterOfGrid = -dirToCenterOfGrid * (distToCenterOfGridSqrd - maxDistanceFromCenterOfGridSqrd) * centerPullStrength
			unit[i].accCenter = accCenterOfGrid
		}

		// determine the accelleration to pull the units to the center of the flock
		let PosToCenterOfFlock = unit[i].Pos - centerOfFlock
		let distToCenterOfFlockSqrd = simd_length_squared(PosToCenterOfFlock)
					
		// calculate pulling accelleration to the center of all the units in the flock
		let dirToCenterOfFlock = simd_normalize(PosToCenterOfFlock)
		accCenterOfFlock = -dirToCenterOfFlock * (distToCenterOfFlockSqrd - maxDistanceFromCenterOfFlockSqrd) * centerOfFlockPullStrength
		
		// Store the acceleratons to the unit considered
		unit[i].accCenter = accCenterOfGrid + accCenterOfFlock
	}



	func CheckKeyInput() {
 // Do we want to print when keys are pressed?
		let showParameterChanges : Bool = ScenePreference.showParameterChanges
		
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_Q)) {
			cohesionStrength = cohesionStrength + 0.25
			if showParameterChanges { print("cohesionStrength = \(cohesionStrength)") }
		}
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_A)) {
			cohesionStrength = cohesionStrength - 0.25
			if ( cohesionStrength < 0 ) { cohesionStrength = 0 }
			if showParameterChanges { print("cohesionStrength = \(cohesionStrength)") }
		}
		
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_W)) {
			alignmentStrength = alignmentStrength + 0.25
			if showParameterChanges { print("alignmentStrength = \(alignmentStrength)") }
		}
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_S)) {
			alignmentStrength = alignmentStrength - 0.25
			if ( alignmentStrength < 0 ) { alignmentStrength = 0 }
			if showParameterChanges { print("alignmentStrength = \(alignmentStrength)") }
		}
		
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_E)) {
			separationStrength = separationStrength + 0.25
			if showParameterChanges { print("separationStrength = \(separationStrength)") }
		}
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_D)) {
			separationStrength = separationStrength - 0.25
			if ( separationStrength < 0 ) { separationStrength = 0 }
			if showParameterChanges { print("separationStrength = \(separationStrength)") }
		}

		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_R)) {
			separationDistance = separationDistance + 0.005
			if showParameterChanges { print("separationDistance = \(separationDistance)") }
		}
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_F)) {
			separationDistance = separationDistance - 0.005
			if ( separationDistance < 0 ) { separationDistance = 0 }
			if showParameterChanges { print("separationDistance = \(separationDistance)") }
		}
		
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_Y)) {
			centerPullStrength = centerPullStrength + 0.01
			if showParameterChanges { print("centerPullStrength = \(centerPullStrength)") }
		}
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_H)) {
			centerPullStrength = centerPullStrength - 0.01
			if ( centerPullStrength < 0 ) { centerPullStrength = 0 }
			if showParameterChanges { print("centerPullStrength = \(centerPullStrength)") }
		}
		
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_U)) {
			maxDistanceFromCenterOfGrid = maxDistanceFromCenterOfGrid + 0.1
			if showParameterChanges { print("maxDistanceFromCenterOfGrid = \(maxDistanceFromCenterOfGrid)") }
		}
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_J)) {
			maxDistanceFromCenterOfGrid = maxDistanceFromCenterOfGrid - 0.1
			if ( maxDistanceFromCenterOfGrid < 0 ) { maxDistanceFromCenterOfGrid = 0 }
			if showParameterChanges { print("maxDistanceFromCenterOfGrid = \(maxDistanceFromCenterOfGrid)") }
		}
		
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_I)) {
			centerOfFlockPullStrength = centerOfFlockPullStrength + 0.01
			if showParameterChanges { print("centerOfFlockPullStrength = \(centerOfFlockPullStrength)") }
		}
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_K)) {
			centerOfFlockPullStrength = centerOfFlockPullStrength - 0.01
			if ( centerOfFlockPullStrength < 0 ) { centerOfFlockPullStrength = 0 }
			if showParameterChanges { print("centerOfFlockPullStrength = \(centerOfFlockPullStrength)") }
		}
		
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_O)) {
			maxDistanceFromCenterOfFlock = maxDistanceFromCenterOfFlock + 0.1
			if showParameterChanges { print("maxDistanceFromCenterOfFlock = \(maxDistanceFromCenterOfFlock)") }
		}
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_L)) {
			maxDistanceFromCenterOfFlock = maxDistanceFromCenterOfFlock - 0.1
			if ( maxDistanceFromCenterOfFlock < 0 ) { maxDistanceFromCenterOfFlock = 0 }
			if showParameterChanges { print("maxDistanceFromCenterOfFlock = \(maxDistanceFromCenterOfFlock)") }
		}

		// Change viewRadius
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_Arrow_Up)) {
			viewRadius = viewRadius + 0.05
			if showParameterChanges { print("viewRadius = \(viewRadius)") }
		}
		if(InputHandler.isKeyPressed(key: KEY_CODES.Key_Arrow_Down)) {
			viewRadius = viewRadius - 0.05
			if ( viewRadius < 0 ) { viewRadius = 0 }
			if showParameterChanges { print("viewRadius = \(viewRadius)") }
		}
		
		// Print all parameters
		if (ScenePreference.showAllParameters) {
			print("")
			print("Change cohesionStrength             = \(cohesionStrength)")
			print("Change alignmentStrength            = \(alignmentStrength)")
			print("Change separationStrength           = \(separationStrength)")
			print("Change separationDistance           = \(separationDistance)")
			print("Change centerPullStrength           = \(centerPullStrength)")
			print("Change maxDistanceFromCenterOfGrid  = \(maxDistanceFromCenterOfGrid)")
			print("Change centerOfFlockPullStrength    = \(centerOfFlockPullStrength)")
			print("Change maxDistanceFromCenterOfFlock = \(maxDistanceFromCenterOfFlock)")
			print("Change viewRadius                   = \(viewRadius)")
			
			// Reset showAllParameters
			ScenePreference.showAllParameters = false
		}

		
	}
	
	func printShortcuts() {
		print("Change cohesionStrength             : keys Q / A")
		print("Change alignmentStrength            : keys W / S")
		print("Change separationStrength           : keys E / D")
		print("Change separationDistance           : keys R / F")
		print("Change centerPullStrength           : keys Y / H")
		print("Change maxDistanceFromCenterOfGrid  : keys U / J")
		print("Change centerOfFlockPullStrength    : keys I / K")
		print("Change maxDistanceFromCenterOfFlock : keys O / L")
		print("Change viewRadius                   : keys Up / Down")
		print("")
		print("Toggle grid : key G")
		print("Toggle simulation : key SPACE")
	}

	func makeTexture(device: MTLDevice,
					 width: Int,
					 height: Int,
					 format : MTLPixelFormat) -> (MTLTexture) {
		//
		let textureDescriptor = MTLTextureDescriptor()
		textureDescriptor.storageMode = .managed
		textureDescriptor.usage = [.shaderWrite, .shaderRead]
		textureDescriptor.pixelFormat = format
		textureDescriptor.width = width
		textureDescriptor.height = height
		textureDescriptor.depth = 1
		
		let texture = device.makeTexture(descriptor: textureDescriptor)!
	  
	  return texture
	}

	func LoadObjFromFile(device: MTLDevice, vertexDescriptor: MDLVertexDescriptor) {
		let bufferAllocator = MTKMeshBufferAllocator(device: device)

		let fishURL = Bundle.main.url(forResource: "NewFish", withExtension: "obj")!
		let fishAsset = MDLAsset(url: fishURL, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)

		let textureLoader = MTKTextureLoader(device: device)
		let options: [MTKTextureLoader.Option : Any] = [.origin : true, .allocateMipmaps : true, .generateMipmaps : true, .SRGB : true]

		baseColorTexture = try? textureLoader.newTexture(name: "pez_02_difusa",
														 scaleFactor: 1.0,
														 bundle: nil,
														 options: options)
		
		bumpColorTexture = try? textureLoader.newTexture(name: "pez_02_bump",
														 scaleFactor: 1.0,
														 bundle: nil,
														 options: options)
		
		unitMesh = try! MTKMesh.newMeshes(asset: fishAsset, device: device).metalKitMeshes.first!
		
		print("Total vertex count in fish mesh: \(String(describing: unitMesh?.vertexCount))")

	}

}
