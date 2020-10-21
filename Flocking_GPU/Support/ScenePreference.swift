//
//  ScenePreference.swift
//  Flocking
//
//  Created by Pieter Hendriks on 02/04/2020.
//  Copyright © 2020 Pieter Hendriks. All rights reserved.
//

import Foundation
import MetalKit


class ScenePreference{
//	static var clearColor = SIMD3<Double>(0.0471, 0.1255, 0.4392)
	static var clearColor = SIMD3<Double>(0.02, 0.06, 0.2)

	public static var drawGrid: Bool = false

	public static var pauseAnimation : Bool = false
	
	public static var showParameterChanges : Bool = false
	
	public static var showAllParameters : Bool = false

	public static var drawTrail : Bool = true

	public static var searchMethod : Int = 1	// Start with Octree search

}
