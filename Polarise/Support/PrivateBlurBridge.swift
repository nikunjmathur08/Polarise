//
//  PrivateBlurBridge.swift
//  Polarise
//
//  Created by Nikunj Mathur on 17/11/26.
//

import Foundation
import CoreGraphics

enum PrivateBlurBridge {
    private typealias CGSConnectionID = UInt32
    private typealias CGSMainConnectionIDFunc = @convention(c) () -> CGSConnectionID
    private typealias CGSSetWindowBackgroundBlurRadiusFunc = @convention(c) (CGSConnectionID, Int, Int) -> CGError
    
    private static let symbols: (mainConnectionID: CGSMainConnectionIDFunc, setBlurRadius: CGSSetWindowBackgroundBlurRadiusFunc)? = {
        guard let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY) else {
            return nil
        }
        
        guard let connSym = dlsym(handle, "CGSMainConnectionID"),
              let blurSym = dlsym(handle, "CGSSetWindowBackgroundBlurRadius") else {
            return nil
        }
        
        let mainConn = unsafeBitCast(connSym, to: CGSMainConnectionIDFunc.self)
        let setBlur = unsafeBitCast(blurSym, to: CGSSetWindowBackgroundBlurRadiusFunc.self)
        return (mainConn, setBlur)
    }()
    
    static var isSupported: Bool {
        symbols != nil
    }
    
    @discardableResult
    static func setBlurRadius(_ radius: Int, forWindowNumber windowNumber: Int) -> Bool {
        guard let symbols, windowNumber > 0 else { return false }
        let cid = symbols.mainConnectionID()
        let result = symbols.setBlurRadius(cid, windowNumber, max(0, radius))
        return result == .success
    }
}
