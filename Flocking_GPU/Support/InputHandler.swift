import MetalKit

enum KEY_CODES: Int {
    case Key_A = 0
    case Key_B = 11
    case Key_C = 8
    case Key_D = 2
    case Key_E = 14
    case Key_F = 3
    case Key_G = 5
	case Key_H = 4
	case Key_I = 34
	case Key_J = 38
	case Key_K = 40
	case Key_L = 37
	case Key_M = 46
	case Key_N = 45
	case Key_O = 31
	case Key_P = 35
	case Key_Q = 12
    case Key_R = 15
    case Key_S = 1
	case Key_T = 17
	case Key_U = 32
	case Key_V = 9
	case Key_W = 13
	case Key_X = 7
	case Key_Y = 16
	case Key_Z = 6

    case Key_1 = 18
    case Key_2 = 19
    case Key_3 = 20
    case Key_4 = 21
    case Key_5 = 23
    case Key_6 = 22
    case Key_7 = 26
    case Key_8 = 28
    case Key_9 = 25
    case Key_0 = 29

    case Key_Arrow_Up = 126
    case Key_Arrow_Down = 125
    case Key_Arrow_Left = 123
    case Key_Arrow_Right = 124
	
	case Key_Space = 49
	case Key_Esc = 53
}

class InputHandler{
    
    private static var KEY_COUNT = 256
    
    private static var keyList = [Bool].init(repeating: false, count: KEY_COUNT)

	public static func setKeyPressed(key: UInt16, isOn: Bool) {
		//
		if (Int(key) == KEY_CODES.Key_G.rawValue) && (keyList[Int(key)] == false) { ScenePreference.drawGrid = !ScenePreference.drawGrid }
		if (Int(key) == KEY_CODES.Key_Space.rawValue) && (keyList[Int(key)] == false) { ScenePreference.pauseAnimation = !ScenePreference.pauseAnimation }
		if (Int(key) == KEY_CODES.Key_X.rawValue) && (keyList[Int(key)] == false) { ScenePreference.showParameterChanges = !ScenePreference.showParameterChanges }
		if (Int(key) == KEY_CODES.Key_Z.rawValue) && (keyList[Int(key)] == false) { ScenePreference.showAllParameters = !ScenePreference.showAllParameters }
		
		if (Int(key) == KEY_CODES.Key_C.rawValue) && (keyList[Int(key)] == false) {
			ScenePreference.searchMethod += 1
			if (ScenePreference.searchMethod == 4) {
				ScenePreference.searchMethod = 1
			}
			if (ScenePreference.searchMethod == 1) { print("Basic search method") }
			if (ScenePreference.searchMethod == 2) { print("Octree search method") }
			if (ScenePreference.searchMethod == 3) { print("Neighbourhood Grid search method") }
		}

		//
		keyList[Int(key)] = isOn
	}
	
	public static func isKeyPressed(key: KEY_CODES)->Bool {
		return keyList[Int(key.rawValue)] == true
	}
    
}

