//
//  ViewController.swift
//  Flocking_GPU
//
//  Created by Pieter Hendriks on 21/10/2020.
//

import Cocoa
import Metal
import MetalKit

class ViewController: NSViewController {
	
	var mtkView: MTKView!
	var renderer: Renderer!
	var cameraController: CameraController!
	
//	var mousePressed: Bool = false

	//MARK: SETUP VIEW
	override func viewDidLoad() {
		super.viewDidLoad()

		// Do any additional setup after loading the view.
		mtkView = MTKView()
		mtkView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(mtkView)
		view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[mtkView]|", options: [], metrics: nil, views: ["mtkView" : mtkView]))
		view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[mtkView]|", options: [], metrics: nil, views: ["mtkView" : mtkView]))
		
		// Connect to the GPU
		let defaultDevice = MTLCreateSystemDefaultDevice()!
		mtkView.device = defaultDevice

		mtkView.colorPixelFormat = .bgra8Unorm_srgb
		mtkView.depthStencilPixelFormat = .depth32Float

		renderer = Renderer(view: mtkView, device: defaultDevice)
		mtkView.delegate = renderer
			
		cameraController = CameraController()
		cameraController.radius = renderer.cameraWorldPosition.z
		renderer.viewMatrix = cameraController.viewMatrix
		
		NSEvent.addLocalMonitorForEvents(matching: .keyUp) { (aEvent) -> NSEvent? in
			self.keyUp(with: aEvent)
			return aEvent
		}

		NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (aEvent) -> NSEvent? in
			self.keyDown(with: aEvent)
			return aEvent
		}
	}
	
	//MARK: HANDLE MOUSE EVENTS
	override func mouseDown(with event: NSEvent) {
		var location = mtkView.convert(event.locationInWindow, from: nil)
		location.y = mtkView.bounds.height - location.y
//		print("pressed mouse at: \(location)")
		cameraController.startedInteraction(at: location)
	}

	override func mouseDragged(with event: NSEvent) {
		var point = mtkView.convert(event.locationInWindow, from: nil)
		point.y = mtkView.bounds.size.height - point.y
		cameraController.dragged(to: point)
		renderer.viewMatrix = cameraController.viewMatrix
	}

	override func scrollWheel(with event: NSEvent) {
		// to be added
		let location = event.scrollingDeltaY
//		print("mouse scroll: \(location)")
		cameraController.wheel(to: Float(location))
		renderer.viewMatrix = cameraController.viewMatrix
	}
		
	
	//MARK: HANDLE KEY EVENTS
	override var acceptsFirstResponder: Bool { return true }
	override func becomeFirstResponder() -> Bool { return true }
	override func resignFirstResponder() -> Bool { return true }
		
	override func keyDown(with event: NSEvent) {
		InputHandler.setKeyPressed(key: event.keyCode, isOn: true)
	}
		
	override func keyUp(with event: NSEvent) {
		InputHandler.setKeyPressed(key: event.keyCode, isOn: false)
	}
	
	
	//
	override var representedObject: Any? {
		didSet {
		// Update the view, if already loaded.
		}
	}


}

