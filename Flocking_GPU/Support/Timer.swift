//
//  Timer.swift
//  Flocking
//
//  Created by Pieter Hendriks on 06/05/2020.
//  Copyright © 2020 Pieter Hendriks. All rights reserved.
//

import Foundation
import CoreFoundation
// Usage:    var timer = RunningTimer.init()
// Start:    timer.start() to restart the timer
// Stop:     timer.stop() returns the time and stops the timer
// Duration: timer.duration returns the time
// May also be used with print(" \(timer) ")

struct RunningTimer: CustomStringConvertible {
    var begin : CFAbsoluteTime
    var end : CFAbsoluteTime
	var frames : Int

    init() {
        begin = CFAbsoluteTimeGetCurrent()
        end = 0
		frames = 0
    }
	
    mutating func start() {
        begin = CFAbsoluteTimeGetCurrent()
        end = 0
		frames = 0
    }
	
    mutating func updateFrame() {
		frames += 1
    }
	
	mutating func stop() -> Double {
		if (end == 0) { end = CFAbsoluteTimeGetCurrent() }
		return Double(end - begin)
	}
	
	mutating func average() -> Double {
		if (end == 0) {
			end = CFAbsoluteTimeGetCurrent()
		}
		let elapsed = Double(end - begin)
		let average = elapsed / Double(frames)
		return average
	}

	var duration:CFAbsoluteTime {
		get {
			if (end == 0) { return CFAbsoluteTimeGetCurrent() - begin }
			else { return end - begin }
		}
	}
	
    var description:String {
		let time = duration
		if (time > 100) {return " \(time/60) min"}
		else if (time < 1e-6) {return " \(time*1e9) ns"}
		else if (time < 1e-3) {return " \(time*1e6) µs"}
		else if (time < 1) {return " \(time*1000) ms"}
		else {return " \(time) s"}
    }
}

